-- ======================================================================
--  ZENITH | BETA | Cloud Loader  v3.0.0
--  Real license backend: API key verification + HWID lock + expiry
-- ======================================================================

local API_URL    = "https://idk-production-9969.up.railway.app"   -- << change this
local CLOUD_URL  = "https://raw.githubusercontent.com/Matehun111/idk/main/zenith_cloud_beta.lua"
local TIER       = "beta"
local AUTH_VER   = 3
local DB_SESSION = "zenith_beta_session_v3"

-- ── LIBS ─────────────────────────────────────────────────────────────────
local http  = require "gamesense/http"
local pui   = require "gamesense/pui"
local _sf   = string.format
local _bxor = bit.bxor
local _band = bit.band
local _flr  = math.floor

if not LPH_OBFUSCATED then LPH_NO_VIRTUALIZE = function(...) return ... end end

-- ── HELPERS ──────────────────────────────────────────────────────────────
local function clog(r,g,b,m) client.color_log(r,g,b,"[zenith.gs BETA] "..tostring(m)) end
local function info(m) clog(113,152,255,m) end
local function warn(m) clog(255,200,80,m)  end
local function err(m)  clog(255,60,60,m)   end

local function get_hwid()
    local steam = "0"
    local ok, pan = pcall(panorama.open)
    if ok and pan then
        local ok2, xuid = pcall(function() return tostring(pan.MyPersonaAPI.GetXuid()) end)
        if ok2 and xuid and xuid ~= "0" then steam = xuid end
    end
    if steam == "0" then
        local lp = entity.get_local_player()
        if lp then local s = entity.get_steam64(lp); if s then steam = tostring(s) end end
    end
    local raw = "ZNHWID:"..steam..":beta:v"..AUTH_VER
    local h = 5381
    for i=1,#raw do h = _band(_bxor(h*33,string.byte(raw,i)),0xFFFFFFFF) end
    local hi = _band(_flr(h/0x10000),0xFFFF)
    local lo = _band(h,0xFFFF)
    return _sf("%04X%04X-%04X%04X",hi,lo,_bxor(hi,0xA5A5),_bxor(lo,0x5A5A))
end

local function db_read(k)
    local ok,r = pcall(database.read,k)
    return ok and type(r)=="table" and r or {}
end
local function db_write(k,v) pcall(database.write,k,v) end

-- ── AUTH STATE ───────────────────────────────────────────────────────────
local auth_ok   = false
local auth_user = nil
local auth_key  = nil
local auth_plan = nil
local auth_exp  = nil

-- ── STATUS ───────────────────────────────────────────────────────────────
local status_msg = "Enter your license key and username, then click Login."
local status_r, status_g, status_b = 160, 160, 200

local function set_status(r,g,b,msg)
    status_r,status_g,status_b = r,g,b
    status_msg = msg
end

