const express = require('express')
const cors    = require('cors')
const crypto  = require('crypto')
const fs      = require('fs')
const path    = require('path')

const app  = express()
const PORT = process.env.PORT || 3000

const ADMIN_SECRET  = process.env.ADMIN_SECRET  || 'change_this_secret_now'
const SCRIPT_SECRET = process.env.SCRIPT_SECRET || 'change_this_script_secret_now'

const DB_PATH             = path.join(__dirname, 'licenses.json')
const BETA_SCRIPT_PATH    = path.join(__dirname, 'zenith_cloud_beta.lua')
const NIGHTLY_SCRIPT_PATH = path.join(__dirname, 'zenith_cloud_nightly.lua')

function db_read() {
    if (!fs.existsSync(DB_PATH)) fs.writeFileSync(DB_PATH, '{}')
    try { return JSON.parse(fs.readFileSync(DB_PATH, 'utf8')) }
    catch { return {} }
}
function db_write(data) { fs.writeFileSync(DB_PATH, JSON.stringify(data, null, 2)) }

const VALID_PLANS = ['beta', 'nightly']

function parse_duration(dur) {
    if (!dur || dur === 'lifetime') return null
    const m = dur.match(/^(\d+)(d|w|m)$/)
    if (!m) throw new Error('Invalid duration. Use: 1d 7d 30d 1w 1m lifetime')
    const n = parseInt(m[1], 10)
    const ms = m[2]==='d' ? n*86400000 : m[2]==='w' ? n*604800000 : m[2]==='m' ? n*2592000000 : null
    if (!ms) throw new Error('Bad unit')
    return Date.now() + ms
}

function gen_key(plan, dur) {
    return `ZEN-${plan.toUpperCase()}-${dur.toUpperCase()}-${crypto.randomBytes(3).toString('hex').toUpperCase()}`
}

function sha256(text) { return crypto.createHash('sha256').update(String(text)).digest('hex') }

function sign_ticket(key, hwid, plan, ticket_exp, nonce) {
    return sha256(`${key}|${hwid}|${plan}|${ticket_exp}|${nonce}|${SCRIPT_SECRET}`)
}

function get_script_path(plan) {
    if (plan === 'beta')    return BETA_SCRIPT_PATH
    if (plan === 'nightly') return NIGHTLY_SCRIPT_PATH
    return null
}

app.use(cors())
app.use(express.json())

app.post('/admin/create', (req, res) => {
    if (req.headers['x-admin-secret'] !== ADMIN_SECRET) return res.status(403).json({ error: 'forbidden' })
    const { plan, duration, note } = req.body
    if (!VALID_PLANS.includes(plan)) return res.status(400).json({ error: 'invalid plan' })
    let expires_at
    try { expires_at = parse_duration(duration || 'lifetime') } catch (e) { return res.status(400).json({ error: e.message }) }
    const key = gen_key(plan, duration || 'LIFE')
    const db  = db_read()
    db[key] = { plan, expires_at, hwid: null, note: note||'', created_at: Date.now(), revoked: false, last_ticket: null, last_ticket_exp: null, last_nonce: null }
    db_write(db)
    res.json({ key, plan, expires_at, note: note||'' })
    console.log(`[CREATE] ${key} plan=${plan}`)
})

app.post('/admin/revoke', (req, res) => {
    if (req.headers['x-admin-secret'] !== ADMIN_SECRET) return res.status(403).json({ error: 'forbidden' })
    const { key } = req.body
    const db = db_read()
    if (!db[key]) return res.status(404).json({ error: 'key not found' })
    db[key].revoked = true; db[key].last_ticket = null; db[key].last_ticket_exp = null
    db_write(db)
    res.json({ revoked: key })
    console.log(`[REVOKE] ${key}`)
})

app.post('/admin/reset_hwid', (req, res) => {
    if (req.headers['x-admin-secret'] !== ADMIN_SECRET) return res.status(403).json({ error: 'forbidden' })
    const { key } = req.body
    const db = db_read()
    if (!db[key]) return res.status(404).json({ error: 'key not found' })
    db[key].hwid = null; db[key].last_ticket = null; db[key].last_ticket_exp = null
    db_write(db)
    res.json({ reset: key })
    console.log(`[HWID_RESET] ${key}`)
})

