export const validateBody = (schema) => {
    return (req, _res, next) => {
        try {
            req.body = schema.parse(req.body);
            next();
        }
        catch (e) {
            next(e);
        }
    };
};
//# sourceMappingURL=validateBody.js.map