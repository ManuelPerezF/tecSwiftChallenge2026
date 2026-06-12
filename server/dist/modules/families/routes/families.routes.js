import { Router } from "express";
import { requireAuth, requireRole } from "../../../shared/middlewares/auth.middleware.js";
import { validateBody } from "../../../shared/utils/validateBody.js";
import { familiesController } from "../controllers/families.controller.js";
import { joinFamilyBodySchema } from "../models/families.model.js";
export const familiesRouter = Router();
familiesRouter.use(requireAuth);
familiesRouter.get("/me", requireRole("family", "elderly"), familiesController.me);
familiesRouter.post("/join", requireRole("elderly"), validateBody(joinFamilyBodySchema), familiesController.join);
//# sourceMappingURL=families.routes.js.map