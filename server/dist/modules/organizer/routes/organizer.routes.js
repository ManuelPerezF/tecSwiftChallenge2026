import { Router } from "express";
import { db } from "../../../shared/db/sqlite.js";
import { NotFoundError } from "../../../shared/errors/appError.js";
import { requireAuth, requireRole } from "../../../shared/middlewares/auth.middleware.js";
import { badgesService } from "../../badges/services/badges.service.js";
import { ratingsService } from "../../ratings/services/ratings.service.js";
export const organizerRouter = Router();
organizerRouter.use(requireAuth, requireRole("organizer"));
function parseTags(raw) {
    try {
        const parsed = JSON.parse(raw);
        return Array.isArray(parsed) ? parsed.filter((t) => typeof t === "string") : [];
    }
    catch {
        return [];
    }
}
/**
 * GET /organizer/students
 * Filtros: ?blocked=true | ?university=<id> | ?career=<texto> | ?tag=<tag>
 * Orden: averageRating desc (mejor calificados primero).
 */
organizerRouter.get("/students", (req, res, next) => {
    try {
        const conditions = [];
        const params = [];
        if (req.query.blocked === "true") {
            conditions.push("s.is_blocked = 1");
        }
        else if (req.query.blocked === "false") {
            conditions.push("s.is_blocked = 0");
        }
        if (typeof req.query.university === "string" && req.query.university) {
            conditions.push("s.university_id = ?");
            params.push(req.query.university);
        }
        if (typeof req.query.career === "string" && req.query.career) {
            conditions.push("LOWER(s.career) LIKE ?");
            params.push(`%${req.query.career.toLowerCase()}%`);
        }
        if (typeof req.query.tag === "string" && req.query.tag) {
            conditions.push("LOWER(s.tags) LIKE ?");
            params.push(`%${req.query.tag.toLowerCase()}%`);
        }
        const where = conditions.length ? `WHERE ${conditions.join(" AND ")}` : "";
        const rows = db.prepare(`
      SELECT s.id, u.name, s.career, s.total_hours, s.average_rating, s.tags, s.is_blocked,
             un.name AS university_name
      FROM students s
      JOIN users u ON s.user_id = u.id
      LEFT JOIN universities un ON s.university_id = un.id
      ${where}
      ORDER BY s.average_rating DESC, s.total_hours DESC
    `).all(...params);
        res.json(rows.map((r) => ({
            id: r.id,
            name: r.name,
            universityName: r.university_name ?? "",
            career: r.career,
            totalHours: r.total_hours,
            averageRating: r.average_rating,
            tags: parseTags(r.tags),
            isBlocked: r.is_blocked === 1,
        })));
    }
    catch (error) {
        next(error);
    }
});
/** GET /organizer/students/:id — perfil completo + historial de bloqueos con comentarios. */
organizerRouter.get("/students/:id", (req, res, next) => {
    try {
        const id = req.params.id;
        const row = db.prepare(`
      SELECT s.id, u.name, s.career, s.total_hours, s.average_rating, s.tags, s.is_blocked,
             un.name AS university_name
      FROM students s
      JOIN users u ON s.user_id = u.id
      LEFT JOIN universities un ON s.university_id = un.id
      WHERE s.id = ?
    `).get(id);
        if (!row)
            throw new NotFoundError("Becario no encontrado");
        const blocks = db.prepare(`
      SELECT b.id, b.reason, b.comment, b.active, b.created_at,
             f.name AS family_name, r.comment AS rating_comment, r.stars AS rating_stars
      FROM student_blocks b
      LEFT JOIN families f ON b.source_family_id = f.id
      LEFT JOIN ratings r ON b.source_rating_id = r.id
      WHERE b.student_id = ?
      ORDER BY b.created_at DESC
    `).all(id);
        res.json({
            id: row.id,
            name: row.name,
            universityName: row.university_name ?? "",
            career: row.career,
            totalHours: row.total_hours,
            averageRating: row.average_rating,
            tags: parseTags(row.tags),
            isBlocked: row.is_blocked === 1,
            badges: badgesService.listForStudent(row.id),
            ratings: ratingsService.listForStudent(row.id).slice(0, 20),
            blocks: blocks.map((b) => ({
                id: b.id,
                reason: b.reason,
                comment: b.comment || b.rating_comment || "",
                familyName: b.family_name ?? "Familia",
                stars: b.rating_stars,
                active: b.active === 1,
                createdAt: b.created_at,
            })),
        });
    }
    catch (error) {
        next(error);
    }
});
//# sourceMappingURL=organizer.routes.js.map