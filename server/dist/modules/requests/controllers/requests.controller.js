import { requestsService } from "../services/requests.service.js";
export const requestsController = {
    listMine(req, res, next) {
        try {
            res.json(requestsService.findMine(req.auth));
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
            const result = requestsService.create(req.auth, req.body);
            res.status(201).json(result);
        }
        catch (error) {
            next(error);
        }
    },
    remove(req, res, next) {
        try {
            res.json(requestsService.remove(req.auth, req.params.id));
        }
        catch (error) {
            next(error);
        }
    },
    listCommunityEvents(_req, res, next) {
        try {
            res.json(requestsService.findCommunityEvents());
        }
        catch (error) {
            next(error);
        }
    },
    registerAttendee(req, res, next) {
        try {
            res.status(201).json(requestsService.registerAttendee(req.auth, req.params.id));
        }
        catch (error) {
            next(error);
        }
    },
    listAttendees(req, res, next) {
        try {
            res.json(requestsService.listAttendees(req.params.id));
        }
        catch (error) {
            next(error);
        }
    },
    unregisterAttendee(req, res, next) {
        try {
            res.json(requestsService.unregisterAttendee(req.auth, req.params.id));
        }
        catch (error) {
            next(error);
        }
    },
};
//# sourceMappingURL=requests.controller.js.map