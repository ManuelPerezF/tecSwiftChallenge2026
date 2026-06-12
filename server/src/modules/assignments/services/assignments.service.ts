import { v4 as uuidv4 } from "uuid";
import { db } from "../../../shared/db/sqlite.js";
import { AppError, NotFoundError, UnauthorizedError } from "../../../shared/errors/appError.js";
import type { AuthContext } from "../../../shared/middlewares/auth.middleware.js";
import { broadcastAssignmentStatus, broadcastLocation, broadcastRequestReopened } from "../../../ws/socketServer.js";
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
  application_id: string;
  student_id: string;
  status: "approved" | "en_camino" | "iniciada" | "completada" | "cancelada";
  approved_at: string;
  en_camino_at: string | null;
  inicio_solicitado_at: string | null;
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
  elderly_profile_id: string | null;
  neighborhood: string | null;
  address: string | null;
  family_id: string;
  is_community_event: number;
  max_helpers_required: number;
}

const SELECT_FULL = `
  SELECT a.*, u.name AS student_name,
         r.activity_type, r.details, r.scheduled_date, r.is_urgent,
         CASE WHEN e.lat IS NOT NULL AND e.lat != 0 THEN e.lat ELSE r.latitude END AS latitude,
         CASE WHEN e.lng IS NOT NULL AND e.lng != 0 THEN e.lng ELSE r.longitude END AS longitude,
         r.family_id, r.elderly_profile_id, r.is_community_event, r.max_helpers_required,
         e.first_name AS elderly_name, e.neighborhood, e.address
  FROM   assignments a
  JOIN   activity_requests r ON a.request_id = r.id
  JOIN   students s ON a.student_id = s.id
  JOIN   users u ON s.user_id = u.id
  LEFT JOIN elderly_profiles e ON r.elderly_profile_id = e.id
`;

function resolveStatus(row: AssignmentRow): AssignmentStatus {
  if (row.status === "en_camino" && row.inicio_solicitado_at && !row.checkin_at) {
    return "esperando_confirmacion";
  }
  return row.status;
}

function toView(row: AssignmentRow): AssignmentView {
  return {
    id: row.id,
    requestId: row.request_id,
    studentId: row.student_id,
    studentName: row.student_name,
    status: resolveStatus(row),
    approvedAt: row.approved_at,
    enCaminoAt: row.en_camino_at,
    inicioSolicitadoAt: row.inicio_solicitado_at,
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
    neighborhood: row.neighborhood ?? "",
    address: row.address ?? "",
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
    en_camino: ["esperando_confirmacion", "iniciada", "cancelada"],
    esperando_confirmacion: ["iniciada", "cancelada"],
    iniciada: ["completada", "cancelada"],
    completada: [],
    cancelada: [],
  };
  if (!allowed[current].includes(target)) {
    throw new AppError(`No se puede pasar de ${current} a ${target}`, 409, "INVALID_TRANSITION");
  }
}