app.get('/admin/list', (req, res) => {
    if (req.headers['x-admin-secret'] !== ADMIN_SECRET) return res.status(403).json({ error: 'forbidden' })
    const db = db_read(); const now = Date.now()
    res.json(Object.entries(db).map(([key, v]) => ({
        key, plan: v.plan, expires_at: v.expires_at,
        expired: v.expires_at ? now > v.expires_at : false,
        hwid_locked: !!v.hwid, revoked: !!v.revoked, note: v.note||''
    })))
})

app.get('/verify', (req, res) => {
    const { key, hwid } = req.query
    if (!key || !hwid) return res.json({ valid: false, reason: 'missing_params' })
    const db = db_read(); const license = db[key]
    if (!license)                                          return res.json({ valid: false, reason: 'invalid_key' })
    if (license.revoked)                                   return res.json({ valid: false, reason: 'revoked' })
    if (license.expires_at && Date.now()>license.expires_at) return res.json({ valid: false, reason: 'expired' })
    if (!license.hwid) { license.hwid = hwid }
    if (license.hwid !== hwid) { db_write(db); return res.json({ valid: false, reason: 'hwid_mismatch' }) }

    const nonce      = crypto.randomBytes(12).toString('hex')
    const ticket_exp = Date.now() + 20000  // 20 second window
    const ticket     = sign_ticket(key, hwid, license.plan, ticket_exp, nonce)
    license.last_ticket = ticket; license.last_ticket_exp = ticket_exp; license.last_nonce = nonce
    db_write(db)

    console.log(`[VERIFY OK] key=${key} plan=${license.plan}`)
    res.json({ valid: true, plan: license.plan, expires_at: license.expires_at, user: license.note||null, ticket, ticket_exp, nonce })
})

app.get('/script', (req, res) => {
    const { key, hwid, plan, ticket, nonce } = req.query
    if (!key||!hwid||!plan||!ticket||!nonce) return res.status(400).json({ ok: false, reason: 'missing_params' })
    const db = db_read(); const license = db[key]
    if (!license)                                               return res.status(404).json({ ok: false, reason: 'invalid_key' })
    if (license.revoked)                                        return res.status(403).json({ ok: false, reason: 'revoked' })
    if (license.expires_at && Date.now()>license.expires_at)   return res.status(403).json({ ok: false, reason: 'expired' })
    if (license.hwid !== hwid)                                  return res.status(403).json({ ok: false, reason: 'hwid_mismatch' })
    if (license.plan !== plan)                                  return res.status(403).json({ ok: false, reason: 'wrong_plan' })
    if (!license.last_ticket||!license.last_ticket_exp||!license.last_nonce) return res.status(403).json({ ok: false, reason: 'no_ticket' })
    if (Date.now() > license.last_ticket_exp)                   return res.status(403).json({ ok: false, reason: 'ticket_expired' })
    const expected = sign_ticket(key, hwid, plan, license.last_ticket_exp, license.last_nonce)
    if (ticket!==expected || nonce!==license.last_nonce || ticket!==license.last_ticket)
        return res.status(403).json({ ok: false, reason: 'bad_ticket' })

    const scriptPath = get_script_path(plan)
    if (!scriptPath || !fs.existsSync(scriptPath)) return res.status(500).json({ ok: false, reason: 'script_missing' })

    const raw    = fs.readFileSync(scriptPath, 'utf8')
    const prefix = [
        `rawset(_G, "_auth_ok",        true)`,
        `rawset(_G, "_auth_alive",      true)`,
        `rawset(_G, "_auth_ticket",     ${JSON.stringify(ticket)})`,
        `rawset(_G, "_auth_ticket_exp", ${license.last_ticket_exp})`,
        `rawset(_G, "_auth_nonce",      ${JSON.stringify(nonce)})`,
        `rawset(_G, "_auth_user",       ${JSON.stringify(license.note||"")})`,
        `rawset(_G, "BUILD_VERSION",    ${JSON.stringify(plan)})`,
    ].join('\n')

    // burn ticket — one-time use
    license.last_ticket = null; license.last_ticket_exp = null; license.last_nonce = null
    db_write(db)

    console.log(`[SCRIPT DELIVERED] key=${key} plan=${plan}`)
    res.type('text/plain').send(prefix + '\n\n' + raw)
})

app.listen(PORT, () => {
    console.log(`Zenith License Server on :${PORT}`)
})
