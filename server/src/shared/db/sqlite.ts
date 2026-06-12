import Database from "better-sqlite3";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { v4 as uuidv4 } from "uuid";
import { hashPassword } from "../utils/password.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dbPath = path.join(__dirname, "kuidar.db");

export const db = new Database(dbPath);

db.pragma("journal_mode = WAL");
db.pragma("foreign_keys = ON");

// ── Schema versioning ─────────────────────────────────────────────
// v2 introduce families/applications/assignments; si la DB es vieja se recrea.
const SCHEMA_VERSION = 2;
const currentVersion = (db.pragma("user_version", { simple: true }) as number) ?? 0;

if (currentVersion < SCHEMA_VERSION) {
  db.exec(`
    DROP TABLE IF EXISTS location_updates;
    DROP TABLE IF EXISTS student_badges;
    DROP TABLE IF EXISTS badges;
    DROP TABLE IF EXISTS ratings;
    DROP TABLE IF EXISTS service_hours;
    DROP TABLE IF EXISTS assignments;
    DROP TABLE IF EXISTS applications;
    DROP TABLE IF EXISTS activity_requests;
    DROP TABLE IF EXISTS elderly_profiles;
    DROP TABLE IF EXISTS elderly_persons;
    DROP TABLE IF EXISTS students;
    DROP TABLE IF EXISTS family_members;
    DROP TABLE IF EXISTS families;
    DROP TABLE IF EXISTS universities;
    DROP TABLE IF EXISTS sessions;
    DROP TABLE IF EXISTS users;
  `);
  db.pragma(`user_version = ${SCHEMA_VERSION}`);
}

