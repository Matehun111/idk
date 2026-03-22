const express = require('express')
const cors    = require('cors')
const crypto  = require('crypto')

const app  = express()
const PORT = process.env.PORT || 3000

const ADMIN_SECRET  = process.env.ADMIN_SECRET  || 'change_this_secret_now'
const SCRIPT_SECRET = process.env.SCRIPT_SECRET || 'change_this_script_secret_now'

// ── PERSISTENT DB via Railway env var ────────────────────────────────────
// Since Railway filesystem resets on redeploy, we store licenses in
// a KV store. Simplest free option: store in memory + sync to
// environment variable via Railway API, OR use a free Redis/Upstash.
// 
// SIMPLEST FIX: Use Upstash Redis (free tier, 10k commands/day)
// npm install @upstash/redis
// Set env: UPSTASH_REDIS_REST_URL and UPSTASH_REDIS_REST_TOKEN

const { Redis } = require('@upstash/redis')

const redis = new Redis({
    url:   process.env.UPSTASH_REDIS_REST_URL,
    token: process.env.UPSTASH_REDIS_REST_TOKEN,
})

const DB_KEY = 'zenith:licenses'

async function db_read() {
    try {
        const data = await redis.get(DB_KEY)
        return data || {}
    } catch(e) {
        console.error('DB read error:', e.message)
        return {}
    }
}

async function db_write(data) {
    try {
        await redis.set(DB_KEY, data)
    } catch(e) {
        console.error('DB write error:', e.message)
    }
}

// ── Script storage — also in Redis ───────────────────────────────────────
async function get_script(plan) {
    try {
        const key = `zenith:script:${plan}`
        return await redis.get(key)
    } catch(e) {
        return null
    }
}

const VALID_PLANS = ['beta', 'nightly']

function parse_duration(dur) {
    if (!dur || dur === 'lifetime') return null
    const m = dur.match(/^(\d+)(d|w|m)$/i)
    if (!m) throw new Error('Invalid duration. Use: 1d 7d 30d 1w 1m lifetime')
    const n  = parseInt(m[1], 10)
    const ms = m[2].toLowerCase()==='d' ? n*86400000
             : m[2].toLowerCase()==='w' ? n*604800000
             : m[2].toLowerCase()==='m' ? n*2592000000 : null
    if (!ms) throw new Error('Bad unit')
    return Date.now() + ms
}

function gen_key(plan, dur) {
    const rnd = crypto.randomBytes(3).toString('hex').toUpperCase()
    // normalize duration label
    const dlabel = (!dur || dur.toLowerCase()==='lifetime') ? 'LIFE' : dur.toUpperCase()
    return `ZEN-${plan.toUpperCase()}-${dlabel}-${rnd}`
}

function sha256(text) {
    return crypto.createHash('sha256').update(String(text)).digest('hex')
}
function sign_ticket(key, hwid, plan, ticket_exp, nonce) {
    return sha256(`${key}|${hwid}|${plan}|${ticket_exp}|${nonce}|${SCRIPT_SECRET}`)
}

app.use(cors())
app.use(express.json({ limit: "10mb" }))

// ── POST /admin/create ────────────────────────────────────────────────────
app.post('/admin/create', async (req, res) => {
    if (req.headers['x-admin-secret'] !== ADMIN_SECRET)
        return res.status(403).json({ error: 'forbidden' })
    const { plan, duration, note } = req.body
    if (!VALID_PLANS.includes(plan))
        return res.status(400).json({ error: 'invalid plan' })
    let expires_at
    try { expires_at = parse_duration(duration || 'lifetime') }
    catch(e) { return res.status(400).json({ error: e.message }) }
    const key = gen_key(plan, duration || 'lifetime')
    const db  = await db_read()
    db[key] = {
        plan, expires_at, hwid: null, note: note||'',
        created_at: Date.now(), revoked: false,
        last_ticket: null, last_ticket_exp: null, last_nonce: null,
    }
    await db_write(db)
    res.json({ key, plan, expires_at, note: note||'' })
    console.log(`[CREATE] ${key}`)
})

// ── POST /admin/revoke ────────────────────────────────────────────────────
app.post('/admin/revoke', async (req, res) => {
    if (req.headers['x-admin-secret'] !== ADMIN_SECRET)
        return res.status(403).json({ error: 'forbidden' })
    const { key } = req.body
    const db = await db_read()
    if (!db[key]) return res.status(404).json({ error: 'key not found' })
    db[key].revoked = true; db[key].last_ticket = null
    await db_write(db)
    res.json({ revoked: key })
})

// ── POST /admin/reset_hwid ────────────────────────────────────────────────
app.post('/admin/reset_hwid', async (req, res) => {
    if (req.headers['x-admin-secret'] !== ADMIN_SECRET)
        return res.status(403).json({ error: 'forbidden' })
    const { key } = req.body
    const db = await db_read()
    if (!db[key]) return res.status(404).json({ error: 'key not found' })
    db[key].hwid = null; db[key].last_ticket = null
    await db_write(db)
    res.json({ reset: key })
})

