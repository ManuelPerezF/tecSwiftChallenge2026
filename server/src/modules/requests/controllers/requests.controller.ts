import type { NextFunction, Request, Response } from "express";
import type { CreateRequestBody } from "../models/requests.model.js";
import { requestsService } from "../services/requests.service.js";

export const requestsController = {
  listMine(req: Request, res: Response, next: NextFunction): void {
    try {
      res.json(requestsService.findMine(req.auth!));
    } catch (error) {
      next(error);
    }
  },

  listOpen(_req: Request, res: Response, next: NextFunction): void {
    try {
      res.json(requestsService.findOpen());
    } catch (error) {
      next(error);
    }
  },

  getById(req: Request, res: Response, next: NextFunction): void {
    try {
      res.json(requestsService.findById(req.params.id as string));
    } catch (error) {
      next(error);
    }
  },

  create(req: Request, res: Response, next: NextFunction): void {
    try {
      const result = requestsService.create(req.auth!, req.body as CreateRequestBody);
      res.status(201).json(result);
    } catch (error) {
      next(error);
    }
  },

  remove(req: Request, res: Response, next: NextFunction): void {
    try {
      res.json(requestsService.remove(req.auth!, req.params.id as string));
    } catch (error) {
      next(error);
    }
  },
};
