import { v4 as uuidv4 } from "uuid";
import { db } from "../../../shared/db/sqlite.js";
import { NotFoundError } from "../../../shared/errors/appError.js";
import type { AuthContext } from "../../../shared/middlewares/auth.middleware.js";
import { sendToUser } from "../../../ws/socketServer.js";

/** Radio de notificación por cercanía (km) — configurable vía env. */
const NEARBY_RADIUS_KM = Number(process.env.NOTIFY_RADIUS_KM ?? 5);

export interface NotificationView {
  id: string;
  type: string;
  title: string;
  body: string;
  data: Record<string, string>;
  read: boolean;
  createdAt: string;
}

interface NotificationRow {
  id: string;
  type: string;
  title: string;
  body: string;
  data: string;
  read: number;
  created_at: string;
}

function toView(row: NotificationRow): NotificationView {
  let data: Record<string, string> = {};
  try {
    const parsed = JSON.parse(row.data) as Record<string, unknown>;
    data = Object.fromEntries(Object.entries(parsed).map(([k, v]) => [k, String(v)]));
  } catch { /* data malformado → vacío */ }
  return {
    id: row.id,
    type: row.type,
    title: row.title,
    body: row.body,
    data,
    read: row.read === 1,
    createdAt: row.created_at,
  };
}

/** Haversine simplificada (misma aproximación que usa la app en toOpenRequest). */
function distanceMeters(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const dLat = (lat1 - lat2) * 111_320;
  const dLng = (lng1 - lng2) * 111_320 * Math.cos((lat2 * Math.PI) / 180);
  return Math.sqrt(dLat * dLat + dLng * dLng);
}

/** Ventana horaria de un Date ISO (es_MX): morning <12, afternoon <18, evening resto. */
function timeWindow(dateISO: string): "morning" | "afternoon" | "evening" {
  const hour = new Date(dateISO).getHours();
  if (hour < 12) return "morning";
  if (hour < 18) return "afternoon";
  return "evening";
}

/**
 * ¿La cita cae dentro de la disponibilidad declarada del becario?
 * Soporta dos formatos por elemento (mezclables):
 *  - Rango real "HH:MM-HH:MM" (nuevo, incluye rangos nocturnos tipo 22:00-02:00)
 *  - Legacy "morning" | "afternoon" | "evening"
 * Sin disponibilidad declarada = siempre disponible.
 */
function isAvailableAt(windows: string[], dateISO: string): boolean {
  if (windows.length === 0) return true;
  const date = new Date(dateISO);
  const minutes = date.getHours() * 60 + date.getMinutes();
  const legacy = timeWindow(dateISO);

  return windows.some((w) => {
    const m = /^(\d{1,2}):(\d{2})-(\d{1,2}):(\d{2})$/.exec(w);
    if (m) {
      const start = Number(m[1]) * 60 + Number(m[2]);
      const end = Number(m[3]) * 60 + Number(m[4]);
      return end >= start
        ? minutes >= start && minutes <= end
        : minutes >= start || minutes <= end; // rango que cruza medianoche
    }
    return w === legacy;
  });
}

function parseWindows(raw: string): string[] {
  try {
    const parsed = JSON.parse(raw) as unknown;
    return Array.isArray(parsed) ? parsed.filter((w): w is string => typeof w === "string") : [];
  } catch {
    return [];
  }
}

interface StudentLocRow {
  student_id: string;
  user_id: string;
  available_windows: string;
  is_blocked: number;
  lat: number | null;
  lng: number | null;
  uni_lat: number | null;
  uni_lng: number | null;
}

/** Última ubicación conocida del becario (location_updates) con fallback a su universidad. */
function studentsWithLocation(): Array<{ studentId: string; userId: string; windows: string[]; blocked: boolean; lat: number; lng: number }> {
  const rows = db.prepare(`
    SELECT s.id AS student_id, s.user_id, s.available_windows, s.is_blocked,
           lu.latitude AS lat, lu.longitude AS lng,
           un.lat AS uni_lat, un.lng AS uni_lng
    FROM students s
    LEFT JOIN universities un ON s.university_id = un.id
    LEFT JOIN (
      SELECT user_id, latitude, longitude,
             ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY recorded_at DESC) AS rn
      FROM location_updates
    ) lu ON lu.user_id = s.user_id AND lu.rn = 1
  `).all() as StudentLocRow[];

  return rows
    .map((r) => ({
      studentId: r.student_id,
      userId: r.user_id,
      windows: parseWindows(r.available_windows),
      blocked: r.is_blocked === 1,
      lat: r.lat ?? r.uni_lat ?? 0,
      lng: r.lng ?? r.uni_lng ?? 0,
    }))
    .filter((r) => r.lat !== 0 || r.lng !== 0);
}

