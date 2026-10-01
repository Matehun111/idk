-- ======================================================================
--  SPECTER | Dev Loader  v2.3
--  For owners/developers only — runs specter_cloud.lua directly
--  from the gamesense lua folder with full debug-tier access.
--
--  Features loaded via specter_cloud.lua:
--    • Resolver: desync / jitter / defensive contexts, learned per record
--    • FFI resolver: animation layers, animstate, server-style feet yaw model
--    • Automatic ping profile (high ping from 35 ms, menu: Resolver > Ping profile)
--    • Cloud config sync (upload / download / delete)
--    • Anti-tamper integrity monitor (10s crash delay)
--    • Full AA, visuals, misc
--
--  Usage: load this file in gamesense instead of specter_loader.lua
--         and put specter_cloud.lua next to it (csgo/lua/).
--         Set SERVER_URL below to your Railway endpoint for cloud configs.
--
--  gamesense has no os / io / debug libraries, so this file only uses
--  client.*, readfile and loadstring.
-- ======================================================================

-- ██ SET YOUR SERVER URL HERE (needed for cloud config sync) ██
local SERVER_URL = "https://your-server.railway.app"

if not LPH_OBFUSCATED then
    LPH_ENCSTR = function(...) return ... end
    LPH_NO_VIRTUALIZE = function(...) return ... end
    LPH_CRASH = function() end
end

-- the same clock expression the auth gate in specter_cloud.lua uses
local function unix_now()
    return (client and client.unix_time and client.unix_time())
        or (os and os.time and os.time())
        or (client and client.timestamp and math.floor(client.timestamp() / 1000))
        or 0
end

-- fake auth globals so specter_cloud.lua's auth gate passes
local function set_auth()
    rawset(_G, "_auth_ok",    true)
    rawset(_G, "_auth_alive", true)
    rawset(_G, "_auth_ts",    unix_now())
    rawset(_G, "_auth_user",  "dev")
    rawset(_G, "_auth_key",   "DEV-LOCAL")
    rawset(_G, "_auth_hwid",  "DEV")
    rawset(_G, "BUILD_VERSION", "debug")
    rawset(_G, "_server_url",  SERVER_URL)
end

local function log_err(msg) client.error_log("[Specter Dev] " .. msg) end

-- read specter_cloud.lua: gamesense's readfile first, io only if this build has it
local NAMES = {
    "lua/specter_cloud.lua", "lua\\specter_cloud.lua", ".\\lua\\specter_cloud.lua",
    "specter_cloud.lua", "csgo/lua/specter_cloud.lua",
}
local function read_source()
    local rf = rawget(_G, "readfile")
    if type(rf) == "function" then
        for _, name in ipairs(NAMES) do
            local ok, data = pcall(rf, name)
            if ok and type(data) == "string" and #data > 1000 then return data, name end
        end
    end
    local iolib = rawget(_G, "io")
    if type(iolib) == "table" and iolib.open then
        for _, name in ipairs(NAMES) do
            local ok, f = pcall(iolib.open, name, "rb")
            if ok and f then
                local data = f:read("*a")
                f:close()
                if data and #data > 1000 then return data, name end
            end
        end
    end
end

local src, found = read_source()
if not src then
    -- last resort: a local module in the lua folder (runs the script when it is required)
    set_auth()
    local ok, rerr = pcall(require, "specter_cloud")
    if ok then
        rawset(_G, "_specter_loader_loaded", true)
        client.color_log(180, 160, 255, "[Specter Dev] Loaded through require.")
    else
        log_err("specter_cloud.lua not found (tried readfile / io / require): " .. tostring(rerr))
        log_err("put specter_cloud.lua into csgo/lua next to this file")
    end
    return
end

local compile = rawget(_G, "loadstring") or rawget(_G, "load") or load
local fn, err = compile(src, "@specter_cloud")
if not fn then
    log_err("Load error: " .. tostring(err))
    return
end

set_auth()   -- right before the run: the gate only accepts a fresh timestamp
local ok, rerr = pcall(fn)
if not ok then
    log_err("Runtime error: " .. tostring(rerr))
    return
end

rawset(_G, "_specter_loader_loaded", true)
client.color_log(180, 160, 255, "[Specter Dev] Loaded with full debug access (" .. tostring(found) .. ").")
client.color_log(130, 195, 255, "[Specter Dev] Cloud configs: " .. (SERVER_URL ~= "" and "enabled" or "no server URL set"))
client.color_log(130, 195, 255, "[Specter Dev] Resolver: desync / jitter / defensive + FFI, auto ping profile (high from 35 ms)")
