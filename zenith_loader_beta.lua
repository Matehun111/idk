-- ======================================================================
--  ZENITH  |  BETA  |  Cloud Loader
--  Drop this into gamesense Lua — no other files needed.
-- ======================================================================

local CLOUD_URL  = "https://raw.githubusercontent.com/Matehun111/idk/main/zenith_cloud_beta.lua"
local LOADER_VER = "1.0.0"
local TIER       = "beta"
local AUTH_VER   = 1
local DB_KEYS    = "zenith_beta_keys_v1"
local DB_SESSION = "zenith_beta_session_v1"

local VALID_KEYS = {
    ["ZNBET-AAAA-2001"] = { hwid = nil, note = "slot 1"  },
    ["ZNBET-BBBB-2002"] = { hwid = nil, note = "slot 2"  },
    ["ZNBET-CCCC-2003"] = { hwid = nil, note = "slot 3"  },
    ["ZNBET-DDDD-2004"] = { hwid = nil, note = "slot 4"  },
    ["ZNBET-EEEE-2005"] = { hwid = nil, note = "slot 5"  },
    ["ZNBET-FFFF-2006"] = { hwid = nil, note = "slot 6"  },
    ["ZNBET-GGGG-2007"] = { hwid = nil, note = "slot 7"  },
    ["ZNBET-HHHH-2008"] = { hwid = nil, note = "slot 8"  },
    ["ZNBET-IIII-2009"] = { hwid = nil, note = "slot 9"  },
    ["ZNBET-JJJJ-2010"] = { hwid = nil, note = "slot 10" },
}

-- =====================================================================
--  INTERNALS
-- =====================================================================

local http   = require "gamesense/http"
local _sf    = string.format
local _bxor  = bit.bxor
local _band  = bit.band
local _flr   = math.floor

local function clog(r,g,b,msg) client.color_log(r,g,b,"[Zenith BETA] "..tostring(msg)) end
local function info(msg) clog(100,160,255,msg) end
local function warn(msg) clog(255,200,80,msg) end
local function err(msg)  clog(255,60,60,msg)  end

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
local status_msg = "Enter your key and press Login."

local function validate_key(key)
    key = (key or ""):match("^%s*(.-)%s*$")
    if key == "" then status_msg = "Enter a key first."; return false end
    local entry = VALID_KEYS[key]
    if not entry then
        err("Invalid key.")
        status_msg = "Invalid key. Must start with ZNBET-"
        return false
    end
    local hwid = get_hwid()
    local db   = db_read(DB_KEYS)
    local saved = db[key]
    if saved and saved.hwid and saved.hwid ~= "" then
        if saved.hwid ~= hwid then
            err("HWID mismatch.")
            status_msg = "HWID mismatch - key locked to another machine."
            return false
        end
    else
        db[key] = {hwid=hwid, note=entry.note}
        db_write(DB_KEYS, db)
        info("Key locked. Slot: "..(entry.note or "?"))
    end
    db_write(DB_SESSION, {key=key,hwid=hwid,v=AUTH_VER})
    auth_ok  = true
    auth_key = key
    status_msg = "Authenticated! Fetching BETA script..."
    info("Login OK: "..key)
    return true
end

