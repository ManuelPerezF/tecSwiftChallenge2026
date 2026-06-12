import { z } from "zod";
export const locationBodySchema = z.object({
    latitude: z.number().min(-90).max(90),
    longitude: z.number().min(-180).max(180),
});
//# sourceMappingURL=assignments.model.js.map