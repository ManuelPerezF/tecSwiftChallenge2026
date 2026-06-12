import { z } from "zod";
export const loginBodySchema = z.object({
    email: z.string().email(),
    password: z.string().min(1),
});
export const logoutBodySchema = z.object({
    token: z.string().optional(),
});
//# sourceMappingURL=auth.model.js.map