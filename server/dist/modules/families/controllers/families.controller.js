import { familiesService } from "../services/families.service.js";
export const familiesController = {
    me(req, res, next) {
        try {
            res.json(familiesService.me(req.auth));
        }
        catch (error) {
            next(error);
        }
    },
    join(req, res, next) {
        try {
            res.json(familiesService.join(req.auth, req.body));
        }
        catch (error) {
            next(error);
        }
    },
};
//# sourceMappingURL=families.controller.js.map