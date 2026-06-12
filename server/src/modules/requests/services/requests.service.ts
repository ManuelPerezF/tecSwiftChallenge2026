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
  SELECT r.*,
         e.first_name AS elderly_name, e.neighborhood,
         CASE WHEN e.lat IS NOT NULL AND e.lat != 0 THEN e.lat ELSE r.latitude END AS latitude,
         CASE WHEN e.lng IS NOT NULL AND e.lng != 0 THEN e.lng ELSE r.longitude END AS longitude,
         (SELECT COUNT(*) FROM assignments a WHERE a.request_id = r.id AND a.status != 'cancelada') AS active_helpers
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

  /** Eventos comunitarios visibles para todos los roles autenticados. */
  findCommunityEvents(): NormalizedRequest[] {
    const rows = db
      .prepare(`${SELECT_WITH_ELDERLY} WHERE r.is_community_event = 1 AND r.status IN ('open','claimed','inProgress') ORDER BY r.scheduled_date ASC`)
      .all() as ActivityRequestRow[];
    return rows.map(normalizeRequest);
  },

  create(auth: AuthContext, data: CreateRequestBody): NormalizedRequest {
    if (!auth.familyId) throw new ValidationError("No perteneces a una familia");

    const isCommunityEvent = data.isCommunityEvent === true;
    if (isCommunityEvent && auth.role !== "organizer") {
      throw new UnauthorizedError("Solo un organizador puede crear eventos comunitarios");
    }
    const maxHelpers = isCommunityEvent ? Math.max(data.maxHelpersRequired ?? 1, 1) : 1;

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

    // Coordenadas: preferir GPS enviado por la familia, luego perfil del adulto mayor
    const elderlyLat = elderly?.lat && elderly.lat !== 0 ? elderly.lat : null;
    const elderlyLng = elderly?.lng && elderly.lng !== 0 ? elderly.lng : null;
    const latitude = data.lat ?? elderlyLat ?? 0;
    const longitude = data.lng ?? elderlyLng ?? 0;

    const requestId = uuidv4();
    db.prepare(`
      INSERT INTO activity_requests
        (id, family_id, elderly_profile_id, activity_type, details, scheduled_date, is_urgent, latitude, longitude, duration_minutes, is_community_event, max_helpers_required)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
      data.durationMinutes ?? null,
      isCommunityEvent ? 1 : 0,
      maxHelpers,
    );

    return this.findById(requestId);
  },

  /** Registro de asistentes (familias/adultos mayores) a un evento comunitario. */
  registerAttendee(auth: AuthContext, requestId: string): { ok: true } {
    const row = db
      .prepare("SELECT id, is_community_event FROM activity_requests WHERE id = ?")
      .get(requestId) as { id: string; is_community_event: number } | undefined;
    if (!row) throw new NotFoundError("Evento no encontrado");
    if (row.is_community_event !== 1) {
      throw new AppError("Esta solicitud no es un evento comunitario", 409, "NOT_COMMUNITY_EVENT");
    }

    const existing = db
      .prepare("SELECT id FROM event_attendees WHERE request_id = ? AND attendee_user_id = ?")
      .get(requestId, auth.id);
    if (existing) throw new AppError("Ya estás registrado en este evento", 409, "ALREADY_REGISTERED");

    db.prepare("INSERT INTO event_attendees (id, request_id, attendee_user_id) VALUES (?, ?, ?)")
      .run(uuidv4(), requestId, auth.id);
    return { ok: true };
  },

  listAttendees(requestId: string): Array<{ id: string; userId: string; name: string; role: string; createdAt: string }> {
    const request = db.prepare("SELECT id FROM activity_requests WHERE id = ?").get(requestId);
    if (!request) throw new NotFoundError("Evento no encontrado");

    const rows = db
      .prepare(`
        SELECT ea.id, ea.attendee_user_id, ea.created_at, u.name, u.role
        FROM event_attendees ea JOIN users u ON ea.attendee_user_id = u.id
        WHERE ea.request_id = ? ORDER BY ea.created_at ASC
      `)
      .all(requestId) as Array<{ id: string; attendee_user_id: string; created_at: string; name: string; role: string }>;

    return rows.map((r) => ({
      id: r.id,
      userId: r.attendee_user_id,
      name: r.name,
      role: r.role,
      createdAt: r.created_at,
    }));
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
