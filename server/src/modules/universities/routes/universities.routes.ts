import { Router } from "express";
import { db } from "../../../shared/db/sqlite.js";

export const universitiesRouter = Router();

universitiesRouter.get("/", (_req, res) => {
  const rows = db.prepare("SELECT id, name, slug, lat, lng FROM universities ORDER BY name").all();
  res.json(rows);
});
