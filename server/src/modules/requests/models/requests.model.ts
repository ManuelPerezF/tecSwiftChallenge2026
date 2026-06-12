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
  // Eventos comunitarios (solo rol organizer)
  isCommunityEvent: z.boolean().optional().default(false),
  maxHelpersRequired: z.number().int().positive().optional().default(1),
  maxElderlyAttendees: z.number().int().nonnegative().optional().default(0),
});

export type CreateRequestBody = z.infer<typeof createRequestBodySchema>;
