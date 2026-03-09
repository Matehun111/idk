-- ======================================================================
--  ZENITH | NIGHTLY | Cloud Loader  v1.0.0
--  Step 1 (first time): type your key  →  ZNNGT-XXXX-XXXX
--  Step 2: register username+password  →  register MyName MyPass
--  Next time: just type                →  login MyName MyPass
-- ======================================================================

local CLOUD_URL  = "https://raw.githubusercontent.com/Matehun111/idk/main/zenith_cloud_nightly.lua"
local LOADER_VER = "1.0.0"
local TIER       = "nightly"
local AUTH_VER   = 2
local DB_KEYS    = "zenith_nightly_keys_v2"
local DB_USERS   = "zenith_nightly_users_v2"
local DB_SESSION = "zenith_nightly_session_v2"

local VALID_KEYS = {
    ["ZNNGT-AAAA-3001"]={hwid=nil,note='slot 1'},
    ["ZNNGT-BBBB-3002"]={hwid=nil,note='slot 2'},
    ["ZNNGT-CCCC-3003"]={hwid=nil,note='slot 3'},
    ["ZNNGT-DDDD-3004"]={hwid=nil,note='slot 4'},
    ["ZNNGT-EEEE-3005"]={hwid=nil,note='slot 5'},
}

local http  = require "gamesense/http"
local _sf   = string.format
local _bxor = bit.bxor
local _band = bit.band
local _flr  = math.floor

local function clog(r,g,b,m) client.color_log(r,g,b,"[Zenith NIGHTLY] "..tostring(m)) end
local function info(m) clog(200,100,255,m) end
local function warn(m) clog(255,200,80,m) end
local function err(m)  clog(255,60,60,m)  end

local function get_hwid()
    local lp    = entity.get_local_player()
    local steam = lp and entity.get_steam64(lp) or "0"
    local raw   = "ZNHWID:"..tostring(steam)..":"..TIER..":v"..AUTH_VER
    local h = 5381
    for i = 1,#raw do h = _band(_bxor(h*33,string.byte(raw,i)),0xFFFFFFFF) end
    local hi = _band(_flr(h/0x10000),0xFFFF)
    local lo = _band(h,0xFFFF)
    return _sf("%04X%04X-%04X%04X",hi,lo,_bxor(hi,0xA5A5),_bxor(lo,0x5A5A))
end

local function db_read(k)
    local ok,r = pcall(database.read,k)
    return ok and type(r)=="table" and r or {}
end
local function db_write(k,v) pcall(database.write,k,v) end

local auth_ok   = false
local auth_user = nil
local auth_key  = nil

-- hash password simply (not crypto but better than plaintext)
local function hash_pw(pw)
    local h = 0xBEEF1234
    for i=1,#pw do
        h = _band(_bxor(h*31, string.byte(pw,i) + i*7), 0xFFFFFFFF)
    end
    return _sf("%08X", h)
end

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
        local fn, lerr = (rawget(_G,"load") or load)(body,"@zenith_nightly_cloud")
        if not fn then err("Compile error: "..tostring(lerr)); return end
        local ok2, rerr = pcall(fn)
        if not ok2 then err("Runtime error: "..tostring(rerr)); return end
        info("Zenith NIGHTLY running!")
    end)
end

-- ── KEY ACTIVATION (one-time) ───────────────────────────────────────
local function activate_key(key)
    key = (key or ""):match("^%s*(.-)%s*$")
    if key == "" then err("No key provided."); return false end
    local entry = VALID_KEYS[key]
    if not entry then err("Invalid key."); return false end
    local hwid = get_hwid()
    local db   = db_read(DB_KEYS)
    local saved = db[key]
    if saved and saved.hwid and saved.hwid ~= "" then
        if saved.hwid ~= hwid then err("Key is locked to another machine."); return false end
        info("Key already activated on this machine.")
    else
        db[key] = {hwid=hwid, note=entry.note}
        db_write(DB_KEYS, db)
        info("Key activated! Now register: register YourName YourPassword")
    end
    auth_key = key
    return true
end

local function key_valid_for_hwid(key)
    if not VALID_KEYS[key] then return false end
    local hwid = get_hwid()
    local db = db_read(DB_KEYS)
    local saved = db[key]
    return saved and saved.hwid == hwid
end

