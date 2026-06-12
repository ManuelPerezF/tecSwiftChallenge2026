import { z } from "zod";
export const createRatingBodySchema = z.object({
    activityRequestId: z.string().min(1),
    stars: z.number().int().min(1).max(5),
    tags: z.array(z.string()).optional().default([]),
});
//# sourceMappingURL=ratings.model.js.map