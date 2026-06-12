import { familiesService } from "../services/families.service.js";
export const familiesController = {
    // 3.12/3.16 — edición de perfil del adulto mayor + control parental
    updateElderly(req, res, next) {
        try {
            res.json(familiesService.updateElderly(req.auth, req.params.id, req.body));
        }
        catch (error) {
            next(error);
        }
    },
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