import { Router } from "express";
import { requireAuth } from "../../../shared/middlewares/auth.middleware.js";
import { validateBody } from "../../../shared/utils/validateBody.js";
import { sendMessageBodySchema, replyMessageBodySchema } from "../models/messages.model.js";
import { messagesService } from "../services/messages.service.js";
export const messagesRouter = Router();
messagesRouter.use(requireAuth);
// Family sends a message to a student
messagesRouter.post("/", validateBody(sendMessageBodySchema), (req, res, next) => {
    try {
        const message = messagesService.send(req.auth, req.body);
        res.status(201).json(message);
    }
    catch (err) {
        next(err);
    }
});
// Student fetches their inbox (auto-marks as read)
messagesRouter.get("/mine", (req, res, next) => {
    try {
        const messages = messagesService.inbox(req.auth);
        res.json(messages);
    }
    catch (err) {
        next(err);
    }
});
// Unread count
messagesRouter.get("/unread-count", (req, res, next) => {
    try {
        res.json({ count: messagesService.unreadCount(req.auth) });
    }
    catch (err) {
        next(err);
    }
});
// Family: list conversations grouped by student
messagesRouter.get("/conversations", (req, res, next) => {
    try {
        res.json(messagesService.conversations(req.auth));
    }
    catch (err) {
        next(err);
    }
});
// Student replies to a family member
messagesRouter.post("/reply", validateBody(replyMessageBodySchema), (req, res, next) => {
    try {
        const message = messagesService.reply(req.auth, req.body);
        res.status(201).json(message);
    }
    catch (err) {
        next(err);
    }
});
// Family or student: full thread (otherId = studentId for family, fromUserId for student)
messagesRouter.get("/thread/:otherId", (req, res, next) => {
    try {
        res.json(messagesService.thread(req.auth, req.params.otherId));
    }
    catch (err) {
        next(err);
    }
});
//# sourceMappingURL=messages.routes.js.map