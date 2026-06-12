import { v4 as uuidv4 } from "uuid";
import { db } from "../../../shared/db/sqlite.js";
import { UnauthorizedError } from "../../../shared/errors/appError.js";
import { verifyPassword } from "../../../shared/utils/password.js";
export const authService = {
    login(data) {
        const email = data.email.trim().toLowerCase();
        const user = db.prepare("SELECT * FROM users WHERE email = ?").get(email);
        if (!user || !verifyPassword(data.password, user.password_hash)) {
            throw new UnauthorizedError();
        }
        const token = uuidv4();
        const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
        db.prepare(`
      INSERT INTO sessions (id, user_id, expires_at)
      VALUES (?, ?, ?)
    `).run(token, user.id, expiresAt);
        return {
            token,
            user: {
                id: user.id,
                name: user.name,
                email: user.email,
                role: user.role,
            },
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