-- ── REGISTER ────────────────────────────────────────────────────────
local function cmd_register(name, pw)
    if not name or not pw then
        err("Usage: register YourName YourPassword"); return
    end
    if #name < 2 then err("Username too short (min 2 chars)."); return end
    if #pw < 4   then err("Password too short (min 4 chars)."); return end
    -- need an activated key first
    if not auth_key then
        err("Activate your key first: ZNNGT-XXXX-XXXX"); return
    end
    if not key_valid_for_hwid(auth_key) then
        err("Key not valid for this machine."); return
    end
    local users = db_read(DB_USERS)
    local name_lower = name:lower()
    if users[name_lower] then
        err("Username '"..name.."' already taken."); return
    end
    -- check key not already used for another account
    for _, u in pairs(users) do
        if u.key == auth_key then
            err("This key is already registered to account '"..u.display_name.."'."); return
        end
    end
    local hwid = get_hwid()
    users[name_lower] = {
        display_name = name,
        pw_hash      = hash_pw(pw),
        key          = auth_key,
        hwid         = hwid,
    }
    db_write(DB_USERS, users)
    -- save session
    db_write(DB_SESSION, {user=name_lower, pw_hash=hash_pw(pw), hwid=hwid, v=AUTH_VER})
    auth_ok   = true
    auth_user = name
    info("Registered as '"..name.."'! Welcome to Zenith.")
    client.delay_call(0.1, load_cloud)
end

-- ── LOGIN ────────────────────────────────────────────────────────────
local function cmd_login(name, pw)
    if not name or not pw then
        err("Usage: login YourName YourPassword"); return
    end
    local users = db_read(DB_USERS)
    local name_lower = name:lower()
    local u = users[name_lower]
    if not u then err("Account '"..name.."' not found."); return end
    if u.pw_hash ~= hash_pw(pw) then err("Wrong password."); return end
    local hwid = get_hwid()
    if u.hwid ~= hwid then err("Account locked to another machine."); return end
    if not key_valid_for_hwid(u.key) then err("Key not valid."); return end
    -- save session
    db_write(DB_SESSION, {user=name_lower, pw_hash=hash_pw(pw), hwid=hwid, v=AUTH_VER})
    auth_ok   = true
    auth_user = u.display_name
    info("Logged in as '"..u.display_name.."'!")
    client.delay_call(0.1, load_cloud)
end

-- ── SESSION RESTORE ──────────────────────────────────────────────────
local function try_restore()
    local hwid = get_hwid()
    local sess = db_read(DB_SESSION)
    if not (sess and sess.v==AUTH_VER and sess.user and sess.hwid==hwid) then return false end
    local users = db_read(DB_USERS)
    local u = users[sess.user]
    if not u then db_write(DB_SESSION,nil); return false end
    if u.pw_hash ~= sess.pw_hash then db_write(DB_SESSION,nil); return false end
    if u.hwid ~= hwid then db_write(DB_SESSION,nil); return false end
    if not key_valid_for_hwid(u.key) then db_write(DB_SESSION,nil); return false end
    auth_ok   = true
    auth_user = u.display_name
    auth_key  = u.key
    info("Session restored: "..u.display_name)
    return true
end

-- ── CONSOLE HANDLER ─────────────────────────────────────────────────
client.set_event_callback("console_input", function(cmd)
    local t = cmd:match("^%s*(.-)%s*$")

    -- Key activation
    if t:match("^ZNNGT%-") then
        activate_key(t); return true
    end

    -- register NAME PASS
    local rname, rpw = t:match("^register%s+(%S+)%s+(%S+)$")
    if rname then cmd_register(rname, rpw); return true end

    -- login NAME PASS
    local lname, lpw = t:match("^login%s+(%S+)%s+(%S+)$")
    if lname then cmd_login(lname, lpw); return true end

    -- logout
    if t == "zn_logout" then
        db_write(DB_SESSION,nil); auth_ok=false; auth_user=nil; auth_key=nil
        warn("Logged out."); return true
    end

    if t == "zn_hwid" then info("HWID: "..get_hwid()); return true end
end)

-- ── STARTUP ──────────────────────────────────────────────────────────
if try_restore() then
    client.delay_call(0.5, load_cloud)
else
    info("Type your key to activate: ZNNGT-XXXX-XXXX")
    info("Then: register YourName YourPassword")
    info("Next time: login YourName YourPassword")
end
info("Loader v"..LOADER_VER.." ready.")
