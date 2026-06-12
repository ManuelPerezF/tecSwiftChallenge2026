import { Router } from "express";
import { validateBody } from "../../../shared/utils/validateBody.js";
import { authController } from "../controllers/auth.controller.js";
import { loginBodySchema, logoutBodySchema } from "../models/auth.model.js";
export const authRouter = Router();
authRouter.post("/login", validateBody(loginBodySchema), authController.login);
authRouter.post("/logout", validateBody(logoutBodySchema), authController.logout);
//# sourceMappingURL=auth.routes.js.map