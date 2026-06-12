import { z } from "zod";
export const createRequestBodySchema = z.object({
    elderlyPersonName: z.string().optional().default("Tu familiar"),
    activityType: z.string().min(1),
    details: z.string().optional().default(""),
    scheduledDate: z.string().min(1),
    isUrgent: z.boolean().optional().default(false),
});
export const updateStatusBodySchema = z.object({
    status: z.enum(["open", "claimed", "inProgress", "completed", "cancelled"]),
});
//# sourceMappingURL=requests.model.js.map