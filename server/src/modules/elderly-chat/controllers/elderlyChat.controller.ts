import type { NextFunction, Request, Response } from "express";
import type { SendElderlyMessageBody } from "../models/elderlyChat.model.js";
import { elderlyChatService } from "../services/elderlyChat.service.js";

export const elderlyChatController = {
  listMatches(req: Request, res: Response, next: NextFunction): void {
    try {
      res.json(elderlyChatService.listMatches(req.auth!));
    } catch (error) {
      next(error);
    }
  },

  listMessages(req: Request, res: Response, next: NextFunction): void {
    try {
      res.json(elderlyChatService.listMessages(req.auth!, req.params.matchId as string));
    } catch (error) {
      next(error);
    }
  },

  sendMessage(req: Request, res: Response, next: NextFunction): void {
    try {
      res.status(201).json(
        elderlyChatService.sendMessage(req.auth!, req.params.matchId as string, req.body as SendElderlyMessageBody),
      );
    } catch (error) {
      next(error);
    }
  },
};
