import { z } from "zod";

export const createEventTypeBodySchema = z.object({
  label: z.string().trim().min(2).max(40),
  icon: z.string().trim().min(1).max(60).optional().default("star.fill"),
});

export type CreateEventTypeBody = z.infer<typeof createEventTypeBodySchema>;

export interface EventTypeView {
  id: string;
  slug: string;
  label: string;
  icon: string;
  isCustom: boolean;
}
