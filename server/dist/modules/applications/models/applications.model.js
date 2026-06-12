import { z } from "zod";
export const applyBodySchema = z.object({
    message: z.string().optional().default(""),
});
//# sourceMappingURL=applications.model.js.map