import type { NextFunction, Request, Response } from "express";
import type { JoinFamilyBody } from "../models/families.model.js";
import { familiesService } from "../services/families.service.js";

export const familiesController = {
  me(req: Request, res: Response, next: NextFunction): void {
    try {
      res.json(familiesService.me(req.auth!));
    } catch (error) {
      next(error);
    }
  },

  join(req: Request, res: Response, next: NextFunction): void {
    try {
      res.json(familiesService.join(req.auth!, req.body as JoinFamilyBody));
    } catch (error) {
      next(error);
    }
  },
};
