import { elderlyChatService } from "../services/elderlyChat.service.js";
export const elderlyChatController = {
    listMatches(req, res, next) {
        try {
            res.json(elderlyChatService.listMatches(req.auth));
        }
        catch (error) {
            next(error);
        }
    },
    listMessages(req, res, next) {
        try {
            res.json(elderlyChatService.listMessages(req.auth, req.params.matchId));
        }
        catch (error) {
            next(error);
        }
    },
    sendMessage(req, res, next) {
        try {
            res.status(201).json(elderlyChatService.sendMessage(req.auth, req.params.matchId, req.body));
        }
        catch (error) {
            next(error);
        }
    },
};
//# sourceMappingURL=elderlyChat.controller.js.map