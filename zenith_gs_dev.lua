-- ======================================================================
--  ZENITH | DEV PANEL  v1.0
--  Admin-only. Run locally only — never distribute.
-- ======================================================================

local DB_KEYS_N  = "zenith_nightly_keys_v2"
local DB_KEYS_B  = "zenith_beta_keys_v2"
local DB_KEYS_S  = "zenith_stable_keys_v2"
local DB_USERS_N = "zenith_nightly_users_v2"
local DB_USERS_B = "zenith_beta_users_v2"
local DB_USERS_S = "zenith_stable_users_v2"
local DB_LB      = "zenith_leaderboard_v2"
local DB_TOT     = "zenith_total_users_v2"
local DB_HB      = "zenith_online_hb_v1"
local ADMIN_PASS = "Trustgxt_11_"

-- ── LIBS ──────────────────────────────────────────────────────────────
local pui = require "gamesense/pui"
if not LPH_OBFUSCATED then LPH_NO_VIRTUALIZE = function(...) return ... end end

-- ── HELPERS ───────────────────────────────────────────────────────────
local function db_read(k)
    local ok, r = pcall(database.read, k)
    return ok and type(r) == "table" and r or {}
end
local function db_read_num(k)
    local ok, r = pcall(database.read, k)
    return ok and type(r) == "number" and r or 0
end
local function db_write(k, v) pcall(database.write, k, v) end
local function info(s)   client.color_log(100,200,255,"[Dev] "..s) end
local function warn(s)   client.color_log(255,100,100,"[Dev] "..s) end
local function ok_log(s) client.color_log(100,255,150,"[Dev] "..s) end

-- ── PUI ───────────────────────────────────────────────────────────────
local grp_fl  = pui.group("AA", "Fake lag")
local grp_aa  = pui.group("AA", "Anti-aimbot angles")

local _vis = grp_aa:checkbox('\n__dev_vis__')
_vis:set(true)
_vis:depend(_vis)
rawset(_G, "_vis", _vis)
pui.macros.dot = '\v•  \r'

-- Branding
grp_fl:label('         Z  E  N  I  T  H'):depend(_vis)
grp_fl:label('\f<dot>\ac8c8c8ffDEV PANEL  v1.0'):depend(_vis)
grp_fl:label(' '):depend(_vis)
local fl_auth   = grp_fl:label('\f<dot>Auth:   \aff4444ff✗ Not verified'):depend(_vis)
local fl_status = grp_fl:label('\f<dot>Status: \ac8c8c8ff—'):depend(_vis)
grp_fl:label(' '):depend(_vis)
grp_fl:label('\f<dot>\ac8c8c8ffType zn_help in console'):depend(_vis)

-- Auth form
grp_aa:label('\f<dot>Admin Password:'):depend(_vis)
local inp_pass = grp_aa:textbox('\nPassword', '', true):depend(_vis)
local btn_auth = grp_aa:button('\nVerify', function() end):depend(_vis)
grp_aa:label(' '):depend(_vis)
local out_label = grp_aa:label('\f<dot>\ac8c8c8ffOutput: —'):depend(_vis)

-- ── STATE ─────────────────────────────────────────────────────────────
local is_authed = false

local function set_status(r,g,b,msg)
    fl_status:set(string.format('\f<dot>Status: \a%02x%02x%02xff%s',r,g,b,msg))
end
local function set_out(r,g,b,msg)
    out_label:set(string.format('\f<dot>\a%02x%02x%02xff%s',r,g,b,msg))
end
local function require_auth()
    if not is_authed then
        warn("Not verified. Enter admin password and click Verify.")
        set_status(255,100,100,"Not verified.")
        return false
    end
    return true
end

local function users_key(tier)
    tier = (tier or "n"):lower():sub(1,1)
    if tier == "b" then return DB_USERS_B,"beta"
    elseif tier == "s" then return DB_USERS_S,"stable"
    else return DB_USERS_N,"nightly" end
end
local function keys_key(tier)
    tier = (tier or "n"):lower():sub(1,1)
    if tier == "b" then return DB_KEYS_B,"beta"
    elseif tier == "s" then return DB_KEYS_S,"stable"
    else return DB_KEYS_N,"nightly" end
end

