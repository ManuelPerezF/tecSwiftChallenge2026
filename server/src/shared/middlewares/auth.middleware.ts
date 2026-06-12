import type { NextFunction, Request, Response } from "express";
import { db } from "../db/sqlite.js";
import { UnauthorizedError } from "../errors/appError.js";

export type UserRole = "family" | "student" | "elderly";

export interface AuthContext {
  id: string;
  name: string;
  email: string;
  role: UserRole;
  familyId?: string;
  studentId?: string;
  elderlyProfileId?: string;
}

declare global {
  namespace Express {
    interface Request {
      auth?: AuthContext;
    }
  }
}

interface SessionRow {
  user_id: string;
  expires_at: string;
}

interface UserRow {
  id: string;
  name: string;
  email: string;
  role: UserRole;
}

export function resolveAuthContext(token: string): AuthContext | null {
  const session = db
    .prepare("SELECT user_id, expires_at FROM sessions WHERE id = ?")
    .get(token) as SessionRow | undefined;

  if (!session || new Date(session.expires_at) < new Date()) return null;

  const user = db
    .prepare("SELECT id, name, email, role FROM users WHERE id = ?")
    .get(session.user_id) as UserRow | undefined;

  if (!user) return null;

  const ctx: AuthContext = { id: user.id, name: user.name, email: user.email, role: user.role };

  if (user.role === "family") {
    const member = db
      .prepare("SELECT family_id FROM family_members WHERE user_id = ?")
      .get(user.id) as { family_id: string } | undefined;
    if (member) ctx.familyId = member.family_id;
  } else if (user.role === "student") {
    const student = db
      .prepare("SELECT id FROM students WHERE user_id = ?")
      .get(user.id) as { id: string } | undefined;
    if (student) ctx.studentId = student.id;
  } else if (user.role === "elderly") {
    const profile = db
      .prepare("SELECT id, family_id FROM elderly_profiles WHERE user_id = ?")
      .get(user.id) as { id: string; family_id: string | null } | undefined;
    if (profile) {
      ctx.elderlyProfileId = profile.id;
      if (profile.family_id) ctx.familyId = profile.family_id;
    }
  }

  return ctx;
}

export function requireAuth(req: Request, _res: Response, next: NextFunction): void {
  const header = req.headers.authorization ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : "";

  if (!token) {
    next(new UnauthorizedError("Falta token de autenticación"));
    return;
  }

  const ctx = resolveAuthContext(token);
  if (!ctx) {
    next(new UnauthorizedError("Sesión inválida o expirada"));
    return;
  }

  req.auth = ctx;
  next();
}

export function requireRole(...roles: UserRole[]) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    if (!req.auth || !roles.includes(req.auth.role)) {
      next(new UnauthorizedError("No tienes permiso para esta acción"));
      return;
    }
    next();
  };
}
