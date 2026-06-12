import { z } from "zod";
export const joinFamilyBodySchema = z.object({
    code: z.string().min(4).max(10),
});
// 3.12/3.16 — edición de perfil del adulto mayor (todos los campos opcionales)
export const updateElderlyBodySchema = z.object({
    address: z.string().min(1).max(200).optional(),
    neighborhood: z.string().min(1).max(120).optional(),
    age: z.number().int().min(50).max(120).nullable().optional(),
    tags: z.array(z.string().min(1).max(40)).max(20).optional(),
    // Control parental — solo la familia puede modificarlos (se valida en el servicio)
    allowSocialConnections: z.boolean().optional(),
    allowSelfProfileEdit: z.boolean().optional(),
});
//# sourceMappingURL=families.model.js.map