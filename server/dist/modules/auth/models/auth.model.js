import { z } from "zod";
export const loginBodySchema = z.object({
    email: z.string().email(),
    password: z.string().min(1),
});
export const registerBodySchema = z.object({
    email: z.string().email(),
    password: z.string().min(6),
    name: z.string().min(1),
    role: z.enum(["family", "student", "elderly", "organizer"]),
    // student
    universityId: z.string().optional(),
    career: z.string().optional(),
    // family
    familyName: z.string().optional(),
    familyCode: z.string().optional(),
    // elderly
    address: z.string().optional(),
    neighborhood: z.string().optional(),
    lat: z.number().optional(),
    lng: z.number().optional(),
});
export const logoutBodySchema = z.object({
    token: z.string().optional(),
});
//# sourceMappingURL=auth.model.js.map