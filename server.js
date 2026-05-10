const express = require('express');
const crypto = require('crypto');
const mysql = require('mysql2/promise');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 8080;

const ADMIN_TOKEN = process.env.ADMIN_TOKEN || '';
const CLIENT_SECRET = process.env.CLIENT_SECRET || '';
const SCRIPT_TOKEN_SECRET = process.env.SCRIPT_TOKEN_SECRET || CLIENT_SECRET;
const SCRIPT_TOKEN_TTL_SECONDS = Number(process.env.SCRIPT_TOKEN_TTL_SECONDS || 45);
const issuedScriptTokens = new Map();

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

function secureEquals(a, b) {
  if (!a || !b) return false;
  const aBuf = Buffer.from(String(a));
  const bBuf = Buffer.from(String(b));
  if (aBuf.length !== bBuf.length) return false;
  return crypto.timingSafeEqual(aBuf, bBuf);
}

function base64UrlEncode(value) {
  return Buffer.from(value).toString('base64url');
}

function base64UrlDecode(value) {
  return Buffer.from(value, 'base64url').toString('utf8');
}

function issueScriptToken() {
  if (!SCRIPT_TOKEN_SECRET) return null;

  const nonce = crypto.randomBytes(12).toString('hex');
  const exp = Date.now() + SCRIPT_TOKEN_TTL_SECONDS * 1000;
  const payloadRaw = JSON.stringify({ nonce, exp });
  const payload = base64UrlEncode(payloadRaw);
  const signature = crypto
    .createHmac('sha256', SCRIPT_TOKEN_SECRET)
    .update(payload)
    .digest('base64url');

  issuedScriptTokens.set(nonce, exp);
  return `${payload}.${signature}`;
}

function validateAndConsumeScriptToken(token) {
  if (!SCRIPT_TOKEN_SECRET || !token) return false;
  const [payload, signature] = String(token).split('.');
  if (!payload || !signature) return false;

  const expectedSig = crypto
    .createHmac('sha256', SCRIPT_TOKEN_SECRET)
    .update(payload)
    .digest('base64url');

  if (!secureEquals(signature, expectedSig)) return false;

  let decoded = null;
  try {
    decoded = JSON.parse(base64UrlDecode(payload));
  } catch {
    return false;
  }

  const { nonce, exp } = decoded || {};
  if (!nonce || !exp || Date.now() > exp) return false;

  const issuedExp = issuedScriptTokens.get(nonce);
  if (!issuedExp || Date.now() > issuedExp) return false;

  issuedScriptTokens.delete(nonce);
  return true;
}

function pruneExpiredScriptTokens() {
  const now = Date.now();
  for (const [nonce, exp] of issuedScriptTokens.entries()) {
    if (exp < now) {
      issuedScriptTokens.delete(nonce);
    }
  }
}

setInterval(pruneExpiredScriptTokens, 60_000).unref();

function requireAdmin(req, res, next) {
  const token = req.headers['x-admin-token'] || req.query.token;
  if (!ADMIN_TOKEN || !secureEquals(token, ADMIN_TOKEN)) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
}

function requireClientSecret(req, res, next) {
  const clientSecret = req.headers['x-babydek-client'];
  if (!CLIENT_SECRET || !secureEquals(clientSecret, CLIENT_SECRET)) {
    return res.status(404).json({ valid: false, reason: 'Not Found' });
  }
  next();
}

function requireAdminPage(req, res, next) {
  const token = req.headers['x-admin-token'] || req.query.token;
  if (!ADMIN_TOKEN || !secureEquals(token, ADMIN_TOKEN)) {
    return res.status(404).type('text/plain').send('Not Found');
  }
  next();
}

app.get('/admin', requireAdminPage, (req, res) => {
  const token = encodeURIComponent(req.query.token || '');
  if (!token) {
    return res.status(404).type('text/plain').send('Not Found');
  }
  return res.redirect(`/admin.html?token=${token}`);
});

app.get('/admin.html', requireAdminPage, (req, res) => {
  return res.sendFile(path.join(__dirname, 'public', 'admin.html'));
});

app.use(express.static(path.join(__dirname, 'public')));

// ── PUBLIC: Serve PowerShell script (PROTECTED) ─────────────────────────────────
app.get('/bd-init-v2', (req, res) => {
  const token = req.query.st;
  if (!validateAndConsumeScriptToken(token)) {
    return res.status(404).type('text/plain').send('Not Found');
  }

  const scriptPath = path.join(__dirname, 'BabyDek.ps1');

  if (!fs.existsSync(scriptPath)) {
    console.error('❌ BabyDek.ps1 not found at:', scriptPath);
    return res.status(404).type('text/plain').send('# Script not found\nPlease contact admin');
  }

  console.log('✅ Serving BabyDek.ps1 to authorized client');

  // Read file and encode as base64 for PowerShell to decode
  const scriptContent = fs.readFileSync(scriptPath, 'utf8');
  const base64Content = Buffer.from(scriptContent, 'utf8').toString('base64');

  res.setHeader('Content-Type', 'text/plain; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate');
  res.send(base64Content);
});

app.post('/api/script-token', requireClientSecret, (req, res) => {
  const token = issueScriptToken();
  if (!token) {
    return res.status(500).json({ ok: false, reason: 'Script token secret is missing' });
  }
  res.json({
    ok: true,
    token,
    expiresIn: SCRIPT_TOKEN_TTL_SECONDS,
  });
});

// ── PUBLIC: Verify key (PROTECTED) ─────────────────────────────────────────────
app.post('/api/verify', requireClientSecret, async (req, res) => {
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
  console.log(`📥 Script URL: http://localhost:${PORT}/bd-init-v2`);
  console.log(`🔧 Admin: http://localhost:${PORT}/admin.html`);
  if (!CLIENT_SECRET) {
    console.warn('⚠️  CLIENT_SECRET is missing. Protected endpoints will be blocked.');
  }
  if (!ADMIN_TOKEN) {
    console.warn('⚠️  ADMIN_TOKEN is missing. Admin endpoints will be blocked.');
  }
  if (!SCRIPT_TOKEN_SECRET) {
    console.warn('⚠️  SCRIPT_TOKEN_SECRET is missing. Script token endpoint will fail.');
  }

  try {
    await getDB();
    console.log('✅ MySQL Connected Successfully');
  } catch (e) {
    console.error('⚠️  MySQL Connection Failed - Check Railway Variables');
  }
});
