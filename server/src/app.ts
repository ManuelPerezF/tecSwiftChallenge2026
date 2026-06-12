import cors from "cors";
import express from "express";
import os from "node:os";
import { applicationsRouter } from "./modules/applications/routes/applications.routes.js";
import { assignmentsRouter } from "./modules/assignments/routes/assignments.routes.js";
import { authRouter } from "./modules/auth/routes/auth.routes.js";
import { familiesRouter } from "./modules/families/routes/families.routes.js";
import { messagesRouter } from "./modules/messages/routes/messages.routes.js";
import { requestsRouter } from "./modules/requests/routes/requests.routes.js";
import { studentsRouter } from "./modules/students/routes/students.routes.js";
import { universitiesRouter } from "./modules/universities/routes/universities.routes.js";
import "./shared/db/sqlite.js";
import { errorMiddleware } from "./shared/middlewares/error.middleware.js";
import { attachWebSocketServer } from "./ws/socketServer.js";

const app = express();
const PORT = Number(process.env.PORT ?? 3000);

app.use(cors());
app.use(express.json());

app.use("/api/auth", authRouter);
app.use("/api/families", familiesRouter);
app.use("/api/universities", universitiesRouter);
app.use("/api/requests", requestsRouter);
app.use("/api/applications", applicationsRouter);
app.use("/api/assignments", assignmentsRouter);
app.use("/api/students", studentsRouter);
app.use("/api/messages", messagesRouter);

app.get("/health", (_req, res) => {
  res.json({ status: "ok", app: "Kuidar" });
});

app.use(errorMiddleware);

function lanIPv4(): string | null {
  try {
    for (const iface of Object.values(os.networkInterfaces())) {
      for (const addr of iface ?? []) {
        if (addr.family === "IPv4" && !addr.internal) return addr.address;
      }
    }
  } catch {
    // sandbox / permisos restringidos — omitir log de IP LAN
  }
  return null;
}

const server = app.listen(PORT, "0.0.0.0", () => {
  const lan = lanIPv4();
  console.log(`\n  🫀  Kuidar server  →  http://localhost:${PORT}`);
  if (lan) console.log(`      Red local      →  http://${lan}:${PORT}  (usa esta IP en el iPhone)`);
  console.log(`      WebSocket      →  ws://localhost:${PORT}/ws\n`);
});

attachWebSocketServer(server);

server.on("error", (err: NodeJS.ErrnoException) => {
  if (err.code === "EADDRINUSE") {
    console.error(`\n  ❌  Port ${PORT} already in use. Kill the process with:\n\n     lsof -ti :${PORT} | xargs kill -9\n`);
    process.exit(1);
  } else {
    throw err;
  }
});
