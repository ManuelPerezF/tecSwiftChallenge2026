import { Router } from "express";
import { requireAuth } from "../../../shared/middlewares/auth.middleware.js";
import { validateBody } from "../../../shared/utils/validateBody.js";
import { authController } from "../controllers/auth.controller.js";
import { loginBodySchema, logoutBodySchema, registerBodySchema } from "../models/auth.model.js";

export const authRouter = Router();

authRouter.post("/register", validateBody(registerBodySchema), authController.register);
authRouter.post("/login", validateBody(loginBodySchema), authController.login);
authRouter.get("/me", requireAuth, authController.me);
authRouter.post("/logout", validateBody(logoutBodySchema), authController.logout);
