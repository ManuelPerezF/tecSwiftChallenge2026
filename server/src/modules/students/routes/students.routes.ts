import { Router } from "express";
import { z } from "zod";
import { db } from "../../../shared/db/sqlite.js";
import { NotFoundError, UnauthorizedError, ValidationError } from "../../../shared/errors/appError.js";
import { requireAuth, requireRole } from "../../../shared/middlewares/auth.middleware.js";
import { badgesService } from "../../badges/services/badges.service.js";
import { notificationsService } from "../../notifications/services/notifications.service.js";
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

// Rango "HH:MM-HH:MM" (nuevo) o legacy morning/afternoon/evening
const windowPattern = /^(morning|afternoon|evening|\d{1,2}:\d{2}-\d{1,2}:\d{2})$/;
const availabilityBodySchema = z.object({
  windows: z.array(z.string().regex(windowPattern)).max(3),
});

/** 3.6: el becario declara su disponibilidad (rango horario) para recibir notificaciones. */
studentsRouter.put("/me/availability", requireRole("student"), (req, res, next) => {
  try {
    if (!req.auth?.studentId) throw new UnauthorizedError("Solo estudiantes");

    const parsed = availabilityBodySchema.safeParse(req.body);
    if (!parsed.success) throw new ValidationError("Disponibilidad inválida");

    const windows = [...new Set(parsed.data.windows)];
    db.prepare("UPDATE students SET available_windows = ? WHERE id = ?")
      .run(JSON.stringify(windows), req.auth.studentId);

    // Resumen inmediato: cuántas oportunidades coinciden con el nuevo horario (3+ agrupado)
    notificationsService.notifyScheduleMatches(req.auth.studentId);

    res.json({ windows });
  } catch (error) {
    next(error);
  }
});

function fetchStudentById(id: string, res: import("express").Response, next: import("express").NextFunction) {
  try {
    const row = db.prepare(`
      SELECT s.id, s.career, s.total_hours, s.average_rating, s.tags,
             u.name, un.name AS university_name
      FROM students s
      JOIN users u ON s.user_id = u.id
      LEFT JOIN universities un ON s.university_id = un.id
      WHERE s.id = ?
    `).get(id) as {
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
}

// Own profile (student role)
studentsRouter.get("/me", (req, res, next) => {
  const studentId = req.auth?.studentId;
  if (!studentId) { res.status(403).json({ error: "No eres un becario" }); return; }
  fetchStudentById(studentId, res, next);
});

studentsRouter.get("/:id", (req, res, next) => {
  fetchStudentById(req.params.id as string, res, next);
});

studentsRouter.get("/:id/ratings", ratingsController.listForStudent);
