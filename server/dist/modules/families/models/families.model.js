import { z } from "zod";
export const joinFamilyBodySchema = z.object({
    code: z.string().min(4).max(10),
});
//# sourceMappingURL=families.model.js.map