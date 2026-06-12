import { Router } from "express";
import { db } from "../../../shared/db/sqlite.js";
import { NotFoundError } from "../../../shared/errors/appError.js";
import { requireAuth } from "../../../shared/middlewares/auth.middleware.js";
import { badgesService } from "../../badges/services/badges.service.js";
import { ratingsController } from "../../ratings/controllers/ratings.controller.js";
import { ratingsService } from "../../ratings/services/ratings.service.js";
export const studentsRouter = Router();
studentsRouter.use(requireAuth);
studentsRouter.get("/:id", (req, res, next) => {
    try {
        const row = db.prepare(`
      SELECT s.id, s.career, s.total_hours, s.average_rating,
             u.name, un.name AS university_name
      FROM students s
      JOIN users u ON s.user_id = u.id
      LEFT JOIN universities un ON s.university_id = un.id
      WHERE s.id = ?
    `).get(req.params.id);
        if (!row)
            throw new NotFoundError("Estudiante no encontrado");
        res.json({
            id: row.id,
            name: row.name,
            universityName: row.university_name ?? "",
            career: row.career,
            totalHours: row.total_hours,
            averageRating: row.average_rating,
            badges: badgesService.listForStudent(row.id),
            ratings: ratingsService.listForStudent(row.id).slice(0, 10),
        });
    }
    catch (error) {
        next(error);
    }
});
studentsRouter.get("/:id/ratings", ratingsController.listForStudent);
//# sourceMappingURL=students.routes.js.map