import { v4 as uuidv4 } from "uuid";
import { db } from "../../../shared/db/sqlite.js";
import { AppError, NotFoundError, UnauthorizedError } from "../../../shared/errors/appError.js";
import { badgesService } from "../../badges/services/badges.service.js";
function toView(row) {
    return {
        id: row.id,
        stars: row.stars,
        tags: JSON.parse(row.tags),
        comment: row.comment,
        authorName: row.author_name ?? "Anónimo",
        createdAt: row.created_at,
    };
}
export const ratingsService = {
    create(auth, assignmentId, data) {
        const assignment = db.prepare(`
      SELECT a.id, a.student_id, a.status, r.family_id
      FROM assignments a JOIN activity_requests r ON a.request_id = r.id
      WHERE a.id = ?
    `).get(assignmentId);
        if (!assignment)
            throw new NotFoundError("Asignación no encontrada");
        if (auth.familyId !== assignment.family_id) {
            throw new UnauthorizedError("Solo la familia o el adulto mayor pueden calificar");
        }
        if (assignment.status !== "completada") {
            throw new AppError("Solo se califica una visita completada", 409, "NOT_COMPLETED");
        }
        const existing = db
            .prepare("SELECT id FROM ratings WHERE assignment_id = ? AND author_user_id = ?")
            .get(assignmentId, auth.id);
        if (existing)
            throw new AppError("Ya calificaste esta visita", 409, "ALREADY_RATED");
        const id = uuidv4();
        const tx = db.transaction(() => {
            db.prepare(`
        INSERT INTO ratings (id, assignment_id, student_id, author_user_id, stars, tags, comment)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `).run(id, assignmentId, assignment.student_id, auth.id, data.stars, JSON.stringify(data.tags), data.comment);
            // Recalcular promedio del estudiante
            const avg = db.prepare("SELECT AVG(stars) AS avg FROM ratings WHERE student_id = ?")
                .get(assignment.student_id);
            db.prepare("UPDATE students SET average_rating = ? WHERE id = ?")
                .run(Math.round((avg.avg ?? 0) * 10) / 10, assignment.student_id);
        });
        tx();
        badgesService.evaluate(assignment.student_id);
        const row = db.prepare(`
      SELECT r.*, u.name AS author_name FROM ratings r
      LEFT JOIN users u ON r.author_user_id = u.id
      WHERE r.id = ?
    `).get(id);
        return toView(row);
    },
    listForStudent(studentId) {
        const rows = db.prepare(`
      SELECT r.*, u.name AS author_name FROM ratings r
      LEFT JOIN users u ON r.author_user_id = u.id
      WHERE r.student_id = ? ORDER BY r.created_at DESC
    `).all(studentId);
        return rows.map(toView);
    },
};
//# sourceMappingURL=ratings.service.js.map