import { z } from "zod";
export const sendMessageBodySchema = z.object({
    toStudentId: z.string().min(1),
    body: z.string().min(1).max(500),
    assignmentId: z.string().optional(),
});
export const replyMessageBodySchema = z.object({
    toUserId: z.string().min(1),
    body: z.string().min(1).max(500),
});
//# sourceMappingURL=messages.model.js.map