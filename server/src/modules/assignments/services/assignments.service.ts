import { v4 as uuidv4 } from "uuid";
import { db } from "../../../shared/db/sqlite.js";
import { AppError, NotFoundError, UnauthorizedError } from "../../../shared/errors/appError.js";
import type { AuthContext } from "../../../shared/middlewares/auth.middleware.js";
import { broadcastAssignmentStatus, broadcastLocation } from "../../../ws/socketServer.js";
import { badgesService } from "../../badges/services/badges.service.js";
import type {
  AssignmentStatus,
  AssignmentView,
  LocationBody,
  LocationView,
} from "../models/assignments.model.js";

interface AssignmentRow {
  id: string;
  request_id: string;
  student_id: string;
  status: AssignmentStatus;
  approved_at: string;
  en_camino_at: string | null;
  checkin_at: string | null;
  checkout_at: string | null;
  hours_logged: number;
  student_name: string;
  activity_type: string;
  details: string;
  scheduled_date: string;
  is_urgent: number;
  latitude: number;
  longitude: number;
  elderly_name: string | null;
  neighborhood: string | null;
  address: string | null;
  family_id: string;
}

const SELECT_FULL = `
  SELECT a.*, u.name AS student_name,
         r.activity_type, r.details, r.scheduled_date, r.is_urgent,
         r.latitude, r.longitude, r.family_id,
         e.first_name AS elderly_name, e.neighborhood, e.address
  FROM   assignments a
  JOIN   activity_requests r ON a.request_id = r.id
  JOIN   students s ON a.student_id = s.id
  JOIN   users u ON s.user_id = u.id
  LEFT JOIN elderly_profiles e ON r.elderly_profile_id = e.id
`;

function toView(row: AssignmentRow): AssignmentView {
  return {
    id: row.id,
    requestId: row.request_id,
    studentId: row.student_id,
    studentName: row.student_name,
    status: row.status,
    approvedAt: row.approved_at,
    enCaminoAt: row.en_camino_at,
    checkinAt: row.checkin_at,
    checkoutAt: row.checkout_at,
    hoursLogged: row.hours_logged,
    activityType: row.activity_type,
    details: row.details,
    scheduledDate: row.scheduled_date,
    isUrgent: row.is_urgent === 1,
    latitude: row.latitude,
    longitude: row.longitude,
    elderlyName: row.elderly_name ?? "Tu familiar",
    neighborhood: row.neighborhood ?? "CDMX",
    address: row.address ?? "CDMX",
    familyId: row.family_id,
  };
}

function getRow(id: string): AssignmentRow {
  const row = db.prepare(`${SELECT_FULL} WHERE a.id = ?`).get(id) as AssignmentRow | undefined;
  if (!row) throw new NotFoundError("Asignación no encontrada");
  return row;
}

function assertTransition(current: AssignmentStatus, target: AssignmentStatus): void {
  const allowed: Record<AssignmentStatus, AssignmentStatus[]> = {
    approved: ["en_camino", "cancelada"],
    en_camino: ["iniciada", "cancelada"],
    iniciada: ["completada", "cancelada"],
    completada: [],
    cancelada: [],
  };
  if (!allowed[current].includes(target)) {
    throw new AppError(`No se puede pasar de ${current} a ${target}`, 409, "INVALID_TRANSITION");
  }
}

