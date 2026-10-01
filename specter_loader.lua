-- ======================================================================
--  SPECTER | Cloud Loader  v2.0.0
--  Auth: username + password + HWID (local gamesense database)
--  Keys synced automatically from GitHub (Discord bot manages them)
--  Cloud script fetched from GitHub on successful auth
-- ======================================================================

local TIER       = "beta"
local AUTH_VER   = 2
local DB_KEYS    = "specter_keys_v2"
local DB_USERS   = "specter_users_v2"
local DB_SESSION = "specter_session_v2"

-- ── LIBS ─────────────────────────────────────────────────────────────
local http  = require "gamesense/http"
local json  = require "json"
local pui   = require "gamesense/pui"
local _sf   = string.format
local _bxor = bit.bxor
local _band = bit.band
local _flr  = math.floor

if not LPH_OBFUSCATED then LPH_NO_VIRTUALIZE = function(...) return ... end end

-- ── HELPERS ──────────────────────────────────────────────────────────
local function clog(r,g,b,m) client.color_log(r,g,b,"[Specter] "..tostring(m)) end
local function info(m) clog(130,195,255,m) end
local function warn(m) clog(255,200,80,m) end
local function err(m)  clog(255,60,60,m)  end

local function get_hwid()
    local lp    = entity.get_local_player()
    local steam = lp and entity.get_steam64(lp) or "0"
    local raw   = "SPEC_HWID:"..tostring(steam)..":v"..AUTH_VER
    local h = 5381
    for i=1,#raw do h = _band(_bxor(h*33,string.byte(raw,i)),0xFFFFFFFF) end
    local hi = _band(_flr(h/0x10000),0xFFFF)
    local lo = _band(h,0xFFFF)
    return _sf("%04X%04X-%04X%04X",hi,lo,_bxor(hi,0xA5A5),_bxor(lo,0x5A5A))
end

local function hash_pw(pw)
    local h = 0xDEAD1337
    for i=1,#pw do h = _band(_bxor(h*31, string.byte(pw,i)+i*13), 0xFFFFFFFF) end
    return _sf("%08X", h)
end

local function db_read(k)
    local ok,r = pcall(database.read,k)
    return ok and type(r)=="table" and r or {}
end
local function db_write(k,v) pcall(database.write,k,v) end

-- ── REMOTE KEYS (fetched from GitHub) ────────────────────────────────
local VALID_KEYS   = {}
local keys_loaded  = false
local keys_loading = false

local function fetch_keys(callback)
    if keys_loading then return end
    keys_loading = true
    local url = LPH_ENCSTR("https://raw.githubusercontent.com/Matehun111/idk/main/specter_keys.json")
    http.get(url, function(success, response)
        keys_loading = false
        if not success then
            err("Failed to fetch keys.")
            return
        end
        local body = type(response)=="table" and response.body or response
        if not body or #body < 2 then
            err("Empty key list.")
            return
        end
        local ok, parsed = pcall(json.parse, body)
        if not ok or type(parsed) ~= "table" then
            err("Invalid key data.")
            return
        end
        VALID_KEYS  = parsed
        keys_loaded = true
        info("Keys synced.")
        if callback then callback() end
    end)
end

-- ── PLAN HELPER ─────────────────────────────────────────────────────
local VALID_PLAN_SET = { debug=true, specter=true, nightly=true, beta=true }
local function key_plan(key)
    local v = VALID_KEYS[key]
    if type(v) == "table" and type(v.plan) == "string" and VALID_PLAN_SET[v.plan] then
        return v.plan
    end
    return TIER
end

-- ── AUTH STATE ───────────────────────────────────────────────────────
local auth_ok   = false
local auth_user = nil
local auth_key  = nil
local auth_plan = nil

-- ── STATUS ───────────────────────────────────────────────────────────
local status_msg = "Loading keys..."
local status_r, status_g, status_b = 160,160,200

local function set_status(r,g,b,msg)
    status_r,status_g,status_b = r,g,b
    status_msg = msg
end

