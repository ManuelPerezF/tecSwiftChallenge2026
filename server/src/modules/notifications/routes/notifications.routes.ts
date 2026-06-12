import { Router } from "express";
import { requireAuth } from "../../../shared/middlewares/auth.middleware.js";
import { notificationsService } from "../services/notifications.service.js";

export const notificationsRouter = Router();

notificationsRouter.use(requireAuth);

notificationsRouter.get("/", (req, res, next) => {
  try {
    res.json(notificationsService.listMine(req.auth!));
  } catch (error) {
    next(error);
  }
});

notificationsRouter.get("/unread-count", (req, res, next) => {
  try {
    res.json({ count: notificationsService.unreadCount(req.auth!) });
  } catch (error) {
    next(error);
  }
});

notificationsRouter.post("/:id/read", (req, res, next) => {
  try {
    res.json(notificationsService.markRead(req.auth!, req.params.id as string));
  } catch (error) {
    next(error);
  }
});
