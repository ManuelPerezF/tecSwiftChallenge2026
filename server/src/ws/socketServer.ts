import type { Server as HttpServer } from "node:http";
import { v4 as uuidv4 } from "uuid";
import { WebSocket, WebSocketServer } from "ws";
import { db } from "../shared/db/sqlite.js";
import { resolveAuthContext, type AuthContext } from "../shared/middlewares/auth.middleware.js";

interface ClientState {
  auth: AuthContext;
  subscribedAssignments: Set<string>;
}

const clients = new Map<WebSocket, ClientState>();

// Throttle: máximo 1 update de ubicación cada 5s por usuario
const lastLocationAt = new Map<string, number>();
const LOCATION_THROTTLE_MS = 5_000;

interface IncomingMessage {
  type: "location:update" | "assignment:subscribe" | "assignment:unsubscribe";
  assignmentId?: string;
  lat?: number;
  lng?: number;
}

interface AssignmentAccessRow {
  id: string;
  student_id: string;
  status: string;
  family_id: string;
  student_user_id: string;
  elderly_user_id: string | null;
}

function assignmentAccess(assignmentId: string): AssignmentAccessRow | undefined {
  return db.prepare(`
    SELECT a.id, a.student_id, a.status, r.family_id,
           su.id AS student_user_id, eu.id AS elderly_user_id
    FROM assignments a
    JOIN activity_requests r ON a.request_id = r.id
    JOIN students s ON a.student_id = s.id
    JOIN users su ON s.user_id = su.id
    LEFT JOIN elderly_profiles e ON r.elderly_profile_id = e.id
    LEFT JOIN users eu ON e.user_id = eu.id
    WHERE a.id = ?
  `).get(assignmentId) as AssignmentAccessRow | undefined;
}

function canWatch(auth: AuthContext, row: AssignmentAccessRow): boolean {
  return (
    auth.familyId === row.family_id ||
    auth.studentId === row.student_id ||
    auth.id === row.elderly_user_id
  );
}

function send(ws: WebSocket, payload: unknown): void {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(payload));
  }
}

function locationsPayload(assignmentId: string): unknown {
  const rows = db
    .prepare("SELECT role, latitude, longitude, recorded_at FROM location_updates WHERE assignment_id = ?")
    .all(assignmentId) as Array<{ role: string; latitude: number; longitude: number; recorded_at: string }>;

  const find = (role: string) => {
    const r = rows.find((x) => x.role === role);
    return r ? { lat: r.latitude, lng: r.longitude, at: r.recorded_at } : null;
  };

  return {
    type: "location:broadcast",
    assignmentId,
    student: find("student"),
    elderly: find("elderly"),
  };
}

/** Envía la última ubicación de ambos a todos los suscritos al assignment. */
export function broadcastLocation(assignmentId: string): void {
  const payload = locationsPayload(assignmentId);
  for (const [ws, state] of clients) {
    if (state.subscribedAssignments.has(assignmentId)) {
      send(ws, payload);
    }
  }
}

/** Notifica cambio de estado de un assignment a todos los involucrados/suscritos. */
export function broadcastAssignmentStatus(assignmentId: string): void {
  const row = db.prepare(`
    SELECT a.id, a.status, a.approved_at, a.en_camino_at, a.inicio_solicitado_at,
           a.checkin_at, a.checkout_at, a.hours_logged,
           r.family_id, a.student_id
    FROM assignments a JOIN activity_requests r ON a.request_id = r.id
    WHERE a.id = ?
  `).get(assignmentId) as {
    id: string; status: string; approved_at: string; en_camino_at: string | null;
    inicio_solicitado_at: string | null;
    checkin_at: string | null; checkout_at: string | null; hours_logged: number;
    family_id: string; student_id: string;
  } | undefined;
  if (!row) return;

  const status =
    row.status === "en_camino" && row.inicio_solicitado_at && !row.checkin_at
      ? "esperando_confirmacion"
      : row.status;

  const payload = {
    type: "assignment:status",
    assignmentId: row.id,
    status,
    timestamps: {
      approvedAt: row.approved_at,
      enCaminoAt: row.en_camino_at,
      inicioSolicitadoAt: row.inicio_solicitado_at,
      checkinAt: row.checkin_at,
      checkoutAt: row.checkout_at,
    },
    hoursLogged: row.hours_logged,
  };

  for (const [ws, state] of clients) {
    const involved =
      state.subscribedAssignments.has(assignmentId) ||
      state.auth.familyId === row.family_id ||
      state.auth.studentId === row.student_id;
    if (involved) send(ws, payload);
  }
}

