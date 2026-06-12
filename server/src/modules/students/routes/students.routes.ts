import { Router } from "express";
import { z } from "zod";
import { db } from "../../../shared/db/sqlite.js";
import { NotFoundError, UnauthorizedError, ValidationError } from "../../../shared/errors/appError.js";
import { requireAuth, requireRole } from "../../../shared/middlewares/auth.middleware.js";
import { badgesService } from "../../badges/services/badges.service.js";
import { ratingsController } from "../../ratings/controllers/ratings.controller.js";
import { ratingsService } from "../../ratings/services/ratings.service.js";

export const studentsRouter = Router();

studentsRouter.use(requireAuth);

const tagsBodySchema = z.object({
  tags: z.array(z.string().trim().min(1).max(30)).max(12),
});

function parseTags(raw: string): string[] {
  try {
    const parsed = JSON.parse(raw) as unknown;
    return Array.isArray(parsed) ? parsed.filter((t): t is string => typeof t === "string") : [];
  } catch {
    return [];
  }
}

/** El estudiante edita los tags de su propio perfil (afinidad para el recomendador). */
studentsRouter.put("/me/tags", requireRole("student"), (req, res, next) => {
  try {
    if (!req.auth?.studentId) throw new UnauthorizedError("Solo estudiantes");

    const parsed = tagsBodySchema.safeParse(req.body);
    if (!parsed.success) throw new ValidationError("Tags inválidos (máx. 12, 30 caracteres c/u)");

    const tags = [...new Set(parsed.data.tags.map((t) => t.toLowerCase()))];
    db.prepare("UPDATE students SET tags = ? WHERE id = ?").run(JSON.stringify(tags), req.auth.studentId);
    res.json({ tags });
  } catch (error) {
    next(error);
  }
});

studentsRouter.get("/:id", (req, res, next) => {
  try {
    const row = db.prepare(`
      SELECT s.id, s.career, s.total_hours, s.average_rating, s.tags,
             u.name, un.name AS university_name
      FROM students s
      JOIN users u ON s.user_id = u.id
      LEFT JOIN universities un ON s.university_id = un.id
      WHERE s.id = ?
    `).get(req.params.id as string) as {
      id: string; career: string; total_hours: number; average_rating: number; tags: string;
      name: string; university_name: string | null;
    } | undefined;

    if (!row) throw new NotFoundError("Estudiante no encontrado");

    res.json({
      id: row.id,
      name: row.name,
      universityName: row.university_name ?? "",
      career: row.career,
      totalHours: row.total_hours,
      averageRating: row.average_rating,
      tags: parseTags(row.tags),
      badges: badgesService.listForStudent(row.id),
      ratings: ratingsService.listForStudent(row.id).slice(0, 10),
    });
  } catch (error) {
    next(error);
  }
});

studentsRouter.get("/:id/ratings", ratingsController.listForStudent);
