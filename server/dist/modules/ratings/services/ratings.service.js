import { v4 as uuidv4 } from "uuid";
import { db } from "../../../shared/db/sqlite.js";
export const ratingsService = {
    create(data) {
        const id = uuidv4();
        db.prepare(`
      INSERT INTO ratings (id, stars, tags, activity_request_id)
      VALUES (?, ?, ?, ?)
    `).run(id, data.stars, JSON.stringify(data.tags), data.activityRequestId);
        if (data.activityRequestId) {
            db.prepare("UPDATE activity_requests SET status = 'completed' WHERE id = ?").run(data.activityRequestId);
        }
        return { id, stars: data.stars, tags: data.tags };
    },
};
//# sourceMappingURL=ratings.service.js.map