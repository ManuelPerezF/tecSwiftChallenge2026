import { v4 as uuidv4 } from "uuid";
import { db } from "../../../shared/db/sqlite.js";
import { AppError, NotFoundError, UnauthorizedError } from "../../../shared/errors/appError.js";
import { notificationsService } from "../../notifications/services/notifications.service.js";
import { sendToUser } from "../../../ws/socketServer.js";
/**
 * 3.13/3.14 — Matching y chat adulto mayor ↔ adulto mayor.
 *
 * Toda la heurística es local (SQL + scoring propio, sin APIs externas):
 *   score = tagsCompartidos * 2 + cercanía (0..1) + bonusEdad (0..1)
 * Hay match cuando comparten ≥1 tag, viven dentro del radio y (si ambos
 * declararon edad) la diferencia es ≤ MATCH_AGE_RANGE años.
 *
 * Control parental (3.16) — decisiones documentadas:
 *   - Si la familia desactivó `allow_social_connections` para el adulto mayor
 *     logueado, los endpoints responden 403: no ve matches ni chats (ni lectura).
 *   - Si quien lo desactivó fue el OTRO lado, el hilo existente queda visible en
 *     modo solo-lectura (`locked: true`): se puede leer pero no enviar.
 *   - Nunca se generan matches nuevos si cualquiera de los dos lados tiene el
 *     flag apagado, y los adultos de una misma familia no se matchean entre sí.
 */
const MATCH_RADIUS_KM = Number(process.env.MATCH_RADIUS_KM ?? 5);
const MATCH_AGE_RANGE = Number(process.env.MATCH_AGE_RANGE ?? 12);
const PROFILE_COLUMNS = "id, user_id, family_id, first_name, neighborhood, lat, lng, tags, age, allow_social_connections";
function parseTags(raw) {
    try {
        const parsed = JSON.parse(raw);
        return Array.isArray(parsed) ? parsed.filter((t) => typeof t === "string") : [];
    }
    catch {
        return [];
    }
}
/** Misma haversine simplificada que usa notifications.service / la app. */
function distanceMeters(lat1, lng1, lat2, lng2) {
    const dLat = (lat1 - lat2) * 111_320;
    const dLng = (lng1 - lng2) * 111_320 * Math.cos((lat2 * Math.PI) / 180);
    return Math.sqrt(dLat * dLat + dLng * dLng);
}
function normalizedTag(tag) {
    return tag.trim().toLowerCase();
}
function sharedTags(a, b) {
    const setB = new Set(b.map(normalizedTag));
    return a.filter((t) => setB.has(normalizedTag(t)));
}
function getProfile(id) {
    return db.prepare(`SELECT ${PROFILE_COLUMNS} FROM elderly_profiles WHERE id = ?`).get(id);
}
/** Perfil del adulto mayor logueado, validando el flag de control parental. */
function requireSocialProfile(auth) {
    if (auth.role !== "elderly" || !auth.elderlyProfileId) {
        throw new UnauthorizedError("Solo adultos mayores pueden usar el chat comunitario");
    }
    const profile = getProfile(auth.elderlyProfileId);
    if (!profile)
        throw new NotFoundError("Perfil no encontrado");
    if (profile.allow_social_connections !== 1) {
        throw new AppError("Tu familia tiene desactivadas las conexiones sociales", 403, "SOCIAL_DISABLED");
    }
    return profile;
}
/**
 * Recalcula matches del perfil contra los demás adultos mayores sociales.
 * Inserta solo pares nuevos (UNIQUE en orden normalizado) y notifica a ambos.
 */
