import { z } from "zod";

export const sendMessageBodySchema = z.object({
  toStudentId: z.string().min(1),
  body: z.string().min(1).max(500),
  assignmentId: z.string().optional(),
});

export type SendMessageBody = z.infer<typeof sendMessageBodySchema>;

export const replyMessageBodySchema = z.object({
  toUserId: z.string().min(1),
  body: z.string().min(1).max(500),
});

export type ReplyMessageBody = z.infer<typeof replyMessageBodySchema>;
