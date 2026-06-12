import { Router } from "express";
import { requireAuth, requireRole } from "../../../shared/middlewares/auth.middleware.js";
import { applicationsController } from "../controllers/applications.controller.js";
export const applicationsRouter = Router();
applicationsRouter.use(requireAuth);
applicationsRouter.get("/mine", requireRole("student"), applicationsController.listMine);
applicationsRouter.post("/:id/approve", requireRole("family", "organizer"), applicationsController.approve);
applicationsRouter.post("/:id/reject", requireRole("family", "organizer"), applicationsController.reject);
//# sourceMappingURL=applications.routes.js.map