import cors from "cors";
import express from "express";
import { authRouter } from "./modules/auth/routes/auth.routes.js";
import { ratingsRouter } from "./modules/ratings/routes/ratings.routes.js";
import { requestsRouter } from "./modules/requests/routes/requests.routes.js";
import "./shared/db/sqlite.js";
import { errorMiddleware } from "./shared/middlewares/error.middleware.js";
const app = express();
const PORT = 3000;
app.use(cors());
app.use(express.json());
app.use("/api/auth", authRouter);
app.use("/api/requests", requestsRouter);
app.use("/api/ratings", ratingsRouter);
app.get("/health", (_req, res) => {
    res.json({ status: "ok", app: "Kuidar" });
});
app.use(errorMiddleware);
const server = app.listen(PORT, () => {
    console.log(`\n  🫀  Kuidar server  →  http://localhost:${PORT}\n`);
});
server.on("error", (err) => {
    if (err.code === "EADDRINUSE") {
        console.error(`\n  ❌  Port ${PORT} already in use. Kill the process with:\n\n     lsof -ti :${PORT} | xargs kill -9\n`);
        process.exit(1);
    }
    else {
        throw err;
    }
});
//# sourceMappingURL=app.js.map