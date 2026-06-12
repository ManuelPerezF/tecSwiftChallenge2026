import { requestsService } from "../services/requests.service.js";
export const requestsController = {
    list(_req, res, next) {
        try {
            res.json(requestsService.findAll());
        }
        catch (error) {
            next(error);
        }
    },
    listOpen(_req, res, next) {
        try {
            res.json(requestsService.findOpen());
        }
        catch (error) {
            next(error);
        }
    },
    getById(req, res, next) {
        try {
            res.json(requestsService.findById(req.params.id));
        }
        catch (error) {
            next(error);
        }
    },
    create(req, res, next) {
        try {
            const result = requestsService.create(req.body);
            res.status(201).json(result);
        }
        catch (error) {
            next(error);
        }
    },
    updateStatus(req, res, next) {
        try {
            const result = requestsService.updateStatus(req.params.id, req.body);
            res.json(result);
        }
        catch (error) {
            next(error);
        }
    },
    remove(req, res, next) {
        try {
            const result = requestsService.remove(req.params.id);
            res.json(result);
        }
        catch (error) {
            next(error);
        }
    },
};
//# sourceMappingURL=requests.controller.js.map