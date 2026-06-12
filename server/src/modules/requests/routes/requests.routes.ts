import { Router } from "express";
import { requireAuth, requireRole } from "../../../shared/middlewares/auth.middleware.js";
import { validateBody } from "../../../shared/utils/validateBody.js";
import { applicationsController } from "../../applications/controllers/applications.controller.js";
import { applyBodySchema } from "../../applications/models/applications.model.js";
import { requestsController } from "../controllers/requests.controller.js";
import { createRequestBodySchema } from "../models/requests.model.js";

export const requestsRouter = Router();

requestsRouter.use(requireAuth);

requestsRouter.get("/mine", requireRole("family", "organizer"), requestsController.listMine);
requestsRouter.get("/open", requireRole("student"), requestsController.listOpen);
requestsRouter.get("/events", requestsController.listCommunityEvents);
requestsRouter.get("/:id", requestsController.getById);
requestsRouter.post("/", requireRole("family", "organizer"), validateBody(createRequestBodySchema), requestsController.create);
requestsRouter.delete("/:id", requireRole("family", "organizer"), requestsController.remove);

// Asistentes a eventos comunitarios
requestsRouter.post("/:id/attendees", requireRole("family", "elderly"), requestsController.registerAttendee);
requestsRouter.get("/:id/attendees", requestsController.listAttendees);
requestsRouter.delete("/:id/attendees", requireRole("family", "elderly"), requestsController.unregisterAttendee);
// Alias semánticos (3.9)
requestsRouter.post("/:id/attend", requireRole("family", "elderly"), requestsController.registerAttendee);
requestsRouter.delete("/:id/attend", requireRole("family", "elderly"), requestsController.unregisterAttendee);

// Postulaciones anidadas
requestsRouter.post(
  "/:id/applications",
  requireRole("student"),
  validateBody(applyBodySchema),
  applicationsController.apply,
);
requestsRouter.get("/:id/applications", requireRole("family", "organizer"), applicationsController.listForRequest);