export const assignmentsService = {
  findById(id: string): AssignmentView {
    return toView(getRow(id));
  },

  listMine(auth: AuthContext): AssignmentView[] {
    if (!auth.studentId) return [];
    const rows = db
      .prepare(`${SELECT_FULL} WHERE a.student_id = ? ORDER BY a.approved_at DESC`)
      .all(auth.studentId) as AssignmentRow[];
    return rows.map(toView);
  },

  listForFamily(auth: AuthContext): AssignmentView[] {
    if (!auth.familyId) return [];
    const rows = db
      .prepare(`${SELECT_FULL} WHERE r.family_id = ? ORDER BY a.approved_at DESC`)
      .all(auth.familyId) as AssignmentRow[];
    return rows.map(toView);
  },

  listForElderly(auth: AuthContext): AssignmentView[] {
    if (!auth.elderlyProfileId) return [];
    const rows = db
      .prepare(`${SELECT_FULL} WHERE r.elderly_profile_id = ? AND a.status != 'cancelada' ORDER BY r.scheduled_date ASC`)
      .all(auth.elderlyProfileId) as AssignmentRow[];
    return rows.map(toView);
  },

  enCamino(auth: AuthContext, id: string): AssignmentView {
    const row = getRow(id);
    if (row.student_id !== auth.studentId) throw new UnauthorizedError("No es tu visita");
    assertTransition(row.status, "en_camino");

    db.prepare("UPDATE assignments SET status = 'en_camino', en_camino_at = datetime('now') WHERE id = ?").run(id);
    db.prepare("UPDATE activity_requests SET status = 'inProgress' WHERE id = ?").run(row.request_id);

    broadcastAssignmentStatus(id);
    return toView(getRow(id));
  },

  iniciar(auth: AuthContext, id: string): AssignmentView {
    const row = getRow(id);
    if (row.student_id !== auth.studentId) throw new UnauthorizedError("No es tu visita");
    assertTransition(row.status, "iniciada");

    db.prepare("UPDATE assignments SET status = 'iniciada', checkin_at = datetime('now') WHERE id = ?").run(id);

    broadcastAssignmentStatus(id);
    return toView(getRow(id));
  },

  completar(auth: AuthContext, id: string): AssignmentView {
    const row = getRow(id);
    if (row.student_id !== auth.studentId) throw new UnauthorizedError("No es tu visita");
    assertTransition(row.status, "completada");

    const tx = db.transaction(() => {
      db.prepare("UPDATE assignments SET status = 'completada', checkout_at = datetime('now') WHERE id = ?").run(id);

      // Horas: checkout - checkin (mínimo 0.25 h para demo)
      const t = db.prepare("SELECT checkin_at, checkout_at FROM assignments WHERE id = ?")
        .get(id) as { checkin_at: string; checkout_at: string };
      const ms = new Date(t.checkout_at + "Z").getTime() - new Date(t.checkin_at + "Z").getTime();
      const hours = Math.max(Math.round((ms / 3_600_000) * 100) / 100, 0.25);

      db.prepare("UPDATE assignments SET hours_logged = ? WHERE id = ?").run(hours, id);
      db.prepare(`
        INSERT INTO service_hours (id, assignment_id, student_id, hours, activity_type)
        VALUES (?, ?, ?, ?, ?)
      `).run(uuidv4(), id, row.student_id, hours, row.activity_type);
      db.prepare("UPDATE students SET total_hours = total_hours + ? WHERE id = ?").run(hours, row.student_id);
      db.prepare("UPDATE activity_requests SET status = 'completed' WHERE id = ?").run(row.request_id);
    });
    tx();

    badgesService.evaluate(row.student_id);
    broadcastAssignmentStatus(id);
    return toView(getRow(id));
  },

  cancelar(auth: AuthContext, id: string): AssignmentView {
    const row = getRow(id);
    if (row.family_id !== auth.familyId) throw new UnauthorizedError("No es una visita de tu familia");
    assertTransition(row.status, "cancelada");

    db.prepare("UPDATE assignments SET status = 'cancelada' WHERE id = ?").run(id);
    db.prepare("UPDATE activity_requests SET status = 'cancelled' WHERE id = ?").run(row.request_id);

    broadcastAssignmentStatus(id);
    return toView(getRow(id));
  },

  // ── Ubicación (REST fallback) ───────────────────────────────────

  postLocation(auth: AuthContext, id: string, data: LocationBody): { ok: true } {
    const row = getRow(id);
    const role = auth.role === "student" ? "student" : "elderly";

    if (role === "student" && row.student_id !== auth.studentId) {
      throw new UnauthorizedError("No es tu visita");
    }
    if (role === "elderly" && auth.familyId !== row.family_id) {
      throw new UnauthorizedError("No es una visita de tu familia");
    }
    if (row.status !== "en_camino" && row.status !== "iniciada") {
      throw new AppError("La visita no está activa", 409, "NOT_ACTIVE");
    }

    db.prepare(`
      INSERT INTO location_updates (id, assignment_id, user_id, role, latitude, longitude, recorded_at)
      VALUES (?, ?, ?, ?, ?, ?, datetime('now'))
      ON CONFLICT(assignment_id, user_id)
      DO UPDATE SET latitude = excluded.latitude, longitude = excluded.longitude, recorded_at = excluded.recorded_at
    `).run(uuidv4(), id, auth.id, role, data.latitude, data.longitude);

    broadcastLocation(id);
    return { ok: true };
  },

  getLocations(auth: AuthContext, id: string): LocationView[] {
    const row = getRow(id);
    const isFamily = auth.familyId === row.family_id;
    const isStudent = auth.studentId === row.student_id;
    if (!isFamily && !isStudent) throw new UnauthorizedError("Sin acceso a esta visita");

    const rows = db
      .prepare("SELECT role, latitude, longitude, recorded_at FROM location_updates WHERE assignment_id = ?")
      .all(id) as Array<{ role: "student" | "elderly"; latitude: number; longitude: number; recorded_at: string }>;

    return rows.map((r) => ({
      role: r.role,
      latitude: r.latitude,
      longitude: r.longitude,
      recordedAt: r.recorded_at,
    }));
  },
};
