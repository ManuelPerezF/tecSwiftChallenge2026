const MATCH_SCORES: Record<string, number> = {
  citas: 94,
  compania: 90,
  tecnologia: 85,
  mandados: 82,
  hogar: 78,
  medicamento: 74,
};

const DURATION_LABELS: Record<string, string> = {
  mandados: "1 h",
  citas: "2 h",
  tecnologia: "45 min",
  hogar: "2 h",
  compania: "1.5 h",
  medicamento: "30 min",
};

const ACTIVITY_HOURS: Record<string, number> = {
  mandados: 1,
  citas: 2,
  tecnologia: 0.75,
  hogar: 2,
  compania: 1.5,
  medicamento: 0.5,
};

export interface ActivityRequestRow {
  id: string;
  family_id: string;
  elderly_profile_id?: string | null;
  activity_type: string;
  details: string;
  scheduled_date: string;
  is_urgent: number;
  status: string;
  published_at: string;
  latitude: number;
  longitude: number;
  elderly_name?: string | null;
  neighborhood?: string | null;
  duration_minutes?: number | null;
  is_community_event?: number;
  max_helpers_required?: number;
  active_helpers?: number;
}

export interface NormalizedRequest {
  id: string;
  familyId: string;
  elderlyProfileId: string | null;
  activityType: string;
  details: string;
  scheduledDate: string;
  isUrgent: boolean;
  status: string;
  publishedAt: string;
  latitude: number;
  longitude: number;
  elderlyName: string;
  neighborhood: string;
  matchScore: number;
  duration: string;
  hours: number;
  isCommunityEvent: boolean;
  maxHelpersRequired: number;
  activeHelpers: number;
}

function matchScore(activityType: string): number {
  return MATCH_SCORES[activityType] ?? 80;
}

function durationLabel(activityType: string): string {
  return DURATION_LABELS[activityType] ?? "1 h";
}

function activityHours(activityType: string): number {
  return ACTIVITY_HOURS[activityType] ?? 1;
}

function formatDuration(minutes: number): string {
  if (minutes < 60) return `${minutes} min`;
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return m === 0 ? `${h} h` : `${h} h ${m} min`;
}

export function normalizeRequest(row: ActivityRequestRow): NormalizedRequest {
  return {
    id: row.id,
    familyId: row.family_id,
    elderlyProfileId: row.elderly_profile_id ?? null,
    activityType: row.activity_type,
    details: row.details,
    scheduledDate: row.scheduled_date,
    isUrgent: row.is_urgent === 1,
    status: row.status,
    publishedAt: row.published_at,
    latitude: row.latitude,
    longitude: row.longitude,
    elderlyName: row.elderly_name ?? "Tu familiar",
    neighborhood: row.neighborhood ?? "CDMX",
    matchScore: matchScore(row.activity_type),
    duration: row.duration_minutes ? formatDuration(row.duration_minutes) : durationLabel(row.activity_type),
    hours: row.duration_minutes ? row.duration_minutes / 60 : activityHours(row.activity_type),
    isCommunityEvent: row.is_community_event === 1,
    maxHelpersRequired: row.max_helpers_required ?? 1,
    activeHelpers: row.active_helpers ?? 0,
  };
}
