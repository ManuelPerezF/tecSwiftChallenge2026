import { authService } from "../services/auth.service.js";
export const authController = {
    register(req, res, next) {
        try {
            const result = authService.register(req.body);
            res.status(201).json(result);
        }
        catch (error) {
            next(error);
        }
    },
    login(req, res, next) {
        try {
            const result = authService.login(req.body);
            res.status(200).json(result);
        }
        catch (error) {
            next(error);
        }
    },
    me(req, res, next) {
        try {
            res.json(authService.me(req.auth));
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
    updateLocation(req, res, next) {
        try {
            const { lat, lng } = req.body;
            res.json(authService.updateElderlyLocation(req.auth, lat, lng));
        }
        catch (error) {
            next(error);
        }
    },
};
//# sourceMappingURL=auth.controller.js.map