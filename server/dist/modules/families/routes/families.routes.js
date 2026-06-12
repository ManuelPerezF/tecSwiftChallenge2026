import { Router } from "express";
import { requireAuth, requireRole } from "../../../shared/middlewares/auth.middleware.js";
import { validateBody } from "../../../shared/utils/validateBody.js";
import { familiesController } from "../controllers/families.controller.js";
import { joinFamilyBodySchema, updateElderlyBodySchema } from "../models/families.model.js";
export const familiesRouter = Router();
familiesRouter.use(requireAuth);
familiesRouter.get("/me", requireRole("family", "elderly"), familiesController.me);
familiesRouter.post("/join", requireRole("elderly"), validateBody(joinFamilyBodySchema), familiesController.join);
// 3.12/3.16 — familia dueña o el propio adulto mayor (si tiene permiso) editan el perfil
familiesRouter.patch("/elderly/:id", requireRole("family", "elderly"), validateBody(updateElderlyBodySchema), familiesController.updateElderly);
//# sourceMappingURL=families.routes.js.map