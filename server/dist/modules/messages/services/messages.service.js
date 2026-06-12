import { v4 as uuidv4 } from "uuid";
import { db } from "../../../shared/db/sqlite.js";
import { NotFoundError, UnauthorizedError } from "../../../shared/errors/appError.js";
import { broadcastChatMessage } from "../../../ws/socketServer.js";
function normalize(row) {
    return {
        id: row.id,
        fromUserId: row.from_user_id,
        fromName: row.from_name,
        toStudentId: row.to_student_id,
        toUserId: row.to_user_id ?? null,
        body: row.body,
        assignmentId: row.assignment_id ?? null,
        readAt: row.read_at ?? null,
        createdAt: row.created_at,
    };
}
export const messagesService = {
    // Family → Student
    send(auth, data) {
        if (!auth.familyId)
            throw new UnauthorizedError("Solo las familias pueden enviar mensajes");
        const student = db.prepare("SELECT id FROM students WHERE id = ?").get(data.toStudentId);
        if (!student)
            throw new NotFoundError("Estudiante no encontrado");
        const id = uuidv4();
        db.prepare(`
      INSERT INTO messages (id, from_user_id, to_student_id, body, assignment_id)
      VALUES (?, ?, ?, ?, ?)
    `).run(id, auth.id, data.toStudentId, data.body, data.assignmentId ?? null);
        const row = db.prepare(`
      SELECT m.*, u.name AS from_name
      FROM messages m JOIN users u ON m.from_user_id = u.id
      WHERE m.id = ?
    `).get(id);
        const msg = normalize(row);
        broadcastChatMessage(msg, auth.familyId);
        return msg;
    },
    // Student → Family member (reply)
    reply(auth, data) {
        if (!auth.studentId)
            throw new UnauthorizedError("Solo los becarios pueden responder");
        const targetUser = db.prepare("SELECT id FROM users WHERE id = ?").get(data.toUserId);
        if (!targetUser)
            throw new NotFoundError("Destinatario no encontrado");
        // Verify relationship: target must be family member who has messaged this student before
        const existing = db.prepare(`
      SELECT id FROM messages WHERE to_student_id = ? AND from_user_id = ? LIMIT 1
    `).get(auth.studentId, data.toUserId);
        if (!existing)
            throw new UnauthorizedError("Solo puedes responder a familias que te han escrito");
        const id = uuidv4();
        // to_student_id = own studentId so thread queries stay simple (all messages share studentId)
        const studentId = auth.studentId;
        db.prepare(`
      INSERT INTO messages (id, from_user_id, to_student_id, to_user_id, body)
      VALUES (?, ?, ?, ?, ?)
    `).run(id, auth.id, studentId, data.toUserId, data.body);
        const row = db.prepare(`
      SELECT m.*, u.name AS from_name
      FROM messages m JOIN users u ON m.from_user_id = u.id
      WHERE m.id = ?
    `).get(id);
        const msg = normalize(row);
        broadcastChatMessage(msg, undefined, data.toUserId);
        return msg;
    },
    // Student inbox — all received messages (from any family), grouped by thread when opened
    inbox(auth) {
        if (!auth.studentId)
            throw new UnauthorizedError("Solo los becarios tienen bandeja de entrada");
        // All messages in threads involving this student (both directions)
        const rows = db.prepare(`
      SELECT m.*, u.name AS from_name
      FROM messages m JOIN users u ON m.from_user_id = u.id
      WHERE m.to_student_id = ?
      ORDER BY m.created_at DESC
      LIMIT 100
    `).all(auth.studentId);
        // Mark unread (only family→student messages) as read
        db.prepare(`
      UPDATE messages SET read_at = datetime('now')
      WHERE to_student_id = ? AND to_user_id IS NULL AND read_at IS NULL
    `).run(auth.studentId);
        return rows.map(normalize);
    },
    // Family: list conversations grouped by student
    conversations(auth) {
        if (!auth.familyId)
            throw new UnauthorizedError("Solo las familias pueden ver conversaciones");
        const rows = db.prepare(`
      SELECT
        s.id         AS studentId,
        u2.name      AS studentName,
        m.body       AS lastBody,
        m.created_at AS lastAt,
        SUM(CASE WHEN m.read_at IS NULL AND m.to_user_id IS NOT NULL THEN 1 ELSE 0 END) AS unreadCount
      FROM messages m
      JOIN students s  ON m.to_student_id = s.id
      JOIN users u2    ON s.user_id        = u2.id
      WHERE m.from_user_id IN (SELECT user_id FROM family_members WHERE family_id = ?)
         OR m.to_user_id   IN (SELECT user_id FROM family_members WHERE family_id = ?)
      GROUP BY s.id
      ORDER BY MAX(m.created_at) DESC
    `).all(auth.familyId, auth.familyId);
        return rows;
    },
    // Full thread between a family and a student (bidirectional)
    thread(auth, otherId) {
        let rows;
        if (auth.familyId) {
            // otherId = studentId — get all messages in this thread regardless of direction
            rows = db.prepare(`
        SELECT m.*, u.name AS from_name
        FROM messages m JOIN users u ON m.from_user_id = u.id
        WHERE m.to_student_id = ?
          AND (
            m.from_user_id IN (SELECT user_id FROM family_members WHERE family_id = ?)
            OR m.to_user_id IN (SELECT user_id FROM family_members WHERE family_id = ?)
          )
        ORDER BY m.created_at ASC
      `).all(otherId, auth.familyId, auth.familyId);
            // Mark student replies as read for the family
            db.prepare(`
        UPDATE messages SET read_at = datetime('now')
        WHERE to_student_id = ? AND to_user_id IN (SELECT user_id FROM family_members WHERE family_id = ?) AND read_at IS NULL
      `).run(otherId, auth.familyId);
        }
        else if (auth.studentId) {
            // otherId = fromUserId (family member user id)
            rows = db.prepare(`
        SELECT m.*, u.name AS from_name
        FROM messages m JOIN users u ON m.from_user_id = u.id
        WHERE m.to_student_id = ?
          AND (m.from_user_id = ? OR m.to_user_id = ?)
        ORDER BY m.created_at ASC
      `).all(auth.studentId, otherId, otherId);
            // Mark received messages as read
            db.prepare(`
        UPDATE messages SET read_at = datetime('now')
        WHERE to_student_id = ? AND from_user_id = ? AND to_user_id IS NULL AND read_at IS NULL
      `).run(auth.studentId, otherId);
        }
        else {
            throw new UnauthorizedError("Sin acceso");
        }
        return rows.map(normalize);
    },
    unreadCount(auth) {
        if (!auth.studentId)
            return 0;
        const result = db.prepare(`
      SELECT COUNT(*) AS n FROM messages
      WHERE to_student_id = ? AND to_user_id IS NULL AND read_at IS NULL
    `).get(auth.studentId);
        return result.n;
    },
};
//# sourceMappingURL=messages.service.js.map