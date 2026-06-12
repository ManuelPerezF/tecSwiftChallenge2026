import { z } from "zod";

export const createRatingBodySchema = z.object({
  stars: z.number().int().min(1).max(5),
  tags: z.array(z.string().trim().min(1).max(30)).max(10).optional().default([]),
  comment: z.string().max(500).optional().default(""),
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
