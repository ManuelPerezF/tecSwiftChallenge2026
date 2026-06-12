import { z } from "zod";
export const createRatingBodySchema = z.object({
    stars: z.number().int().min(1).max(5),
    tags: z.array(z.string()).optional().default([]),
    comment: z.string().optional().default(""),
});
//# sourceMappingURL=ratings.model.js.map