export const notificationsService = {
  /** Crea la notificación y la empuja por WebSocket si el usuario está conectado. */
  create(userId: string, type: string, title: string, body: string, data: Record<string, unknown> = {}): NotificationView {
    const id = uuidv4();
    db.prepare(`
      INSERT INTO notifications (id, user_id, type, title, body, data)
      VALUES (?, ?, ?, ?, ?, ?)
    `).run(id, userId, type, title, body, JSON.stringify(data));

    const row = db.prepare("SELECT * FROM notifications WHERE id = ?").get(id) as NotificationRow;
    const view = toView(row);
    sendToUser(userId, { type: "notification", notification: view });
    return view;
  },

  listMine(auth: AuthContext): NotificationView[] {
    const rows = db
      .prepare("SELECT * FROM notifications WHERE user_id = ? ORDER BY created_at DESC LIMIT 100")
      .all(auth.id) as NotificationRow[];
    return rows.map(toView);
  },

  markRead(auth: AuthContext, id: string): { ok: true } {
    const result = db
      .prepare("UPDATE notifications SET read = 1 WHERE id = ? AND user_id = ?")
      .run(id, auth.id);
    if (result.changes === 0) throw new NotFoundError("Notificación no encontrada");
    return { ok: true };
  },

  unreadCount(auth: AuthContext): number {
    const { n } = db
      .prepare("SELECT COUNT(*) AS n FROM notifications WHERE user_id = ? AND read = 0")
      .get(auth.id) as { n: number };
    return n;
  },

  /**
   * 3.6.1 — Nueva solicitud de familia → becarios cercanos y disponibles.
   * Pide confirmación explícita en el cliente ("¿Estás disponible y cerca?").
   */
  notifyNearbyStudentsOfRequest(requestId: string): void {
    const request = db.prepare(`
      SELECT r.id, r.activity_type, r.scheduled_date, r.latitude, r.longitude, r.is_urgent,
             e.first_name AS elderly_name, e.neighborhood
      FROM activity_requests r
      LEFT JOIN elderly_profiles e ON r.elderly_profile_id = e.id
      WHERE r.id = ?
    `).get(requestId) as {
      id: string; activity_type: string; scheduled_date: string;
      latitude: number; longitude: number; is_urgent: number;
      elderly_name: string | null; neighborhood: string | null;
    } | undefined;
    if (!request || (request.latitude === 0 && request.longitude === 0)) return;

    for (const student of studentsWithLocation()) {
      if (student.blocked) continue;
      // (b) dentro de la disponibilidad declarada (sin declarar = disponible)
      if (!isAvailableAt(student.windows, request.scheduled_date)) continue;
      // (a) dentro del radio
      const dist = distanceMeters(student.lat, student.lng, request.latitude, request.longitude);
      if (dist > NEARBY_RADIUS_KM * 1000) continue;

      const km = (dist / 1000).toFixed(1);
      this.create(
        student.userId,
        "request_nearby",
        request.is_urgent === 1 ? "Solicitud urgente cerca de ti" : "Nueva solicitud cerca de ti",
        `${request.elderly_name ?? "Un adulto mayor"} necesita ayuda a ${km} km (${request.neighborhood ?? "tu zona"}). ¿Estás disponible y cerca para esta actividad?`,
        { requestId: request.id, requiresConfirmation: "true", distanceKm: km },
      );
    }
  },

  /**
   * 3.6.2 — Nuevo evento comunitario → becarios cercanos+disponibles Y familias
   * cuyos adultos mayores estén dentro del radio.
   */
  notifyNearbyOfCommunityEvent(requestId: string): void {
    const event = db.prepare(`
      SELECT id, activity_type, details, scheduled_date, latitude, longitude
      FROM activity_requests WHERE id = ? AND is_community_event = 1
    `).get(requestId) as {
      id: string; activity_type: string; details: string; scheduled_date: string;
      latitude: number; longitude: number;
    } | undefined;
    if (!event || (event.latitude === 0 && event.longitude === 0)) return;

    // Becarios cercanos + disponibles
    for (const student of studentsWithLocation()) {
      if (student.blocked) continue;
      if (!isAvailableAt(student.windows, event.scheduled_date)) continue;
      const dist = distanceMeters(student.lat, student.lng, event.latitude, event.longitude);
      if (dist > NEARBY_RADIUS_KM * 1000) continue;

      this.create(
        student.userId,
        "event_nearby",
        "Evento comunitario cerca de ti",
        `Se busca apoyo de becarios a ${(dist / 1000).toFixed(1)} km. ¿Estás disponible y cerca para esta actividad?`,
        { requestId: event.id, requiresConfirmation: "true" },
      );
    }

    // Familias con adultos mayores cercanos (para que puedan asistir)
    const elderly = db.prepare(`
      SELECT e.id, e.first_name, e.family_id, e.user_id, e.lat, e.lng
      FROM elderly_profiles e WHERE e.family_id IS NOT NULL
    `).all() as Array<{ id: string; first_name: string; family_id: string; user_id: string; lat: number; lng: number }>;

    const notifiedFamilies = new Set<string>();
    for (const person of elderly) {
      if (person.lat === 0 && person.lng === 0) continue;
      const dist = distanceMeters(person.lat, person.lng, event.latitude, event.longitude);
      if (dist > NEARBY_RADIUS_KM * 1000) continue;

      // Notificar al adulto mayor
      this.create(
        person.user_id,
        "event_nearby_elderly",
        "Evento comunitario cerca de tu casa",
        `Hay un evento a ${(dist / 1000).toFixed(1)} km. Pide a tu familia que te registre si quieres ir.`,
        { requestId: event.id },
      );

      // Notificar a los miembros de su familia (una vez por familia)
      if (notifiedFamilies.has(person.family_id)) continue;
      notifiedFamilies.add(person.family_id);
      const members = db
        .prepare("SELECT user_id FROM family_members WHERE family_id = ?")
        .all(person.family_id) as Array<{ user_id: string }>;
      for (const member of members) {
        this.create(
          member.user_id,
          "event_nearby_family",
          "Evento comunitario cerca",
          `Hay un evento comunitario a ${(dist / 1000).toFixed(1)} km de ${person.first_name}. ¿Quieres registrarle como asistente?`,
          { requestId: event.id },
        );
      }
    }
  },

  /**
   * Resumen agrupado al declarar disponibilidad: cuenta solicitudes/eventos
   * abiertos, cercanos y dentro del horario del becario. Si hay más de 3 se
   * agrupa como "3+" en una sola notificación.
   */
  notifyScheduleMatches(studentId: string): void {
    const student = studentsWithLocation().find((s) => s.studentId === studentId);
    if (!student || student.blocked) return;

    const rows = db.prepare(`
      SELECT id, scheduled_date, latitude, longitude, is_community_event
      FROM activity_requests WHERE status = 'open'
    `).all() as Array<{
      id: string; scheduled_date: string; latitude: number; longitude: number; is_community_event: number;
    }>;

    let events = 0;
    let services = 0;
    for (const r of rows) {
      if (r.latitude === 0 && r.longitude === 0) continue;
      if (!isAvailableAt(student.windows, r.scheduled_date)) continue;
      if (distanceMeters(student.lat, student.lng, r.latitude, r.longitude) > NEARBY_RADIUS_KM * 1000) continue;
      if (r.is_community_event === 1) events += 1; else services += 1;
    }

    const total = events + services;
    if (total === 0) return;

    const label = total > 3 ? "3+" : String(total);
    const noun =
      events > 0 && services > 0 ? "eventos y servicios"
      : events > 0 ? (events === 1 && total <= 3 ? "evento" : "eventos")
      : (services === 1 && total <= 3 ? "servicio" : "servicios");
    const verb = total === 1 ? "encontrado" : "encontrados";

    this.create(
      student.userId,
      "schedule_matches",
      `${label} ${noun} en tu horario`,
      `${label} ${noun} ${verb} cerca de ti y dentro de tu disponibilidad. Échales un ojo en el mapa.`,
      { count: String(total) },
    );
  },
};
