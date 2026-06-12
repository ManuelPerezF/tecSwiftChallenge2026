import { z } from "zod";
export const createRequestBodySchema = z.object({
    elderlyProfileId: z.string().optional(),
    activityType: z.string().min(1),
    details: z.string().optional().default(""),
    scheduledDate: z.string().min(1),
    isUrgent: z.boolean().optional().default(false),
});
//# sourceMappingURL=requests.model.js.map