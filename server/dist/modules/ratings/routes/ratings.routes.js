import { Router } from "express";
import { validateBody } from "../../../shared/utils/validateBody.js";
import { ratingsController } from "../controllers/ratings.controller.js";
import { createRatingBodySchema } from "../models/ratings.model.js";
export const ratingsRouter = Router();
ratingsRouter.post("/", validateBody(createRatingBodySchema), ratingsController.create);
//# sourceMappingURL=ratings.routes.js.map