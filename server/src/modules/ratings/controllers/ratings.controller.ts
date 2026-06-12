import type { NextFunction, Request, Response } from "express";
import type { CreateRatingBody } from "../models/ratings.model.js";
import { ratingsService } from "../services/ratings.service.js";

export const ratingsController = {
  create(req: Request, res: Response, next: NextFunction): void {
    try {
      const result = ratingsService.create(req.auth!, req.params.id as string, req.body as CreateRatingBody);
      res.status(201).json(result);
    } catch (error) {
      next(error);
    }
  },

  listForStudent(req: Request, res: Response, next: NextFunction): void {
    try {
      res.json(ratingsService.listForStudent(req.params.id as string));
    } catch (error) {
      next(error);
    }
  },
};
