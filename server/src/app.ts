import cors from "cors";
import express from "express";
import { applicationsRouter } from "./modules/applications/routes/applications.routes.js";
import { assignmentsRouter } from "./modules/assignments/routes/assignments.routes.js";
import { authRouter } from "./modules/auth/routes/auth.routes.js";
import { familiesRouter } from "./modules/families/routes/families.routes.js";
import { requestsRouter } from "./modules/requests/routes/requests.routes.js";
import { studentsRouter } from "./modules/students/routes/students.routes.js";
import { universitiesRouter } from "./modules/universities/routes/universities.routes.js";
import "./shared/db/sqlite.js";
import { errorMiddleware } from "./shared/middlewares/error.middleware.js";
import { attachWebSocketServer } from "./ws/socketServer.js";

const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());

app.use("/api/auth", authRouter);
app.use("/api/families", familiesRouter);
app.use("/api/universities", universitiesRouter);
app.use("/api/requests", requestsRouter);
app.use("/api/applications", applicationsRouter);
app.use("/api/assignments", assignmentsRouter);
app.use("/api/students", studentsRouter);

app.get("/health", (_req, res) => {
  res.json({ status: "ok", app: "Kuidar" });
});

app.use(errorMiddleware);

const server = app.listen(PORT, () => {
  console.log(`\n  🫀  Kuidar server  →  http://localhost:${PORT}\n      WebSocket      →  ws://localhost:${PORT}/ws\n`);
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