function refreshMatchesFor(me) {
    if (me.lat === 0 && me.lng === 0)
        return;
    const myTags = parseTags(me.tags);
    if (myTags.length === 0)
        return;
    const candidates = db.prepare(`
    SELECT ${PROFILE_COLUMNS} FROM elderly_profiles
    WHERE id != ? AND allow_social_connections = 1 AND user_id IS NOT NULL
  `).all(me.id);
    const insert = db.prepare("INSERT OR IGNORE INTO elderly_matches (id, elderly_a_id, elderly_b_id, score) VALUES (?, ?, ?, ?)");
    for (const other of candidates) {
        if (me.family_id !== null && other.family_id === me.family_id)
            continue;
        if (other.lat === 0 && other.lng === 0)
            continue;
        const common = sharedTags(myTags, parseTags(other.tags));
        if (common.length === 0)
            continue;
        const dist = distanceMeters(me.lat, me.lng, other.lat, other.lng);
        if (dist > MATCH_RADIUS_KM * 1000)
            continue;
        let ageBonus = 0.5; // neutral si alguno no declaró edad
        if (me.age !== null && other.age !== null) {
            const diff = Math.abs(me.age - other.age);
            if (diff > MATCH_AGE_RANGE)
                continue;
            ageBonus = 1 - diff / MATCH_AGE_RANGE;
        }
        const score = common.length * 2 + (1 - dist / (MATCH_RADIUS_KM * 1000)) + ageBonus;
        const [a, b] = me.id < other.id ? [me.id, other.id] : [other.id, me.id];
        const matchId = uuidv4();
        const result = insert.run(matchId, a, b, Math.round(score * 100) / 100);
        // Match nuevo → notificación SOLO a los adultos mayores (3.13: no a la familia)
        if (result.changes > 0) {
            const pairs = [[me, other], [other, me]];
            for (const [recipient, matched] of pairs) {
                if (!recipient.user_id)
                    continue;
                notificationsService.create(recipient.user_id, "match_found", "Alguien cerca comparte tus gustos", `${matched.first_name} también disfruta: ${common.join(", ")}. Ya pueden platicar en Kuidar.`, { matchId, otherName: matched.first_name });
            }
        }
    }
}
function getMatch(matchId) {
    return db
        .prepare("SELECT id, elderly_a_id, elderly_b_id, score, created_at FROM elderly_matches WHERE id = ?")
        .get(matchId);
}
function otherProfileId(match, myProfileId) {
    return match.elderly_a_id === myProfileId ? match.elderly_b_id : match.elderly_a_id;
}
function requireParticipant(auth, matchId) {
    const me = requireSocialProfile(auth);
    const match = getMatch(matchId);
    if (!match || (match.elderly_a_id !== me.id && match.elderly_b_id !== me.id)) {
        throw new NotFoundError("Conversación no encontrada");
    }
    const other = getProfile(otherProfileId(match, me.id));
    if (!other)
        throw new NotFoundError("El otro perfil ya no existe");
    return { me, match, other };
}
export const elderlyChatService = {
    /** GET /elderly-chat/matches — recalcula y lista los matches del adulto mayor. */
    listMatches(auth) {
        const me = requireSocialProfile(auth);
        refreshMatchesFor(me);
        const rows = db.prepare(`
      SELECT id, elderly_a_id, elderly_b_id, score, created_at
      FROM elderly_matches
      WHERE elderly_a_id = ? OR elderly_b_id = ?
      ORDER BY created_at DESC
    `).all(me.id, me.id);
        const myTags = parseTags(me.tags);
        const views = [];
        for (const match of rows) {
            const other = getProfile(otherProfileId(match, me.id));
            if (!other)
                continue;
            const last = db.prepare(`
        SELECT body, created_at FROM elderly_messages
        WHERE match_id = ? ORDER BY created_at DESC LIMIT 1
      `).get(match.id);
            const { n: unread } = db.prepare(`
        SELECT COUNT(*) AS n FROM elderly_messages
        WHERE match_id = ? AND sender_profile_id != ? AND read_at IS NULL
      `).get(match.id, me.id);
            views.push({
                id: match.id,
                otherProfileId: other.id,
                otherName: other.first_name,
                otherNeighborhood: other.neighborhood,
                otherAge: other.age,
                sharedTags: sharedTags(myTags, parseTags(other.tags)),
                score: match.score,
                locked: other.allow_social_connections !== 1,
                lastMessage: last?.body ?? null,
                lastMessageAt: last?.created_at ?? null,
                unreadCount: unread,
                createdAt: match.created_at,
            });
        }
        return views;
    },
    /** GET /elderly-chat/:matchId/messages — historial; marca como leídos los recibidos. */
    listMessages(auth, matchId) {
        const { me, match } = requireParticipant(auth, matchId);
        db.prepare(`
      UPDATE elderly_messages SET read_at = datetime('now')
      WHERE match_id = ? AND sender_profile_id != ? AND read_at IS NULL
    `).run(match.id, me.id);
        const rows = db.prepare(`
      SELECT m.id, m.match_id, m.sender_profile_id, m.body, m.read_at, m.created_at,
             e.first_name AS sender_name
      FROM elderly_messages m JOIN elderly_profiles e ON m.sender_profile_id = e.id
      WHERE m.match_id = ?
      ORDER BY m.created_at ASC
    `).all(match.id);
        return rows.map((r) => ({
            id: r.id,
            matchId: r.match_id,
            senderProfileId: r.sender_profile_id,
            senderName: r.sender_name,
            body: r.body,
            readAt: r.read_at,
            createdAt: r.created_at,
            isMine: r.sender_profile_id === me.id,
        }));
    },
    /** POST /elderly-chat/:matchId/messages — requiere flag social activo en AMBOS lados. */
    sendMessage(auth, matchId, data) {
        const { me, match, other } = requireParticipant(auth, matchId);
        if (other.allow_social_connections !== 1) {
            throw new AppError("La familia de tu contacto pausó sus conexiones sociales", 403, "SOCIAL_DISABLED");
        }
        const id = uuidv4();
        db.prepare("INSERT INTO elderly_messages (id, match_id, sender_profile_id, body) VALUES (?, ?, ?, ?)").run(id, match.id, me.id, data.body.trim());
        const view = {
            id,
            matchId: match.id,
            senderProfileId: me.id,
            senderName: me.first_name,
            body: data.body.trim(),
            readAt: null,
            createdAt: new Date().toISOString(),
            isMine: true,
        };
        // Tiempo real: WS nativo a ambos participantes (el cliente ignora tipos desconocidos)
        for (const userId of [me.user_id, other.user_id]) {
            if (userId)
                sendToUser(userId, { type: "elderly-chat:message", message: { ...view, isMine: userId === me.user_id } });
        }
        return view;
    },
};
//# sourceMappingURL=elderlyChat.service.js.map