db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id            TEXT PRIMARY KEY,
    email         TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    name          TEXT NOT NULL,
    role          TEXT NOT NULL CHECK(role IN ('family', 'student', 'elderly')),
    created_at    TEXT NOT NULL DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS sessions (
    id         TEXT PRIMARY KEY,
    user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS universities (
    id   TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    lat  REAL NOT NULL DEFAULT 19.33,
    lng  REAL NOT NULL DEFAULT -99.18
  );

  CREATE TABLE IF NOT EXISTS families (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    family_code TEXT NOT NULL UNIQUE,
    created_at  TEXT NOT NULL DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS family_members (
    id         TEXT PRIMARY KEY,
    user_id    TEXT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    family_id  TEXT NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    is_primary INTEGER NOT NULL DEFAULT 0
  );

  CREATE TABLE IF NOT EXISTS students (
    id             TEXT PRIMARY KEY,
    user_id        TEXT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    university_id  TEXT REFERENCES universities(id) ON DELETE SET NULL,
    career         TEXT NOT NULL DEFAULT '',
    total_hours    REAL NOT NULL DEFAULT 0,
    average_rating REAL NOT NULL DEFAULT 0
  );

  CREATE TABLE IF NOT EXISTS elderly_profiles (
    id           TEXT PRIMARY KEY,
    user_id      TEXT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    family_id    TEXT REFERENCES families(id) ON DELETE SET NULL,
    first_name   TEXT NOT NULL,
    address      TEXT NOT NULL DEFAULT 'CDMX',
    neighborhood TEXT NOT NULL DEFAULT 'CDMX',
    lat          REAL NOT NULL DEFAULT 19.3826,
    lng          REAL NOT NULL DEFAULT -99.1677
  );

  CREATE TABLE IF NOT EXISTS activity_requests (
    id                 TEXT PRIMARY KEY,
    family_id          TEXT NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    elderly_profile_id TEXT REFERENCES elderly_profiles(id) ON DELETE SET NULL,
    activity_type      TEXT NOT NULL,
    details            TEXT NOT NULL DEFAULT '',
    scheduled_date     TEXT NOT NULL,
    is_urgent          INTEGER NOT NULL DEFAULT 0,
    status             TEXT NOT NULL DEFAULT 'open'
                       CHECK(status IN ('open','claimed','inProgress','completed','cancelled')),
    latitude           REAL NOT NULL,
    longitude          REAL NOT NULL,
    published_at       TEXT NOT NULL DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS applications (
    id         TEXT PRIMARY KEY,
    request_id TEXT NOT NULL REFERENCES activity_requests(id) ON DELETE CASCADE,
    student_id TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    message    TEXT NOT NULL DEFAULT '',
    status     TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected')),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(request_id, student_id)
  );

  CREATE TABLE IF NOT EXISTS assignments (
    id             TEXT PRIMARY KEY,
    request_id     TEXT NOT NULL UNIQUE REFERENCES activity_requests(id) ON DELETE CASCADE,
    application_id TEXT NOT NULL REFERENCES applications(id) ON DELETE CASCADE,
    student_id     TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    status         TEXT NOT NULL DEFAULT 'approved'
                   CHECK(status IN ('approved','en_camino','iniciada','completada','cancelada')),
    approved_at    TEXT NOT NULL DEFAULT (datetime('now')),
    en_camino_at   TEXT,
    inicio_solicitado_at TEXT,
    checkin_at     TEXT,
    checkout_at    TEXT,
    hours_logged   REAL NOT NULL DEFAULT 0
  );

  CREATE TABLE IF NOT EXISTS service_hours (
    id            TEXT PRIMARY KEY,
    assignment_id TEXT NOT NULL REFERENCES assignments(id) ON DELETE CASCADE,
    student_id    TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    hours         REAL NOT NULL,
    activity_type TEXT NOT NULL,
    verified      INTEGER NOT NULL DEFAULT 1,
    date          TEXT NOT NULL DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS ratings (
    id             TEXT PRIMARY KEY,
    assignment_id  TEXT NOT NULL REFERENCES assignments(id) ON DELETE CASCADE,
    student_id     TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    author_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
    stars          INTEGER NOT NULL CHECK(stars BETWEEN 1 AND 5),
    tags           TEXT NOT NULL DEFAULT '[]',
    comment        TEXT NOT NULL DEFAULT '',
    created_at     TEXT NOT NULL DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS badges (
    id          TEXT PRIMARY KEY,
    slug        TEXT NOT NULL UNIQUE,
    title       TEXT NOT NULL,
    description TEXT NOT NULL,
    icon        TEXT NOT NULL DEFAULT '🏅'
  );

  CREATE TABLE IF NOT EXISTS student_badges (
    id         TEXT PRIMARY KEY,
    student_id TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    badge_id   TEXT NOT NULL REFERENCES badges(id) ON DELETE CASCADE,
    earned_at  TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(student_id, badge_id)
  );

  CREATE TABLE IF NOT EXISTS location_updates (
    id            TEXT PRIMARY KEY,
    assignment_id TEXT NOT NULL REFERENCES assignments(id) ON DELETE CASCADE,
    user_id       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role          TEXT NOT NULL CHECK(role IN ('student','elderly')),
    latitude      REAL NOT NULL,
    longitude     REAL NOT NULL,
    recorded_at   TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(assignment_id, user_id)
  );

  CREATE INDEX IF NOT EXISTS idx_requests_status ON activity_requests(status);
  CREATE INDEX IF NOT EXISTS idx_applications_request ON applications(request_id);
  CREATE INDEX IF NOT EXISTS idx_assignments_student ON assignments(student_id);
`);

// Migración incremental: columna inicio_solicitado_at en DBs existentes
const assignmentCols = db.prepare("PRAGMA table_info(assignments)").all() as Array<{ name: string }>;
if (!assignmentCols.some((c) => c.name === "inicio_solicitado_at")) {
  db.exec("ALTER TABLE assignments ADD COLUMN inicio_solicitado_at TEXT");
}

// ── Seed ──────────────────────────────────────────────────────────

export function generateFamilyCode(): string {
  const alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"; // sin 0/O/1/I/L
  let code = "";
  for (let i = 0; i < 6; i++) {
    code += alphabet[Math.floor(Math.random() * alphabet.length)];
  }
  return code;
}

const uniCount = db.prepare("SELECT COUNT(*) AS n FROM universities").get() as { n: number };
if (uniCount.n === 0) {
  const insertUni = db.prepare("INSERT INTO universities (id, name, slug, lat, lng) VALUES (?, ?, ?, ?, ?)");
  const unis = [
    { name: "UNAM", slug: "unam", lat: 19.3322, lng: -99.1870 },
    { name: "IPN", slug: "ipn", lat: 19.4506, lng: -99.1709 },
    { name: "Tec de Monterrey CCM", slug: "itesm-ccm", lat: 19.2837, lng: -99.1344 },
    { name: "UAM", slug: "uam", lat: 19.3540, lng: -99.0710 },
    { name: "Ibero", slug: "ibero", lat: 19.3700, lng: -99.2640 },
  ];
  for (const u of unis) insertUni.run(uuidv4(), u.name, u.slug, u.lat, u.lng);
}

const badgeCount = db.prepare("SELECT COUNT(*) AS n FROM badges").get() as { n: number };
if (badgeCount.n === 0) {
  const insertBadge = db.prepare("INSERT INTO badges (id, slug, title, description, icon) VALUES (?, ?, ?, ?, ?)");
  const badgeSeed = [
    { slug: "primera_visita", title: "Primera visita", description: "Completaste tu primera visita", icon: "🌱" },
    { slug: "10_horas", title: "10 horas", description: "Acumulaste 10 horas de servicio", icon: "⏱️" },
    { slug: "5_estrellas", title: "5 estrellas", description: "Promedio de 4.8+ con al menos 3 calificaciones", icon: "⭐️" },
    { slug: "confiable", title: "Confiable", description: "5 visitas completadas sin cancelar", icon: "🤝" },
    { slug: "urgencias", title: "Héroe de urgencias", description: "3 actividades urgentes completadas", icon: "🚨" },
  ];
  for (const b of badgeSeed) insertBadge.run(uuidv4(), b.slug, b.title, b.description, b.icon);
}

const userCount = db.prepare("SELECT COUNT(*) AS n FROM users").get() as { n: number };
if (userCount.n === 0) {
  const insertUser = db.prepare(
    "INSERT INTO users (id, email, password_hash, name, role) VALUES (?, ?, ?, ?, ?)",
  );

  // Familiar demo + familia
  const familyUserId = uuidv4();
  insertUser.run(familyUserId, "familia@kuidar.app", hashPassword("demo123"), "María García", "family");

  const familyId = uuidv4();
  db.prepare("INSERT INTO families (id, name, family_code) VALUES (?, ?, ?)")
    .run(familyId, "Familia García", "KUIDAR");
  db.prepare("INSERT INTO family_members (id, user_id, family_id, is_primary) VALUES (?, ?, ?, 1)")
    .run(uuidv4(), familyUserId, familyId);

  // Estudiante demo
  const studentUserId = uuidv4();
  insertUser.run(studentUserId, "becario@kuidar.app", hashPassword("demo123"), "Carlos Ruiz", "student");

  const unam = db.prepare("SELECT id FROM universities WHERE slug = 'unam'").get() as { id: string };
  db.prepare("INSERT INTO students (id, user_id, university_id, career) VALUES (?, ?, ?, ?)")
    .run(uuidv4(), studentUserId, unam.id, "Medicina");

  // Adulto mayor demo, ya unido a la familia García
  const elderlyUserId = uuidv4();
  insertUser.run(elderlyUserId, "adulto@kuidar.app", hashPassword("demo123"), "Don Roberto", "elderly");

  db.prepare(`
    INSERT INTO elderly_profiles (id, user_id, family_id, first_name, address, neighborhood, lat, lng)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `).run(uuidv4(), elderlyUserId, familyId, "Don Roberto", "Av. Coyoacán 1435", "Del Valle", 19.3826, -99.1677);
}
