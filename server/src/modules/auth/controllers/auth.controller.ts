import type { NextFunction, Request, Response } from "express";
import type { LoginBody, LogoutBody, RegisterBody } from "../models/auth.model.js";
import { authService } from "../services/auth.service.js";

export const authController = {
  register(req: Request, res: Response, next: NextFunction): void {
    try {
      const result = authService.register(req.body as RegisterBody);
      res.status(201).json(result);
    } catch (error) {
      next(error);
    }
  },

  login(req: Request, res: Response, next: NextFunction): void {
    try {
      const result = authService.login(req.body as LoginBody);
      res.status(200).json(result);
    } catch (error) {
      next(error);
    }
  },

  me(req: Request, res: Response, next: NextFunction): void {
    try {
      res.json(authService.me(req.auth!));
    } catch (error) {
      next(error);
    }
  },

  logout(req: Request, res: Response, next: NextFunction): void {
    try {
      const result = authService.logout(req.body as LogoutBody);
      res.status(200).json(result);
    } catch (error) {
      next(error);
    }
  },

  updateLocation(req: Request, res: Response, next: NextFunction): void {
    try {
      const { lat, lng } = req.body as { lat: number; lng: number };
      res.json(authService.updateElderlyLocation(req.auth!, lat, lng));
    } catch (error) {
      next(error);
    }
  },
};
