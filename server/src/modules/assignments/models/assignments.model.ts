import { z } from "zod";

export const locationBodySchema = z.object({
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
});

export type LocationBody = z.infer<typeof locationBodySchema>;

export type AssignmentStatus =
  | "approved"
  | "en_camino"
  | "esperando_confirmacion"
  | "iniciada"
  | "completada"
  | "cancelada";

export interface AssignmentView {
  id: string;
  requestId: string;
  studentId: string;
  studentName: string;
  status: AssignmentStatus;
  approvedAt: string;
  enCaminoAt: string | null;
  inicioSolicitadoAt: string | null;
  checkinAt: string | null;
  checkoutAt: string | null;
  hoursLogged: number;
  // contexto de la solicitud
  activityType: string;
  details: string;
  scheduledDate: string;
  isUrgent: boolean;
  latitude: number;
  longitude: number;
  elderlyName: string;
  neighborhood: string;
  address: string;
  familyId: string;
}

export interface LocationView {
  role: "student" | "elderly";
  latitude: number;
  longitude: number;
  recordedAt: string;
}
