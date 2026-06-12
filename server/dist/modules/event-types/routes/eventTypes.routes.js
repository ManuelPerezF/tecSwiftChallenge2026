import { Router } from "express";
import { v4 as uuidv4 } from "uuid";
import { db } from "../../../shared/db/sqlite.js";
import { ValidationError } from "../../../shared/errors/appError.js";
import { requireAuth, requireRole } from "../../../shared/middlewares/auth.middleware.js";
import { createEventTypeBodySchema } from "../models/eventTypes.model.js";
export const eventTypesRouter = Router();
eventTypesRouter.use(requireAuth);
function toView(row) {
    return { id: row.id, slug: row.slug, label: row.label, icon: row.icon, isCustom: row.is_custom === 1 };
}
function slugify(label) {
    return label
        .toLowerCase()
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/(^-|-$)/g, "")
        .slice(0, 40);
}
/** Catálogo completo: estándar + custom. */
eventTypesRouter.get("/", (_req, res, next) => {
    try {
        const rows = db
            .prepare("SELECT id, slug, label, icon, is_custom FROM event_types ORDER BY is_custom ASC, created_at ASC")
            .all();
        res.json(rows.map(toView));
    }
    catch (error) {
        next(error);
    }
});
/** Crear tipo custom (solo organizador). */
eventTypesRouter.post("/", requireRole("organizer"), (req, res, next) => {
    try {
        const parsed = createEventTypeBodySchema.safeParse(req.body);
        if (!parsed.success)
            throw new ValidationError("Tipo de evento inválido (label 2-40 caracteres)");
        const base = slugify(parsed.data.label);
        if (!base)
            throw new ValidationError("Nombre de tipo inválido");
        // slug único: sufijo incremental si choca
        let slug = base;
        let n = 1;
        while (db.prepare("SELECT 1 FROM event_types WHERE slug = ?").get(slug)) {
            slug = `${base}-${++n}`;
        }
        const id = uuidv4();
        db.prepare(`
      INSERT INTO event_types (id, slug, label, icon, is_custom, created_by_organizer_id)
      VALUES (?, ?, ?, ?, 1, ?)
    `).run(id, slug, parsed.data.label.trim(), parsed.data.icon, req.auth.id);
        const row = db
            .prepare("SELECT id, slug, label, icon, is_custom FROM event_types WHERE id = ?")
            .get(id);
        res.status(201).json(toView(row));
    }
    catch (error) {
        next(error);
    }
});
//# sourceMappingURL=eventTypes.routes.js.map