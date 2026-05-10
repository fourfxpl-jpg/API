const express = require('express');
const crypto  = require('crypto');
const fs      = require('fs');
const path    = require('path');

const app  = express();
const PORT = process.env.PORT || 8080;
const DB   = path.join(__dirname, 'keys.json');

function loadDB() {
  if (!fs.existsSync(DB)) fs.writeFileSync(DB, JSON.stringify({ keys: [] }));
  return JSON.parse(fs.readFileSync(DB));
}
function saveDB(data) {
  fs.writeFileSync(DB, JSON.stringify(data, null, 2));
}
function genKey() {
  const seg = () => crypto.randomBytes(2).toString('hex').toUpperCase();
  return `BDEK-${seg()}-${seg()}-${seg()}`;
}

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const ADMIN_TOKEN = process.env.ADMIN_TOKEN || 'babydek-admin-2025';

function requireAdmin(req, res, next) {
  const token = req.headers['x-admin-token'] || req.query.token;
  if (token !== ADMIN_TOKEN) return res.status(401).json({ error: 'Unauthorized' });
  next();
}

// ── PUBLIC: Serve PowerShell script ──────────────────────────────────────────
// User รันด้วย:  irm https://your-url.railway.app/get | iex
app.get('/get', (req, res) => {
  const scriptPath = path.join(__dirname, 'BabyDek.ps1');
  if (!fs.existsSync(scriptPath)) {
    return res.status(404).type('text/plain').send('# Script not found on server');
  }
  res.setHeader('Content-Type', 'text/plain; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  res.sendFile(scriptPath);
});

// ── PUBLIC: Verify key ────────────────────────────────────────────────────────
app.post('/api/verify', (req, res) => {
  const { key, hwid } = req.body;
  if (!key) return res.status(400).json({ valid: false, reason: 'No key provided' });

  const db    = loadDB();
  const entry = db.keys.find(k => k.key === key.toUpperCase().trim());

  if (!entry)        return res.json({ valid: false, reason: 'Key not found' });
  if (!entry.active) return res.json({ valid: false, reason: 'Key has been revoked' });

  if (entry.expiresAt && new Date() > new Date(entry.expiresAt)) {
    entry.active = false; saveDB(db);
    return res.json({ valid: false, reason: 'Key expired' });
  }

  if (hwid) {
    if (!entry.hwid) {
      entry.hwid = hwid; entry.boundAt = new Date().toISOString();
    } else if (entry.hwid !== hwid) {
      return res.json({ valid: false, reason: 'Key already used on another machine' });
    }
  }

  entry.lastUsed = new Date().toISOString();
  entry.uses     = (entry.uses || 0) + 1;
  saveDB(db);
  return res.json({ valid: true, label: entry.label || '', expiresAt: entry.expiresAt || null });
});

// ── ADMIN: List ───────────────────────────────────────────────────────────────
app.get('/api/admin/keys', requireAdmin, (req, res) => res.json(loadDB().keys));

// ── ADMIN: Create ─────────────────────────────────────────────────────────────
app.post('/api/admin/keys', requireAdmin, (req, res) => {
  const { label, expiresAt } = req.body;
  const db = loadDB();
  const entry = {
    key: genKey(), label: label || '', active: true,
    createdAt: new Date().toISOString(), expiresAt: expiresAt || null,
    hwid: null, boundAt: null, lastUsed: null, uses: 0
  };
  db.keys.push(entry); saveDB(db); res.json(entry);
});

// ── ADMIN: Revoke / Restore / Delete / Reset HWID ────────────────────────────
app.patch('/api/admin/keys/:key/revoke', requireAdmin, (req, res) => {
  const db = loadDB(); const e = db.keys.find(k => k.key === req.params.key);
  if (!e) return res.status(404).json({ error: 'Not found' });
  e.active = false; saveDB(db); res.json({ ok: true });
});
app.patch('/api/admin/keys/:key/restore', requireAdmin, (req, res) => {
  const db = loadDB(); const e = db.keys.find(k => k.key === req.params.key);
  if (!e) return res.status(404).json({ error: 'Not found' });
  e.active = true; saveDB(db); res.json({ ok: true });
});
app.delete('/api/admin/keys/:key', requireAdmin, (req, res) => {
  const db = loadDB(); db.keys = db.keys.filter(k => k.key !== req.params.key);
  saveDB(db); res.json({ ok: true });
});
app.patch('/api/admin/keys/:key/reset-hwid', requireAdmin, (req, res) => {
  const db = loadDB(); const e = db.keys.find(k => k.key === req.params.key);
  if (!e) return res.status(404).json({ error: 'Not found' });
  e.hwid = null; e.boundAt = null; saveDB(db); res.json({ ok: true });
});

app.listen(PORT, () => {
  console.log(`BabyDek Key Server  →  http://localhost:${PORT}`);
  console.log(`Script URL          →  http://localhost:${PORT}/get`);
  console.log(`Admin panel         →  http://localhost:${PORT}/admin.html`);
  console.log(`Admin token         →  ${ADMIN_TOKEN}`);
});
