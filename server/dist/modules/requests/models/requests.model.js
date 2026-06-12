import { z } from "zod";
export const createRequestBodySchema = z.object({
    elderlyProfileId: z.string().optional(),
    activityType: z.string().min(1),
    details: z.string().optional().default(""),
    scheduledDate: z.string().min(1),
    isUrgent: z.boolean().optional().default(false),
    lat: z.number().optional(),
    lng: z.number().optional(),
    durationMinutes: z.number().int().positive().optional(),
});
//# sourceMappingURL=requests.model.js.map