import { db } from "../../../shared/db/sqlite.js";
import { NotFoundError } from "../../../shared/errors/appError.js";
import type { AuthContext } from "../../../shared/middlewares/auth.middleware.js";
import type { ElderlySummary, FamilyInfo, JoinFamilyBody } from "../models/families.model.js";

interface ElderlyRow {
  id: string;
  first_name: string;
  address: string;
  neighborhood: string;
  lat: number;
  lng: number;
  tags: string;
}

function parseTags(raw: string): string[] {
  try {
    const parsed = JSON.parse(raw) as unknown;
    return Array.isArray(parsed) ? parsed.filter((t): t is string => typeof t === "string") : [];
  } catch {
    return [];
  }
}

function elderlyForFamily(familyId: string): ElderlySummary[] {
  const rows = db
    .prepare("SELECT id, first_name, address, neighborhood, lat, lng, tags FROM elderly_profiles WHERE family_id = ?")
    .all(familyId) as ElderlyRow[];
  return rows.map((r) => ({
    id: r.id,
    firstName: r.first_name,
    address: r.address,
    neighborhood: r.neighborhood,
    lat: r.lat,
    lng: r.lng,
    tags: parseTags(r.tags),
  }));
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
};
