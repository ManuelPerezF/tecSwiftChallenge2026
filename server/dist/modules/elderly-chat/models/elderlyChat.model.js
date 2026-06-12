import { z } from "zod";
export const sendElderlyMessageBodySchema = z.object({
    body: z.string().min(1).max(2000),
});
//# sourceMappingURL=elderlyChat.model.js.map