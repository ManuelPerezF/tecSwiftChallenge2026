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
    confirmCompletion(req, res, next) {
        try {
            res.json(assignmentsService.confirmCompletion(req.auth, req.params.id));
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
    cancelarPorEstudiante(req, res, next) {
        try {
            res.json(assignmentsService.cancelByStudent(req.auth, req.params.id));
        }
        catch (error) {
            next(error);
        }
    },
    proposeChange(req, res, next) {
        try {
            const { scheduledDate } = req.body;
            res.status(201).json(assignmentsService.proposeChange(req.auth, req.params.id, scheduledDate ?? ""));
        }
        catch (error) {
            next(error);
        }
    },
    getPendingProposal(req, res, next) {
        try {
            res.json(assignmentsService.getPendingProposal(req.auth, req.params.id));
        }
        catch (error) {
            next(error);
        }
    },
    respondToProposal(req, res, next) {
        try {
            const { accept } = req.body;
            res.json(assignmentsService.respondToProposal(req.auth, req.params.id, accept === true));
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