function assertElderlyOwnsVisit(auth: AuthContext, row: AssignmentRow): void {
  if (row.elderly_profile_id !== auth.elderlyProfileId) {
    throw new UnauthorizedError("No es una visita tuya");
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
    assertTransition(resolveStatus(row), "en_camino");

    db.prepare("UPDATE assignments SET status = 'en_camino', en_camino_at = datetime('now') WHERE id = ?").run(id);
    db.prepare("UPDATE activity_requests SET status = 'inProgress' WHERE id = ?").run(row.request_id);

    broadcastAssignmentStatus(id);
    return toView(getRow(id));
  },

  /** Becario llegó: solicita inicio. Horas NO cuentan hasta que el adulto mayor confirme. */
  iniciar(auth: AuthContext, id: string): AssignmentView {
    const row = getRow(id);
    if (row.student_id !== auth.studentId) throw new UnauthorizedError("No es tu visita");

    const current = resolveStatus(row);
    if (current !== "en_camino") {
      throw new AppError("Solo puedes iniciar cuando estás en camino", 409, "INVALID_STATE");
    }
    if (row.inicio_solicitado_at) {
      throw new AppError("Ya solicitaste inicio", 409, "ALREADY_REQUESTED");
    }

    db.prepare("UPDATE assignments SET inicio_solicitado_at = datetime('now') WHERE id = ?").run(id);

    broadcastAssignmentStatus(id);
    return toView(getRow(id));
  },

  /** Adulto mayor confirma inicio → arranca cronómetro (checkin_at). */
  confirmarInicio(auth: AuthContext, id: string): AssignmentView {
    const row = getRow(id);
    assertElderlyOwnsVisit(auth, row);

    const current = resolveStatus(row);
    if (current !== "esperando_confirmacion") {
      throw new AppError("No hay inicio pendiente de confirmar", 409, "NO_PENDING_START");
    }

    assertTransition(current, "iniciada");

    db.prepare("UPDATE assignments SET status = 'iniciada', checkin_at = datetime('now') WHERE id = ?").run(id);

    broadcastAssignmentStatus(id);
    return toView(getRow(id));
  },

  completar(auth: AuthContext, id: string): AssignmentView {
    const row = getRow(id);
    if (row.student_id !== auth.studentId) throw new UnauthorizedError("No es tu visita");
    assertTransition(resolveStatus(row), "completada");

    if (!row.checkin_at) {
      throw new AppError("La visita no fue confirmada por el adulto mayor", 409, "NOT_CONFIRMED");
    }

    const tx = db.transaction(() => {
      db.prepare("UPDATE assignments SET status = 'completada', checkout_at = datetime('now') WHERE id = ?").run(id);

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
    assertTransition(resolveStatus(row), "cancelada");

    let reopened = false;
    const tx = db.transaction(() => {
      db.prepare("UPDATE assignments SET status = 'cancelada' WHERE id = ?").run(id);
      // La postulación de ESTE assignment no se queda en 'approved'
      db.prepare("UPDATE applications SET status = 'cancelled_by_helper' WHERE id = ? AND status = 'approved'")
        .run(row.application_id);

      if (row.is_community_event === 1) {
        // Evento multi-cupo: reabrir solo si quedó cupo libre
        const { n } = db
          .prepare("SELECT COUNT(*) AS n FROM assignments WHERE request_id = ? AND status != 'cancelada'")
          .get(row.request_id) as { n: number };
        if (n < row.max_helpers_required) {
          db.prepare("UPDATE applications SET status = 'pending' WHERE request_id = ? AND status = 'waiting_list'")
            .run(row.request_id);
          db.prepare("UPDATE activity_requests SET status = 'open' WHERE id = ?").run(row.request_id);
          reopened = true;
        }
      } else {
        // Las de waiting_list vuelven al pool como pending (la familia decide, sin auto-asignar)
        db.prepare("UPDATE applications SET status = 'pending' WHERE request_id = ? AND status = 'waiting_list'")
          .run(row.request_id);
        // El request se reabre en lugar de morir
        db.prepare("UPDATE activity_requests SET status = 'open' WHERE id = ?").run(row.request_id);
        reopened = true;
      }
    });
    tx();

    broadcastAssignmentStatus(id);
    if (reopened) broadcastRequestReopened(row.request_id);
    return toView(getRow(id));
  },

  postLocation(auth: AuthContext, id: string, data: LocationBody): { ok: true } {
    const row = getRow(id);
    const role = auth.role === "student" ? "student" : "elderly";

    if (role === "student" && row.student_id !== auth.studentId) {
      throw new UnauthorizedError("No es tu visita");
    }
    if (role === "elderly") {
      assertElderlyOwnsVisit(auth, row);
    }
    const current = resolveStatus(row);
    if (current !== "en_camino" && current !== "esperando_confirmacion" && current !== "iniciada") {
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
    const isElderly = auth.elderlyProfileId === row.elderly_profile_id;
    if (!isFamily && !isStudent && !isElderly) throw new UnauthorizedError("Sin acceso a esta visita");

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