local function load_cloud()
    status_msg = "Downloading from cloud..."
    info("Fetching: "..CLOUD_URL)
    http.get(CLOUD_URL, function(success, response)
        if not success or not response or #response < 100 then
            err("Download failed - check console.")
            status_msg = "Download failed."
            return
        end
        info("Downloaded " .. #response .. " bytes, writing to disk...")

        -- Set auth globals before execution
        _auth_ok    = true
        _auth_alive = true
        _auth_user  = auth_key

        -- Write to temp file using gamesense filesystem, then dofile()
        local tmp = "lua\\zenith_beta_exec.lua"
        filesystem.write(tmp, response)

        local ok, exec_err = pcall(dofile, tmp)
        if not ok then
            err("Execution error: " .. tostring(exec_err))
            status_msg = "Runtime error - see console."
            pcall(filesystem.remove, tmp)
            return
        end

        pcall(filesystem.remove, tmp)

        status_msg = "Zenith BETA loaded!"
        info("Running from cloud.")
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
    status_msg = "Session restored - loading BETA..."
    info("Session restored: "..sess.key)
    return true
end

client.set_event_callback("console_input", function(cmd)
    local t = cmd:match("^%s*(.-)%s*$")
    if t:match("^ZNBET%-") then
        if validate_key(t) then client.delay_call(0.1,load_cloud) end
        return true
    end
    if t=="zn_logout" then
        db_write(DB_SESSION,nil); auth_ok=false; auth_key=nil
        status_msg="Logged out."; warn("Logged out."); return true
    end
    if t=="zn_hwid" then info("HWID: "..get_hwid()); return true end
end)

-- =====================================================================
--  UI  (menu.new_item - works in standalone scripts)
-- =====================================================================

local function lbl(col, text) return ui.new_label(col, "Anti-aimbot angles", text) end
local function flbl(text)     return ui.new_label("AA", "Fake lag", text) end
local function olbl(text)     return ui.new_label("AA", "Other", text) end

-- Fake lag column (left)
local _w = flbl("Z  E  N  I  T  H")
local _t = flbl("BETA Loader v"..LOADER_VER)
local _s = flbl("Key: ZNBET-XXXX-XXXX")
local _i1 = flbl("Includes: AA + Aimbot")
local _i2 = flbl("No Resolver. 10 slots.")
-- Main column
local _h  = lbl("AA", "Zenith BETA - Authentication")
local _h2 = lbl("AA", "Enter your license key below:")
local ui_key    = ui.new_textbox("AA", "Anti-aimbot angles", "License Key")
local ui_login  = ui.new_button("AA", "Anti-aimbot angles", "Login and Load", function()
    if validate_key(ui.get(ui_key)) then
        client.delay_call(0.1, load_cloud)
    end
end)
local ui_reload = ui.new_button("AA", "Anti-aimbot angles", "Reload Script", function()
    if not auth_ok then status_msg="Authenticate first."; return end
    load_cloud()
end)
local ui_logout = ui.new_button("AA", "Anti-aimbot angles", "Logout", function()
    db_write(DB_SESSION,nil); auth_ok=false; auth_key=nil
    status_msg="Logged out."
end)
local ui_status = lbl("AA", "Status: waiting...")

-- Other column (right)
local _o1 = olbl("Auth Info")
local ui_o_tier  = olbl("Tier: -")
local ui_o_key   = olbl("Key:  -")
local ui_o_state = olbl("State: Not logged in")
local _o2 = olbl("---")
local _o3 = olbl("Console commands:")
local _o4 = olbl("zn_hwid  = show HWID")
local _o5 = olbl("zn_logout = log out")

client.set_event_callback("paint_ui", function()
    ui.set(ui_status, "Status: "..status_msg)
    if auth_ok and auth_key then
        ui.set(ui_o_tier,  "Tier:  BETA")
        ui.set(ui_o_key,   "Key:   ..."..auth_key:sub(-9))
        ui.set(ui_o_state, "State: Authenticated")
        pcall(ui.set_enabled, ui_reload, true)
    else
        ui.set(ui_o_tier,  "Tier:  -")
        ui.set(ui_o_key,   "Key:   -")
        ui.set(ui_o_state, "State: Not logged in")
        pcall(ui.set_enabled, ui_reload, false)
    end
end)

-- ── BOOT ──────────────────────────────────────────────────────────────
if try_restore() then
    client.delay_call(0.5, load_cloud)
else
    info("Not authenticated. Enter key ZNBET-XXXX-XXXX")
    status_msg = "Enter your BETA key and press Login."
end
info("Loader ready v"..LOADER_VER)
