-- ======================================================================
--  ZENITH | BETA | Cloud Loader  v2.0.0
--  In-menu UI: Register with username+password, key activates tier.
--  After first register, auto-restores session every load.
-- ======================================================================

local CLOUD_URL  = "https://raw.githubusercontent.com/Matehun111/idk/main/zenith_cloud_beta.lua"
local TIER       = "beta"
local AUTH_VER   = 2
local DB_KEYS    = "zenith_beta_keys_v2"
local DB_USERS   = "zenith_beta_users_v2"
local DB_SESSION = "zenith_beta_session_v2"

local VALID_KEYS = {
    ["ZNNGT-AAAA-3001"] = { note = "slot 1" },
    ["ZNNGT-BBBB-3002"] = { note = "slot 2" },
    ["ZNNGT-CCCC-3003"] = { note = "slot 3" },
    ["ZNNGT-DDDD-3004"] = { note = "slot 4" },
    ["ZNNGT-EEEE-3005"] = { note = "slot 5" },
}

-- ── LIBS ──────────────────────────────────────────────────────────────
local http  = require "gamesense/http"
local pui   = require "gamesense/pui"
local _sf   = string.format
local _bxor = bit.bxor
local _band = bit.band
local _flr  = math.floor

if not LPH_OBFUSCATED then LPH_NO_VIRTUALIZE = function(...) return ... end end

-- ── HELPERS ───────────────────────────────────────────────────────────
local function clog(r,g,b,m) client.color_log(r,g,b,"[Zenith BETA] "..tostring(m)) end
local function info(m) clog(195,130,255,m) end
local function warn(m) clog(255,200,80,m) end
local function err(m)  clog(255,60,60,m)  end

local function get_hwid()
    local lp    = entity.get_local_player()
    local steam = lp and entity.get_steam64(lp) or "0"
    local raw   = "ZNHWID:"..tostring(steam)..":beta:v"..AUTH_VER
    local h = 5381
    for i=1,#raw do h = _band(_bxor(h*33,string.byte(raw,i)),0xFFFFFFFF) end
    local hi = _band(_flr(h/0x10000),0xFFFF)
    local lo = _band(h,0xFFFF)
    return _sf("%04X%04X-%04X%04X",hi,lo,_bxor(hi,0xA5A5),_bxor(lo,0x5A5A))
end

local function hash_pw(pw)
    local h = 0xBEEF1337
    for i=1,#pw do h = _band(_bxor(h*31, string.byte(pw,i)+i*13), 0xFFFFFFFF) end
    return _sf("%08X", h)
end

local function db_read(k)
    local ok,r = pcall(database.read,k)
    return ok and type(r)=="table" and r or {}
end
local function db_write(k,v) pcall(database.write,k,v) end

-- ── AUTH STATE ────────────────────────────────────────────────────────
local auth_ok   = false
local auth_user = nil  -- display name
local auth_key  = nil

-- ── STATUS ────────────────────────────────────────────────────────────
local status_msg = "Enter key, then Register or Login."
local status_r, status_g, status_b = 160,160,200

local function set_status(r,g,b,msg)
    status_r,status_g,status_b = r,g,b
    status_msg = msg
end

