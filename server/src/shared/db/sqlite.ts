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

// Safe column migrations (no version bump needed — idempotent)
function addColumnIfMissing(table: string, column: string, definition: string) {
  try { db.prepare(`ALTER TABLE ${table} ADD COLUMN ${column} ${definition}`).run(); } catch {}
}

// ── Schema versioning ─────────────────────────────────────────────
// v2 introduce families/applications/assignments; si la DB es vieja se recrea.
const SCHEMA_VERSION = 3;
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
    role          TEXT NOT NULL CHECK(role IN ('family', 'student', 'elderly', 'organizer')),
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
    address      TEXT NOT NULL DEFAULT '',
    neighborhood TEXT NOT NULL DEFAULT '',
    lat          REAL NOT NULL DEFAULT 0,
    lng          REAL NOT NULL DEFAULT 0
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
    status     TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected','waiting_list','cancelled_by_helper')),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(request_id, student_id)
  );

  CREATE TABLE IF NOT EXISTS assignments (
    id             TEXT PRIMARY KEY,
    request_id     TEXT NOT NULL REFERENCES activity_requests(id) ON DELETE CASCADE,
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

  CREATE TABLE IF NOT EXISTS event_attendees (
    id               TEXT PRIMARY KEY,
    request_id       TEXT NOT NULL REFERENCES activity_requests(id) ON DELETE CASCADE,
    attendee_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at       TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(request_id, attendee_user_id)
  );

  CREATE INDEX IF NOT EXISTS idx_requests_status ON activity_requests(status);
  CREATE INDEX IF NOT EXISTS idx_applications_request ON applications(request_id);
  CREATE INDEX IF NOT EXISTS idx_assignments_student ON assignments(student_id);
  CREATE INDEX IF NOT EXISTS idx_assignments_request ON assignments(request_id);
`);

// Migraciones incrementales
const assignmentCols = db.prepare("PRAGMA table_info(assignments)").all() as Array<{ name: string }>;
if (!assignmentCols.some((c) => c.name === "inicio_solicitado_at")) {
  db.exec("ALTER TABLE assignments ADD COLUMN inicio_solicitado_at TEXT");
}
addColumnIfMissing("activity_requests", "duration_minutes", "INTEGER");
addColumnIfMissing("activity_requests", "is_community_event", "INTEGER NOT NULL DEFAULT 0");
addColumnIfMissing("activity_requests", "max_helpers_required", "INTEGER NOT NULL DEFAULT 1");
// Tags de afinidad (JSON array string) para el recomendador on-device
addColumnIfMissing("students", "tags", "TEXT NOT NULL DEFAULT '[]'");
addColumnIfMissing("elderly_profiles", "tags", "TEXT NOT NULL DEFAULT '[]'");

// 3.9: cupo de adultos mayores en eventos comunitarios (0 = no aplica/sin límite)
addColumnIfMissing("activity_requests", "max_elderly_attendees", "INTEGER NOT NULL DEFAULT 0");
// 3.6: disponibilidad declarada del becario (JSON array de TimeWindow: morning/afternoon/evening)
addColumnIfMissing("students", "available_windows", "TEXT NOT NULL DEFAULT '[]'");
// 3.5: bloqueo de becarios
addColumnIfMissing("students", "is_blocked", "INTEGER NOT NULL DEFAULT 0");
addColumnIfMissing("ratings", "is_report", "INTEGER NOT NULL DEFAULT 0");
// 3.12/3.16: edad + control parental
addColumnIfMissing("elderly_profiles", "age", "INTEGER");
addColumnIfMissing("elderly_profiles", "allow_social_connections", "INTEGER NOT NULL DEFAULT 1");
addColumnIfMissing("elderly_profiles", "allow_self_profile_edit", "INTEGER NOT NULL DEFAULT 0");

// Tablas nuevas (idempotentes)
db.exec(`
  CREATE TABLE IF NOT EXISTS event_types (
    id                      TEXT PRIMARY KEY,
    slug                    TEXT NOT NULL UNIQUE,
    label                   TEXT NOT NULL,
    icon                    TEXT NOT NULL DEFAULT 'star.fill',
    is_custom               INTEGER NOT NULL DEFAULT 0,
    created_by_organizer_id TEXT REFERENCES users(id) ON DELETE SET NULL,
    created_at              TEXT NOT NULL DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS student_blocks (
    id               TEXT PRIMARY KEY,
    student_id       TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    reason           TEXT NOT NULL,
    source_rating_id TEXT REFERENCES ratings(id) ON DELETE SET NULL,
    source_family_id TEXT REFERENCES families(id) ON DELETE SET NULL,
    comment          TEXT NOT NULL DEFAULT '',
    active           INTEGER NOT NULL DEFAULT 1,
    created_at       TEXT NOT NULL DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS notifications (
    id         TEXT PRIMARY KEY,
    user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type       TEXT NOT NULL,
    title      TEXT NOT NULL,
    body       TEXT NOT NULL DEFAULT '',
    data       TEXT NOT NULL DEFAULT '{}',
    read       INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  );
  CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, read);

  CREATE TABLE IF NOT EXISTS assignment_change_proposals (
    id                 TEXT PRIMARY KEY,
    assignment_id      TEXT NOT NULL REFERENCES assignments(id) ON DELETE CASCADE,
    proposed_by        TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    proposed_date      TEXT NOT NULL,
    status             TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','accepted','rejected')),
    created_at         TEXT NOT NULL DEFAULT (datetime('now')),
    resolved_at        TEXT
  );

  CREATE TABLE IF NOT EXISTS elderly_matches (
    id           TEXT PRIMARY KEY,
    elderly_a_id TEXT NOT NULL REFERENCES elderly_profiles(id) ON DELETE CASCADE,
    elderly_b_id TEXT NOT NULL REFERENCES elderly_profiles(id) ON DELETE CASCADE,
    score        REAL NOT NULL DEFAULT 0,
    created_at   TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(elderly_a_id, elderly_b_id)
  );
`);

// Seed del catálogo de tipos de evento
const eventTypeCount = db.prepare("SELECT COUNT(*) AS n FROM event_types").get() as { n: number };
if (eventTypeCount.n === 0) {
  const insertType = db.prepare("INSERT INTO event_types (id, slug, label, icon, is_custom) VALUES (?, ?, ?, ?, 0)");
  const standardTypes = [
    { slug: "mandados", label: "Mandados", icon: "cart.fill" },
    { slug: "citas", label: "Citas médicas", icon: "car.fill" },
    { slug: "tecnologia", label: "Ayuda digital", icon: "iphone" },
    { slug: "hogar", label: "Tareas del hogar", icon: "house.fill" },
    { slug: "compania", label: "Compañía", icon: "bubble.left.and.bubble.right.fill" },
    { slug: "medicamento", label: "Medicamentos", icon: "pills.fill" },
    { slug: "recreacion", label: "Recreación", icon: "theatermasks.fill" },
    { slug: "taller", label: "Taller", icon: "hammer.fill" },
    { slug: "ejercicio", label: "Ejercicio y movilidad", icon: "figure.walk" },
    { slug: "charla", label: "Conferencia / charla", icon: "person.wave.2.fill" },
  ];
  for (const t of standardTypes) insertType.run(uuidv4(), t.slug, t.label, t.icon);
}

// activity_requests: agregar estado 'full' al CHECK (3.9)
if (!tableSql("activity_requests").includes("'full'")) {
  rebuildTable(
    "activity_requests",
    `CREATE TABLE activity_requests_new (
      id                 TEXT PRIMARY KEY,
      family_id          TEXT NOT NULL REFERENCES families(id) ON DELETE CASCADE,
      elderly_profile_id TEXT REFERENCES elderly_profiles(id) ON DELETE SET NULL,
      activity_type      TEXT NOT NULL,
      details            TEXT NOT NULL DEFAULT '',
      scheduled_date     TEXT NOT NULL,
      is_urgent          INTEGER NOT NULL DEFAULT 0,
      status             TEXT NOT NULL DEFAULT 'open'
                         CHECK(status IN ('open','claimed','inProgress','completed','cancelled','full')),
      latitude           REAL NOT NULL,
      longitude          REAL NOT NULL,
      published_at       TEXT NOT NULL DEFAULT (datetime('now')),
      duration_minutes   INTEGER,
      is_community_event INTEGER NOT NULL DEFAULT 0,
      max_helpers_required INTEGER NOT NULL DEFAULT 1,
      max_elderly_attendees INTEGER NOT NULL DEFAULT 0
    )`,
    ["CREATE INDEX IF NOT EXISTS idx_requests_status ON activity_requests(status)"],
  );
}

// assignments: agregar 'esperando_confirmacion_fin' al CHECK (3.15)
if (!tableSql("assignments").includes("esperando_confirmacion_fin")) {
  rebuildTable(
    "assignments",
    `CREATE TABLE assignments_new (
      id             TEXT PRIMARY KEY,
      request_id     TEXT NOT NULL REFERENCES activity_requests(id) ON DELETE CASCADE,
      application_id TEXT NOT NULL REFERENCES applications(id) ON DELETE CASCADE,
      student_id     TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
      status         TEXT NOT NULL DEFAULT 'approved'
                     CHECK(status IN ('approved','en_camino','iniciada','esperando_confirmacion_fin','completada','cancelada')),
      approved_at    TEXT NOT NULL DEFAULT (datetime('now')),
      en_camino_at   TEXT,
      inicio_solicitado_at TEXT,
      checkin_at     TEXT,
      checkout_at    TEXT,
      hours_logged   REAL NOT NULL DEFAULT 0
    )`,
    [
      "CREATE INDEX IF NOT EXISTS idx_assignments_student ON assignments(student_id)",
      "CREATE INDEX IF NOT EXISTS idx_assignments_request ON assignments(request_id)",
    ],
  );
}

// ── Migraciones Lumina (rebuild de tablas con CHECK/UNIQUE cambiados; preserva datos) ──

/** Reconstruye una tabla con una nueva definición, copiando todas las filas existentes. */
function rebuildTable(table: string, createNewSql: string, postSql: string[] = []) {
  db.pragma("foreign_keys = OFF");
  const tx = db.transaction(() => {
    db.exec(createNewSql); // crea `${table}_new`
    const cols = (db.prepare(`PRAGMA table_info(${table})`).all() as Array<{ name: string }>)
      .map((c) => c.name)
      .join(", ");
    db.exec(`INSERT INTO ${table}_new (${cols}) SELECT ${cols} FROM ${table}`);
    db.exec(`DROP TABLE ${table}`);
    db.exec(`ALTER TABLE ${table}_new RENAME TO ${table}`);
    for (const sql of postSql) db.exec(sql);
  });
  tx();
  db.pragma("foreign_keys = ON");
}

function tableSql(table: string): string {
  const row = db
    .prepare("SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?")
    .get(table) as { sql: string } | undefined;
  return row?.sql ?? "";
}

// users: agregar rol 'organizer' al CHECK
if (!tableSql("users").includes("organizer")) {
  rebuildTable(
    "users",
    `CREATE TABLE users_new (
      id            TEXT PRIMARY KEY,
      email         TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      name          TEXT NOT NULL,
      role          TEXT NOT NULL CHECK(role IN ('family', 'student', 'elderly', 'organizer')),
      created_at    TEXT NOT NULL DEFAULT (datetime('now'))
    )`,
  );
}

// applications: agregar estados 'waiting_list' y 'cancelled_by_helper' al CHECK
if (!tableSql("applications").includes("waiting_list")) {
  rebuildTable(
    "applications",
    `CREATE TABLE applications_new (
      id         TEXT PRIMARY KEY,
      request_id TEXT NOT NULL REFERENCES activity_requests(id) ON DELETE CASCADE,
      student_id TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
      message    TEXT NOT NULL DEFAULT '',
      status     TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected','waiting_list','cancelled_by_helper')),
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      UNIQUE(request_id, student_id)
    )`,
    ["CREATE INDEX IF NOT EXISTS idx_applications_request ON applications(request_id)"],
  );
}

// assignments: quitar UNIQUE de request_id (reapertura tras cancelación + eventos multi-cupo)
if (tableSql("assignments").includes("UNIQUE REFERENCES activity_requests")) {
  rebuildTable(
    "assignments",
    `CREATE TABLE assignments_new (
      id             TEXT PRIMARY KEY,
      request_id     TEXT NOT NULL REFERENCES activity_requests(id) ON DELETE CASCADE,
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
    )`,
    [
      "CREATE INDEX IF NOT EXISTS idx_assignments_student ON assignments(student_id)",
      "CREATE INDEX IF NOT EXISTS idx_assignments_request ON assignments(request_id)",
    ],
  );
}

// Mensajería in-app (tabla segura — idempotente)
db.exec(`
  CREATE TABLE IF NOT EXISTS messages (
    id            TEXT PRIMARY KEY,
    from_user_id  TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    to_student_id TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    to_user_id    TEXT REFERENCES users(id) ON DELETE CASCADE,
    body          TEXT NOT NULL,
    assignment_id TEXT REFERENCES assignments(id) ON DELETE SET NULL,
    read_at       TEXT,
    created_at    TEXT NOT NULL DEFAULT (datetime('now'))
  );
  CREATE INDEX IF NOT EXISTS idx_messages_to_student ON messages(to_student_id);
`);

// Migración segura: añadir to_user_id a tablas existentes
try { db.exec(`ALTER TABLE messages ADD COLUMN to_user_id TEXT REFERENCES users(id) ON DELETE CASCADE`); } catch { /* ya existe */ }

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

// ── Demo seed helpers ─────────────────────────────────────────────

function scheduledISO(daysFromNow: number, hour: number, minute = 0): string {
  const d = new Date();
  d.setDate(d.getDate() + daysFromNow);
  d.setHours(hour, minute, 0, 0);
  return d.toISOString();
}

const insertRequest = db.prepare(`
  INSERT INTO activity_requests
    (id, family_id, elderly_profile_id, activity_type, details, scheduled_date, is_urgent, status, latitude, longitude, duration_minutes)
  VALUES (?, ?, ?, ?, ?, ?, ?, 'open', ?, ?, ?)
`);

interface ElderlySeed {
  email: string;
  name: string;
  firstName: string;
  address: string;
  neighborhood: string;
  lat: number;
  lng: number;
  requests: Array<{
    activityType: string;
    details: string;
    daysFromNow: number;
    hour: number;
    urgent?: boolean;
    durationMinutes?: number;
  }>;
}

interface FamilySeed {
  familyName: string;
  familyCode: string;
  familyEmail: string;
  familyUserName: string;
  elderly: ElderlySeed[];
}

const DEMO_FAMILIES: FamilySeed[] = [
  {
    familyName: "Familia García",
    familyCode: "KUIDAR",
    familyEmail: "familia@kuidar.app",
    familyUserName: "María García",
    elderly: [
      {
        email: "adulto@kuidar.app",
        name: "Don Roberto",
        firstName: "Don Roberto",
        address: "Av. Coyoacán 1435",
        neighborhood: "Del Valle",
        lat: 19.3826,
        lng: -99.1677,
        requests: [
          { activityType: "citas", details: "Acompañarlo al cardiólogo en el hospital ABC. Llevar carpeta de estudios.", daysFromNow: 0, hour: 10, urgent: true, durationMinutes: 120 },
          { activityType: "mandados", details: "Mandado al super Sanborns. Ayuda cargando bolsas (3er piso sin elevador).", daysFromNow: 1, hour: 11, durationMinutes: 60 },
          { activityType: "compania", details: "Tarde de plática y dominó. Le gusta hablar de fútbol.", daysFromNow: 3, hour: 17, durationMinutes: 90 },
        ],
      },
      {
        email: "carmen@kuidar.app",
        name: "Doña Carmen",
        firstName: "Doña Carmen",
        address: "Calz. de Tlalpan 480, int. 2",
        neighborhood: "Del Valle",
        lat: 19.3788,
        lng: -99.1721,
        requests: [
          { activityType: "medicamento", details: "Recoger receta en farmacia del hospital y entregarla en casa.", daysFromNow: 0, hour: 9, urgent: true, durationMinutes: 30 },
          { activityType: "tecnologia", details: "Configurar videollamada con sus nietos por WhatsApp.", daysFromNow: 2, hour: 16, durationMinutes: 45 },
        ],
      },
    ],
  },
  {
    familyName: "Familia Martínez",
    familyCode: "MARTNZ",
    familyEmail: "martinez@kuidar.app",
    familyUserName: "Ana Martínez",
    elderly: [
      {
        email: "jorge@kuidar.app",
        name: "Don Jorge",
        firstName: "Don Jorge",
        address: "Calle Pitágoras 812",
        neighborhood: "Narvarte",
        lat: 19.4002,
        lng: -99.1578,
        requests: [
          { activityType: "mandados", details: "Ayuda con mandado al mercado Coyoacán. Vive en planta baja.", daysFromNow: 1, hour: 15, durationMinutes: 60 },
          { activityType: "hogar", details: "Cambiar focos del comedor y revisar enchufes sueltos.", daysFromNow: 4, hour: 10, durationMinutes: 120 },
        ],
      },
      {
        email: "elena@kuidar.app",
        name: "Doña Elena",
        firstName: "Doña Elena",
        address: "Av. Universidad 1778",
        neighborhood: "Narvarte",
        lat: 19.4035,
        lng: -99.1545,
        requests: [
          { activityType: "citas", details: "Acompañarla a consulta de oftalmología. Llegar 20 min antes.", daysFromNow: 2, hour: 8, urgent: true, durationMinutes: 120 },
          { activityType: "compania", details: "Leer el periódico en voz alta y paseo corto en el parque.", daysFromNow: 5, hour: 18, durationMinutes: 90 },
        ],
      },
    ],
  },
  {
    familyName: "Familia López",
    familyCode: "LOPEZ8",
    familyEmail: "lopez@kuidar.app",
    familyUserName: "Patricia López",
    elderly: [
      {
        email: "alberto@kuidar.app",
        name: "Don Alberto",
        firstName: "Don Alberto",
        address: "Monterrey 194, Roma Sur",
        neighborhood: "Roma Sur",
        lat: 19.4088,
        lng: -99.164,
        requests: [
          { activityType: "tecnologia", details: "Enseñarle a usar la app del banco en su tablet.", daysFromNow: 1, hour: 11, durationMinutes: 45 },
          { activityType: "mandados", details: "Recoger paquetería en estafeta y subirla al departamento.", daysFromNow: 0, hour: 14, durationMinutes: 60 },
        ],
      },
      {
        email: "lupita@kuidar.app",
        name: "Doña Lupita",
        firstName: "Doña Lupita",
        address: "Álvaro Obregón 286",
        neighborhood: "Roma Norte",
        lat: 19.4155,
        lng: -99.1625,
        requests: [
          { activityType: "compania", details: "Acompañarla a misa dominical y desayuno después.", daysFromNow: 6, hour: 9, durationMinutes: 90 },
          { activityType: "medicamento", details: "Comprar vitaminas recetadas en farmacia San Pablo.", daysFromNow: 3, hour: 12, urgent: true, durationMinutes: 30 },
          { activityType: "hogar", details: "Ayuda ordenando el closet y etiquetar medicinas.", daysFromNow: 7, hour: 10, durationMinutes: 120 },
        ],
      },
    ],
  },
];

function seedFamilyBundle(
  demoPassword: string,
  bundle: FamilySeed,
  universityId: string,
  alsoSeedStudent: boolean,
): void {
  const insertUser = db.prepare(
    "INSERT INTO users (id, email, password_hash, name, role) VALUES (?, ?, ?, ?, ?)",
  );

  const existingFamily = db
    .prepare("SELECT id FROM families WHERE family_code = ?")
    .get(bundle.familyCode) as { id: string } | undefined;

  let familyId = existingFamily?.id;
  if (!familyId) {
    const familyUserId = uuidv4();
    insertUser.run(familyUserId, bundle.familyEmail, hashPassword(demoPassword), bundle.familyUserName, "family");
    familyId = uuidv4();
    db.prepare("INSERT INTO families (id, name, family_code) VALUES (?, ?, ?)")
      .run(familyId, bundle.familyName, bundle.familyCode);
    db.prepare("INSERT INTO family_members (id, user_id, family_id, is_primary) VALUES (?, ?, ?, 1)")
      .run(uuidv4(), familyUserId, familyId);
  }

  if (alsoSeedStudent) {
    const hasStudent = db.prepare("SELECT 1 FROM users WHERE email = 'becario@kuidar.app'").get();
    if (!hasStudent) {
      const studentUserId = uuidv4();
      insertUser.run(studentUserId, "becario@kuidar.app", hashPassword(demoPassword), "Carlos Ruiz", "student");
      db.prepare("INSERT INTO students (id, user_id, university_id, career) VALUES (?, ?, ?, ?)")
        .run(uuidv4(), studentUserId, universityId, "Medicina");
    }
  }

  for (const person of bundle.elderly) {
    let elderlyProfileId: string | undefined;

    const existingUser = db
      .prepare("SELECT id FROM users WHERE email = ?")
      .get(person.email) as { id: string } | undefined;

    if (existingUser) {
      const profile = db
        .prepare("SELECT id FROM elderly_profiles WHERE user_id = ?")
        .get(existingUser.id) as { id: string } | undefined;
      elderlyProfileId = profile?.id;
      if (profile && familyId) {
        db.prepare("UPDATE elderly_profiles SET family_id = ? WHERE id = ?").run(familyId, profile.id);
      }
    } else {
      const elderlyUserId = uuidv4();
      insertUser.run(elderlyUserId, person.email, hashPassword(demoPassword), person.name, "elderly");
      elderlyProfileId = uuidv4();
      db.prepare(`
        INSERT INTO elderly_profiles (id, user_id, family_id, first_name, address, neighborhood, lat, lng)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      `).run(
        elderlyProfileId,
        elderlyUserId,
        familyId,
        person.firstName,
        person.address,
        person.neighborhood,
        person.lat,
        person.lng,
      );
    }

    if (!elderlyProfileId || !familyId) continue;

    const existingRequests = db
      .prepare("SELECT COUNT(*) AS n FROM activity_requests WHERE elderly_profile_id = ?")
      .get(elderlyProfileId) as { n: number };

    if (existingRequests.n > 0) continue;

    for (const req of person.requests) {
      insertRequest.run(
        uuidv4(),
        familyId,
        elderlyProfileId,
        req.activityType,
        req.details,
        scheduledISO(req.daysFromNow, req.hour),
        req.urgent ? 1 : 0,
        person.lat,
        person.lng,
        req.durationMinutes ?? null,
      );
    }
  }
}

const userCount = db.prepare("SELECT COUNT(*) AS n FROM users").get() as { n: number };
const demoPassword = process.env.DEMO_PASSWORD ?? "demo123";
const unamRow = db.prepare("SELECT id FROM universities WHERE slug = 'unam'").get() as { id: string } | undefined;
const universityId = unamRow?.id ?? uuidv4();

if (userCount.n === 0) {
  DEMO_FAMILIES.forEach((bundle, index) => {
    seedFamilyBundle(demoPassword, bundle, universityId, index === 0);
  });
} else {
  // DB ya existe: agregar familias/adultos/solicitudes demo que falten
  DEMO_FAMILIES.forEach((bundle) => {
    seedFamilyBundle(demoPassword, bundle, universityId, false);
  });
}
