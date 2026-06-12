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

  listCommunityEvents(_req: Request, res: Response, next: NextFunction): void {
    try {
      res.json(requestsService.findCommunityEvents());
    } catch (error) {
      next(error);
    }
  },

  registerAttendee(req: Request, res: Response, next: NextFunction): void {
    try {
      res.status(201).json(requestsService.registerAttendee(req.auth!, req.params.id as string));
    } catch (error) {
      next(error);
    }
  },

  listAttendees(req: Request, res: Response, next: NextFunction): void {
    try {
      res.json(requestsService.listAttendees(req.params.id as string));
    } catch (error) {
      next(error);
    }
  },

  unregisterAttendee(req: Request, res: Response, next: NextFunction): void {
    try {
      res.json(requestsService.unregisterAttendee(req.auth!, req.params.id as string));
    } catch (error) {
      next(error);
    }
  },
};