-- ── CLOUD LOAD ────────────────────────────────────────────────────────
local function load_cloud()
    info("Fetching cloud script...")
    http.get(CLOUD_URL, function(success, response)
        if not success then err("HTTP failed."); return end
        local body = type(response)=="table" and response.body or response
        if not body or #body < 100 then err("Empty response."); return end
        info("Downloaded "..#body.." bytes, executing...")
        rawset(_G,"_auth_ok",      true)
        rawset(_G,"_auth_alive",   true)
        rawset(_G,"_auth_user",    auth_user)
        rawset(_G,"BUILD_VERSION", TIER)
        local fn, lerr = (rawget(_G,"load") or load)(body,"@zenith_beta_cloud")
        if not fn then err("Compile error: "..tostring(lerr)); return end
        local ok2,rerr = pcall(fn)
        if not ok2 then err("Runtime error: "..tostring(rerr)); return end
        info("Zenith BETA running!")
        -- Hide loader UI
        pcall(function() _vis_cb:set(false) end)
        rawset(_G, "_zenith_loader_loaded", true)
    end)
end

-- ── KEY CHECK ─────────────────────────────────────────────────────────
local function key_ok(key)
    if not VALID_KEYS[key] then return false end
    local hwid = get_hwid()
    local db   = db_read(DB_KEYS)
    local saved = db[key]
    if saved and saved.hwid and saved.hwid ~= "" then
        return saved.hwid == hwid
    end
    -- First use: lock to this HWID
    db[key] = { hwid=hwid, note=VALID_KEYS[key].note }
    db_write(DB_KEYS, db)
    return true
end

-- ── REGISTER ──────────────────────────────────────────────────────────
local function do_register(key, name, pw)
    key  = (key  or ""):match("^%s*(.-)%s*$")
    name = (name or ""):match("^%s*(.-)%s*$")
    pw   = (pw   or ""):match("^%s*(.-)%s*$")

    if key  == "" then set_status(255,120,50,"Enter your license key."); return end
    if name == "" then set_status(255,120,50,"Enter a username."); return end
    if pw   == "" then set_status(255,120,50,"Enter a password."); return end
    if #name < 2  then set_status(255,120,50,"Username too short (min 2)."); return end
    if #pw   < 4  then set_status(255,120,50,"Password too short (min 4)."); return end

    if not VALID_KEYS[key] then
        set_status(255,60,60,"Invalid key. Check prefix: ZNBET-XXXX-XXXX"); return
    end
    if not key_ok(key) then
        set_status(255,60,60,"Key is locked to another machine."); return
    end

    local users = db_read(DB_USERS)
    local nl = name:lower()

    if users[nl] then
        set_status(255,60,60,"Username '"..name.."' is already taken."); return
    end
    for _,u in pairs(users) do
        if u.key == key then
            set_status(255,60,60,"Key already registered to '"..u.display_name.."'."); return
        end
    end

    local hwid = get_hwid()
    users[nl] = { display_name=name, pw_hash=hash_pw(pw), key=key, hwid=hwid }
    db_write(DB_USERS, users)
    db_write(DB_SESSION, { user=nl, pw_hash=hash_pw(pw), hwid=hwid, v=AUTH_VER })

    auth_ok   = true
    auth_user = name
    auth_key  = key
    set_status(100,255,160,"Registered as '"..name.."'! Loading Zenith...")
    info("Registered: "..name)
    client.delay_call(0.5, load_cloud)
end

-- ── LOGIN ─────────────────────────────────────────────────────────────
local function do_login(name, pw)
    name = (name or ""):match("^%s*(.-)%s*$")
    pw   = (pw   or ""):match("^%s*(.-)%s*$")

    if name == "" then set_status(255,120,50,"Enter your username."); return end
    if pw   == "" then set_status(255,120,50,"Enter your password."); return end

    local users = db_read(DB_USERS)
    local nl = name:lower()
    local u  = users[nl]

    if not u then set_status(255,60,60,"Account '"..name.."' not found."); return end
    if u.pw_hash ~= hash_pw(pw) then set_status(255,60,60,"Wrong password."); return end

    local hwid = get_hwid()
    if u.hwid ~= hwid then set_status(255,60,60,"Account locked to another machine."); return end
    if not key_ok(u.key) then set_status(255,60,60,"Your key is no longer valid."); return end

    db_write(DB_SESSION, { user=nl, pw_hash=hash_pw(pw), hwid=hwid, v=AUTH_VER })
    auth_ok   = true
    auth_user = u.display_name
    auth_key  = u.key
    set_status(100,255,160,"Welcome back, '"..u.display_name.."'! Loading...")
    info("Logged in: "..u.display_name)
    client.delay_call(0.5, load_cloud)
end

-- ── SESSION RESTORE ───────────────────────────────────────────────────
local function try_restore()
    local hwid = get_hwid()
    local sess = db_read(DB_SESSION)
    if not (sess.v==AUTH_VER and sess.user and sess.hwid==hwid) then return false end
    local users = db_read(DB_USERS)
    local u = users[sess.user]
    if not u then db_write(DB_SESSION,nil); return false end
    if u.pw_hash ~= sess.pw_hash then db_write(DB_SESSION,nil); return false end
    if u.hwid ~= hwid then db_write(DB_SESSION,nil); return false end
    if not key_ok(u.key) then db_write(DB_SESSION,nil); return false end
    auth_ok   = true
    auth_user = u.display_name
    auth_key  = u.key
    set_status(150,200,255,"Session restored: "..u.display_name)
    info("Session restored: "..u.display_name)
    return true
end

-- ── PUI MENU ──────────────────────────────────────────────────────────
local grp_fl  = pui.group('AA','Fake lag')
local grp_aa  = pui.group('AA','Anti-aimbot angles')
local grp_oth = pui.group('AA','Other')
pui.macros.dot = '\v•  \r'

-- Visibility gate: uncheck this to hide all loader UI
local _vis_cb = grp_aa:checkbox('\n__zn_loader_visible__')
_vis_cb:set(true)

-- Fake lag column: branding
grp_fl:label('         Z  E  N  I  T  H')
    :depend(_vis_cb)
grp_fl:label('\f<dot>\ac8c8c8ffBETA  —  Authentication')
    :depend(_vis_cb)
grp_fl:label(' ')
    :depend(_vis_cb)

local fl_user   = grp_fl:label('\f<dot>User:   \ac8c8c8ff—')
    :depend(_vis_cb)
local fl_status = grp_fl:label('\f<dot>Auth:   \aff6060ff✗ Not logged in')
    :depend(_vis_cb)
local fl_tier   = grp_fl:label('\f<dot>Tier:   \ac8c8c8ffBETA')
    :depend(_vis_cb)
grp_fl:label(' ')
    :depend(_vis_cb)
grp_fl:label('\f<dot>\ac8c8c8ffHWID: (console: zn_hwid)')
    :depend(_vis_cb)
grp_fl:label('\f<dot>\ac8c8c8ffLogout: zn_logout')
    :depend(_vis_cb)

-- Main column: auth form
grp_aa:label('\f<dot>License Key:')
    :depend(_vis_cb)
local inp_key  = grp_aa:textbox('\nKey',  '', false)
    :depend(_vis_cb)
grp_aa:label('\f<dot>Username:')
    :depend(_vis_cb)
local inp_name = grp_aa:textbox('\nUsername', '', false)
    :depend(_vis_cb)
grp_aa:label('\f<dot>Password:')
    :depend(_vis_cb)
local inp_pw   = grp_aa:textbox('\nPassword', '', false)
    :depend(_vis_cb)
grp_aa:label(' ')
    :depend(_vis_cb)

local btn_register = grp_aa:button('Register')
    :depend(_vis_cb)
local btn_login    = grp_aa:button('Login')
    :depend(_vis_cb)
local btn_logout   = grp_aa:button('Logout')
    :depend(_vis_cb)

grp_aa:label(' ')
    :depend(_vis_cb)
local lbl_status = grp_aa:label('\f<dot>\ac8c8c8ffEnter key, then Register or Login.')
    :depend(_vis_cb)

-- Other column: info
grp_oth:label('\f<dot>How to use:')
    :depend(_vis_cb)
grp_oth:label('\f<dot>\ac8c8c8ff1. Enter your key')
    :depend(_vis_cb)
grp_oth:label('\f<dot>\ac8c8c8ff   (ZNBET-XXXX-XXXX)')
    :depend(_vis_cb)
grp_oth:label('\f<dot>\ac8c8c8ff2. Enter a username')
    :depend(_vis_cb)
grp_oth:label('\f<dot>\ac8c8c8ff3. Enter a password')
    :depend(_vis_cb)
grp_oth:label('\f<dot>\ac8c8c8ff4. Click Register')
    :depend(_vis_cb)
grp_oth:label(' ')
    :depend(_vis_cb)
grp_oth:label('\f<dot>\ac8c8c8ffNext time: just Login')
    :depend(_vis_cb)
grp_oth:label('\f<dot>\ac8c8c8ffor it auto-restores.')
    :depend(_vis_cb)
grp_oth:label(' ')
    :depend(_vis_cb)
grp_oth:label('\f<dot>\ac8c8c8ffKey slots: 5 (Nightly)')
    :depend(_vis_cb)
grp_oth:label('\f<dot>\ac8c8c8ffHWID locked on first use.')
    :depend(_vis_cb)

-- Button callbacks
btn_register:set_callback(function()
    do_register(inp_key:get(), inp_name:get(), inp_pw:get())
end)

btn_login:set_callback(function()
    do_login(inp_name:get(), inp_pw:get())
end)

btn_logout:set_callback(function()
    db_write(DB_SESSION,nil)
    auth_ok=false; auth_user=nil; auth_key=nil
    set_status(160,160,200,"Logged out.")
    warn("Logged out.")
end)

-- Live UI updates
client.set_event_callback('paint_ui', function()
    lbl_status:set('\f<dot>\a'.._sf('%02x%02x%02xff',status_r,status_g,status_b)..status_msg)
    if auth_ok and auth_user then
        fl_user:set('\f<dot>User:   \ac8ffbcff'..auth_user)
        fl_status:set('\f<dot>Auth:   \a60ff90ff✓ Logged in')
    else
        fl_user:set('\f<dot>User:   \ac8c8c8ff—')
        fl_status:set('\f<dot>Auth:   \aff6060ff✗ Not logged in')
    end
    pcall(function() btn_logout:set_enabled(auth_ok) end)
    pcall(function() btn_login:set_enabled(not auth_ok) end)
    pcall(function() btn_register:set_enabled(not auth_ok) end)
end)

-- ── CONSOLE FALLBACK ──────────────────────────────────────────────────
client.set_event_callback("console_input", function(cmd)
    local t = cmd:match("^%s*(.-)%s*$")
    if t=="zn_logout" then
        db_write(DB_SESSION,nil); auth_ok=false; auth_user=nil; auth_key=nil
        set_status(160,160,200,"Logged out."); warn("Logged out."); return true
    end
    if t=="zn_hwid" then info("HWID: "..get_hwid()); return true end
end)

-- ── STARTUP ───────────────────────────────────────────────────────────
if try_restore() then
    client.delay_call(0.5, load_cloud)
end
info("Loader v2.0.0 ready.")