-- ── CLOUD LOAD ───────────────────────────────────────────────────────────
local function load_cloud()
    info("Fetching cloud script...")
    http.get(CLOUD_URL, function(success, response)
        if not success then err("HTTP failed."); return end
        local body = type(response)=="table" and response.body or response
        if not body or #body < 100 then err("Empty response."); return end
        info("Downloaded "..(#body).." bytes, executing...")
        rawset(_G,"_auth_ok",      true)
        rawset(_G,"_auth_alive",   true)
        rawset(_G,"_auth_user",    auth_user)
        rawset(_G,"BUILD_VERSION", auth_plan or TIER)
        local fn, lerr = (rawget(_G,"load") or load)(body,"@zenith_beta_cloud")
        if not fn then err("Compile error: "..tostring(lerr)); return end
        local ok2,rerr = pcall(fn)
        if not ok2 then err("Runtime error: "..tostring(rerr)); return end
        rawset(_G,"_zenith_loader_loaded", true)
        client.delay_call(0.1, function()
            if rawget(_G,"_vis") then pcall(function() _G._vis:set(false) end) end
        end)
    end)
end

-- ── API VERIFY ───────────────────────────────────────────────────────────
local function verify_key(key, username, callback)
    local hwid = get_hwid()
    local url  = API_URL.."/verify?key="..key.."&hwid="..hwid
    set_status(255,200,80,"Verifying with server...")
    http.get(url, function(success, response)
        if not success then
            set_status(255,60,60,"Server unreachable. Check connection.")
            err("API request failed")
            callback(false)
            return
        end
        local body = type(response)=="table" and response.body or response
        local ok2, data = pcall(function()
            -- simple JSON parse for flat objects
            local t = {}
            for k2,v in (body or ""):gmatch('"([^"]+)":%s*([^,}]+)') do
                v = v:match('^"(.*)"$') or v
                if v == "true" then v = true elseif v == "false" then v = false
                elseif tonumber(v) then v = tonumber(v) end
                t[k2] = v
            end
            return t
        end)
        if not ok2 or not data then
            set_status(255,60,60,"Invalid server response.")
            err("Parse error")
            callback(false)
            return
        end
        if data.valid then
            callback(true, data)
        else
            local reason = data.reason or "unknown"
            local msg = reason == "expired"       and "Key has expired."
                     or reason == "hwid_mismatch" and "Key is locked to another machine."
                     or reason == "invalid_key"   and "Invalid key."
                     or "Verification failed: "..reason
            set_status(255,60,60, msg)
            err(msg)
            callback(false)
        end
    end)
end

-- ── LOGIN (API-backed) ────────────────────────────────────────────────────
local function do_login(key, username)
    key      = (key      or ""):match("^%s*(.-)%s*$")
    username = (username or ""):match("^%s*(.-)%s*$")
    if key      == "" then set_status(255,120,50,"Enter your license key."); return end
    if username == "" then set_status(255,120,50,"Enter a username."); return end
    if #username < 2  then set_status(255,120,50,"Username too short (min 2)."); return end

    verify_key(key, username, function(valid, data)
        if not valid then return end

        -- check plan matches this loader's tier
        local plan = data.plan or TIER
        if plan ~= TIER and plan ~= "nightly" then
            set_status(255,60,60,"This key is for the "..plan:upper().." loader, not "..TIER:upper()..".")
            return
        end

        local hwid = get_hwid()
        auth_ok   = true
        auth_user = username
        auth_key  = key
        auth_plan = plan
        auth_exp  = data.expires_at

        -- save session
        db_write(DB_SESSION, {
            user     = username,
            key      = key,
            hwid     = hwid,
            plan     = plan,
            exp      = auth_exp,
            v        = AUTH_VER,
        })

        local exp_str = auth_exp and os.date("%Y-%m-%d", auth_exp/1000) or "lifetime"
        set_status(100,255,160,"Welcome, '"..username.."'!  Expires: "..exp_str)
        info("Logged in: "..username.." | plan="..plan)
        client.delay_call(0.5, load_cloud)
    end)
end

-- ── SESSION RESTORE ───────────────────────────────────────────────────────
local function try_restore()
    local hwid = get_hwid()
    local sess = db_read(DB_SESSION)
    if not (sess.v == AUTH_VER and sess.user and sess.key and sess.hwid == hwid) then
        return false
    end
    -- re-verify with API every load (catches expired/revoked)
    verify_key(sess.key, sess.user, function(valid, data)
        if not valid then
            db_write(DB_SESSION, nil)
            set_status(255,60,60,"Session invalid. Please login again.")
            return
        end
        auth_ok   = true
        auth_user = sess.user
        auth_key  = sess.key
        auth_plan = data.plan or TIER
        auth_exp  = data.expires_at
        set_status(113,152,255,"Session restored: "..sess.user)
        info("Session restored: "..sess.user)
        client.delay_call(0.5, load_cloud)
    end)
    return true
end

-- Try session restore BEFORE creating UI
local restored = try_restore()

-- ── PUI MENU ─────────────────────────────────────────────────────────────
if not restored then
local grp_fl  = pui.group("AA","Fake lag")
local grp_aa  = pui.group("AA","Anti-aimbot angles")
local grp_oth = pui.group("AA","Other")

local _vis = grp_aa:checkbox("\n__loader_vis__")
_vis:set(true); _vis:depend(_vis)
rawset(_G,"_vis",_vis)
pui.macros.dot = "\vâ¢  \r"

-- Fake lag column: branding
grp_fl:label("         Z  E  N  I  T  H"):depend(_vis)
grp_fl:label("\f<dot>\a4799ffffBETA  â  Authentication"):depend(_vis)
grp_fl:label(" "):depend(_vis)
local fl_user   = grp_fl:label("\f<dot>User:   \ac8c8c8ffâ"):depend(_vis)
local fl_status = grp_fl:label("\f<dot>Auth:   \aff6060ffâ Not logged in"):depend(_vis)
local fl_tier   = grp_fl:label("\f<dot>Tier:   \a4799ffffBETA"):depend(_vis)
grp_fl:label(" "):depend(_vis)
grp_fl:label("\f<dot>\ac8c8c8ffHWID: (console: zn_hwid)"):depend(_vis)

-- Main column: auth form
grp_aa:label("\f<dot>License Key:"):depend(_vis)
local inp_key  = grp_aa:textbox("\nKey","",false):depend(_vis)
grp_aa:label("\f<dot>Username:"):depend(_vis)
local inp_name = grp_aa:textbox("\nUsername","",false):depend(_vis)
grp_aa:label(" "):depend(_vis)

local btn_login  = grp_aa:button("Login"):depend(_vis)
local btn_logout = grp_aa:button("Logout"):depend(_vis)

grp_aa:label(" "):depend(_vis)
local lbl_status = grp_aa:label("\f<dot>\ac8c8c8ffEnter key and username, then click Login."):depend(_vis)

-- Other column: info
grp_oth:label("\f<dot>How to use:"):depend(_vis)
grp_oth:label("\f<dot>\ac8c8c8ff1. Enter your ZEN key"):depend(_vis)
grp_oth:label("\f<dot>\ac8c8c8ff   (ZEN-BETA-...)"):depend(_vis)
grp_oth:label("\f<dot>\ac8c8c8ff2. Enter a username"):depend(_vis)
grp_oth:label("\f<dot>\ac8c8c8ff3. Click Login"):depend(_vis)
grp_oth:label(" "):depend(_vis)
grp_oth:label("\f<dot>\ac8c8c8ffNext time: auto-restored."):depend(_vis)
grp_oth:label("\f<dot>\ac8c8c8ffHWID locked on first use."):depend(_vis)

-- Button callbacks
btn_login:set_callback(function()
    do_login(inp_key:get(), inp_name:get())
end)

btn_logout:set_callback(function()
    db_write(DB_SESSION,nil)
    auth_ok=false; auth_user=nil; auth_key=nil
    set_status(160,160,200,"Logged out.")
    warn("Logged out.")
end)

-- Live UI updates
client.set_event_callback("paint_ui", function()
    lbl_status:set("\f<dot>\a".._sf("%02x%02x%02xff",status_r,status_g,status_b)..status_msg)
    if auth_ok and auth_user then
        fl_user:set("\f<dot>User:   \a4dff91ff"..auth_user)
        fl_status:set("\f<dot>Auth:   \a4dff91ffâ Logged in")
    else
        fl_user:set("\f<dot>User:   \ac8c8c8ffâ")
        fl_status:set("\f<dot>Auth:   \aff6060ffâ Not logged in")
    end
    pcall(function() btn_logout:set_enabled(auth_ok) end)
    pcall(function() btn_login:set_enabled(not auth_ok) end)
end)

end -- if not restored

-- ── CONSOLE COMMANDS ─────────────────────────────────────────────────────
client.set_event_callback("console_input", function(cmd)
    local t = cmd:match("^%s*(.-)%s*$")
    if t == "zn_logout" then
        db_write(DB_SESSION,nil); auth_ok=false; auth_user=nil; auth_key=nil
        set_status(160,160,200,"Logged out."); warn("Logged out."); return true
    end
    if t == "zn_hwid" then info("HWID: "..get_hwid()); return true end
    if t == "zn_key"  then info("Key:  "..(auth_key or "none")); return true end
end)

-- ── STARTUP ──────────────────────────────────────────────────────────────
info("Loader v3.0.0 ready. API: "..API_URL)
