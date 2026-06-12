import { ZodError } from "zod";
import { AppError, ValidationError } from "../errors/appError.js";
export const errorMiddleware = (error, _req, res, _next) => {
    if (error instanceof ZodError) {
        const err = new ValidationError("Payload inválido");
        res.status(err.statusCode).json({ error: err.message });
        return;
    }
    if (error instanceof AppError) {
        res.status(error.statusCode).json({ error: error.message });
        return;
    }
    console.error("Unhandled error:", error);
    res.status(500).json({ error: "Error interno del servidor" });
};
//# sourceMappingURL=error.middleware.js.map