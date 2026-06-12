import { z } from "zod";

export const applyBodySchema = z.object({
  message: z.string().optional().default(""),
});

export type ApplyBody = z.infer<typeof applyBodySchema>;

export interface ApplicationView {
  id: string;
  requestId: string;
  studentId: string;
  studentName: string;
  universityName: string;
  career: string;
  totalHours: number;
  averageRating: number;
  message: string;
  status: "pending" | "approved" | "rejected";
  createdAt: string;
}
