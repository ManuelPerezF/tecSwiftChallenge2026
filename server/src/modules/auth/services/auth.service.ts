import { v4 as uuidv4 } from "uuid";
import { db, generateFamilyCode } from "../../../shared/db/sqlite.js";
import { AppError, NotFoundError, UnauthorizedError, ValidationError } from "../../../shared/errors/appError.js";
import type { AuthContext } from "../../../shared/middlewares/auth.middleware.js";
import { hashPassword, verifyPassword } from "../../../shared/utils/password.js";
import type {
  AuthResponse,
  LoginBody,
  LogoutBody,
  ProfilePayload,
  RegisterBody,
  UserRow,
} from "../models/auth.model.js";

function createSession(userId: string): string {
  const token = uuidv4();
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
  db.prepare("INSERT INTO sessions (id, user_id, expires_at) VALUES (?, ?, ?)").run(token, userId, expiresAt);
  return token;
}

export function buildProfile(userId: string, role: string): ProfilePayload {
  if (role === "family" || role === "organizer") {
    const row = db.prepare(`
      SELECT f.id AS family_id, f.family_code, f.name AS family_name
      FROM family_members fm JOIN families f ON fm.family_id = f.id
      WHERE fm.user_id = ?
    `).get(userId) as { family_id: string; family_code: string; family_name: string } | undefined;
    if (!row) return {};
    return { familyId: row.family_id, familyCode: row.family_code, familyName: row.family_name };
  }

  if (role === "student") {
    const row = db.prepare(`
      SELECT s.id, s.university_id, s.career, s.total_hours, s.average_rating, u.name AS university_name
      FROM students s LEFT JOIN universities u ON s.university_id = u.id
      WHERE s.user_id = ?
    `).get(userId) as {
      id: string; university_id: string | null; career: string;
      total_hours: number; average_rating: number; university_name: string | null;
    } | undefined;
    if (!row) return {};
    return {
      studentId: row.id,
      universityId: row.university_id ?? undefined,
      universityName: row.university_name ?? undefined,
      career: row.career,
      totalHours: row.total_hours,
      averageRating: row.average_rating,
    };
  }

  // elderly
  const row = db.prepare(`
    SELECT e.id, e.family_id, f.family_code, f.name AS family_name
    FROM elderly_profiles e LEFT JOIN families f ON e.family_id = f.id
    WHERE e.user_id = ?
  `).get(userId) as {
    id: string; family_id: string | null; family_code: string | null; family_name: string | null;
  } | undefined;
  if (!row) return {};
  return {
    elderlyProfileId: row.id,
    familyId: row.family_id ?? undefined,
    familyCode: row.family_code ?? undefined,
    familyName: row.family_name ?? undefined,
    joinedFamily: row.family_id != null,
  };
}

export const authService = {
  register(data: RegisterBody): AuthResponse {
    const email = data.email.trim().toLowerCase();

    const existing = db.prepare("SELECT id FROM users WHERE email = ?").get(email);
    if (existing) throw new AppError("Ese correo ya está registrado", 409, "EMAIL_TAKEN");

    const userId = uuidv4();

    const tx = db.transaction(() => {
      db.prepare("INSERT INTO users (id, email, password_hash, name, role) VALUES (?, ?, ?, ?, ?)")
        .run(userId, email, hashPassword(data.password), data.name.trim(), data.role);

      if (data.role === "family" || data.role === "organizer") {
        // organizer: organización comunitaria modelada como "familia" propia
        let familyId: string;
        if (data.familyCode) {
          // Unirse a familia existente con código
          const family = db.prepare("SELECT id FROM families WHERE family_code = ?")
            .get(data.familyCode.trim().toUpperCase()) as { id: string } | undefined;
          if (!family) throw new NotFoundError("Código de familia no encontrado");
          familyId = family.id;
          db.prepare("INSERT INTO family_members (id, user_id, family_id, is_primary) VALUES (?, ?, ?, 0)")
            .run(uuidv4(), userId, familyId);
        } else {
          // Crear familia nueva con código único
          familyId = uuidv4();
          let code = generateFamilyCode();
          while (db.prepare("SELECT 1 FROM families WHERE family_code = ?").get(code)) {
            code = generateFamilyCode();
          }
          db.prepare("INSERT INTO families (id, name, family_code) VALUES (?, ?, ?)")
            .run(familyId, data.familyName?.trim() || `Familia de ${data.name.trim()}`, code);
          db.prepare("INSERT INTO family_members (id, user_id, family_id, is_primary) VALUES (?, ?, ?, 1)")
            .run(uuidv4(), userId, familyId);
        }
      } else if (data.role === "student") {
        if (!data.universityId) throw new ValidationError("El estudiante debe elegir universidad");
        const uni = db.prepare("SELECT id FROM universities WHERE id = ?").get(data.universityId);
        if (!uni) throw new NotFoundError("Universidad no encontrada");
        db.prepare("INSERT INTO students (id, user_id, university_id, career) VALUES (?, ?, ?, ?)")
          .run(uuidv4(), userId, data.universityId, data.career?.trim() ?? "");
      } else {
        // elderly: perfil sin familia hasta que use el código
        db.prepare(`
          INSERT INTO elderly_profiles (id, user_id, first_name, address, neighborhood, lat, lng)
          VALUES (?, ?, ?, ?, ?, ?, ?)
        `).run(
          uuidv4(),
          userId,
          data.name.trim(),
          data.address?.trim() ?? "",
          data.neighborhood?.trim() ?? "",
          data.lat ?? 0,
          data.lng ?? 0,
        );
      }
    });
    tx();

    const token = createSession(userId);
    return {
      token,
      user: { id: userId, name: data.name.trim(), email, role: data.role },
      profile: buildProfile(userId, data.role),
    };
  },

  login(data: LoginBody): AuthResponse {
    const email = data.email.trim().toLowerCase();
    const user = db.prepare("SELECT * FROM users WHERE email = ?").get(email) as UserRow | undefined;

    if (!user || !verifyPassword(data.password, user.password_hash)) {
      throw new UnauthorizedError();
    }

    const token = createSession(user.id);
    return {
      token,
      user: { id: user.id, name: user.name, email: user.email, role: user.role },
      profile: buildProfile(user.id, user.role),
    };
  },

  me(auth: AuthContext): Omit<AuthResponse, "token"> {
    return {
      user: { id: auth.id, name: auth.name, email: auth.email, role: auth.role },
      profile: buildProfile(auth.id, auth.role),
    };
  },

  logout(data: LogoutBody): { ok: true } {
    if (data.token) {
      db.prepare("DELETE FROM sessions WHERE id = ?").run(data.token);
    }
    return { ok: true };
  },

  updateElderlyLocation(auth: AuthContext, lat: number, lng: number): { ok: true } {
    if (!auth.elderlyProfileId) throw new AppError("Solo adultos mayores pueden usar este endpoint", 403, "FORBIDDEN");
    db.prepare("UPDATE elderly_profiles SET lat = ?, lng = ? WHERE id = ?")
      .run(lat, lng, auth.elderlyProfileId);
    return { ok: true };
  },
};
