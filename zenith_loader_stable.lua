-- ======================================================================
--  ZENITH | STABLE | Cloud Loader
--  No UI - auth via console only.
--  Type your key in console to load Zenith.
-- ======================================================================

local CLOUD_URL  = "https://raw.githubusercontent.com/Matehun111/idk/main/zenith_cloud_stable.lua"
local LOADER_VER = "1.0.0"
local TIER       = "stable"
local AUTH_VER   = 1
local DB_KEYS    = "zenith_stable_keys_v1"
local DB_SESSION = "zenith_stable_session_v1"

local VALID_KEYS = {
    ["ZNTST-AAAA-1001"]={hwid=nil,note="slot 1"},
    ["ZNTST-BBBB-1002"]={hwid=nil,note="slot 2"},
    ["ZNTST-CCCC-1003"]={hwid=nil,note="slot 3"},
    ["ZNTST-DDDD-1004"]={hwid=nil,note="slot 4"},
    ["ZNTST-EEEE-1005"]={hwid=nil,note="slot 5"},
    ["ZNTST-FFFF-1006"]={hwid=nil,note="slot 6"},
    ["ZNTST-GGGG-1007"]={hwid=nil,note="slot 7"},
    ["ZNTST-HHHH-1008"]={hwid=nil,note="slot 8"},
    ["ZNTST-IIII-1009"]={hwid=nil,note="slot 9"},
    ["ZNTST-JJJJ-1010"]={hwid=nil,note="slot 10"},
}

local http  = require "gamesense/http"
local _sf   = string.format
local _bxor = bit.bxor
local _band = bit.band
local _flr  = math.floor

local function clog(r,g,b,m) client.color_log(r,g,b,"[Zenith STABLE] "..tostring(m)) end
local function info(m) clog(100,200,100,m) end
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

local auth_ok  = false
local auth_key = nil

local function validate_key(key)
    key = (key or ""):match("^%s*(.-)%s*$")
    if key == "" then err("Enter a key."); return false end
    local entry = VALID_KEYS[key]
    if not entry then err("Invalid key."); return false end
    local hwid = get_hwid()
    local db   = db_read(DB_KEYS)
    local saved = db[key]
    if saved and saved.hwid and saved.hwid ~= "" then
        if saved.hwid ~= hwid then err("HWID mismatch."); return false end
    else
        db[key] = {hwid=hwid,note=entry.note}
        db_write(DB_KEYS,db)
        info("Key locked to this machine. Slot: "..(entry.note or "?"))
    end
    db_write(DB_SESSION,{key=key,hwid=hwid,v=AUTH_VER})
    auth_ok  = true
    auth_key = key
    info("Authenticated: "..key)
    return true
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
        rawset(_G,"_auth_user",    auth_key)
        rawset(_G,"BUILD_VERSION", TIER)
        local fn, lerr = (rawget(_G,"load") or load)(body,"@zenith_stable_cloud")
        if not fn then err("Compile error: "..tostring(lerr)); return end
        local ok, rerr = pcall(fn)
        if not ok then err("Runtime error: "..tostring(rerr)); return end
        info("Zenith STABLE running!")
    end)
end

local function try_restore()
    local hwid = get_hwid()
    local sess = db_read(DB_SESSION)
    if not (sess and sess.v==AUTH_VER and sess.key and sess.hwid==hwid) then return false end
    if not VALID_KEYS[sess.key] then db_write(DB_SESSION,nil); return false end
    local db = db_read(DB_KEYS)
    local saved = db[sess.key]
    if not saved or saved.hwid~=hwid then db_write(DB_SESSION,nil); return false end
    auth_ok  = true
    auth_key = sess.key
    info("Session restored: "..sess.key)
    return true
end

client.set_event_callback("console_input", function(cmd)
    local t = cmd:match("^%s*(.-)%s*$")
    if t:match("^ZNTST%-") then
        if validate_key(t) then client.delay_call(0.1,load_cloud) end
        return true
    end
    if t=="zn_logout" then
        db_write(DB_SESSION,nil); auth_ok=false; auth_key=nil
        warn("Logged out."); return true
    end
    if t=="zn_hwid" then info("HWID: "..get_hwid()); return true end
end)

if try_restore() then
    client.delay_call(0.5, load_cloud)
else
    info("Not authenticated. Type your key in console: ZNTST-XXXX-XXXX")
end
info("Loader v"..LOADER_VER.." ready.")
