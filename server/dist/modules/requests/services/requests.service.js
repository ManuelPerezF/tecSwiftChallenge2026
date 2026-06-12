import { v4 as uuidv4 } from "uuid";
import { db } from "../../../shared/db/sqlite.js";
import { AppError, NotFoundError, UnauthorizedError, ValidationError } from "../../../shared/errors/appError.js";
import { normalizeRequest, } from "../../../shared/utils/requestMapper.js";
import { notificationsService } from "../../notifications/services/notifications.service.js";
const SELECT_WITH_ELDERLY = `
  SELECT r.*,
         e.first_name AS elderly_name, e.neighborhood,
         CASE WHEN e.lat IS NOT NULL AND e.lat != 0 THEN e.lat ELSE r.latitude END AS latitude,
         CASE WHEN e.lng IS NOT NULL AND e.lng != 0 THEN e.lng ELSE r.longitude END AS longitude,
         (SELECT COUNT(*) FROM assignments a WHERE a.request_id = r.id AND a.status != 'cancelada') AS active_helpers,
         (SELECT COUNT(*) FROM event_attendees ea WHERE ea.request_id = r.id) AS active_elderly_attendees
  FROM   activity_requests r
  LEFT JOIN elderly_profiles e ON r.elderly_profile_id = e.id
`;
export const requestsService = {
    findMine(auth) {
        if (!auth.familyId)
            return [];
        const rows = db
            .prepare(`${SELECT_WITH_ELDERLY} WHERE r.family_id = ? ORDER BY r.scheduled_date ASC`)
            .all(auth.familyId);
        return rows.map(normalizeRequest);
    },
    findOpen() {
        const rows = db
            .prepare(`${SELECT_WITH_ELDERLY} WHERE r.status = 'open' ORDER BY r.published_at DESC`)
            .all();
        return rows.map(normalizeRequest);
    },
    findById(id) {
        const row = db.prepare(`${SELECT_WITH_ELDERLY} WHERE r.id = ?`).get(id);
        if (!row)
            throw new NotFoundError();
        return normalizeRequest(row);
    },
    /** Eventos comunitarios visibles para todos los roles autenticados. */
    findCommunityEvents() {
        const rows = db
            .prepare(`${SELECT_WITH_ELDERLY} WHERE r.is_community_event = 1 AND r.status IN ('open','claimed','inProgress','full') ORDER BY r.scheduled_date ASC`)
            .all();
        return rows.map(normalizeRequest);
    },
    create(auth, data) {
        if (!auth.familyId)
            throw new ValidationError("No perteneces a una familia");
        const isCommunityEvent = data.isCommunityEvent === true;
        if (isCommunityEvent && auth.role !== "organizer") {
            throw new UnauthorizedError("Solo un organizador puede crear eventos comunitarios");
        }
        const maxHelpers = isCommunityEvent ? Math.max(data.maxHelpersRequired ?? 1, 1) : 1;
        const maxElderly = isCommunityEvent ? Math.max(data.maxElderlyAttendees ?? 0, 0) : 0;
        // Resolver adulto mayor: el indicado o el primero de la familia
        let elderly;
        if (data.elderlyProfileId) {
            elderly = db
                .prepare("SELECT id, family_id, lat, lng FROM elderly_profiles WHERE id = ?")
                .get(data.elderlyProfileId);
            if (!elderly)
                throw new NotFoundError("Adulto mayor no encontrado");
            if (elderly.family_id !== auth.familyId) {
                throw new UnauthorizedError("Ese adulto mayor no pertenece a tu familia");
            }
        }
        else {
            elderly = db
                .prepare("SELECT id, family_id, lat, lng FROM elderly_profiles WHERE family_id = ? LIMIT 1")
                .get(auth.familyId);
        }
        // Coordenadas: preferir GPS enviado por la familia, luego perfil del adulto mayor
        const elderlyLat = elderly?.lat && elderly.lat !== 0 ? elderly.lat : null;
        const elderlyLng = elderly?.lng && elderly.lng !== 0 ? elderly.lng : null;
        const latitude = data.lat ?? elderlyLat ?? 0;
        const longitude = data.lng ?? elderlyLng ?? 0;
        const requestId = uuidv4();
        db.prepare(`
      INSERT INTO activity_requests
        (id, family_id, elderly_profile_id, activity_type, details, scheduled_date, is_urgent, latitude, longitude, duration_minutes, is_community_event, max_helpers_required, max_elderly_attendees)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(requestId, auth.familyId, elderly?.id ?? null, data.activityType, data.details, data.scheduledDate, data.isUrgent ? 1 : 0, latitude, longitude, data.durationMinutes ?? null, isCommunityEvent ? 1 : 0, maxHelpers, maxElderly);
        // 3.6: notificar a becarios cercanos (+familias cercanas si es evento comunitario)
        if (isCommunityEvent) {
            notificationsService.notifyNearbyOfCommunityEvent(requestId);
        }
        else {
            notificationsService.notifyNearbyStudentsOfRequest(requestId);
        }
        return this.findById(requestId);
    },
    /** Recalcula el estado 'full'/'open' de un evento según ambos topes (becarios y adultos mayores). */
    recomputeEventFullness(requestId) {
        const row = db
            .prepare(`
        SELECT r.id, r.status, r.is_community_event, r.max_helpers_required, r.max_elderly_attendees,
               (SELECT COUNT(*) FROM assignments a WHERE a.request_id = r.id AND a.status != 'cancelada') AS helpers,
               (SELECT COUNT(*) FROM event_attendees ea WHERE ea.request_id = r.id) AS attendees
        FROM activity_requests r WHERE r.id = ?
      `)
            .get(requestId);
        if (!row || row.is_community_event !== 1)
            return;
        // Solo gestionamos la transición open ⇄ full (no tocar inProgress/completed/cancelled)
        if (row.status !== "open" && row.status !== "full" && row.status !== "claimed")
            return;
        const helpersFull = row.helpers >= row.max_helpers_required;
        const elderlyFull = row.max_elderly_attendees > 0 && row.attendees >= row.max_elderly_attendees;
        const shouldBeFull = helpersFull || elderlyFull;
        if (shouldBeFull && row.status !== "full") {
            db.prepare("UPDATE activity_requests SET status = 'full' WHERE id = ?").run(row.id);
        }
        else if (!shouldBeFull && row.status === "full") {
            db.prepare("UPDATE activity_requests SET status = 'open' WHERE id = ?").run(row.id);
        }
    },
    /** Registro de asistentes (familias/adultos mayores) a un evento comunitario. */
    registerAttendee(auth, requestId) {
        const row = db
            .prepare("SELECT id, is_community_event, status, max_elderly_attendees FROM activity_requests WHERE id = ?")
            .get(requestId);
        if (!row)
            throw new NotFoundError("Evento no encontrado");
        if (row.is_community_event !== 1) {
            throw new AppError("Esta solicitud no es un evento comunitario", 409, "NOT_COMMUNITY_EVENT");
        }
        if (row.max_elderly_attendees > 0) {
            const { n } = db
                .prepare("SELECT COUNT(*) AS n FROM event_attendees WHERE request_id = ?")
                .get(requestId);
            if (n >= row.max_elderly_attendees) {
                throw new AppError("El evento ya está lleno", 409, "EVENT_FULL");
            }
        }
        const existing = db
            .prepare("SELECT id FROM event_attendees WHERE request_id = ? AND attendee_user_id = ?")
            .get(requestId, auth.id);
        if (existing)
            throw new AppError("Ya estás registrado en este evento", 409, "ALREADY_REGISTERED");
        db.prepare("INSERT INTO event_attendees (id, request_id, attendee_user_id) VALUES (?, ?, ?)")
            .run(uuidv4(), requestId, auth.id);
        this.recomputeEventFullness(requestId);
        return { ok: true };
    },
    /** Cancelar asistencia a un evento. Si se libera cupo, el evento vuelve a 'open'. */
    unregisterAttendee(auth, requestId) {
        const result = db
            .prepare("DELETE FROM event_attendees WHERE request_id = ? AND attendee_user_id = ?")
            .run(requestId, auth.id);
        if (result.changes === 0)
            throw new NotFoundError("No estabas registrado en este evento");
        this.recomputeEventFullness(requestId);
        return { ok: true };
    },
    listAttendees(requestId) {
        const request = db.prepare("SELECT id FROM activity_requests WHERE id = ?").get(requestId);
        if (!request)
            throw new NotFoundError("Evento no encontrado");
        const rows = db
            .prepare(`
        SELECT ea.id, ea.attendee_user_id, ea.created_at, u.name, u.role
        FROM event_attendees ea JOIN users u ON ea.attendee_user_id = u.id
        WHERE ea.request_id = ? ORDER BY ea.created_at ASC
      `)
            .all(requestId);
        return rows.map((r) => ({
            id: r.id,
            userId: r.attendee_user_id,
            name: r.name,
            role: r.role,
            createdAt: r.created_at,
        }));
    },
    remove(auth, id) {
        const row = db
            .prepare("SELECT family_id, status FROM activity_requests WHERE id = ?")
            .get(id);
        if (!row)
            throw new NotFoundError();
        if (row.family_id !== auth.familyId)
            throw new UnauthorizedError("No es una solicitud de tu familia");
        if (row.status !== "open")
            throw new AppError("Solo puedes borrar solicitudes abiertas", 409, "NOT_OPEN");
        db.prepare("DELETE FROM activity_requests WHERE id = ?").run(id);
        return { ok: true };
    },
};
//# sourceMappingURL=requests.service.js.map