// ── GET /admin/list ───────────────────────────────────────────────────────
app.get('/admin/list', async (req, res) => {
    if (req.headers['x-admin-secret'] !== ADMIN_SECRET)
        return res.status(403).json({ error: 'forbidden' })
    const db  = await db_read()
    const now = Date.now()
    res.json(Object.entries(db).map(([key, v]) => ({
        key, plan: v.plan, expires_at: v.expires_at,
        expired: v.expires_at ? now > v.expires_at : false,
        hwid_locked: !!v.hwid, revoked: !!v.revoked, note: v.note||''
    })))
})

// ── POST /admin/upload_script ─────────────────────────────────────────────
// Upload the cloud Lua scripts so they live in Redis, not on disk
app.post('/admin/upload_script', async (req, res) => {
    if (req.headers['x-admin-secret'] !== ADMIN_SECRET)
        return res.status(403).json({ error: 'forbidden' })
    const { plan, script } = req.body
    if (!VALID_PLANS.includes(plan))
        return res.status(400).json({ error: 'invalid plan' })
    if (!script || script.length < 100)
        return res.status(400).json({ error: 'script too short' })
    await redis.set(`zenith:script:${plan}`, script)
    res.json({ ok: true, plan, bytes: script.length })
    console.log(`[SCRIPT UPLOAD] plan=${plan} bytes=${script.length}`)
})

// ── GET /verify ───────────────────────────────────────────────────────────
app.get('/verify', async (req, res) => {
    const { key, hwid } = req.query
    if (!key || !hwid) return res.json({ valid: false, reason: 'missing_params' })
    const db      = await db_read()
    const license = db[key]
    if (!license)                                             return res.json({ valid: false, reason: 'invalid_key' })
    if (license.revoked)                                      return res.json({ valid: false, reason: 'revoked' })
    if (license.expires_at && Date.now()>license.expires_at) return res.json({ valid: false, reason: 'expired' })
    if (!license.hwid) { license.hwid = hwid }
    if (license.hwid !== hwid) { await db_write(db); return res.json({ valid: false, reason: 'hwid_mismatch' }) }

    const nonce      = crypto.randomBytes(12).toString('hex')
    const ticket_exp = Date.now() + 20000
    const ticket     = sign_ticket(key, hwid, license.plan, ticket_exp, nonce)
    license.last_ticket = ticket; license.last_ticket_exp = ticket_exp; license.last_nonce = nonce
    await db_write(db)

    console.log(`[VERIFY OK] key=${key} plan=${license.plan}`)
    res.json({
        valid: true, plan: license.plan, expires_at: license.expires_at,
        user: license.note||null, ticket, ticket_exp, nonce,
    })
})

// ── GET /script ───────────────────────────────────────────────────────────
app.get('/script', async (req, res) => {
    const { key, hwid, plan, ticket, nonce } = req.query
    if (!key||!hwid||!plan||!ticket||!nonce)
        return res.status(400).json({ ok: false, reason: 'missing_params' })
    const db      = await db_read()
    const license = db[key]
    if (!license)                                              return res.status(404).json({ ok: false, reason: 'invalid_key' })
    if (license.revoked)                                       return res.status(403).json({ ok: false, reason: 'revoked' })
    if (license.expires_at && Date.now()>license.expires_at)  return res.status(403).json({ ok: false, reason: 'expired' })
    if (license.hwid !== hwid)                                 return res.status(403).json({ ok: false, reason: 'hwid_mismatch' })
    if (license.plan !== plan)                                 return res.status(403).json({ ok: false, reason: 'wrong_plan' })
    if (!license.last_ticket||!license.last_ticket_exp)        return res.status(403).json({ ok: false, reason: 'no_ticket' })
    if (Date.now() > license.last_ticket_exp)                  return res.status(403).json({ ok: false, reason: 'ticket_expired' })
    const expected = sign_ticket(key, hwid, plan, license.last_ticket_exp, license.last_nonce)
    if (ticket!==expected || nonce!==license.last_nonce || ticket!==license.last_ticket)
        return res.status(403).json({ ok: false, reason: 'bad_ticket' })

    const raw = await get_script(plan)
    if (!raw) return res.status(500).json({ ok: false, reason: 'script_missing' })

    const prefix = [
        `rawset(_G, "_auth_ok",        true)`,
        `rawset(_G, "_auth_alive",      true)`,
        `rawset(_G, "_auth_ticket",     ${JSON.stringify(ticket)})`,
        `rawset(_G, "_auth_ticket_exp", ${license.last_ticket_exp})`,
        `rawset(_G, "_auth_nonce",      ${JSON.stringify(nonce)})`,
        `rawset(_G, "_auth_user",       ${JSON.stringify(license.note||"")})`,
        `rawset(_G, "BUILD_VERSION",    ${JSON.stringify(plan)})`,
    ].join('\n')

    // burn ticket
    license.last_ticket = null; license.last_ticket_exp = null; license.last_nonce = null
    await db_write(db)

    console.log(`[SCRIPT DELIVERED] key=${key} plan=${plan}`)
    res.type('text/plain').send(prefix + '\n\n' + raw)
})

app.listen(PORT, () => console.log(`Zenith License Server on :${PORT}`))
