import { z } from "zod";

export const loginBodySchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

export const registerBodySchema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
  name: z.string().min(1),
  role: z.enum(["family", "student", "elderly"]),
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

export type LoginBody = z.infer<typeof loginBodySchema>;
export type RegisterBody = z.infer<typeof registerBodySchema>;
export type LogoutBody = z.infer<typeof logoutBodySchema>;

export type UserRole = "family" | "student" | "elderly";

export interface PublicUser {
  id: string;
  name: string;
  email: string;
  role: UserRole;
}

export interface ProfilePayload {
  familyId?: string;
  familyCode?: string;
  familyName?: string;
  studentId?: string;
  universityId?: string;
  universityName?: string;
  career?: string;
  totalHours?: number;
  averageRating?: number;
  elderlyProfileId?: string;
  joinedFamily?: boolean;
}

export interface AuthResponse {
  token: string;
  user: PublicUser;
  profile: ProfilePayload;
}

export interface UserRow {
  id: string;
  email: string;
  password_hash: string;
  name: string;
  role: UserRole;
}