-- ── VERIFY BUTTON ─────────────────────────────────────────────────────
btn_auth:set_callback(function()
    local pass = inp_pass:get()
    if pass == ADMIN_PASS then
        is_authed = true
        fl_auth:set('\f<dot>Auth:   \a00ff88ff✓ Verified')
        set_status(100,255,150,"Verified. All commands unlocked.")
        ok_log("Admin verified.")
    else
        is_authed = false
        fl_auth:set('\f<dot>Auth:   \aff4444ff✗ Wrong password')
        set_status(255,80,80,"Wrong password.")
        warn("Wrong password.")
    end
end)

-- ── CONSOLE COMMANDS ──────────────────────────────────────────────────
client.set_event_callback("console_input", function(cmd)
    local t = cmd:match("^%s*(.-)%s*$")
    if not t or t == "" then return end

    -- zn_users [n/b/s]
    local tier_arg = t:match("^zn_users%s*(.*)$")
    if tier_arg ~= nil then
        if not require_auth() then return true end
        local dbk,tname = users_key(tier_arg ~= "" and tier_arg or "n")
        local users = db_read(dbk)
        local count = 0
        info("=== "..tname:upper().." USERS ===")
        for name,u in pairs(users) do
            if type(u)=="table" then
                count=count+1
                info(string.format("  [%d] %s | hwid: %s | key: %s",
                    count, name, u.hwid or "none", u.key or "none"))
            end
        end
        info("Total: "..count)
        set_out(100,200,255, tname..": "..count.." users")
        return true
    end

    -- zn_hwid_reset <user> [tier]
    local ru,rt = t:match("^zn_hwid_reset%s+(%S+)%s*(%S*)$")
    if ru then
        -- no auth required for single user HWID reset
        local dbk,tname = users_key(rt ~= "" and rt or "n")
        local users = db_read(dbk)
        local ukey = ru:lower()
        if users[ukey] then
            users[ukey].hwid = nil
            db_write(dbk, users)
            ok_log("HWID reset: "..ru.." ("..tname..")")
            set_out(100,255,150,"HWID reset: "..ru)
        else
            warn("Not found: "..ru.." in "..tname)
            set_out(255,100,100,"Not found: "..ru)
        end
        return true
    end

    -- zn_hwid_reset_all [tier|all]
    local rat = t:match("^zn_hwid_reset_all%s*(%S*)$")
    if rat ~= nil then
        if not require_auth() then return true end
        local tiers = rat=="all" and {"n","b","s"} or {rat~=""and rat or"n"}
        local total=0
        for _,tier in ipairs(tiers) do
            local dbk,tname = users_key(tier)
            local users = db_read(dbk)
            local cnt=0
            for _,u in pairs(users) do
                if type(u)=="table" and u.hwid then u.hwid=nil; cnt=cnt+1 end
            end
            db_write(dbk,users)
            ok_log(string.format("Reset %d HWIDs (%s)",cnt,tname))
            total=total+cnt
        end
        set_out(100,255,150,"Reset "..total.." HWIDs total")
        return true
    end

    -- zn_delete <user> [tier]
    local du,drt = t:match("^zn_delete%s+(%S+)%s*(%S*)$")
    if du and du~="all" then
        if not require_auth() then return true end
        local dbk,tname = users_key(drt~=""and drt or"n")
        local users = db_read(dbk)
        local ukey = du:lower()
        if users[ukey] then
            local freed = users[ukey].key
            if freed then
                local kdbk = keys_key(drt~=""and drt or"n")
                local keys = db_read(kdbk)
                if keys[freed] then
                    keys[freed].used=false; keys[freed].owner=nil
                    db_write(kdbk,keys)
                end
            end
            users[ukey]=nil
            db_write(dbk,users)
            ok_log("Deleted "..du.." ("..tname..")"..
                (freed and " | key "..freed.." freed" or ""))
            set_out(100,255,150,"Deleted: "..du)
        else
            warn("Not found: "..du.." in "..tname)
            set_out(255,100,100,"Not found: "..du)
        end
        return true
    end

    -- zn_delete_all [tier|all]
    local dat = t:match("^zn_delete_all%s*(%S*)$")
    if dat ~= nil then
        if not require_auth() then return true end
        local tiers = dat=="all" and {"n","b","s"} or {dat~=""and dat or"n"}
        local total=0
        for _,tier in ipairs(tiers) do
            local dbk,tname = users_key(tier)
            local kdbk = keys_key(tier)
            local users = db_read(dbk)
            local keys  = db_read(kdbk)
            local cnt=0
            for _,u in pairs(users) do
                if type(u)=="table" then
                    if u.key and keys[u.key] then
                        keys[u.key].used=false; keys[u.key].owner=nil
                    end
                    cnt=cnt+1
                end
            end
            db_write(dbk,{}); db_write(kdbk,keys)
            ok_log(string.format("Deleted %d users (%s), keys freed",cnt,tname))
            total=total+cnt
        end
        set_out(255,160,60,"Deleted "..total.." users total")
        return true
    end

    -- zn_reset_key <key> (no auth required - emergency use)
    local rk = t:match("^zn_reset_key%s+(%S+)$")
    if rk then
        local freed = false
        for _, dbk in ipairs({DB_KEYS_N, DB_KEYS_B, DB_KEYS_S}) do
            local keys = db_read(dbk)
            if keys[rk] then
                keys[rk].hwid = nil
                db_write(dbk, keys)
                ok_log("Key HWID reset: "..rk)
                set_out(100,255,150,"Key reset: "..rk)
                freed = true
            end
        end
        if not freed then
            warn("Key not found in any tier: "..rk)
            set_out(255,100,100,"Key not found: "..rk)
        end
        return true
    end

    -- zn_keys [tier]
    local kt = t:match("^zn_keys%s*(%S*)$")
    if kt ~= nil then
        if not require_auth() then return true end
        local dbk,tname = keys_key(kt~=""and kt or"n")
        local keys = db_read(dbk)
        local used,free=0,0
        info("=== "..tname:upper().." KEYS ===")
        for key,data in pairs(keys) do
            if type(data)=="table" then
                if data.used then
                    used=used+1
                    info("  [USED] "..key.." → "..(data.owner or "?"))
                else
                    free=free+1
                    info("  [FREE] "..key)
                end
            end
        end
        info(string.format("Used: %d | Free: %d",used,free))
        set_out(100,200,255,tname..": "..used.." used, "..free.." free")
        return true
    end

    -- zn_lb
    if t=="zn_lb" then
        if not require_auth() then return true end
        local lb = db_read(DB_LB)
        local entries={}
        for u,k in pairs(lb) do entries[#entries+1]={u=u,k=k} end
        table.sort(entries,function(a,b) return a.k>b.k end)
        info("=== LEADERBOARD ===")
        for i,e in ipairs(entries) do
            info(string.format("  #%d  %s  —  %d kills",i,e.u,e.k))
        end
        info("Total: "..#entries)
        set_out(100,200,255,"LB: "..#entries.." entries")
        return true
    end

    -- zn_lb_reset
    if t=="zn_lb_reset" then
        if not require_auth() then return true end
        db_write(DB_LB,{}); db_write(DB_TOT,0)
        ok_log("Leaderboard wiped.")
        set_out(255,160,60,"Leaderboard reset.")
        return true
    end

    -- zn_online
    if t=="zn_online" then
        if not require_auth() then return true end
        local hb = db_read(DB_HB)
        local now = math.floor(globals.tickcount()/globals.tickrate())
        local online,stale=0,0
        info("=== ONLINE SESSIONS ===")
        for uid,ts in pairs(hb) do
            local age=now-ts
            if age<=90 then
                online=online+1
                info(string.format("  ONLINE  %s  (%ds ago)",uid,age))
            else
                stale=stale+1
                info(string.format("  STALE   %s  (%ds ago)",uid,age))
            end
        end
        info(string.format("Online: %d | Stale: %d",online,stale))
        set_out(100,255,150,string.format("Online: %d | Stale: %d",online,stale))
        return true
    end

    -- zn_online_clear
    if t=="zn_online_clear" then
        if not require_auth() then return true end
        db_write(DB_HB,{})
        ok_log("Sessions cleared.")
        set_out(255,160,60,"Sessions cleared.")
        return true
    end

    -- zn_help
    if t=="zn_help" then
        info("=== ZENITH DEV COMMANDS ===")
        info("  zn_users [n/b/s]")
        info("  zn_hwid_reset <user> [tier]")
        info("  zn_hwid_reset_all [tier|all]")
        info("  zn_delete <user> [tier]")
        info("  zn_delete_all [tier|all]")
        info("  zn_keys [tier]")
        info("  zn_lb  /  zn_lb_reset")
        info("  zn_online  /  zn_online_clear")
        info("  tier: n=nightly  b=beta  s=stable  all=all tiers")
        return true
    end
end)

-- ── STARTUP ───────────────────────────────────────────────────────────
client.set_event_callback("shutdown", function()
    rawset(_G,"_vis",nil)
end)
client.delay_call(0.1, function()
    if _vis then _vis:set(false) end
end)

client.color_log(255,160,60,"[Zenith] Dev Panel loaded. Enter password + click Verify, then type zn_help.")
