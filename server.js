const express = require('express');
const crypto  = require('crypto');
const mysql   = require('mysql2/promise');
const path    = require('path');

const app  = express();
const PORT = process.env.PORT || 8080;

// ── MySQL connection ──────────────────────────────────────────────────────────
// Railway inject MYSQL_URL อัตโนมัติ
let db;
async function getDB() {
  if (!db) {
    db = await mysql.createPool({
      uri: process.env.MYSQL_URL || process.env.DATABASE_URL,
      waitForConnections: true,
      connectionLimit: 10,
    });
    // สร้าง table ถ้ายังไม่มี
    await db.execute(`
      CREATE TABLE IF NOT EXISTS api_keys (
        id         INT AUTO_INCREMENT PRIMARY KEY,
        \`key\`    VARCHAR(32) NOT NULL UNIQUE,
        label      VARCHAR(255) DEFAULT '',
        active     TINYINT(1)  DEFAULT 1,
        hwid       VARCHAR(64)  DEFAULT NULL,
        bound_at   DATETIME     DEFAULT NULL,
        expires_at DATETIME     DEFAULT NULL,
        last_used  DATETIME     DEFAULT NULL,
        uses       INT          DEFAULT 0,
        created_at DATETIME     DEFAULT CURRENT_TIMESTAMP
      )
    `);
  }
  return db;
}

function genKey() {
  const seg = () => crypto.randomBytes(2).toString('hex').toUpperCase();
  return `BDEK-${seg()}-${seg()}-${seg()}`;
}

// ── middleware ────────────────────────────────────────────────────────────────
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const ADMIN_TOKEN = process.env.ADMIN_TOKEN || 'babydek-admin-2025';
function requireAdmin(req, res, next) {
  const token = req.headers['x-admin-token'] || req.query.token;
  if (token !== ADMIN_TOKEN) return res.status(401).json({ error: 'Unauthorized' });
  next();
}

// ── PUBLIC: Serve PowerShell script ──────────────────────────────────────────
const fs = require('fs');
app.get('/get', (req, res) => {
  const scriptPath = path.join(__dirname, 'BabyDek.ps1');
  if (!fs.existsSync(scriptPath)) {
    return res.status(404).type('text/plain').send('# Script not found');
  }
  res.setHeader('Content-Type', 'text/plain; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  res.sendFile(scriptPath);
});

// ── PUBLIC: Verify key ────────────────────────────────────────────────────────
app.post('/api/verify', async (req, res) => {
  const { key, hwid } = req.body;
  if (!key) return res.status(400).json({ valid: false, reason: 'No key provided' });

  try {
    const db = await getDB();
    const [rows] = await db.execute(
      'SELECT * FROM api_keys WHERE `key` = ?', [key.toUpperCase().trim()]
    );
    const entry = rows[0];

    if (!entry)        return res.json({ valid: false, reason: 'Key not found' });
    if (!entry.active) return res.json({ valid: false, reason: 'Key has been revoked' });

    if (entry.expires_at && new Date() > new Date(entry.expires_at)) {
      await db.execute('UPDATE api_keys SET active=0 WHERE `key`=?', [entry.key]);
      return res.json({ valid: false, reason: 'Key expired' });
    }

    if (hwid) {
      if (!entry.hwid) {
        await db.execute(
          'UPDATE api_keys SET hwid=?, bound_at=NOW() WHERE `key`=?', [hwid, entry.key]
        );
      } else if (entry.hwid !== hwid) {
        return res.json({ valid: false, reason: 'Key already used on another machine' });
      }
    }

    await db.execute(
      'UPDATE api_keys SET last_used=NOW(), uses=uses+1 WHERE `key`=?', [entry.key]
    );

    return res.json({ valid: true, label: entry.label || '', expiresAt: entry.expires_at || null });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ valid: false, reason: 'Server error' });
  }
});

// ── ADMIN: List all keys ──────────────────────────────────────────────────────
app.get('/api/admin/keys', requireAdmin, async (req, res) => {
  const db = await getDB();
  const [rows] = await db.execute('SELECT * FROM api_keys ORDER BY created_at DESC');
  // normalize field names สำหรับ admin.html
  const keys = rows.map(r => ({
    key:       r.key,
    label:     r.label,
    active:    !!r.active,
    hwid:      r.hwid,
    boundAt:   r.bound_at,
    expiresAt: r.expires_at,
    lastUsed:  r.last_used,
    uses:      r.uses,
    createdAt: r.created_at,
  }));
  res.json(keys);
});

// ── ADMIN: Create key ─────────────────────────────────────────────────────────
app.post('/api/admin/keys', requireAdmin, async (req, res) => {
  const { label, expiresAt } = req.body;
  const db  = await getDB();
  const key = genKey();
  await db.execute(
    'INSERT INTO api_keys (`key`, label, expires_at) VALUES (?, ?, ?)',
    [key, label || '', expiresAt || null]
  );
  res.json({ key, label: label || '', active: true, expiresAt: expiresAt || null });
});

// ── ADMIN: Revoke ─────────────────────────────────────────────────────────────
app.patch('/api/admin/keys/:key/revoke', requireAdmin, async (req, res) => {
  const db = await getDB();
  await db.execute('UPDATE api_keys SET active=0 WHERE `key`=?', [req.params.key]);
  res.json({ ok: true });
});

// ── ADMIN: Restore ────────────────────────────────────────────────────────────
app.patch('/api/admin/keys/:key/restore', requireAdmin, async (req, res) => {
  const db = await getDB();
  await db.execute('UPDATE api_keys SET active=1 WHERE `key`=?', [req.params.key]);
  res.json({ ok: true });
});

// ── ADMIN: Delete ─────────────────────────────────────────────────────────────
app.delete('/api/admin/keys/:key', requireAdmin, async (req, res) => {
  const db = await getDB();
  await db.execute('DELETE FROM api_keys WHERE `key`=?', [req.params.key]);
  res.json({ ok: true });
});

// ── ADMIN: Reset HWID ─────────────────────────────────────────────────────────
app.patch('/api/admin/keys/:key/reset-hwid', requireAdmin, async (req, res) => {
  const db = await getDB();
  await db.execute('UPDATE api_keys SET hwid=NULL, bound_at=NULL WHERE `key`=?', [req.params.key]);
  res.json({ ok: true });
});

// ── Start ─────────────────────────────────────────────────────────────────────
app.listen(PORT, async () => {
  console.log(`BabyDek Key Server  →  http://localhost:${PORT}`);
  console.log(`Script URL          →  http://localhost:${PORT}/get`);
  console.log(`Admin panel         →  http://localhost:${PORT}/admin.html`);
  console.log(`Admin token         →  ${ADMIN_TOKEN}`);
  try {
    await getDB();
    console.log('MySQL connected ✓');
  } catch (e) {
    console.error('MySQL connection failed:', e.message);
  }
});
