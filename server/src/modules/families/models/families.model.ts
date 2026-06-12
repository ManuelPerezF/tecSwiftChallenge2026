import { z } from "zod";

export const joinFamilyBodySchema = z.object({
  code: z.string().min(4).max(10),
});

export type JoinFamilyBody = z.infer<typeof joinFamilyBodySchema>;

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
}
