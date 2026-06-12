import { v4 as uuidv4 } from "uuid";
import { db, generateFamilyCode } from "../../../shared/db/sqlite.js";
import { AppError, NotFoundError, UnauthorizedError, ValidationError } from "../../../shared/errors/appError.js";
import { hashPassword, verifyPassword } from "../../../shared/utils/password.js";
function createSession(userId) {
    const token = uuidv4();
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
    db.prepare("INSERT INTO sessions (id, user_id, expires_at) VALUES (?, ?, ?)").run(token, userId, expiresAt);
    return token;
}
export function buildProfile(userId, role) {
    if (role === "family") {
        const row = db.prepare(`
      SELECT f.id AS family_id, f.family_code, f.name AS family_name
      FROM family_members fm JOIN families f ON fm.family_id = f.id
      WHERE fm.user_id = ?
    `).get(userId);
        if (!row)
            return {};
        return { familyId: row.family_id, familyCode: row.family_code, familyName: row.family_name };
    }
    if (role === "student") {
        const row = db.prepare(`
      SELECT s.id, s.university_id, s.career, s.total_hours, s.average_rating, u.name AS university_name
      FROM students s LEFT JOIN universities u ON s.university_id = u.id
      WHERE s.user_id = ?
    `).get(userId);
        if (!row)
            return {};
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
  `).get(userId);
    if (!row)
        return {};
    return {
        elderlyProfileId: row.id,
        familyId: row.family_id ?? undefined,
        familyCode: row.family_code ?? undefined,
        familyName: row.family_name ?? undefined,
        joinedFamily: row.family_id != null,
    };
}
export const authService = {
    register(data) {
        const email = data.email.trim().toLowerCase();
        const existing = db.prepare("SELECT id FROM users WHERE email = ?").get(email);
        if (existing)
            throw new AppError("Ese correo ya está registrado", 409, "EMAIL_TAKEN");
        const userId = uuidv4();
        const tx = db.transaction(() => {
            db.prepare("INSERT INTO users (id, email, password_hash, name, role) VALUES (?, ?, ?, ?, ?)")
                .run(userId, email, hashPassword(data.password), data.name.trim(), data.role);
            if (data.role === "family") {
                let familyId;
                if (data.familyCode) {
                    // Unirse a familia existente con código
                    const family = db.prepare("SELECT id FROM families WHERE family_code = ?")
                        .get(data.familyCode.trim().toUpperCase());
                    if (!family)
                        throw new NotFoundError("Código de familia no encontrado");
                    familyId = family.id;
                    db.prepare("INSERT INTO family_members (id, user_id, family_id, is_primary) VALUES (?, ?, ?, 0)")
                        .run(uuidv4(), userId, familyId);
                }
                else {
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
            }
            else if (data.role === "student") {
                if (!data.universityId)
                    throw new ValidationError("El estudiante debe elegir universidad");
                const uni = db.prepare("SELECT id FROM universities WHERE id = ?").get(data.universityId);
                if (!uni)
                    throw new NotFoundError("Universidad no encontrada");
                db.prepare("INSERT INTO students (id, user_id, university_id, career) VALUES (?, ?, ?, ?)")
                    .run(uuidv4(), userId, data.universityId, data.career?.trim() ?? "");
            }
            else {
                // elderly: perfil sin familia hasta que use el código
                db.prepare(`
          INSERT INTO elderly_profiles (id, user_id, first_name, address, neighborhood)
          VALUES (?, ?, ?, ?, ?)
        `).run(uuidv4(), userId, data.name.trim(), data.address?.trim() || "CDMX", data.neighborhood?.trim() || "CDMX");
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
    login(data) {
        const email = data.email.trim().toLowerCase();
        const user = db.prepare("SELECT * FROM users WHERE email = ?").get(email);
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
    me(auth) {
        return {
            user: { id: auth.id, name: auth.name, email: auth.email, role: auth.role },
            profile: buildProfile(auth.id, auth.role),
        };
    },
    logout(data) {
        if (data.token) {
            db.prepare("DELETE FROM sessions WHERE id = ?").run(data.token);
        }
        return { ok: true };
    },
};
//# sourceMappingURL=auth.service.js.map