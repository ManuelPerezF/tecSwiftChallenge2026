import { assignmentsService } from "../services/assignments.service.js";
export const assignmentsController = {
    getById(req, res, next) {
        try {
            res.json(assignmentsService.findById(req.params.id));
        }
        catch (error) {
            next(error);
        }
    },
    listMine(req, res, next) {
        try {
            res.json(assignmentsService.listMine(req.auth));
        }
        catch (error) {
            next(error);
        }
    },
    listForFamily(req, res, next) {
        try {
            res.json(assignmentsService.listForFamily(req.auth));
        }
        catch (error) {
            next(error);
        }
    },
    listForElderly(req, res, next) {
        try {
            res.json(assignmentsService.listForElderly(req.auth));
        }
        catch (error) {
            next(error);
        }
    },
    enCamino(req, res, next) {
        try {
            res.json(assignmentsService.enCamino(req.auth, req.params.id));
        }
        catch (error) {
            next(error);
        }
    },
    iniciar(req, res, next) {
        try {
            res.json(assignmentsService.iniciar(req.auth, req.params.id));
        }
        catch (error) {
            next(error);
        }
    },
    confirmarInicio(req, res, next) {
        try {
            res.json(assignmentsService.confirmarInicio(req.auth, req.params.id));
        }
        catch (error) {
            next(error);
        }
    },
    completar(req, res, next) {
        try {
            res.json(assignmentsService.completar(req.auth, req.params.id));
        }
        catch (error) {
            next(error);
        }
    },
    cancelar(req, res, next) {
        try {
            res.json(assignmentsService.cancelar(req.auth, req.params.id));
        }
        catch (error) {
            next(error);
        }
    },
    postLocation(req, res, next) {
        try {
            res.json(assignmentsService.postLocation(req.auth, req.params.id, req.body));
        }
        catch (error) {
            next(error);
        }
    },
    getLocations(req, res, next) {
        try {
            res.json(assignmentsService.getLocations(req.auth, req.params.id));
        }
        catch (error) {
            next(error);
        }
    },
};
//# sourceMappingURL=assignments.controller.js.map