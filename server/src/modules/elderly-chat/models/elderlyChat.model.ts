import { z } from "zod";

export const sendElderlyMessageBodySchema = z.object({
  body: z.string().min(1).max(2000),
});

export type SendElderlyMessageBody = z.infer<typeof sendElderlyMessageBodySchema>;

/** Match visto desde el adulto mayor logueado. */
export interface ElderlyMatchView {
  id: string;
  otherProfileId: string;
  otherName: string;
  otherNeighborhood: string;
  otherAge: number | null;
  sharedTags: string[];
  score: number;
  /** true si el otro lado desactivó conexiones sociales: hilo solo-lectura. */
  locked: boolean;
  lastMessage: string | null;
  lastMessageAt: string | null;
  unreadCount: number;
  createdAt: string;
}

export interface ElderlyMessageView {
  id: string;
  matchId: string;
  senderProfileId: string;
  senderName: string;
  body: string;
  readAt: string | null;
  createdAt: string;
  /** true si lo envió el adulto mayor logueado. */
  isMine: boolean;
}