-- ── CLOUD LOAD ───────────────────────────────────────────────────────
local function load_cloud()
    info("Loading script...")
    local url = LPH_ENCSTR("https://raw.githubusercontent.com/Matehun111/idk/main/specter_cloud.lua")
    http.get(url, function(success, response)
        if not success then err("Connection failed."); return end
        local body = type(response)=="table" and response.body or response
        if not body or #body < 100 then err("Invalid response."); return end
        info("Loaded "..#body.." bytes, starting...")
        rawset(_G,"_auth_ok",      true)
        rawset(_G,"_auth_alive",   true)
        rawset(_G,"_auth_ts",      os.time())
        rawset(_G,"_auth_user",    auth_user)
        rawset(_G,"_auth_key",     auth_key)
        rawset(_G,"_auth_hwid",    get_hwid())
        rawset(_G,"BUILD_VERSION", auth_plan or TIER)
        local fn, lerr = (rawget(_G,"load") or load)(body,"@specter_cloud")
        if not fn then err("Load error: "..tostring(lerr)); return end
        local ok2,rerr = pcall(fn)
        if not ok2 then err("Runtime error: "..tostring(rerr)); return end
        info("Specter loaded successfully!")
        rawset(_G, "_specter_loader_loaded", true)
    end)
end

-- ── KEY CHECK ────────────────────────────────────────────────────────
local function key_ok(key)
    if not VALID_KEYS[key] then return false end
    local hwid = get_hwid()
    local db   = db_read(DB_KEYS)
    local saved = db[key]
    if saved and saved.hwid and saved.hwid ~= "" then
        return saved.hwid == hwid
    end
    local note = ""
    if type(VALID_KEYS[key]) == "table" then
        note = VALID_KEYS[key].note or ""
    end
    db[key] = { hwid=hwid, note=note }
    db_write(DB_KEYS, db)
    return true
end

-- ── REGISTER ─────────────────────────────────────────────────────────
local function do_register(key, name, pw)
    key  = (key  or ""):match("^%s*(.-)%s*$")
    name = (name or ""):match("^%s*(.-)%s*$")
    pw   = (pw   or ""):match("^%s*(.-)%s*$")

    if not keys_loaded then set_status(255,120,50,"Keys still loading, wait..."); return end
    if key  == "" then set_status(255,120,50,"Enter your license key."); return end
    if name == "" then set_status(255,120,50,"Enter a username."); return end
    if pw   == "" then set_status(255,120,50,"Enter a password."); return end
    if #name < 2  then set_status(255,120,50,"Username too short (min 2)."); return end
    if #pw   < 4  then set_status(255,120,50,"Password too short (min 4)."); return end

    if not VALID_KEYS[key] then
        set_status(255,60,60,"Invalid key."); return
    end
    if not key_ok(key) then
        set_status(255,60,60,"Key is locked to another machine."); return
    end

    local users = db_read(DB_USERS)
    local nl = name:lower()

    if users[nl] then
        set_status(255,60,60,"Username '"..name.."' already taken."); return
    end
    for _,u in pairs(users) do
        if u.key == key then
            set_status(255,60,60,"Key already registered to '"..u.display_name.."'."); return
        end
    end

    local hwid = get_hwid()
    local plan = key_plan(key)
    users[nl] = { display_name=name, pw_hash=hash_pw(pw), key=key, hwid=hwid, plan=plan }
    db_write(DB_USERS, users)
    db_write(DB_SESSION, { user=nl, pw_hash=hash_pw(pw), hwid=hwid, plan=plan, v=AUTH_VER })

    auth_ok   = true
    auth_user = name
    auth_key  = key
    auth_plan = plan
    set_status(100,255,160,"Registered as '"..name.."'! Loading ["..plan.."]...")
    info("Registered: "..name.." (plan: "..plan..")")
    client.delay_call(0.5, load_cloud)
end

-- ── LOGIN ────────────────────────────────────────────────────────────
local function do_login(name, pw)
    name = (name or ""):match("^%s*(.-)%s*$")
    pw   = (pw   or ""):match("^%s*(.-)%s*$")

    if not keys_loaded then set_status(255,120,50,"Keys still loading, wait..."); return end
    if name == "" then set_status(255,120,50,"Enter your username."); return end
    if pw   == "" then set_status(255,120,50,"Enter your password."); return end

    local users = db_read(DB_USERS)
    local nl = name:lower()
    local u  = users[nl]

    if not u then set_status(255,60,60,"Account '"..name.."' not found."); return end
    if u.pw_hash ~= hash_pw(pw) then set_status(255,60,60,"Wrong password."); return end

    local hwid = get_hwid()
    if u.hwid ~= hwid then set_status(255,60,60,"Account locked to another machine."); return end
    if not key_ok(u.key) then set_status(255,60,60,"Key is no longer valid."); return end

    local plan = u.plan or key_plan(u.key)
    db_write(DB_SESSION, { user=nl, pw_hash=hash_pw(pw), hwid=hwid, plan=plan, v=AUTH_VER })
    auth_ok   = true
    auth_user = u.display_name
    auth_key  = u.key
    auth_plan = plan
    set_status(100,255,160,"Welcome back, '"..u.display_name.."'! Loading ["..plan.."]...")
    info("Logged in: "..u.display_name.." (plan: "..plan..")")
    client.delay_call(0.5, load_cloud)
end

-- ── SESSION RESTORE ──────────────────────────────────────────────────
local function try_restore()
    if not keys_loaded then return false end
    local hwid = get_hwid()
    local sess = db_read(DB_SESSION)
    if not (sess.v==AUTH_VER and sess.user and sess.hwid==hwid) then return false end
    local users = db_read(DB_USERS)
    local u = users[sess.user]
    if not u then db_write(DB_SESSION,nil); return false end
    if u.pw_hash ~= sess.pw_hash then db_write(DB_SESSION,nil); return false end
    if u.hwid ~= hwid then db_write(DB_SESSION,nil); return false end
    if not key_ok(u.key) then db_write(DB_SESSION,nil); return false end
    local plan = sess.plan or u.plan or key_plan(u.key)
    auth_ok   = true
    auth_user = u.display_name
    auth_key  = u.key
    auth_plan = plan
    set_status(150,200,255,"Session restored: "..u.display_name.." ["..plan.."]")
    info("Session restored: "..u.display_name.." (plan: "..plan..")")
    return true
end

-- ── PUI MENU ─────────────────────────────────────────────────────────
local grp_fl  = pui.group('AA','Fake lag')
local grp_aa  = pui.group('AA','Anti-aimbot angles')
local grp_oth = pui.group('AA','Other')
pui.macros.dot = '\v•  \r'

grp_fl:label('      S  P  E  C  T  E  R')
grp_fl:label('\f<dot>\ac8c8c8ffAuthentication')
grp_fl:label(' ')

local fl_user   = grp_fl:label('\f<dot>User:   \ac8c8c8ff—')
local fl_status = grp_fl:label('\f<dot>Auth:   \aff6060ff✗ Not logged in')
local fl_plan   = grp_fl:label('\f<dot>Plan:   \ac8c8c8ff—')
local fl_keys   = grp_fl:label('\f<dot>Keys:   \affc850ffLoading...')
grp_fl:label(' ')
grp_fl:label('\f<dot>\ac8c8c8ffspec_hwid  spec_plan  spec_logout')

grp_aa:label('\f<dot>License Key:')
local inp_key  = grp_aa:textbox('\nKey',  '', false)
grp_aa:label('\f<dot>Username:')
local inp_name = grp_aa:textbox('\nUsername', '', false)
grp_aa:label('\f<dot>Password:')
local inp_pw   = grp_aa:textbox('\nPassword', '', false)
grp_aa:label(' ')

local btn_register = grp_aa:button('Register')
local btn_login    = grp_aa:button('Login')
local btn_logout   = grp_aa:button('Logout')
local btn_refresh  = grp_aa:button('Refresh Keys')

grp_aa:label(' ')
local lbl_status = grp_aa:label('\f<dot>\affc850ffLoading keys...')

grp_oth:label('\f<dot>How to use:')
grp_oth:label('\f<dot>\ac8c8c8ff1. Get key from Discord')
grp_oth:label('\f<dot>\ac8c8c8ff   (/redeem command)')
grp_oth:label('\f<dot>\ac8c8c8ff2. Enter a username')
grp_oth:label('\f<dot>\ac8c8c8ff3. Enter a password')
grp_oth:label('\f<dot>\ac8c8c8ff4. Click Register')
grp_oth:label(' ')
grp_oth:label('\f<dot>\ac8c8c8ffNext time: just Login')
grp_oth:label('\f<dot>\ac8c8c8ffor it auto-restores.')
grp_oth:label(' ')
grp_oth:label('\f<dot>\ac8c8c8ffHWID locked on first use.')
grp_oth:label(' ')
grp_oth:label('\f<dot>\ac8c8c8ffPlans: debug > specter > nightly > beta')

btn_register:set_callback(function()
    do_register(inp_key:get(), inp_name:get(), inp_pw:get())
end)

btn_login:set_callback(function()
    do_login(inp_name:get(), inp_pw:get())
end)

btn_logout:set_callback(function()
    db_write(DB_SESSION,nil)
    auth_ok=false; auth_user=nil; auth_key=nil; auth_plan=nil
    set_status(160,160,200,"Logged out.")
    warn("Logged out.")
end)

btn_refresh:set_callback(function()
    set_status(255,200,80,"Refreshing keys...")
    fetch_keys(function()
        set_status(100,255,160,"Keys refreshed!")
    end)
end)

client.set_event_callback('paint_ui', function()
    lbl_status:set('\f<dot>\a'.._sf('%02x%02x%02xff',status_r,status_g,status_b)..status_msg)
    if auth_ok and auth_user then
        fl_user:set('\f<dot>User:   \a82c3ffff'..auth_user)
        fl_status:set('\f<dot>Auth:   \a60ff90ff✓ Logged in')
        local plan_colors = { debug='\aff5050ff', specter='\a82c3ffff', nightly='\aff82a0ff', beta='\ac882ffff' }
        fl_plan:set('\f<dot>Plan:   '..(plan_colors[auth_plan] or '\ac8c8c8ff')..(auth_plan or '—'))
    else
        fl_user:set('\f<dot>User:   \ac8c8c8ff—')
        fl_status:set('\f<dot>Auth:   \aff6060ff✗ Not logged in')
        fl_plan:set('\f<dot>Plan:   \ac8c8c8ff—')
    end
    if keys_loaded then
        local count = 0
        for _ in pairs(VALID_KEYS) do count = count + 1 end
        fl_keys:set('\f<dot>Keys:   \a60ff90ff'..count..' loaded')
    else
        fl_keys:set('\f<dot>Keys:   \affc850ffLoading...')
    end
    pcall(function() btn_logout:set_enabled(auth_ok) end)
    pcall(function() btn_login:set_enabled(not auth_ok and keys_loaded) end)
    pcall(function() btn_register:set_enabled(not auth_ok and keys_loaded) end)
end)

-- ── CONSOLE COMMANDS ─────────────────────────────────────────────────
client.set_event_callback("console_input", function(cmd)
    local t = cmd:match("^%s*(.-)%s*$")
    if t=="spec_logout" then
        db_write(DB_SESSION,nil); auth_ok=false; auth_user=nil; auth_key=nil; auth_plan=nil
        set_status(160,160,200,"Logged out."); warn("Logged out."); return true
    end
    if t=="spec_hwid" then info("HWID: "..get_hwid()); return true end
    if t=="spec_plan" then info("Plan: "..(auth_plan or "none")); return true end
    if t=="spec_refresh" then
        fetch_keys(function() info("Keys refreshed.") end); return true
    end
end)

-- ── STARTUP ──────────────────────────────────────────────────────────
fetch_keys(function()
    set_status(160,160,200,"Enter key, then Register or Login.")
    if try_restore() then
        client.delay_call(0.5, load_cloud)
    end
end)
info("Loader v2.0.0 ready.")
