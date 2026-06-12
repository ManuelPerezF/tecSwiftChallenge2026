import { v4 as uuidv4 } from "uuid";
import { db } from "../../../shared/db/sqlite.js";
function award(studentId, slug) {
    const badge = db.prepare("SELECT id FROM badges WHERE slug = ?").get(slug);
    if (!badge)
        return;
    db.prepare("INSERT OR IGNORE INTO student_badges (id, student_id, badge_id) VALUES (?, ?, ?)")
        .run(uuidv4(), studentId, badge.id);
}
export const badgesService = {
    listForStudent(studentId) {
        const rows = db.prepare(`
      SELECT b.slug, b.title, b.description, b.icon, sb.earned_at
      FROM student_badges sb JOIN badges b ON sb.badge_id = b.id
      WHERE sb.student_id = ? ORDER BY sb.earned_at ASC
    `).all(studentId);
        return rows.map((r) => ({
            slug: r.slug, title: r.title, description: r.description, icon: r.icon, earnedAt: r.earned_at,
        }));
    },
    /** Evalúa todas las reglas de badges para un estudiante. */
    evaluate(studentId) {
        const stats = db.prepare(`
      SELECT
        (SELECT COUNT(*) FROM assignments WHERE student_id = ? AND status = 'completada') AS completed,
        (SELECT COUNT(*) FROM assignments WHERE student_id = ? AND status = 'cancelada') AS cancelled,
        (SELECT total_hours FROM students WHERE id = ?) AS total_hours,
        (SELECT COUNT(*) FROM ratings WHERE student_id = ?) AS rating_count,
        (SELECT AVG(stars) FROM ratings WHERE student_id = ?) AS avg_stars,
        (SELECT COUNT(*) FROM assignments a
           JOIN activity_requests r ON a.request_id = r.id
           WHERE a.student_id = ? AND a.status = 'completada' AND r.is_urgent = 1) AS urgent_completed
    `).get(studentId, studentId, studentId, studentId, studentId, studentId);
        if (stats.completed >= 1)
            award(studentId, "primera_visita");
        if (stats.total_hours >= 10)
            award(studentId, "10_horas");
        if (stats.rating_count >= 3 && (stats.avg_stars ?? 0) >= 4.8)
            award(studentId, "5_estrellas");
        if (stats.completed >= 5 && stats.cancelled === 0)
            award(studentId, "confiable");
        if (stats.urgent_completed >= 3)
            award(studentId, "urgencias");
    },
};
//# sourceMappingURL=badges.service.js.map