import { Router } from "express";
import { requireAuth, requireRole } from "../../../shared/middlewares/auth.middleware.js";
import { validateBody } from "../../../shared/utils/validateBody.js";
import { elderlyChatController } from "../controllers/elderlyChat.controller.js";
import { sendElderlyMessageBodySchema } from "../models/elderlyChat.model.js";
// 3.13/3.14 — matches y chat adulto mayor ↔ adulto mayor (gateado por control parental 3.16)
export const elderlyChatRouter = Router();
elderlyChatRouter.use(requireAuth, requireRole("elderly"));
elderlyChatRouter.get("/matches", elderlyChatController.listMatches);
elderlyChatRouter.get("/:matchId/messages", elderlyChatController.listMessages);
elderlyChatRouter.post("/:matchId/messages", validateBody(sendElderlyMessageBodySchema), elderlyChatController.sendMessage);
//# sourceMappingURL=elderlyChat.routes.js.map