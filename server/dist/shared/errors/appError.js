export class AppError extends Error {
    statusCode;
    code;
    constructor(message, statusCode, code = "APP_ERROR") {
        super(message);
        this.name = this.constructor.name;
        this.statusCode = statusCode;
        this.code = code;
    }
}
export class ValidationError extends AppError {
    constructor(message = "Payload inválido") {
        super(message, 400, "VALIDATION_ERROR");
    }
}
export class UnauthorizedError extends AppError {
    constructor(message = "Credenciales inválidas") {
        super(message, 401, "UNAUTHORIZED");
    }
}
export class NotFoundError extends AppError {
    constructor(message = "Not found") {
        super(message, 404, "NOT_FOUND");
    }
}
//# sourceMappingURL=appError.js.map