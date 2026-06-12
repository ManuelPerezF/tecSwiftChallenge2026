import type { NextFunction, Request, Response } from "express";
import type { LocationBody } from "../models/assignments.model.js";
import { assignmentsService } from "../services/assignments.service.js";

export const assignmentsController = {
  getById(req: Request, res: Response, next: NextFunction): void {
    try {
      res.json(assignmentsService.findById(req.params.id as string));
    } catch (error) {
      next(error);
    }
  },

  listMine(req: Request, res: Response, next: NextFunction): void {
    try {
      res.json(assignmentsService.listMine(req.auth!));
    } catch (error) {
      next(error);
    }
  },

  listForFamily(req: Request, res: Response, next: NextFunction): void {
    try {
      res.json(assignmentsService.listForFamily(req.auth!));
    } catch (error) {
      next(error);
    }
  },

  listForElderly(req: Request, res: Response, next: NextFunction): void {
    try {
      res.json(assignmentsService.listForElderly(req.auth!));
    } catch (error) {
      next(error);
    }
  },

  enCamino(req: Request, res: Response, next: NextFunction): void {
    try {
      res.json(assignmentsService.enCamino(req.auth!, req.params.id as string));
    } catch (error) {
      next(error);
    }
  },

  iniciar(req: Request, res: Response, next: NextFunction): void {
    try {
      res.json(assignmentsService.iniciar(req.auth!, req.params.id as string));
    } catch (error) {
      next(error);
    }
  },

  confirmarInicio(req: Request, res: Response, next: NextFunction): void {
    try {
      res.json(assignmentsService.confirmarInicio(req.auth!, req.params.id as string));
    } catch (error) {
      next(error);
    }
  },

  completar(req: Request, res: Response, next: NextFunction): void {
    try {
      res.json(assignmentsService.completar(req.auth!, req.params.id as string));
    } catch (error) {
      next(error);
    }
  },

  cancelar(req: Request, res: Response, next: NextFunction): void {
    try {
      res.json(assignmentsService.cancelar(req.auth!, req.params.id as string));
    } catch (error) {
      next(error);
    }
  },

  postLocation(req: Request, res: Response, next: NextFunction): void {
    try {
      res.json(assignmentsService.postLocation(req.auth!, req.params.id as string, req.body as LocationBody));
    } catch (error) {
      next(error);
    }
  },

  getLocations(req: Request, res: Response, next: NextFunction): void {
    try {
      res.json(assignmentsService.getLocations(req.auth!, req.params.id as string));
    } catch (error) {
      next(error);
    }
  },
};
