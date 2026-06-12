import { Router } from "express";
import { requireAuth, requireRole } from "../../../shared/middlewares/auth.middleware.js";
import { validateBody } from "../../../shared/utils/validateBody.js";
import { ratingsController } from "../../ratings/controllers/ratings.controller.js";
import { createRatingBodySchema } from "../../ratings/models/ratings.model.js";
import { assignmentsController } from "../controllers/assignments.controller.js";
import { locationBodySchema } from "../models/assignments.model.js";

export const assignmentsRouter = Router();

assignmentsRouter.use(requireAuth);

assignmentsRouter.get("/mine", requireRole("student"), assignmentsController.listMine);
assignmentsRouter.get("/for-family", requireRole("family", "organizer"), assignmentsController.listForFamily);
assignmentsRouter.get("/for-elderly", requireRole("elderly"), assignmentsController.listForElderly);
assignmentsRouter.get("/:id", assignmentsController.getById);

// Ciclo de visita (estudiante)
assignmentsRouter.post("/:id/en-camino", requireRole("student"), assignmentsController.enCamino);
assignmentsRouter.post("/:id/iniciar", requireRole("student"), assignmentsController.iniciar);
assignmentsRouter.post("/:id/confirmar-inicio", requireRole("elderly"), assignmentsController.confirmarInicio);
assignmentsRouter.post("/:id/completar", requireRole("student"), assignmentsController.completar);
// 3.15: doble confirmación de fin (familia o adulto mayor)
assignmentsRouter.post("/:id/confirm-completion", requireRole("family", "elderly", "organizer"), assignmentsController.confirmCompletion);
assignmentsRouter.post("/:id/cancelar", requireRole("family", "organizer"), assignmentsController.cancelar);

// 3.7: el becario modifica su asignación mientras esté en 'approved'
assignmentsRouter.post("/:id/cancelar-estudiante", requireRole("student"), assignmentsController.cancelarPorEstudiante);
assignmentsRouter.post("/:id/proponer-cambio", requireRole("student"), assignmentsController.proposeChange);
assignmentsRouter.get("/:id/proposal", assignmentsController.getPendingProposal);
assignmentsRouter.post("/proposals/:id/respond", requireRole("family", "organizer"), assignmentsController.respondToProposal);

// Ubicación (REST fallback del WebSocket)
assignmentsRouter.post(
  "/:id/location",
  requireRole("student", "elderly"),
  validateBody(locationBodySchema),
  assignmentsController.postLocation,
);
assignmentsRouter.get("/:id/locations", assignmentsController.getLocations);

// Calificación post-visita
assignmentsRouter.post(
  "/:id/ratings",
  requireRole("family", "elderly"),
  validateBody(createRatingBodySchema),
  ratingsController.create,
);
