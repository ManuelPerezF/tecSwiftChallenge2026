import { applicationsService } from "../services/applications.service.js";
export const applicationsController = {
    apply(req, res, next) {
        try {
            const result = applicationsService.apply(req.auth, req.params.id, req.body);
            res.status(201).json(result);
        }
        catch (error) {
            next(error);
        }
    },
    listForRequest(req, res, next) {
        try {
            res.json(applicationsService.listForRequest(req.auth, req.params.id));
        }
        catch (error) {
            next(error);
        }
    },
    listMine(req, res, next) {
        try {
            res.json(applicationsService.listMine(req.auth));
        }
        catch (error) {
            next(error);
        }
    },
    approve(req, res, next) {
        try {
            res.json(applicationsService.approve(req.auth, req.params.id));
        }
        catch (error) {
            next(error);
        }
    },
    reject(req, res, next) {
        try {
            res.json(applicationsService.reject(req.auth, req.params.id));
        }
        catch (error) {
            next(error);
        }
    },
};
//# sourceMappingURL=applications.controller.js.map