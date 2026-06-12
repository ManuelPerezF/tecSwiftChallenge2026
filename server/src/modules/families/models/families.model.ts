import { z } from "zod";

export const joinFamilyBodySchema = z.object({
  code: z.string().min(4).max(10),
});

export type JoinFamilyBody = z.infer<typeof joinFamilyBodySchema>;

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

export type UpdateElderlyBody = z.infer<typeof updateElderlyBodySchema>;

export interface FamilyInfo {
  id: string;
  name: string;
  familyCode: string;
  elderly: ElderlySummary[];
}

export interface ElderlySummary {
  id: string;
  firstName: string;
  address: string;
  neighborhood: string;
  lat: number;
  lng: number;
  tags: string[];
  age: number | null;
  allowSocialConnections: boolean;
  allowSelfProfileEdit: boolean;
}
