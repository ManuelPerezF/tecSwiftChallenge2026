import { Router } from "express";
import { validateBody } from "../../../shared/utils/validateBody.js";
import { requestsController } from "../controllers/requests.controller.js";
import { createRequestBodySchema, updateStatusBodySchema } from "../models/requests.model.js";
export const requestsRouter = Router();
requestsRouter.get("/", requestsController.list);
requestsRouter.get("/open", requestsController.listOpen);
requestsRouter.get("/:id", requestsController.getById);
requestsRouter.post("/", validateBody(createRequestBodySchema), requestsController.create);
requestsRouter.patch("/:id/status", validateBody(updateStatusBodySchema), requestsController.updateStatus);
requestsRouter.delete("/:id", requestsController.remove);
//# sourceMappingURL=requests.routes.js.map