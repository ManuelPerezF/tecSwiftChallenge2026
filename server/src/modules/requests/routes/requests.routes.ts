import { Router } from "express";
import { requireAuth, requireRole } from "../../../shared/middlewares/auth.middleware.js";
import { validateBody } from "../../../shared/utils/validateBody.js";
import { applicationsController } from "../../applications/controllers/applications.controller.js";
import { applyBodySchema } from "../../applications/models/applications.model.js";
import { requestsController } from "../controllers/requests.controller.js";
import { createRequestBodySchema } from "../models/requests.model.js";

export const requestsRouter = Router();

requestsRouter.use(requireAuth);

requestsRouter.get("/mine", requireRole("family"), requestsController.listMine);
requestsRouter.get("/open", requireRole("student"), requestsController.listOpen);
requestsRouter.get("/:id", requestsController.getById);
requestsRouter.post("/", requireRole("family"), validateBody(createRequestBodySchema), requestsController.create);
requestsRouter.delete("/:id", requireRole("family"), requestsController.remove);

// Postulaciones anidadas
requestsRouter.post(
  "/:id/applications",
  requireRole("student"),
  validateBody(applyBodySchema),
  applicationsController.apply,
);
requestsRouter.get("/:id/applications", requireRole("family"), applicationsController.listForRequest);
