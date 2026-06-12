import { ratingsService } from "../services/ratings.service.js";
export const ratingsController = {
    create(req, res, next) {
        try {
            const result = ratingsService.create(req.auth, req.params.id, req.body);
            res.status(201).json(result);
        }
        catch (error) {
            next(error);
        }
    },
    listForStudent(req, res, next) {
        try {
            res.json(ratingsService.listForStudent(req.params.id));
        }
        catch (error) {
            next(error);
        }
    },
};
//# sourceMappingURL=ratings.controller.js.map