import { z } from "zod";

export const applyBodySchema = z.object({
  message: z.string().optional().default(""),
});

export type ApplyBody = z.infer<typeof applyBodySchema>;

export type ApplicationStatus =
  | "pending"
  | "approved"
  | "rejected"
  | "waiting_list"
  | "cancelled_by_helper";

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
  status: ApplicationStatus;
  createdAt: string;
  tags: string[];
}
