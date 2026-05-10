const express = require('express');
const crypto = require('crypto');
const mysql = require('mysql2/promise');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 8080;

const ADMIN_TOKEN = process.env.ADMIN_TOKEN || 'babydek-admin-2025';

// ── MySQL Connection Pool ─────────────────────────────────────
let pool = null;

async function getDB() {
  if (pool) return pool;

  try {
    // Railway มักให้ MYSQL_URL หรือ DATABASE_URL
    const connectionString = process.env.MYSQL_URL || 
                            process.env.DATABASE_URL;

    if (!connectionString) {
      throw new Error('❌ MYSQL_URL or DATABASE_URL is not set in Railway Variables');
    }

    pool = mysql.createPool({
      uri: connectionString,
      waitForConnections: true,
      connectionLimit: 10,
      queueLimit: 0,
      enableKeepAlive: true,
    });

    console.log('✅ MySQL Pool Created');

    // สร้างตารางอัตโนมัติ
    await pool.execute(`
      CREATE TABLE IF NOT EXISTS api_keys (
        id INT AUTO_INCREMENT PRIMARY KEY,
        \`key\` VARCHAR(32) NOT NULL UNIQUE,
        label VARCHAR(255) DEFAULT '',
        active TINYINT(1) DEFAULT 1,
        hwid VARCHAR(64) DEFAULT NULL,
        bound_at DATETIME DEFAULT NULL,
        expires_at DATETIME DEFAULT NULL,
        last_used DATETIME DEFAULT NULL,
        uses INT DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);

    console.log('✅ Table `api_keys` is ready');
    return pool;

  } catch (err) {
    console.error('❌ MySQL Pool Error:', err.message);
    throw err;
  }
}

// ── Middleware ────────────────────────────────────────────────
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

function requireAdmin(req, res, next) {
  const token = req.headers['x-admin-token'] || req.query.token;
  if (token !== ADMIN_TOKEN) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
}

// ── PUBLIC: Serve PowerShell script ─────────────────────────────────
app.get('/get', (req, res) => {
  const scriptPath = path.join(__dirname, 'BabyDek.ps1');
  
  if (!fs.existsSync(scriptPath)) {
    console.error('❌ BabyDek.ps1 not found at:', scriptPath);
    return res.status(404).type('text/plain').send('# Script not found\nPlease contact admin');
  }

  console.log('✅ Serving BabyDek.ps1 to client');
  res.setHeader('Content-Type', 'text/plain; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate');
  res.sendFile(scriptPath);
});

// ── PUBLIC: Verify key ─────────────────────────────────────────────
app.post('/api/verify', async (req, res) => {
  const { key, hwid } = req.body;
  if (!key) return res.status(400).json({ valid: false, reason: 'No key provided' });

  try {
    const db = await getDB();
    const [rows] = await db.execute(
      'SELECT * FROM api_keys WHERE `key` = ?', 
      [key.toUpperCase().trim()]
    );

    const entry = rows[0];
    if (!entry) return res.json({ valid: false, reason: 'Key not found' });
    if (!entry.active) return res.json({ valid: false, reason: 'Key has been revoked' });

    if (entry.expires_at && new Date() > new Date(entry.expires_at)) {
      await db.execute('UPDATE api_keys SET active=0 WHERE `key`=?', [entry.key]);
      return res.json({ valid: false, reason: 'Key expired' });
    }

    if (hwid) {
      if (!entry.hwid) {
        await db.execute('UPDATE api_keys SET hwid=?, bound_at=NOW() WHERE `key`=?', 
          [hwid, entry.key]);
      } else if (entry.hwid !== hwid) {
        return res.json({ valid: false, reason: 'Key already used on another machine' });
      }
    }

    await db.execute(
      'UPDATE api_keys SET last_used=NOW(), uses=uses+1 WHERE `key`=?', 
      [entry.key]
    );

    return res.json({ 
      valid: true, 
      label: entry.label || '', 
      expiresAt: entry.expires_at 
    });

  } catch (err) {
    console.error('Verify Error:', err);
    return res.status(500).json({ valid: false, reason: 'Server error' });
  }
});

// ── ADMIN Routes (เหมือนเดิม) ─────────────────────────────────────
app.get('/api/admin/keys', requireAdmin, async (req, res) => {
  const db = await getDB();
  const [rows] = await db.execute('SELECT * FROM api_keys ORDER BY created_at DESC');
  
  const keys = rows.map(r => ({
    key: r.key,
    label: r.label,
    active: !!r.active,
    hwid: r.hwid,
    boundAt: r.bound_at,
    expiresAt: r.expires_at,
    lastUsed: r.last_used,
    uses: r.uses,
    createdAt: r.created_at,
  }));
  res.json(keys);
});

app.post('/api/admin/keys', requireAdmin, async (req, res) => {
  const { label, expiresAt } = req.body;
  const db = await getDB();
  const key = `BDEK-${crypto.randomBytes(2).toString('hex').toUpperCase()}-${crypto.randomBytes(2).toString('hex').toUpperCase()}-${crypto.randomBytes(2).toString('hex').toUpperCase()}`;

  await db.execute(
    'INSERT INTO api_keys (`key`, label, expires_at) VALUES (?, ?, ?)',
    [key, label || '', expiresAt || null]
  );
  res.json({ key, label: label || '', active: true, expiresAt: expiresAt || null });
});

app.patch('/api/admin/keys/:key/revoke', requireAdmin, async (req, res) => {
  const db = await getDB();
  await db.execute('UPDATE api_keys SET active=0 WHERE `key`=?', [req.params.key]);
  res.json({ ok: true });
});

app.patch('/api/admin/keys/:key/restore', requireAdmin, async (req, res) => {
  const db = await getDB();
  await db.execute('UPDATE api_keys SET active=1 WHERE `key`=?', [req.params.key]);
  res.json({ ok: true });
});

app.delete('/api/admin/keys/:key', requireAdmin, async (req, res) => {
  const db = await getDB();
  await db.execute('DELETE FROM api_keys WHERE `key`=?', [req.params.key]);
  res.json({ ok: true });
});

app.patch('/api/admin/keys/:key/reset-hwid', requireAdmin, async (req, res) => {
  const db = await getDB();
  await db.execute('UPDATE api_keys SET hwid=NULL, bound_at=NULL WHERE `key`=?', [req.params.key]);
  res.json({ ok: true });
});

// ── Start Server ─────────────────────────────────────────────
app.listen(PORT, async () => {
  console.log(`🚀 BabyDek Key Server running on port ${PORT}`);
  console.log(`📥 Script URL: http://localhost:${PORT}/get`);
  console.log(`🔧 Admin: http://localhost:${PORT}/admin.html`);

  try {
    await getDB();
    console.log('✅ MySQL Connected Successfully');
  } catch (e) {
    console.error('⚠️  MySQL Connection Failed - Check Railway Variables');
  }
});
