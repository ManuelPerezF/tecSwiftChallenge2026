import { v4 as uuidv4 } from "uuid";
import { db } from "../../../shared/db/sqlite.js";
import { AppError, NotFoundError, UnauthorizedError } from "../../../shared/errors/appError.js";
import type { AuthContext } from "../../../shared/middlewares/auth.middleware.js";
import { broadcastAssignmentStatus } from "../../../ws/socketServer.js";
import type { ApplicationStatus, ApplicationView, ApplyBody } from "../models/applications.model.js";

interface ApplicationRow {
  id: string;
  request_id: string;
  student_id: string;
  message: string;
  status: ApplicationStatus;
  created_at: string;
  student_name: string;
  university_name: string | null;
  career: string;
  total_hours: number;
  average_rating: number;
  student_tags: string;
}

const SELECT_WITH_STUDENT = `
  SELECT a.*, u.name AS student_name, s.career, s.total_hours, s.average_rating, s.tags AS student_tags,
         un.name AS university_name
  FROM   applications a
  JOIN   students s ON a.student_id = s.id
  JOIN   users u ON s.user_id = u.id
  LEFT JOIN universities un ON s.university_id = un.id
`;

function parseTags(raw: string): string[] {
  try {
    const parsed = JSON.parse(raw) as unknown;
    return Array.isArray(parsed) ? parsed.filter((t): t is string => typeof t === "string") : [];
  } catch {
    return [];
  }
}

function toView(row: ApplicationRow): ApplicationView {
  return {
    id: row.id,
    requestId: row.request_id,
    studentId: row.student_id,
    studentName: row.student_name,
    universityName: row.university_name ?? "",
    career: row.career,
    totalHours: row.total_hours,
    averageRating: row.average_rating,
    message: row.message,
    status: row.status,
    createdAt: row.created_at,
    tags: parseTags(row.student_tags),
  };
}

export const applicationsService = {
  apply(auth: AuthContext, requestId: string, data: ApplyBody): ApplicationView {
    if (!auth.studentId) throw new UnauthorizedError("Solo estudiantes pueden postularse");

    const request = db
      .prepare("SELECT id, status FROM activity_requests WHERE id = ?")
      .get(requestId) as { id: string; status: string } | undefined;
    if (!request) throw new NotFoundError("Solicitud no encontrada");
    if (request.status !== "open") throw new AppError("La solicitud ya no está abierta", 409, "NOT_OPEN");

    const existing = db
      .prepare("SELECT id FROM applications WHERE request_id = ? AND student_id = ?")
      .get(requestId, auth.studentId);
    if (existing) throw new AppError("Ya te postulaste a esta solicitud", 409, "ALREADY_APPLIED");

    const id = uuidv4();
    db.prepare("INSERT INTO applications (id, request_id, student_id, message) VALUES (?, ?, ?, ?)")
      .run(id, requestId, auth.studentId, data.message);

    const row = db.prepare(`${SELECT_WITH_STUDENT} WHERE a.id = ?`).get(id) as ApplicationRow;
    return toView(row);
  },

  listForRequest(auth: AuthContext, requestId: string): ApplicationView[] {
    const request = db
      .prepare("SELECT family_id FROM activity_requests WHERE id = ?")
      .get(requestId) as { family_id: string } | undefined;
    if (!request) throw new NotFoundError("Solicitud no encontrada");
    if (request.family_id !== auth.familyId) throw new UnauthorizedError("No es una solicitud de tu familia");

    const rows = db
      .prepare(`${SELECT_WITH_STUDENT} WHERE a.request_id = ? ORDER BY a.created_at ASC`)
      .all(requestId) as ApplicationRow[];
    return rows.map(toView);
  },

  listMine(auth: AuthContext): ApplicationView[] {
    if (!auth.studentId) return [];
    const rows = db
      .prepare(`${SELECT_WITH_STUDENT} WHERE a.student_id = ? ORDER BY a.created_at DESC`)
      .all(auth.studentId) as ApplicationRow[];
    return rows.map(toView);
  },

  approve(auth: AuthContext, applicationId: string): { assignmentId: string } {
    const app = db
      .prepare(`
        SELECT a.id, a.request_id, a.student_id, a.status, r.family_id, r.status AS request_status,
               r.is_community_event, r.max_helpers_required
        FROM applications a JOIN activity_requests r ON a.request_id = r.id
        WHERE a.id = ?
      `)
      .get(applicationId) as {
        id: string; request_id: string; student_id: string; status: string;
        family_id: string; request_status: string;
        is_community_event: number; max_helpers_required: number;
      } | undefined;

    if (!app) throw new NotFoundError("Postulación no encontrada");
    if (app.family_id !== auth.familyId) throw new UnauthorizedError("No es una solicitud de tu familia");
    if (app.status !== "pending") throw new AppError("La postulación ya fue resuelta", 409, "ALREADY_RESOLVED");
    if (app.request_status !== "open") throw new AppError("La solicitud ya tiene becario", 409, "NOT_OPEN");

    const assignmentId = uuidv4();
    const tx = db.transaction(() => {
      db.prepare("UPDATE applications SET status = 'approved' WHERE id = ?").run(app.id);
      db.prepare(`
        INSERT INTO assignments (id, request_id, application_id, student_id)
        VALUES (?, ?, ?, ?)
      `).run(assignmentId, app.request_id, app.id, app.student_id);

      if (app.is_community_event === 1) {
        // Evento multi-cupo: sigue abierto hasta llenar max_helpers_required
        const { n } = db
          .prepare("SELECT COUNT(*) AS n FROM assignments WHERE request_id = ? AND status != 'cancelada'")
          .get(app.request_id) as { n: number };
        if (n >= app.max_helpers_required) {
          db.prepare("UPDATE activity_requests SET status = 'claimed' WHERE id = ?").run(app.request_id);
          db.prepare("UPDATE applications SET status = 'waiting_list' WHERE request_id = ? AND status = 'pending'")
            .run(app.request_id);
        }
      } else {
        // Pool con lista de espera: las demás pending NO se rechazan, quedan en waiting_list
        db.prepare("UPDATE applications SET status = 'waiting_list' WHERE request_id = ? AND id != ? AND status = 'pending'")
          .run(app.request_id, app.id);
        db.prepare("UPDATE activity_requests SET status = 'claimed' WHERE id = ?").run(app.request_id);
      }
    });
    tx();

    broadcastAssignmentStatus(assignmentId);
    return { assignmentId };
  },

  reject(auth: AuthContext, applicationId: string): { ok: true } {
    const app = db
      .prepare(`
        SELECT a.id, a.status, r.family_id
        FROM applications a JOIN activity_requests r ON a.request_id = r.id
        WHERE a.id = ?
      `)
      .get(applicationId) as { id: string; status: string; family_id: string } | undefined;

    if (!app) throw new NotFoundError("Postulación no encontrada");
    if (app.family_id !== auth.familyId) throw new UnauthorizedError("No es una solicitud de tu familia");
    if (app.status !== "pending" && app.status !== "waiting_list") {
      throw new AppError("La postulación ya fue resuelta", 409, "ALREADY_RESOLVED");
    }

    db.prepare("UPDATE applications SET status = 'rejected' WHERE id = ?").run(app.id);
    return { ok: true };
  },
};
