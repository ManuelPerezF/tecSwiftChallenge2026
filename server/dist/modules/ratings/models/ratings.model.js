import { z } from "zod";
export const createRatingBodySchema = z.object({
    stars: z.number().int().min(1).max(5),
    tags: z.array(z.string().trim().min(1).max(30)).max(10).optional().default([]),
    comment: z.string().max(500).optional().default(""),
    // 3.5: bandera de reporte — con rating bajo dispara bloqueo del becario
    isReport: z.boolean().optional().default(false),
});
//# sourceMappingURL=ratings.model.js.map