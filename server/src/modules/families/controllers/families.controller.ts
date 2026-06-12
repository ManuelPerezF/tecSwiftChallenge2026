import type { NextFunction, Request, Response } from "express";
import type { JoinFamilyBody, UpdateElderlyBody } from "../models/families.model.js";
import { familiesService } from "../services/families.service.js";

export const familiesController = {
  // 3.12/3.16 — edición de perfil del adulto mayor + control parental
  updateElderly(req: Request, res: Response, next: NextFunction): void {
    try {
      res.json(familiesService.updateElderly(req.auth!, req.params.id as string, req.body as UpdateElderlyBody));
    } catch (error) {
      next(error);
    }
  },

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
