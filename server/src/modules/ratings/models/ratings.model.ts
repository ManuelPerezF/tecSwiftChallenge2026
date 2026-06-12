import { z } from "zod";

export const createRatingBodySchema = z.object({
  stars: z.number().int().min(1).max(5),
  tags: z.array(z.string()).optional().default([]),
  comment: z.string().optional().default(""),
});

export type CreateRatingBody = z.infer<typeof createRatingBodySchema>;

export interface RatingView {
  id: string;
  stars: number;
  tags: string[];
  comment: string;
  authorName: string;
  createdAt: string;
}
