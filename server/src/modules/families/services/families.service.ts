import { db } from "../../../shared/db/sqlite.js";
import { NotFoundError, UnauthorizedError } from "../../../shared/errors/appError.js";
import type { AuthContext } from "../../../shared/middlewares/auth.middleware.js";
import type { ElderlySummary, FamilyInfo, JoinFamilyBody, UpdateElderlyBody } from "../models/families.model.js";

interface ElderlyRow {
  id: string;
  user_id: string | null;
  family_id: string | null;
  first_name: string;
  address: string;
  neighborhood: string;
  lat: number;
  lng: number;
  tags: string;
  age: number | null;
  allow_social_connections: number;
  allow_self_profile_edit: number;
}

const ELDERLY_COLUMNS =
  "id, user_id, family_id, first_name, address, neighborhood, lat, lng, tags, age, allow_social_connections, allow_self_profile_edit";

function parseTags(raw: string): string[] {
  try {
    const parsed = JSON.parse(raw) as unknown;
    return Array.isArray(parsed) ? parsed.filter((t): t is string => typeof t === "string") : [];
  } catch {
    return [];
  }
}

function toSummary(r: ElderlyRow): ElderlySummary {
  return {
    id: r.id,
    firstName: r.first_name,
    address: r.address,
    neighborhood: r.neighborhood,
    lat: r.lat,
    lng: r.lng,
    tags: parseTags(r.tags),
    age: r.age,
    allowSocialConnections: r.allow_social_connections === 1,
    allowSelfProfileEdit: r.allow_self_profile_edit === 1,
  };
}

function elderlyForFamily(familyId: string): ElderlySummary[] {
  const rows = db
    .prepare(`SELECT ${ELDERLY_COLUMNS} FROM elderly_profiles WHERE family_id = ?`)
    .all(familyId) as ElderlyRow[];
  return rows.map(toSummary);
}

export const familiesService = {
  me(auth: AuthContext): FamilyInfo {
    if (!auth.familyId) throw new NotFoundError("No perteneces a una familia");
    const family = db
      .prepare("SELECT id, name, family_code FROM families WHERE id = ?")
      .get(auth.familyId) as { id: string; name: string; family_code: string } | undefined;
    if (!family) throw new NotFoundError("Familia no encontrada");

    return {
      id: family.id,
      name: family.name,
      familyCode: family.family_code,
      elderly: elderlyForFamily(family.id),
    };
  },

  join(auth: AuthContext, data: JoinFamilyBody): FamilyInfo {
    const family = db
      .prepare("SELECT id, name, family_code FROM families WHERE family_code = ?")
      .get(data.code.trim().toUpperCase()) as { id: string; name: string; family_code: string } | undefined;
    if (!family) throw new NotFoundError("Código de familia no encontrado");

    db.prepare("UPDATE elderly_profiles SET family_id = ? WHERE user_id = ?").run(family.id, auth.id);

    return {
      id: family.id,
      name: family.name,
      familyCode: family.family_code,
      elderly: elderlyForFamily(family.id),
    };
  },

  /**
   * 3.12/3.16 — PATCH /families/elderly/:id
   * - La familia dueña siempre puede editar (datos + flags de control parental).
   * - El propio adulto mayor solo puede editar sus datos si `allow_self_profile_edit`
   *   está activo, y NUNCA puede modificar sus propios flags de control parental.
   */
  updateElderly(auth: AuthContext, elderlyId: string, data: UpdateElderlyBody): ElderlySummary {
    const row = db
      .prepare(`SELECT ${ELDERLY_COLUMNS} FROM elderly_profiles WHERE id = ?`)
      .get(elderlyId) as ElderlyRow | undefined;
    if (!row) throw new NotFoundError("Adulto mayor no encontrado");

    const isOwnerFamily = auth.role === "family" && auth.familyId !== undefined && auth.familyId === row.family_id;
    const isSelf = auth.role === "elderly" && row.user_id === auth.id;

    if (!isOwnerFamily && !isSelf) {
      throw new UnauthorizedError("No puedes editar este perfil");
    }
    if (isSelf && row.allow_self_profile_edit !== 1) {
      throw new UnauthorizedError("Tu familia tiene desactivada la edición de tu perfil");
    }
    const touchesParentalFlags = data.allowSocialConnections !== undefined || data.allowSelfProfileEdit !== undefined;
    if (isSelf && touchesParentalFlags) {
      throw new UnauthorizedError("Solo tu familia puede cambiar el control parental");
    }

    const sets: string[] = [];
    const values: unknown[] = [];
    if (data.address !== undefined) { sets.push("address = ?"); values.push(data.address.trim()); }
    if (data.neighborhood !== undefined) { sets.push("neighborhood = ?"); values.push(data.neighborhood.trim()); }
    if (data.age !== undefined) { sets.push("age = ?"); values.push(data.age); }
    if (data.tags !== undefined) { sets.push("tags = ?"); values.push(JSON.stringify(data.tags)); }
    if (data.allowSocialConnections !== undefined) {
      sets.push("allow_social_connections = ?");
      values.push(data.allowSocialConnections ? 1 : 0);
    }
    if (data.allowSelfProfileEdit !== undefined) {
      sets.push("allow_self_profile_edit = ?");
      values.push(data.allowSelfProfileEdit ? 1 : 0);
    }

    if (sets.length > 0) {
      db.prepare(`UPDATE elderly_profiles SET ${sets.join(", ")} WHERE id = ?`).run(...values, elderlyId);
    }

    const updated = db
      .prepare(`SELECT ${ELDERLY_COLUMNS} FROM elderly_profiles WHERE id = ?`)
      .get(elderlyId) as ElderlyRow;
    return toSummary(updated);
  },

  /** 3.16 — helper para que otros módulos (chats/matches) consulten el flag social. */
  allowsSocialConnections(elderlyProfileId: string): boolean {
    const row = db
      .prepare("SELECT allow_social_connections FROM elderly_profiles WHERE id = ?")
      .get(elderlyProfileId) as { allow_social_connections: number } | undefined;
    return row?.allow_social_connections === 1;
  },
};
