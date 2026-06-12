import { authService } from "../services/auth.service.js";
export const authController = {
    login(req, res, next) {
        try {
            const result = authService.login(req.body);
            res.status(200).json(result);
        }
        catch (error) {
            next(error);
        }
    },
    logout(req, res, next) {
        try {
            const result = authService.logout(req.body);
            res.status(200).json(result);
        }
        catch (error) {
            next(error);
        }
    },
};
//# sourceMappingURL=auth.controller.js.map