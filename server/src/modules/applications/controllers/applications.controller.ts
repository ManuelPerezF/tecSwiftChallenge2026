import type { NextFunction, Request, Response } from "express";
import type { ApplyBody } from "../models/applications.model.js";
import { applicationsService } from "../services/applications.service.js";

export const applicationsController = {
  apply(req: Request, res: Response, next: NextFunction): void {
    try {
      const result = applicationsService.apply(req.auth!, req.params.id as string, req.body as ApplyBody);
      res.status(201).json(result);
    } catch (error) {
      next(error);
    }
  },

  listForRequest(req: Request, res: Response, next: NextFunction): void {
    try {
      res.json(applicationsService.listForRequest(req.auth!, req.params.id as string));
    } catch (error) {
      next(error);
    }
  },

  listMine(req: Request, res: Response, next: NextFunction): void {
    try {
      res.json(applicationsService.listMine(req.auth!));
    } catch (error) {
      next(error);
    }
  },

  approve(req: Request, res: Response, next: NextFunction): void {
    try {
      res.json(applicationsService.approve(req.auth!, req.params.id as string));
    } catch (error) {
      next(error);
    }
  },

  reject(req: Request, res: Response, next: NextFunction): void {
    try {
      res.json(applicationsService.reject(req.auth!, req.params.id as string));
    } catch (error) {
      next(error);
    }
  },
};
