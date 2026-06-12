import { v4 as uuidv4 } from "uuid";
import { db } from "../../../shared/db/sqlite.js";
import { AppError, NotFoundError, UnauthorizedError } from "../../../shared/errors/appError.js";
import { broadcastAssignmentStatus, broadcastLocation, broadcastRequestReopened } from "../../../ws/socketServer.js";
import { badgesService } from "../../badges/services/badges.service.js";
import { notificationsService } from "../../notifications/services/notifications.service.js";
import { requestsService } from "../../requests/services/requests.service.js";
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
function resolveStatus(row) {
    if (row.status === "en_camino" && row.inicio_solicitado_at && !row.checkin_at) {
        return "esperando_confirmacion";
    }
    return row.status;
}
function toView(row) {
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
function getRow(id) {
    const row = db.prepare(`${SELECT_FULL} WHERE a.id = ?`).get(id);
    if (!row)
        throw new NotFoundError("Asignación no encontrada");
    return row;
}
function assertTransition(current, target) {
    const allowed = {
        approved: ["en_camino", "cancelada"],
        en_camino: ["esperando_confirmacion", "iniciada", "cancelada"],
        esperando_confirmacion: ["iniciada", "cancelada"],
        iniciada: ["esperando_confirmacion_fin", "cancelada"],
        esperando_confirmacion_fin: ["completada", "cancelada"],
        completada: [],
        cancelada: [],
    };
    if (!allowed[current].includes(target)) {
        throw new AppError(`No se puede pasar de ${current} a ${target}`, 409, "INVALID_TRANSITION");
    }
}
/** 3.8: regla de los 15 minutos — no se puede iniciar antes de scheduledDate - 15min. */
function assertNotTooEarly(scheduledDate) {
    const scheduled = new Date(scheduledDate).getTime();
    if (Number.isNaN(scheduled))
        return;
    if (Date.now() < scheduled - 15 * 60_000) {
        throw new AppError("Podrás iniciar 15 minutos antes de la cita", 409, "TOO_EARLY");
    }
}
/** Notifica a todos los miembros de la familia. */
function notifyFamily(familyId, type, title, body, data = {}) {
    const members = db
        .prepare("SELECT user_id FROM family_members WHERE family_id = ?")
        .all(familyId);
    for (const member of members) {
        notificationsService.create(member.user_id, type, title, body, data);
    }
}
function assertElderlyOwnsVisit(auth, row) {
    if (row.elderly_profile_id !== auth.elderlyProfileId) {
        throw new UnauthorizedError("No es una visita tuya");
    }
}
export const assignmentsService = {
    findById(id) {
        return toView(getRow(id));
    },
    listMine(auth) {
        if (!auth.studentId)
            return [];
        const rows = db
            .prepare(`${SELECT_FULL} WHERE a.student_id = ? ORDER BY a.approved_at DESC`)
            .all(auth.studentId);
        return rows.map(toView);
    },
    listForFamily(auth) {
        if (!auth.familyId)
            return [];
        const rows = db
            .prepare(`${SELECT_FULL} WHERE r.family_id = ? ORDER BY a.approved_at DESC`)
            .all(auth.familyId);
        return rows.map(toView);
    },
    listForElderly(auth) {
        if (!auth.elderlyProfileId)
            return [];
        const rows = db
            .prepare(`${SELECT_FULL} WHERE r.elderly_profile_id = ? AND a.status != 'cancelada' ORDER BY r.scheduled_date ASC`)
            .all(auth.elderlyProfileId);
        return rows.map(toView);
    },
    enCamino(auth, id) {
        const row = getRow(id);
        if (row.student_id !== auth.studentId)
            throw new UnauthorizedError("No es tu visita");
        assertTransition(resolveStatus(row), "en_camino");
        assertNotTooEarly(row.scheduled_date);
        db.prepare("UPDATE assignments SET status = 'en_camino', en_camino_at = datetime('now') WHERE id = ?").run(id);
        db.prepare("UPDATE activity_requests SET status = 'inProgress' WHERE id = ?").run(row.request_id);
        broadcastAssignmentStatus(id);
        return toView(getRow(id));
    },
    /** Becario llegó: solicita inicio. Horas NO cuentan hasta que el adulto mayor confirme. */
    iniciar(auth, id) {
        const row = getRow(id);
        if (row.student_id !== auth.studentId)
            throw new UnauthorizedError("No es tu visita");
        const current = resolveStatus(row);
        if (current !== "en_camino") {
            throw new AppError("Solo puedes iniciar cuando estás en camino", 409, "INVALID_STATE");
        }
        if (row.inicio_solicitado_at) {
            throw new AppError("Ya solicitaste inicio", 409, "ALREADY_REQUESTED");
        }
        assertNotTooEarly(row.scheduled_date);
        db.prepare("UPDATE assignments SET inicio_solicitado_at = datetime('now') WHERE id = ?").run(id);
        broadcastAssignmentStatus(id);
        return toView(getRow(id));
    },
    /** Adulto mayor confirma inicio → arranca cronómetro (checkin_at). */
    confirmarInicio(auth, id) {
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
    /**
     * 3.15: el becario marca "Terminé" → estado intermedio `esperando_confirmacion_fin`.
     * Se registra `checkout_at` provisional (tiempo REAL), pero las horas NO se
     * calculan ni suman hasta que la familia confirme (`confirmCompletion`).
     */
    completar(auth, id) {
        const row = getRow(id);
        if (row.student_id !== auth.studentId)
            throw new UnauthorizedError("No es tu visita");
        assertTransition(resolveStatus(row), "esperando_confirmacion_fin");
        if (!row.checkin_at) {
            throw new AppError("La visita no fue confirmada por el adulto mayor", 409, "NOT_CONFIRMED");
        }
        db.prepare("UPDATE assignments SET status = 'esperando_confirmacion_fin', checkout_at = datetime('now') WHERE id = ?")
            .run(id);
        notifyFamily(row.family_id, "completion_pending", "¿El servicio terminó?", `${row.student_name} marcó como terminada la visita de ${row.activity_type} con ${row.elderly_name ?? "tu familiar"}. Confirma para registrar las horas.`, { assignmentId: id });
        broadcastAssignmentStatus(id);
        return toView(getRow(id));
    },
    /**
     * 3.15: la familia (o el adulto mayor) confirma el fin → se calculan las horas
     * REALES desde checkin_at hasta el checkout_at registrado por el becario.
     */
    confirmCompletion(auth, id) {
        const row = getRow(id);
        const isFamily = auth.familyId === row.family_id;
        const isElderly = auth.elderlyProfileId != null && auth.elderlyProfileId === row.elderly_profile_id;
        if (!isFamily && !isElderly)
            throw new UnauthorizedError("No es una visita de tu familia");
        assertTransition(resolveStatus(row), "completada");
        if (!row.checkin_at || !row.checkout_at) {
            throw new AppError("Faltan registros de inicio/fin", 409, "MISSING_TIMESTAMPS");
        }
        const tx = db.transaction(() => {
            db.prepare("UPDATE assignments SET status = 'completada' WHERE id = ?").run(id);
            // Tiempo real del servicio (checkin → checkout provisional), no estimado
            const ms = new Date(row.checkout_at + "Z").getTime() - new Date(row.checkin_at + "Z").getTime();
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
        // Avisar al becario que ya se registraron sus horas (y que puede ser calificado)
        const studentUser = db
            .prepare("SELECT user_id FROM students WHERE id = ?")
            .get(row.student_id);
        if (studentUser) {
            notificationsService.create(studentUser.user_id, "completion_confirmed", "¡Visita confirmada!", "La familia confirmó el fin del servicio. Tus horas reales ya fueron registradas.", { assignmentId: id });
        }
        broadcastAssignmentStatus(id);
        return toView(getRow(id));
    },
    cancelar(auth, id) {
        const row = getRow(id);
        if (row.family_id !== auth.familyId)
            throw new UnauthorizedError("No es una visita de tu familia");
        assertTransition(resolveStatus(row), "cancelada");
        return this.performCancellation(row, id);
    },
    /** 3.7: el becario cancela su asignación mientras siga en 'approved' (libera el cupo y reabre). */
    cancelByStudent(auth, id) {
        const row = getRow(id);
        if (row.student_id !== auth.studentId)
            throw new UnauthorizedError("No es tu visita");
        if (resolveStatus(row) !== "approved") {
            throw new AppError("Solo puedes cancelar antes de ir en camino", 409, "INVALID_STATE");
        }
        const view = this.performCancellation(row, id);
        notifyFamily(row.family_id, "assignment_cancelled", "El becario canceló la visita", `${row.student_name} canceló la visita de ${row.activity_type}. La solicitud volvió a abrirse y la lista de espera está disponible.`, { requestId: row.request_id, assignmentId: id });
        return view;
    },
    performCancellation(row, id) {
        let reopened = false;
        const tx = db.transaction(() => {
            db.prepare("UPDATE assignments SET status = 'cancelada' WHERE id = ?").run(id);
            // La postulación de ESTE assignment no se queda en 'approved'
            db.prepare("UPDATE applications SET status = 'cancelled_by_helper' WHERE id = ? AND status = 'approved'")
                .run(row.application_id);
            if (row.is_community_event === 1) {
                // Evento multi-cupo: reabrir solo si quedó cupo libre de becarios
                const { n } = db
                    .prepare("SELECT COUNT(*) AS n FROM assignments WHERE request_id = ? AND status != 'cancelada'")
                    .get(row.request_id);
                if (n < row.max_helpers_required) {
                    db.prepare("UPDATE applications SET status = 'pending' WHERE request_id = ? AND status = 'waiting_list'")
                        .run(row.request_id);
                    db.prepare("UPDATE activity_requests SET status = 'open' WHERE id = ?").run(row.request_id);
                    // El tope de adultos mayores puede seguir lleno → recalcular
                    requestsService.recomputeEventFullness(row.request_id);
                    reopened = true;
                }
            }
            else {
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
        if (reopened)
            broadcastRequestReopened(row.request_id);
        return toView(getRow(id));
    },
    /** 3.7: el becario propone otra hora; requiere aprobación de la familia. */
    proposeChange(auth, id, proposedDate) {
        const row = getRow(id);
        if (row.student_id !== auth.studentId)
            throw new UnauthorizedError("No es tu visita");
        if (resolveStatus(row) !== "approved") {
            throw new AppError("Solo puedes proponer cambios antes de ir en camino", 409, "INVALID_STATE");
        }
        if (Number.isNaN(new Date(proposedDate).getTime())) {
            throw new AppError("Fecha propuesta inválida", 400, "INVALID_DATE");
        }
        const existing = db
            .prepare("SELECT id FROM assignment_change_proposals WHERE assignment_id = ? AND status = 'pending'")
            .get(id);
        if (existing)
            throw new AppError("Ya hay una propuesta pendiente", 409, "PROPOSAL_PENDING");
        const proposalId = uuidv4();
        db.prepare(`
      INSERT INTO assignment_change_proposals (id, assignment_id, proposed_by, proposed_date)
      VALUES (?, ?, ?, ?)
    `).run(proposalId, id, auth.id, proposedDate);
        notifyFamily(row.family_id, "change_proposal", "Propuesta de cambio de horario", `${row.student_name} propone cambiar la visita de ${row.activity_type} a otra hora. Revísala para aceptar o rechazar.`, { assignmentId: id, proposalId, proposedDate });
        return { proposalId };
    },
    /** Propuesta pendiente de un assignment (familia o becario). */
    getPendingProposal(auth, id) {
        const row = getRow(id);
        if (row.family_id !== auth.familyId && row.student_id !== auth.studentId) {
            throw new UnauthorizedError("Sin acceso a esta visita");
        }
        const proposal = db
            .prepare("SELECT id, proposed_date, created_at FROM assignment_change_proposals WHERE assignment_id = ? AND status = 'pending'")
            .get(id);
        return proposal ? { id: proposal.id, proposedDate: proposal.proposed_date, createdAt: proposal.created_at } : null;
    },
    /** La familia acepta/rechaza la propuesta de cambio de horario. */
    respondToProposal(auth, proposalId, accept) {
        const proposal = db.prepare(`
      SELECT p.id, p.assignment_id, p.proposed_date, p.status, p.proposed_by,
             a.request_id, r.family_id, u.name AS student_name
      FROM assignment_change_proposals p
      JOIN assignments a ON p.assignment_id = a.id
      JOIN activity_requests r ON a.request_id = r.id
      JOIN students s ON a.student_id = s.id
      JOIN users u ON s.user_id = u.id
      WHERE p.id = ?
    `).get(proposalId);
        if (!proposal)
            throw new NotFoundError("Propuesta no encontrada");
        if (proposal.family_id !== auth.familyId)
            throw new UnauthorizedError("No es una visita de tu familia");
        if (proposal.status !== "pending")
            throw new AppError("La propuesta ya fue resuelta", 409, "ALREADY_RESOLVED");
        const tx = db.transaction(() => {
            db.prepare("UPDATE assignment_change_proposals SET status = ?, resolved_at = datetime('now') WHERE id = ?")
                .run(accept ? "accepted" : "rejected", proposalId);
            if (accept) {
                db.prepare("UPDATE activity_requests SET scheduled_date = ? WHERE id = ?")
                    .run(proposal.proposed_date, proposal.request_id);
            }
        });
        tx();
        notificationsService.create(proposal.proposed_by, accept ? "change_accepted" : "change_rejected", accept ? "Cambio de horario aceptado" : "Cambio de horario rechazado", accept
            ? "La familia aceptó tu propuesta. La visita quedó reagendada."
            : "La familia prefirió mantener el horario original.", { assignmentId: proposal.assignment_id });
        broadcastAssignmentStatus(proposal.assignment_id);
        return { ok: true };
    },
    postLocation(auth, id, data) {
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
    getLocations(auth, id) {
        const row = getRow(id);
        const isFamily = auth.familyId === row.family_id;
        const isStudent = auth.studentId === row.student_id;
        const isElderly = auth.elderlyProfileId === row.elderly_profile_id;
        if (!isFamily && !isStudent && !isElderly)
            throw new UnauthorizedError("Sin acceso a esta visita");
        const rows = db
            .prepare("SELECT role, latitude, longitude, recorded_at FROM location_updates WHERE assignment_id = ?")
            .all(id);
        return rows.map((r) => ({
            role: r.role,
            latitude: r.latitude,
            longitude: r.longitude,
            recordedAt: r.recorded_at,
        }));
    },
};
//# sourceMappingURL=assignments.service.js.map