function handleLocationUpdate(ws: WebSocket, state: ClientState, msg: IncomingMessage): void {
  const { assignmentId, lat, lng } = msg;
  if (!assignmentId || typeof lat !== "number" || typeof lng !== "number") {
    send(ws, { type: "error", error: "Payload de ubicación inválido" });
    return;
  }
  if (state.auth.role !== "student" && state.auth.role !== "elderly") {
    send(ws, { type: "error", error: "Solo estudiante o adulto mayor envían ubicación" });
    return;
  }

  const row = assignmentAccess(assignmentId);
  if (!row || !canWatch(state.auth, row)) {
    send(ws, { type: "error", error: "Sin acceso a esta visita" });
    return;
  }
  if (row.status !== "en_camino" && row.status !== "iniciada") {
    send(ws, { type: "error", error: "La visita no está activa" });
    return;
  }

  const throttleKey = `${assignmentId}:${state.auth.id}`;
  const now = Date.now();
  if (now - (lastLocationAt.get(throttleKey) ?? 0) < LOCATION_THROTTLE_MS) return;
  lastLocationAt.set(throttleKey, now);

  const role = state.auth.role === "student" ? "student" : "elderly";
  db.prepare(`
    INSERT INTO location_updates (id, assignment_id, user_id, role, latitude, longitude, recorded_at)
    VALUES (?, ?, ?, ?, ?, ?, datetime('now'))
    ON CONFLICT(assignment_id, user_id)
    DO UPDATE SET latitude = excluded.latitude, longitude = excluded.longitude, recorded_at = excluded.recorded_at
  `).run(uuidv4(), assignmentId, state.auth.id, role, lat, lng);

  broadcastLocation(assignmentId);
}

function handleSubscribe(ws: WebSocket, state: ClientState, msg: IncomingMessage): void {
  const { assignmentId } = msg;
  if (!assignmentId) return;

  const row = assignmentAccess(assignmentId);
  if (!row || !canWatch(state.auth, row)) {
    send(ws, { type: "error", error: "Sin acceso a esta visita" });
    return;
  }

  state.subscribedAssignments.add(assignmentId);
  // Snapshot inicial al suscribirse
  send(ws, locationsPayload(assignmentId));
}

export function attachWebSocketServer(server: HttpServer): void {
  const wss = new WebSocketServer({ server, path: "/ws" });

  wss.on("connection", (ws, req) => {
    const url = new URL(req.url ?? "", "http://localhost");
    const token = url.searchParams.get("token") ?? "";
    const auth = token ? resolveAuthContext(token) : null;

    if (!auth) {
      send(ws, { type: "error", error: "Token inválido" });
      ws.close(4001, "unauthorized");
      return;
    }

    clients.set(ws, { auth, subscribedAssignments: new Set() });

    ws.on("message", (raw) => {
      const state = clients.get(ws);
      if (!state) return;

      let msg: IncomingMessage;
      try {
        msg = JSON.parse(raw.toString()) as IncomingMessage;
      } catch {
        send(ws, { type: "error", error: "JSON inválido" });
        return;
      }

      switch (msg.type) {
        case "location:update":
          handleLocationUpdate(ws, state, msg);
          break;
        case "assignment:subscribe":
          handleSubscribe(ws, state, msg);
          break;
        case "assignment:unsubscribe":
          if (msg.assignmentId) state.subscribedAssignments.delete(msg.assignmentId);
          break;
        default:
          send(ws, { type: "error", error: "Tipo de mensaje desconocido" });
      }
    });

    ws.on("close", () => {
      clients.delete(ws);
    });
  });
}
