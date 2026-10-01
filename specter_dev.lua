-- ======================================================================
--  SPECTER | Dev Loader (no auth, no cloud fetch)
--  For owners/developers only — runs specter_cloud.lua directly
--  from the gamesense scripts folder with full debug-tier access.
--
--  Usage: load this file in gamesense instead of specter_loader.lua
--         and place specter_cloud.lua next to it.
-- ======================================================================

if not LPH_OBFUSCATED then
    LPH_ENCSTR = function(...) return ... end
    LPH_NO_VIRTUALIZE = function(...) return ... end
    LPH_CRASH = function() end
end

-- fake auth globals so specter_cloud.lua's auth gate passes
rawset(_G, "_auth_ok",    true)
rawset(_G, "_auth_alive", true)
rawset(_G, "_auth_ts",    os.time())
rawset(_G, "_auth_user",  "dev")
rawset(_G, "_auth_key",   "DEV-LOCAL")
rawset(_G, "_auth_hwid",  "DEV")
rawset(_G, "BUILD_VERSION", "debug")

-- locate specter_cloud.lua next to this file
local me = debug.getinfo(1, "S").source:match("^@?(.*)")
local dir = me:match("^(.*[\\/])") or ""
local path = dir .. "specter_cloud.lua"

local f = io.open(path, "r")
if not f then
    client.error_log("[Specter Dev] specter_cloud.lua not found at: " .. path)
    return
end
local src = f:read("*a")
f:close()

local fn, err = (rawget(_G, "load") or load)(src, "@specter_cloud")
if not fn then
    client.error_log("[Specter Dev] Load error: " .. tostring(err))
    return
end

local ok, rerr = pcall(fn)
if not ok then
    client.error_log("[Specter Dev] Runtime error: " .. tostring(rerr))
    return
end

rawset(_G, "_specter_loader_loaded", true)
client.color_log(180, 160, 255, "[Specter Dev] Loaded with full debug access.")
