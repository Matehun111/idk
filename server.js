// ============================================================
//  ZENITH LICENSE SERVER  —  Node.js + Express
//  npm install express cors uuid
//  node server.js
// ============================================================

const express = require('express')
const cors    = require('cors')
const crypto  = require('crypto')
const fs      = require('fs')
const path    = require('path')

const app     = express()
const PORT    = process.env.PORT || 3000

// ── Admin secret (used by Discord bot to create/revoke keys) ─────────────
const ADMIN_SECRET = process.env.ADMIN_SECRET || 'change_this_secret_now'

// ── JSON file database ────────────────────────────────────────────────────
const DB_PATH = path.join(__dirname, 'licenses.json')

function db_read() {
    if (!fs.existsSync(DB_PATH)) fs.writeFileSync(DB_PATH, '{}')
    try { return JSON.parse(fs.readFileSync(DB_PATH, 'utf8')) }
    catch { return {} }
}
function db_write(data) {
    fs.writeFileSync(DB_PATH, JSON.stringify(data, null, 2))
}

// ── Plan validation ───────────────────────────────────────────────────────
const VALID_PLANS = ['beta', 'nightly']

// ── Duration parser ───────────────────────────────────────────────────────
//  '1d' '7d' '30d' '1w' '1m' 'lifetime'
function parse_duration(dur) {
    if (!dur || dur === 'lifetime') return null
    const m = dur.match(/^(\d+)(d|w|m)$/)
    if (!m) throw new Error('Invalid duration. Use: 1d 7d 30d 1w 1m lifetime')
    const n = parseInt(m[1])
    const unit = m[2]
    const ms = unit === 'd' ? n * 86400000
             : unit === 'w' ? n * 604800000
             : unit === 'm' ? n * 2592000000
             : null
    if (!ms) throw new Error('Bad unit')
    return Date.now() + ms
}

// ── Key generator ─────────────────────────────────────────────────────────
//  ZEN-NIGHTLY-1W-A3F9
function gen_key(plan, dur) {
    const p   = plan.toUpperCase()
    const d   = dur.toUpperCase()
    const rnd = crypto.randomBytes(3).toString('hex').toUpperCase()
    return `ZEN-${p}-${d}-${rnd}`
}

app.use(cors())
app.use(express.json())

// ── POST /admin/create  ───────────────────────────────────────────────────
//  Headers: x-admin-secret: <ADMIN_SECRET>
//  Body:    { plan: 'nightly', duration: '1w', note: 'discord @user' }
//  Returns: { key, plan, expires_at, note }
app.post('/admin/create', (req, res) => {
    if (req.headers['x-admin-secret'] !== ADMIN_SECRET)
        return res.status(403).json({ error: 'forbidden' })

    const { plan, duration, note } = req.body
    if (!VALID_PLANS.includes(plan))
        return res.status(400).json({ error: 'invalid plan. use: beta | nightly' })

    let expires_at
    try { expires_at = parse_duration(duration || 'lifetime') }
    catch (e) { return res.status(400).json({ error: e.message }) }

    const key = gen_key(plan, duration || 'LIFE')
    const db  = db_read()
    db[key]   = { plan, expires_at, hwid: null, note: note || '', created_at: Date.now() }
    db_write(db)

    res.json({ key, plan, expires_at, note: note || '' })
    console.log(`[CREATE] ${key} | plan=${plan} expires=${expires_at ? new Date(expires_at).toISOString() : 'never'}`)
})

// ── POST /admin/revoke  ───────────────────────────────────────────────────
//  Body: { key: 'ZEN-...' }
app.post('/admin/revoke', (req, res) => {
    if (req.headers['x-admin-secret'] !== ADMIN_SECRET)
        return res.status(403).json({ error: 'forbidden' })

    const { key } = req.body
    const db = db_read()
    if (!db[key]) return res.status(404).json({ error: 'key not found' })
    delete db[key]
    db_write(db)
    res.json({ revoked: key })
    console.log(`[REVOKE] ${key}`)
})

// ── POST /admin/reset_hwid  ───────────────────────────────────────────────
//  Body: { key: 'ZEN-...' }
app.post('/admin/reset_hwid', (req, res) => {
    if (req.headers['x-admin-secret'] !== ADMIN_SECRET)
        return res.status(403).json({ error: 'forbidden' })

    const { key } = req.body
    const db = db_read()
    if (!db[key]) return res.status(404).json({ error: 'key not found' })
    db[key].hwid = null
    db_write(db)
    res.json({ reset: key })
    console.log(`[HWID_RESET] ${key}`)
})

// ── GET /admin/list  ──────────────────────────────────────────────────────
app.get('/admin/list', (req, res) => {
    if (req.headers['x-admin-secret'] !== ADMIN_SECRET)
        return res.status(403).json({ error: 'forbidden' })

    const db  = db_read()
    const now = Date.now()
    const out = Object.entries(db).map(([key, v]) => ({
        key,
        plan:       v.plan,
        expires_at: v.expires_at,
        expired:    v.expires_at ? now > v.expires_at : false,
        hwid_locked: !!v.hwid,
        note:       v.note || '',
    }))
    res.json(out)
})

// ── GET /verify  ──────────────────────────────────────────────────────────
//  Query: ?key=ZEN-...&hwid=XXXXX
//  Returns: { valid, plan, expires_at, reason }
app.get('/verify', (req, res) => {
    const { key, hwid } = req.query

    if (!key || !hwid) {
        return res.json({ valid: false, reason: 'missing_params' })
    }

    const db      = db_read()
    const license = db[key]

    if (!license) {
        console.log(`[VERIFY FAIL] key=${key} reason=not_found`)
        return res.json({ valid: false, reason: 'invalid_key' })
    }

    // expiry check
    if (license.expires_at && Date.now() > license.expires_at) {
        console.log(`[VERIFY FAIL] key=${key} reason=expired`)
        return res.json({ valid: false, reason: 'expired' })
    }

    // HWID lock on first use
    if (!license.hwid) {
        license.hwid = hwid
        db_write(db)
        console.log(`[HWID LOCK] key=${key} hwid=${hwid}`)
    }

    if (license.hwid !== hwid) {
        console.log(`[VERIFY FAIL] key=${key} reason=hwid_mismatch`)
        return res.json({ valid: false, reason: 'hwid_mismatch' })
    }

    console.log(`[VERIFY OK] key=${key} plan=${license.plan}`)
    res.json({
        valid:      true,
        plan:       license.plan,
        expires_at: license.expires_at,
        user:       license.note || null,
    })
})

app.listen(PORT, () => {
    console.log(`Zenith License Server running on :${PORT}`)
    console.log(`Admin secret: ${ADMIN_SECRET}`)
})
