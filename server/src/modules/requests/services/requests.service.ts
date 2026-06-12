import { v4 as uuidv4 } from "uuid";
import { db } from "../../../shared/db/sqlite.js";
import { AppError, NotFoundError, UnauthorizedError, ValidationError } from "../../../shared/errors/appError.js";
import type { AuthContext } from "../../../shared/middlewares/auth.middleware.js";
import {
  normalizeRequest,
  type ActivityRequestRow,
  type NormalizedRequest,
} from "../../../shared/utils/requestMapper.js";
import type { CreateRequestBody } from "../models/requests.model.js";

const SELECT_WITH_ELDERLY = `
  SELECT r.*, e.first_name AS elderly_name, e.neighborhood
  FROM   activity_requests r
  LEFT JOIN elderly_profiles e ON r.elderly_profile_id = e.id
`;

interface ElderlyRow {
  id: string;
  family_id: string | null;
  lat: number;
  lng: number;
}

export const requestsService = {
  findMine(auth: AuthContext): NormalizedRequest[] {
    if (!auth.familyId) return [];
    const rows = db
      .prepare(`${SELECT_WITH_ELDERLY} WHERE r.family_id = ? ORDER BY r.scheduled_date ASC`)
      .all(auth.familyId) as ActivityRequestRow[];
    return rows.map(normalizeRequest);
  },

  findOpen(): NormalizedRequest[] {
    const rows = db
      .prepare(`${SELECT_WITH_ELDERLY} WHERE r.status = 'open' ORDER BY r.published_at DESC`)
      .all() as ActivityRequestRow[];
    return rows.map(normalizeRequest);
  },

  findById(id: string): NormalizedRequest {
    const row = db.prepare(`${SELECT_WITH_ELDERLY} WHERE r.id = ?`).get(id) as ActivityRequestRow | undefined;
    if (!row) throw new NotFoundError();
    return normalizeRequest(row);
  },

  create(auth: AuthContext, data: CreateRequestBody): NormalizedRequest {
    if (!auth.familyId) throw new ValidationError("No perteneces a una familia");

    // Resolver adulto mayor: el indicado o el primero de la familia
    let elderly: ElderlyRow | undefined;
    if (data.elderlyProfileId) {
      elderly = db
        .prepare("SELECT id, family_id, lat, lng FROM elderly_profiles WHERE id = ?")
        .get(data.elderlyProfileId) as ElderlyRow | undefined;
      if (!elderly) throw new NotFoundError("Adulto mayor no encontrado");
      if (elderly.family_id !== auth.familyId) {
        throw new UnauthorizedError("Ese adulto mayor no pertenece a tu familia");
      }
    } else {
      elderly = db
        .prepare("SELECT id, family_id, lat, lng FROM elderly_profiles WHERE family_id = ? LIMIT 1")
        .get(auth.familyId) as ElderlyRow | undefined;
    }

    // Coordenadas: domicilio del adulto, con jitter pequeño si no hay perfil
    const latitude = elderly?.lat ?? 19.3826 + (Math.random() * 0.018 - 0.006);
    const longitude = elderly?.lng ?? -99.1677 + (Math.random() * 0.02 - 0.01);

    const requestId = uuidv4();
    db.prepare(`
      INSERT INTO activity_requests
        (id, family_id, elderly_profile_id, activity_type, details, scheduled_date, is_urgent, latitude, longitude)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      requestId,
      auth.familyId,
      elderly?.id ?? null,
      data.activityType,
      data.details,
      data.scheduledDate,
      data.isUrgent ? 1 : 0,
      latitude,
      longitude,
    );

    return this.findById(requestId);
  },

  remove(auth: AuthContext, id: string): { ok: true } {
    const row = db
      .prepare("SELECT family_id, status FROM activity_requests WHERE id = ?")
      .get(id) as { family_id: string; status: string } | undefined;
    if (!row) throw new NotFoundError();
    if (row.family_id !== auth.familyId) throw new UnauthorizedError("No es una solicitud de tu familia");
    if (row.status !== "open") throw new AppError("Solo puedes borrar solicitudes abiertas", 409, "NOT_OPEN");

    db.prepare("DELETE FROM activity_requests WHERE id = ?").run(id);
    return { ok: true };
  },
};
