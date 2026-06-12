import { v4 as uuidv4 } from "uuid";
import { db } from "../../../shared/db/sqlite.js";
import { NotFoundError } from "../../../shared/errors/appError.js";
import { normalizeRequest, } from "../../../shared/utils/requestMapper.js";
const SELECT_WITH_ELDERLY = `
  SELECT r.*, e.first_name AS elderly_name, e.neighborhood
  FROM   activity_requests r
  LEFT JOIN elderly_persons e ON r.elderly_person_id = e.id
`;
export const requestsService = {
    findAll() {
        const rows = db.prepare(`${SELECT_WITH_ELDERLY} ORDER BY r.scheduled_date ASC`).all();
        return rows.map(normalizeRequest);
    },
    findOpen() {
        const rows = db
            .prepare(`${SELECT_WITH_ELDERLY} WHERE r.status = 'open' ORDER BY r.published_at DESC`)
            .all();
        return rows.map(normalizeRequest);
    },
    findById(id) {
        const row = db.prepare(`${SELECT_WITH_ELDERLY} WHERE r.id = ?`).get(id);
        if (!row)
            throw new NotFoundError();
        return normalizeRequest(row);
    },
    create(data) {
        const latitude = 19.3826 + (Math.random() * 0.018 - 0.006);
        const longitude = -99.1677 + (Math.random() * 0.020 - 0.010);
        const elderlyId = uuidv4();
        const requestId = uuidv4();
        db.prepare(`
      INSERT INTO elderly_persons (id, first_name, neighborhood, address)
      VALUES (?, ?, 'Del Valle', 'Del Valle, CDMX')
    `).run(elderlyId, data.elderlyPersonName);
        db.prepare(`
      INSERT INTO activity_requests
        (id, activity_type, details, scheduled_date, is_urgent, latitude, longitude, elderly_person_id)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `).run(requestId, data.activityType, data.details, data.scheduledDate, data.isUrgent ? 1 : 0, latitude, longitude, elderlyId);
        return this.findById(requestId);
    },
    updateStatus(id, data) {
        db.prepare("UPDATE activity_requests SET status = ? WHERE id = ?").run(data.status, id);
        return { ok: true };
    },
    remove(id) {
        db.prepare("DELETE FROM activity_requests WHERE id = ?").run(id);
        return { ok: true };
    },
};
//# sourceMappingURL=requests.service.js.map