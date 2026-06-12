const { DatabaseSync } = require('node:sqlite');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const { hashPassword } = require('../helpers/auth');

const db = new DatabaseSync(path.join(__dirname, 'kuidar.db'));

db.exec(`PRAGMA journal_mode = WAL`);
db.exec(`PRAGMA foreign_keys = ON`);

db.exec(`
  CREATE TABLE IF NOT EXISTS elderly_persons (
    id           TEXT PRIMARY KEY,
    first_name   TEXT NOT NULL,
    neighborhood TEXT NOT NULL DEFAULT 'CDMX',
    address      TEXT NOT NULL DEFAULT 'CDMX',
    notes        TEXT NOT NULL DEFAULT '',
    created_at   TEXT NOT NULL DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS activity_requests (
    id                TEXT PRIMARY KEY,
    activity_type     TEXT NOT NULL,
    details           TEXT NOT NULL DEFAULT '',
    scheduled_date    TEXT NOT NULL,
    is_urgent         INTEGER NOT NULL DEFAULT 0,
    status            TEXT NOT NULL DEFAULT 'open',
    published_at      TEXT NOT NULL DEFAULT (datetime('now')),
    latitude          REAL NOT NULL,
    longitude         REAL NOT NULL,
    elderly_person_id TEXT REFERENCES elderly_persons(id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS students (
    id             TEXT PRIMARY KEY,
    name           TEXT NOT NULL,
    university     TEXT NOT NULL DEFAULT '',
    career         TEXT NOT NULL DEFAULT '',
    average_rating REAL NOT NULL DEFAULT 0.0,
    total_hours    INTEGER NOT NULL DEFAULT 0
  );

  CREATE TABLE IF NOT EXISTS ratings (
    id                  TEXT PRIMARY KEY,
    stars               INTEGER NOT NULL,
    tags                TEXT NOT NULL DEFAULT '[]',
    created_at          TEXT NOT NULL DEFAULT (datetime('now')),
    activity_request_id TEXT REFERENCES activity_requests(id) ON DELETE SET NULL,
    student_id          TEXT REFERENCES students(id) ON DELETE SET NULL
  );

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
`);

const userCount = db.prepare('SELECT COUNT(*) AS n FROM users').get().n;
if (userCount === 0) {
  const insert = db.prepare(`
    INSERT INTO users (id, email, password_hash, name, role)
    VALUES (?, ?, ?, ?, ?)
  `);

  const demoUsers = [
    { email: 'familia@kuidar.app',  password: 'demo123', name: 'María García',  role: 'family'  },
    { email: 'becario@kuidar.app',  password: 'demo123', name: 'Carlos Ruiz',   role: 'student' },
    { email: 'adulto@kuidar.app',   password: 'demo123', name: 'Don Roberto',   role: 'elderly' },
  ];

  for (const u of demoUsers) {
    insert.run(uuidv4(), u.email, hashPassword(u.password), u.name, u.role);
  }
}

module.exports = db;
