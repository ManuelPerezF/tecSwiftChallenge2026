const MATCH_SCORES = {
    citas: 94,
    compania: 90,
    tecnologia: 85,
    mandados: 82,
    hogar: 78,
    medicamento: 74,
};
const DURATION_LABELS = {
    mandados: "1 h",
    citas: "2 h",
    tecnologia: "45 min",
    hogar: "2 h",
    compania: "1.5 h",
    medicamento: "30 min",
};
const ACTIVITY_HOURS = {
    mandados: 1,
    citas: 2,
    tecnologia: 0.75,
    hogar: 2,
    compania: 1.5,
    medicamento: 0.5,
};
function matchScore(activityType) {
    return MATCH_SCORES[activityType] ?? 80;
}
function durationLabel(activityType) {
    return DURATION_LABELS[activityType] ?? "1 h";
}
function activityHours(activityType) {
    return ACTIVITY_HOURS[activityType] ?? 1;
}
export function normalizeRequest(row) {
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
        duration: durationLabel(row.activity_type),
        hours: activityHours(row.activity_type),
    };
}
//# sourceMappingURL=requestMapper.js.map