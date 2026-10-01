-- ======================================================================
--  SPECTER | Desync Resolver
--
--  A standalone gamesense script that does one thing: it resolves the desync (body yaw) of the enemies.
--  No anti-aim, no visuals, no login. Menu: RAGE > Other > "Specter desync resolver".
--
--  How it works
--    * every enemy update the target is classified (static / jitter / desync jitter / shifting tickbase) and
--      an angle is picked from a set of "arms": freestand side, half / low angles, the angle that last hit,
--      the networked body yaw pose, a copy of the server's feet yaw logic ("feet model"), a hold of the last
--      good angle while the target shifts its tickbase, and the native resolver as a fallback arm
--    * which arm works is learned per player and per context from your own shots, backed by what worked on
--      everybody else (and remembered between sessions). A shot is judged by the angle the record it went
--      at really got, not by what is forced at the moment of firing
--    * FFI (optional, validated against the netvars, switches itself off on any problem): server animation
--      layers (realign tracking) and the client animstate (polarity of the forced values)
--    * high ping profile from 35 ms (automatic), safe point / body aim when the resolver is not sure
-- ======================================================================

local VERSION = "1.0"

local ffi_loaded, ffi = pcall(require, "ffi")
if not ffi_loaded then ffi = nil end

local math_floor, math_ceil, math_abs, math_min, math_max, math_sqrt = math.floor, math.ceil, math.abs, math.min, math.max, math.sqrt
local string_format = string.format
local table_insert, table_remove, table_sort = table.insert, table.remove, table.sort

local entity_get_prop, entity_get_local_player, entity_get_player_name = entity.get_prop, entity.get_local_player, entity.get_player_name
local globals_tickcount, globals_tickinterval, globals_curtime, globals_realtime = globals.tickcount, globals.tickinterval, globals.curtime, globals.realtime

-- ── helpers ──────────────────────────────────────────────────────────────
local function clamp(v, lo, hi)
    if v ~= v then return lo end
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function finite(v)
    return type(v) == "number" and v == v and v > -1e9 and v < 1e9
end

-- any angle -> [-180, 180); NaN / inf can never loop or leak
local function normalize_yaw(a)
    if a ~= a or a == math.huge or a == -math.huge then return 0 end
    return (a + 180) % 360 - 180
end

local function approach_angle(target, value, step)
    local d = normalize_yaw(target - value)
    if d > step then return normalize_yaw(value + step) end
    if d < -step then return normalize_yaw(value - step) end
    return normalize_yaw(target)
end

local function to_set(list)
    local s = {}
    if type(list) == "table" then
        for _, v in ipairs(list) do s[v] = true end
    end
    return s
end

local function say(msg)
    client.color_log(180, 160, 255, "specter resolver  \0")
    client.color_log(255, 255, 255, msg)
end

-- ── menu ─────────────────────────────────────────────────────────────────
local OPTION_LIST = {
    "Jitter fix", "Defensive fix", "Defensive snap fix", "LC: body aim",
    "Safe point on misses", "Body aim on misses", "Native fallback", "Remember learning", "ESP flags", "Log",
}
local OPTION_DEFAULT = {
    "Jitter fix", "Defensive fix", "Defensive snap fix", "LC: body aim",
    "Safe point on misses", "Body aim on misses", "Native fallback", "Remember learning", "Log",
}
local OPT_LAYERS, OPT_MODEL, OPT_APPLY, OPT_TELE = "Animation layers", "Feet model", "Animstate apply (experimental)", "Telemetry"
local FFI_LIST = { OPT_LAYERS, OPT_MODEL, OPT_APPLY, OPT_TELE }
local FFI_DEFAULT = { OPT_LAYERS, OPT_MODEL }

local TAB, BOX = "RAGE", "Other"
local U = {}
U.enable = ui.new_checkbox(TAB, BOX, "Specter desync resolver")
U.options = ui.new_multiselect(TAB, BOX, "Resolver options", OPTION_LIST)
U.safe_after = ui.new_slider(TAB, BOX, "Safe point after misses", 1, 5, 2)
U.baim_after = ui.new_slider(TAB, BOX, "Body aim after misses", 1, 6, 3)
U.ping_mode = ui.new_combobox(TAB, BOX, "Ping profile", { "Auto", "Low ping", "High ping" })
U.ping_thr = ui.new_slider(TAB, BOX, "High ping from", 15, 120, 35, true, "ms")
U.ffi = ui.new_multiselect(TAB, BOX, "FFI resolver", FFI_LIST)
U.flip = ui.new_hotkey(TAB, BOX, "Flip side on target")
U.debug = ui.new_multiselect(TAB, BOX, "Resolver debugger", { "Panel", "Console" })
local on_reset_pressed
U.reset = ui.new_button(TAB, BOX, "Reset resolver memory", function() if on_reset_pressed then on_reset_pressed() end end)
ui.set(U.options, OPTION_DEFAULT)
ui.set(U.ffi, FFI_DEFAULT)

-- selected options as sets, refreshed once per update (the menu is not read in the middle of a pass)
local O, FO, DO = to_set(OPTION_DEFAULT), to_set(FFI_DEFAULT), {}
local function refresh_options()
    O, FO, DO = to_set(ui.get(U.options)), to_set(ui.get(U.ffi)), to_set(ui.get(U.debug))
end

local function update_menu()
    local on = ui.get(U.enable)
    for _, key in ipairs({ "options", "ping_mode", "ffi", "flip", "debug", "reset" }) do
        ui.set_visible(U[key], on)
    end
    local o = to_set(ui.get(U.options))
    ui.set_visible(U.safe_after, on and o["Safe point on misses"] == true)
    ui.set_visible(U.baim_after, on and o["Body aim on misses"] == true)
    ui.set_visible(U.ping_thr, on and ui.get(U.ping_mode) == "Auto")
end
ui.set_callback(U.enable, update_menu)
ui.set_callback(U.options, update_menu)
ui.set_callback(U.ping_mode, update_menu)
update_menu()

-- ── constants ────────────────────────────────────────────────────────────
local RECORDS       = 32      -- eye angle records kept per player
local DEF_CAP       = 14      -- most ticks one tickbase shift keeps "shifting" on
local FS_INTERVAL   = 4       -- ticks between freestand traces
local TRACE_OFFSET  = 22
local JIT_ENTER     = 32      -- yaw spread that makes a target a jitterer
local JIT_EXIT      = 22      -- and the spread it needs to stay one
local HIST_SIZE     = 64      -- applied overrides remembered per player (shot attribution)
local MAX_YAW       = 58      -- aim yaw max of the animstate
local LC_SQ_BASE    = 4096    -- squared origin jump (64 units) that breaks lag compensation
local LC_TICKS_BASE = 10
local RESOLVER_MISS = { ["?"] = true, resolver = true }
local PRIOR_KEY     = "specter_desync_resolver_priors"
local PRIOR_VERSION = 3

-- state shared by everything below
local R = {
    database = {}, memory = {}, miss_count = {}, hit_count = {},
    forced = {}, forced_sp = {}, forced_ba = {}, forced_pitch = {}, correction_saved = {},
    shots = {}, debug_log = {}, next_shot_id = 0,
    global = {},            -- session-wide arm results per context, the prior of every new target
    feet_global = {},       -- how often the feet model hit, per choke class
    session = { shots = 0, hits = 0, misses = 0 },
    dyn_global = { hit = { n = 0, f = 0 }, miss = { n = 0, f = 0 } },    -- side switches after a hit / miss, everybody
    dirty = false, last_save = 0,
}

-- ── ping profiles ────────────────────────────────────────────────────────
-- "low" below the threshold, "high" above it (switched automatically). At high ping our view of the target is
-- older and shot feedback arrives later: react slower, hedge with half angles, safe point / body aim earlier.
local PROFILES = {
    low = {
        name = "low", window = 10, shift_tol = 0, def_pad = 2,
        decay_player = 0.90, decay_global = 0.97, prior_n = 2, miss_w = 1.0, stale_base = 10,
        half_bias = 0, sp_off = 0, ba_off = 0, conf_sp = 0.30, conf_ba = 0.22,
    },
    high = {
        name = "high", window = 12, shift_tol = 1, def_pad = 4,
        decay_player = 0.93, decay_global = 0.985, prior_n = 3, miss_w = 0.75, stale_base = 14,
        half_bias = 0.06, sp_off = -1, ba_off = -1, conf_sp = 0.36, conf_ba = 0.27,
    },
}
local profile = PROFILES.low
local ping = { ms = 0, lat_ms = 0, ticks = 0, high = false, tick = -1000 }

local function log(fmt, ...)
    if not O["Log"] then return end
    say(string_format(fmt, ...))
end

local function tick_of(sim)
    return math_floor(sim / globals_tickinterval() + 0.5)
end

local function jit_group(stance)
    return stance == "air" and "air" or "ground"
end

-- the ping the player sees on the scoreboard; the net channel latency when it is not there yet
local function read_ping_ms()
    local ms, lat_ms = 0, 0
    local ok, lat = pcall(client.latency)
    if ok and type(lat) == "number" and lat == lat and lat > 0 then lat_ms = lat * 1000 end
    local me = entity_get_local_player()
    local pr = me and entity.get_player_resource and entity.get_player_resource()
    if pr then
        local ok2, v = pcall(entity_get_prop, pr, "m_iPing", me)
        if ok2 and type(v) == "number" and v == v and v > 0 then ms = v end
    end
    return math_max(ms, lat_ms), lat_ms
end

-- Auto switches to "high" at the threshold (35 ms by default) and only drops back 4 ms below it,
-- so a ping hovering around the limit does not flap
local function refresh_ping(force)
    local tick = globals_tickcount()
    if not force and tick >= ping.tick and tick - ping.tick < 16 then return end
    ping.tick = tick

    local ms, lat_ms = read_ping_ms()
    ping.ms = ping.ms > 0 and (ping.ms * 0.5 + ms * 0.5) or ms
    ping.lat_ms = lat_ms
    ping.ticks = math_ceil(math_max(lat_ms, 0) / 1000 / globals_tickinterval())

    local mode, thr = ui.get(U.ping_mode), ui.get(U.ping_thr)
    local high
    if mode == "High ping" then
        high = true
    elseif mode == "Low ping" then
        high = false
    elseif ping.high then
        high = ping.ms >= thr - 4
    else
        high = ping.ms >= thr
    end

    if high ~= ping.high then
        ping.high = high
        profile = high and PROFILES.high or PROFILES.low
        log("ping %d ms -> %s ping profile", math_floor(ping.ms + 0.5), profile.name)
    end
end

local function stale_threshold()
    return math_max(profile.stale_base, profile.stale_base + ping.ticks - 2)
end

-- ── arms ─────────────────────────────────────────────────────────────────
-- Every way the resolver can pick an angle. Learned per player and per context:
--   s|<stance>  static desync      j|ground / j|air  jitter      d|s / d|j  while the target shifts its tickbase
local STATIC_ARMS = {
    { pol =  1, frac = 1,    name = "fs full"  },
    { pol = -1, frac = 1,    name = "opp full" },
    { pol =  1, frac = 0.5,  name = "fs half"  },
    { pol = -1, frac = 0.5,  name = "opp half" },
    { pol =  0, frac = 0,    name = "zero"     },
    { src = "db",            name = "db hit"   },
    { src = "pose", pol =  1, name = "pose"     },
    { src = "pose", pol = -1, name = "pose inv" },
    { pol =  1, frac = 0.25, name = "fs low"   },
    { pol = -1, frac = 0.25, name = "opp low"  },
    { src = "feet", pol =  1, name = "feet"     },
    { src = "feet", pol = -1, name = "feet inv" },
    { src = "native",        name = "native"   },
    { src = "dyn",           name = "flip pattern" },
}
local JITTER_ARMS = {
    { next = false, pol =  1, frac = 1,   name = "cur +"     },
    { next = false, pol = -1, frac = 1,   name = "cur -"     },
    { next = true,  pol =  1, frac = 1,   name = "next +"    },
    { next = true,  pol = -1, frac = 1,   name = "next -"    },
    { next = false, pol =  1, frac = 0.6, name = "cur + low" },
    { next = false, pol = -1, frac = 0.6, name = "cur - low" },
    { src = "zero",                       name = "zero"      },
    { src = "feet", pol =  1,             name = "feet"      },
    { src = "feet", pol = -1,             name = "feet inv"  },
    { src = "native",                     name = "native"    },
}
local DEF_ARMS = {
    { src = "hold", pol =  1, frac = 1,   name = "hold"      },
    { src = "hold", pol =  1, frac = 0.5, name = "hold half" },
    { src = "hold", pol = -1, frac = 1,   name = "hold flip" },
    { src = "zero",                       name = "zero"      },
    { src = "fresh",                      name = "fresh"     },
    { src = "native",                     name = "native"    },
}
local ARM_LISTS = { s = STATIC_ARMS, j = JITTER_ARMS, d = DEF_ARMS }

-- score offsets: the order of the first guesses, plus what the animation layers tell us
local GUESS_ARMS = { 1, 2, 3, 4, 6, 9, 10 }     -- static arms that are guesses at a side (the side prior steers these)
local STATIC_BIAS = { 0, -0.02, -0.04, -0.06, -0.12, 0.05, 0, 0, -0.14, -0.15, 0, 0, -0.10, 0 }
local LOW_BIAS    = { -0.15, -0.15, 0.20, 0.20, 0.05, 0, 0, 0, 0.26, 0.26 }    -- no realign for a while: small desync
local FULL_BIAS   = {  0.10,  0.10, -0.12, -0.12, -0.25, 0, 0, 0, -0.10, -0.10 } -- realign just played: desync > 35
local JITTER_BIAS = { 0, 0, 0, 0, -0.03, -0.03, -0.10, 0, 0, -0.10 }
local DEF_BIAS    = { 0.10, 0.04, -0.02, -0.04, 0, -0.12 }

local function arm_name(ctx, arm)
    if not ctx or not arm then return "-" end
    local list = ARM_LISTS[ctx:sub(1, 1)] or STATIC_ARMS
    return list[arm] and list[arm].name or tostring(arm)
end

-- ── learning ─────────────────────────────────────────────────────────────
local function arm_table(store, ctx, n)
    local t = store[ctx]
    if not t then t = {}; store[ctx] = t end
    for i = 1, n do t[i] = t[i] or { s = 0, f = 0 } end
    return t
end

local function wild(ctx) return ctx:sub(1, 1) .. "|*" end

-- mean hit rate of an arm: the target's own shots, backed by what worked on everybody else
local function arm_score(m, ctx, i, n)
    local own = arm_table(m.arms, ctx, n)[i]
    local g = arm_table(R.global, ctx, n)[i]
    local w = arm_table(R.global, wild(ctx), n)[i]
    local prior = (g.s + w.s + 1) / (g.s + g.f + w.s + w.f + 2)
    return (own.s + profile.prior_n * prior) / (own.s + own.f + profile.prior_n)
end

-- the best available arm; also returns its unbiased score as the confidence of the pick
local function arm_pick(m, ctx, n, bias, avail)
    local best, best_score, best_raw = nil, -math.huge, 0.5
    for i = 1, n do
        if not avail or avail[i] then
            local raw = arm_score(m, ctx, i, n)
            local sc = raw + (bias and bias[i] or 0) - i * 0.001
            if sc > best_score then best, best_score, best_raw = i, sc, raw end
        end
    end
    return best or 1, best_raw
end

local function arm_learn(m, ctx, i, n, hit, weight)
    weight = weight or 1
    local own = arm_table(m.arms, ctx, n)
    local g = arm_table(R.global, ctx, n)
    local w = arm_table(R.global, wild(ctx), n)
    local dp, dg = profile.decay_player, profile.decay_global
    for k = 1, n do
        own[k].s, own[k].f = own[k].s * dp, own[k].f * dp
        g[k].s, g[k].f = g[k].s * dg, g[k].f * dg
        w[k].s, w[k].f = w[k].s * dg, w[k].f * dg
    end
    if hit then
        own[i].s, g[i].s, w[i].s = own[i].s + weight, g[i].s + weight * 0.5, w[i].s + weight * 0.5
    else
        own[i].f, g[i].f, w[i].f = own[i].f + weight, g[i].f + weight * 0.5, w[i].f + weight * 0.5
    end
    R.dirty = true
end

-- how often the feet model hit, per choke class (n: no choke, m: some, h: a lot). A target that chokes moves
-- its feet through updates we never see, so the model is only worth following where it keeps hitting.
local function choke_class(choke)
    if choke <= 1 then return "n" end
    if choke <= 5 then return "m" end
    return "h"
end

local function feet_rate(store, class)
    local t = store[class]
    if not t then return nil end
    local total = t.s + t.f
    if total < 3 then return nil end
    return (t.s + 1) / (total + 2)
end

local function feet_learn(store, class, hit)
    local t = store[class]
    if not t then t = { s = 0, f = 0 }; store[class] = t end
    t.s, t.f = t.s * 0.98, t.f * 0.98
    if hit then t.s = t.s + 1 else t.f = t.f + 1 end
end

-- remembered between sessions: the global priors, so the first shots of a new session are informed too
local function save_priors()
    if not O["Remember learning"] then return end
    local snapshot = { v = PRIOR_VERSION, arms = {}, feet = {} }
    for ctx, list in pairs(R.global) do
        local arms = ARM_LISTS[ctx:sub(1, 1)]
        if arms and #list == #arms then
            local out = {}
            for i = 1, #arms do out[i] = { s = list[i].s, f = list[i].f } end
            snapshot.arms[ctx] = out
        end
    end
    for class, t in pairs(R.feet_global) do snapshot.feet[class] = { s = t.s, f = t.f } end
    pcall(database.write, PRIOR_KEY, snapshot)
    R.dirty, R.last_save = false, globals_realtime()
end

local function load_priors()
    local ok, saved = pcall(database.read, PRIOR_KEY)
    if not ok or type(saved) ~= "table" or saved.v ~= PRIOR_VERSION then return end
    local scale = 0.6      -- yesterday's server is not today's: it is a prior, not a verdict
    if type(saved.arms) == "table" then
        for ctx, list in pairs(saved.arms) do
            local arms = type(ctx) == "string" and ARM_LISTS[ctx:sub(1, 1)]
            if arms and type(list) == "table" then
                local good = true
                for i = 1, #arms do
                    local a = list[i]
                    if type(a) ~= "table" or not finite(a.s) or not finite(a.f) then good = false; break end
                end
                if good then
                    local t = arm_table(R.global, ctx, #arms)
                    for i = 1, #arms do
                        t[i].s, t[i].f = clamp(list[i].s * scale, 0, 8), clamp(list[i].f * scale, 0, 8)
                    end
                end
            end
        end
    end
    if type(saved.feet) == "table" then
        for class, t in pairs(saved.feet) do
            if type(t) == "table" and finite(t.s) and finite(t.f) then
                R.feet_global[class] = { s = clamp(t.s * scale, 0, 8), f = clamp(t.f * scale, 0, 8) }
            end
        end
    end
end


-- ── players ──────────────────────────────────────────────────────────────
-- what is remembered about a player across rounds is keyed by steam id (names change, ids do not)
local function member_key(idx)
    local ok, sid = pcall(entity.get_steam64, idx)
    if ok and sid ~= nil and sid ~= 0 and tostring(sid) ~= "0" then return "id" .. tostring(sid) end
    return "n" .. tostring(entity_get_player_name(idx) or idx)
end

local function new_data(idx)
    return {
        key = idx, records = {}, hist = {}, last_sim = nil, max_st = nil, last_origin = nil,
        def_until = 0, def_reason = nil, def_rate = 0, lc_until = 0,
        stance = "stand", used_stance = "stand", speed = 0, max_desync = MAX_YAW, choke = 0,
        is_jitter = false, yaw_jitter = false, jitter_kind = "static", jitter_regular = false, jitter_period = 1,
        jitter_ratio = 0, jitter_side = 0, jitter_next = 0, jitter_amp = 0, jitter_run = 1, jitter_flips = 0, spread = 0,
        clean_count = 0, freestand = 0, fs_pending = 0,
        is_shifting = false, pitch_snap = false, real_pitch = 89, lc_break = false,
        confidence = 0, consecutive_misses = 0, last_reason = "native", meta_type = "normal",
        pose = nil, pose_ok = false, pose_jit_on = false,
        low_desync = false, bal_recent = false, arm_conf = nil, def_conf = nil, new_record = false,
        feet = nil, feet_st = nil, model_body = 0, model_ok = false,
        fx = nil, fx_delta = nil, act_cache = {}, adj_prev_active = false, realign_tick = nil, realign_gap = nil, still_s = nil,
    }
end

local function new_memory(key, name)
    return {
        key = key, name = name, hit_value = {}, arms = {}, learn_time = {},
        hits = 0, resolver_misses = 0, streak = 0, def_misses_round = 0, lc_misses_round = 0,
        feet = {},                       -- this player's feet model results per choke class
        arm_streak = {},                 -- consecutive misses with the same arm, per context
        stay = { n = 0, ok = 0 },        -- does the same arm still hit right after it hit?
        anti_stay = false, after_hit = nil, probe = 0,
        dyn = {}, shot_seq = 0,          -- side tracking per stance, number of shots fired at this player
    }
end

local function init_player(idx)
    local data = R.database[idx]
    if not data then
        data = new_data(idx)
        R.database[idx] = data
    end
    local tick = globals_tickcount()
    if not data.mkey or tick - (data.mkey_tick or 0) > 128 or tick < (data.mkey_tick or 0) then
        data.mkey, data.mkey_tick = member_key(idx), tick
    end
    local m = R.memory[data.mkey]
    if not m then
        m = new_memory(data.mkey, entity_get_player_name(idx))
        R.memory[data.mkey] = m
    end
    R.miss_count[idx] = R.miss_count[idx] or 0
    R.hit_count[idx] = R.hit_count[idx] or 0
    return data, m
end

local function get_stance(idx)
    local flags = entity_get_prop(idx, "m_fFlags") or 0
    if bit.band(flags, 1) == 0 then return "air" end
    if (entity_get_prop(idx, "m_flDuckAmount") or 0) > 0.7 then return "duck" end
    local vx, vy = entity_get_prop(idx, "m_vecVelocity")
    if vx and vy and math_sqrt(vx * vx + vy * vy) > 5 then return "move" end
    return "stand"
end

-- which side of the enemy's head is covered from our eye (1 / -1, 0 = no difference)
local function freestand_side(idx, me)
    local hx, hy, hz = entity.hitbox_position(idx, 0)
    local mx, my, mz = client.eye_position()
    if not hx or not mx then return 0 end
    local dx, dy = mx - hx, my - hy
    local len = math_sqrt(dx * dx + dy * dy)
    if len < 1 then return 0 end
    local ux, uy = -dy / len, dx / len
    local left, right = 0, 0
    for _, off in ipairs({ TRACE_OFFSET * 0.6, TRACE_OFFSET * 1.2 }) do
        for _, h in ipairs({ 0, -8 }) do
            left  = left  + (client.trace_line(me, hx + ux * off, hy + uy * off, hz + h, mx, my, mz) or 1)
            right = right + (client.trace_line(me, hx - ux * off, hy - uy * off, hz + h, mx, my, mz) or 1)
        end
    end
    if math_abs(left - right) < 0.3 then return 0 end
    return left < right and 1 or -1
end

-- networked body yaw pose parameter in degrees (-60..60). Never trusted blindly: whether it is the real
-- server value (or just gamesense's own animation) is decided by the shots through the "pose" arms.
local function read_pose(idx)
    local ok, v = pcall(entity_get_prop, idx, "m_flPoseParameter", 11)
    if not ok or type(v) ~= "number" or v ~= v or v < 0 or v > 1 then return nil end
    return (v - 0.5) * 120
end

-- ── FFI ──────────────────────────────────────────────────────────────────
-- Reads what the server networked about the enemy's animation (animation layers) and what the client animstate
-- shows. Everything here is optional: any failure only switches this part off and the resolver keeps running on
-- netvars + learning. Reads are pointer-checked, the animstate layout is verified against the netvars before it is
-- trusted, and nothing is ever written unless "Animstate apply" is on AND the layout checked out.
local F = {
    types_ok = false, disabled = false, errors = 0, last_note = "", layers_broken = false, layer_bad = 0,
    layout = "unknown",
    y_n = 0, y_rate = 0, p_n = 0, p_rate = 0, g_n = 0, goal_rate = 0,
    pol_n = 0, pol_ema = 0, polarity = nil, apply_err = nil, writes = 0,
    get_entity = nil, layers_off = nil, get_activity = nil,
}
local ANIM_OFF, STUDIO_OFF = 0x9960, 0x2950      -- m_PlayerAnimState / the studio header of a client entity
local ACT_BALANCE_ADJUST = 979                   -- the feet realign with the eye yaw
local ADDR_MAX = (ffi and ffi.abi("32bit")) and 0x7FFE0000 or 0x7FFFFFFFFFFF

local function ptr_ok(p)
    if p == nil or not ffi then return false end
    local addr = tonumber(ffi.cast("uintptr_t", p))
    return addr ~= nil and addr >= 0x10000 and addr <= ADDR_MAX
end

if ffi then
    local ok = pcall(function()
        if not pcall(ffi.typeof, "sdr_animstate_t") then
            -- CCSGOPlayerAnimState up to on_ground (0x108). Pointer fields are plain ints: the same layout on any pointer size
            ffi.cdef[[
                typedef struct {
                    char         pad0[0x60];
                    unsigned int base_entity;       // 0x60
                    unsigned int active_weapon;     // 0x64
                    unsigned int last_weapon;       // 0x68
                    float        last_update_time;  // 0x6C
                    int          last_update_frame; // 0x70
                    float        last_update_inc;   // 0x74
                    float        eye_yaw;           // 0x78
                    float        eye_pitch;         // 0x7C
                    float        goal_feet_yaw;     // 0x80
                    float        cur_feet_yaw;      // 0x84
                    float        torso_yaw;         // 0x88
                    float        unk_vel_lean;      // 0x8C
                    float        lean_amount;       // 0x90
                    float        unk94;             // 0x94
                    float        feet_cycle;        // 0x98
                    float        feet_yaw_rate;     // 0x9C
                    float        unkA0;             // 0xA0
                    float        duck_amount;       // 0xA4
                    float        landing_duck_add;  // 0xA8
                    float        unkAC;             // 0xAC
                    float        origin[3];         // 0xB0
                    float        last_origin[3];    // 0xBC
                    float        velocity[3];       // 0xC8
                    float        vel_norm[3];       // 0xD4
                    float        vel_norm_nz[3];    // 0xE0
                    float        vel_len_xy;        // 0xEC
                    float        vel_len_z;         // 0xF0
                    float        speed_run_frac;    // 0xF4
                    float        speed_walk_frac;   // 0xF8
                    float        speed_crouch_frac; // 0xFC
                    float        duration_moving;   // 0x100
                    float        duration_still;    // 0x104
                    bool         on_ground;         // 0x108
                    bool         in_hit_ground;     // 0x109
                } sdr_animstate_t;
            ]]
        end
        if not pcall(ffi.typeof, "sdr_animlayer_t") then
            ffi.cdef[[
                typedef struct {
                    float anim_time; float fade_out_time; int dispatched_hdr; int dispatched_src; int dispatched_dst;
                    int order; int sequence; float prev_cycle; float weight; float weight_delta_rate;
                    float playback_rate; float cycle; int owner; int bits;
                } sdr_animlayer_t;
            ]]
        end
        -- a typo in the structs above must not turn into a wrong read in game
        local expect = {
            eye_yaw = 0x78, eye_pitch = 0x7C, goal_feet_yaw = 0x80, cur_feet_yaw = 0x84, duck_amount = 0xA4,
            vel_len_xy = 0xEC, duration_moving = 0x100, duration_still = 0x104, on_ground = 0x108,
        }
        for name, off in pairs(expect) do
            if ffi.offsetof("sdr_animstate_t", name) ~= off then error("struct offset " .. name) end
        end
        if ffi.sizeof("sdr_animlayer_t") ~= 56 or ffi.offsetof("sdr_animlayer_t", "weight") ~= 32 then error("layer struct") end
    end)
    F.types_ok = ok

    if ok then
        local vb = rawget(_G, "vtable_bind")
        if type(vb) == "function" then
            local ok2, fn = pcall(vb, "client.dll", "VClientEntityList003", 3, "void*(__thiscall*)(void***, int)")
            if ok2 and type(fn) == "function" then F.get_entity = fn end
        end

        local ok3, off = pcall(function()
            local sig = client.find_signature("client.dll", "\x8B\x89\xCC\xCC\xCC\xCC\x8D\x0C\xD1")
            if not sig then return nil end
            return ffi.cast("int*", ffi.cast("uintptr_t", sig) + 2)[0]
        end)
        if ok3 and type(off) == "number" and off > 0x1000 and off < 0xA000 then F.layers_off = off end

        pcall(function()
            if not pcall(ffi.typeof, "sdr_get_sequence") then
                ffi.cdef("typedef int(__fastcall* sdr_get_sequence)(void* entity, void* studio_hdr, int sequence);")
            end
        end)
        local ok4, fnp = pcall(function()
            local sig = client.find_signature("client.dll", "\x55\x8B\xEC\x53\x8B\x5D\x08\x56\x8B\xF1\x83")
            if not sig then return nil end
            return ffi.cast("sdr_get_sequence", sig)
        end)
        if ok4 and fnp ~= nil then F.get_activity = fnp end
    end
end

local function ffi_fail(why)
    F.errors = F.errors + 1
    F.last_note = tostring(why)
    if F.errors > 25 and not F.disabled then
        F.disabled = true
        say(string_format("FFI part: too many errors (%s) - it is off, the resolver keeps running without it", tostring(why)))
    end
end

local function layer_sane(l)
    local w, c = l.weight, l.cycle
    return w == w and c == c and w >= -0.01 and w <= 1.01 and c >= -0.01 and c <= 1.01
end

-- one read of the server animation layers and the client animstate of an enemy
local function ffi_sample(idx, data)
    if F.disabled or not F.get_entity then return nil end
    local use_layers = FO[OPT_LAYERS] and F.layers_off and F.get_activity and not F.layers_broken
    local use_anim = F.types_ok and F.layout ~= "bad" and (FO[OPT_MODEL] or FO[OPT_APPLY] or FO[OPT_TELE])
    if not use_layers and not use_anim then return nil end

    local ok, fx = pcall(function()
        -- everything below adds an offset to this pointer and dereferences the result: a NULL entity never gets that far
        local ent = F.get_entity(idx)
        if not ptr_ok(ent) then return nil end
        local base = ffi.cast("uintptr_t", ent)
        local fx = {}

        if use_layers then
            local layers = ffi.cast("sdr_animlayer_t**", base + F.layers_off)[0]
            if ptr_ok(layers) then
                local l3, l6, l7, l12 = layers[3], layers[6], layers[7], layers[12]
                if layer_sane(l3) and layer_sane(l6) then
                    fx.layers = true
                    fx.adj_w, fx.adj_cycle, fx.adj_seq = l3.weight, l3.cycle, l3.sequence
                    fx.mov_w, fx.mov_rate, fx.mov_seq = l6.weight, l6.playback_rate, l6.sequence
                    fx.str_w, fx.lean_w = l7.weight, l12.weight
                    -- which activity the adjust layer runs (native lookup, cached per sequence)
                    fx.adj_act = 0
                    if fx.adj_w > 0.01 and fx.adj_cycle < 0.99 then
                        local act = data.act_cache[fx.adj_seq]
                        if act == nil then
                            local studio = ffi.cast("void**", base + STUDIO_OFF)[0]
                            act = ptr_ok(studio) and F.get_activity(ent, studio, fx.adj_seq) or -1
                            data.act_cache[fx.adj_seq] = act
                        end
                        fx.adj_act = act
                    end
                else
                    F.layer_bad = F.layer_bad + 1
                    if F.layer_bad > 40 then F.layers_broken = true end
                end
            end
        end

        if use_anim then
            local a = ffi.cast("sdr_animstate_t**", base + ANIM_OFF)[0]
            if ptr_ok(a) then
                local eye, goal, pit = a.eye_yaw, a.goal_feet_yaw, a.eye_pitch
                if eye == eye and goal == goal and pit == pit and eye > -1e4 and eye < 1e4 and goal > -1e4 and goal < 1e4
                    and pit > -1e4 and pit < 1e4 then
                    fx.anim = true
                    fx.a_eye, fx.a_goal, fx.a_cur, fx.a_pitch = eye, goal, a.cur_feet_yaw, pit
                    fx.a_still, fx.a_moving, fx.a_vel = a.duration_still, a.duration_moving, a.vel_len_xy
                end
            end
        end
        return fx
    end)
    if not ok then
        ffi_fail(fx)
        return nil
    end
    return fx
end

-- does the animstate eye yaw / pitch belong to one of the last records (netvars)?
local function eye_matches(data, a_eye, a_pitch)
    local recs = data.records
    local n = #recs
    local yaw_inf, yaw_match, pit_inf, pit_match = false, false, false, false
    for i = math_max(1, n - 5), n do
        local e, pt = recs[i].eye, recs[i].pitch
        if e then
            if math_abs(e) >= 5 then yaw_inf = true end
            if math_abs(normalize_yaw(a_eye - e)) < 1.5 then yaw_match = true end
        end
        if pt and i >= n - 2 then
            if math_abs(pt) >= 5 then pit_inf = true end
            if math_abs(a_pitch - pt) < 2.5 then pit_match = true end
        end
    end
    return yaw_inf, yaw_match, pit_inf, pit_match
end

-- is the struct we read really the animstate? Its eye yaw and pitch have to be eye yaws / pitches the netvars just
-- showed, and the goal feet yaw can never be further than the max body yaw (58) away from the eye yaw. Only samples
-- where the netvar value is not ~0 prove anything (a zeroed or tiny-garbage struct would "match" a target that looks
-- straight ahead), so a layout is only accepted after enough of those.
local function ffi_validate(data, fx)
    if not fx.anim or F.layout == "bad" or #data.records < 2 then return end
    local yaw_inf, yaw_match, pit_inf, pit_match = eye_matches(data, fx.a_eye, fx.a_pitch)
    if yaw_inf then
        F.y_n = F.y_n + 1
        F.y_rate = F.y_rate + ((yaw_match and 1 or 0) - F.y_rate) * math_max(1 / F.y_n, 0.03)
    end
    if pit_inf then
        F.p_n = F.p_n + 1
        F.p_rate = F.p_rate + ((pit_match and 1 or 0) - F.p_rate) * math_max(1 / F.p_n, 0.03)
    end
    F.g_n = F.g_n + 1
    local goal_ok = math_abs(normalize_yaw(fx.a_eye - fx.a_goal)) <= 62
    F.goal_rate = F.goal_rate + ((goal_ok and 1 or 0) - F.goal_rate) * math_max(1 / F.g_n, 0.03)

    if F.y_n >= 16 then
        local pitch_known = F.p_n >= 8
        local pitch_good = not pitch_known or F.p_rate >= 0.7
        local pitch_bad = pitch_known and (F.p_rate < 0.4 or (F.layout == "ok" and F.p_rate < 0.5))
        if F.layout ~= "ok" and F.y_rate >= 0.75 and F.goal_rate >= 0.9 and pitch_good then
            F.layout = "ok"
            say(string_format("FFI part: animstate layout verified (eye yaw %d%%, pitch %s)", math_floor(F.y_rate * 100),
                pitch_known and (math_floor(F.p_rate * 100) .. "%") or "n/a"))
        elseif F.y_rate <= 0.3 or F.goal_rate < 0.6 or pitch_bad or (F.layout == "ok" and F.y_rate < 0.4) then
            F.layout = "bad"
            say(string_format("FFI part: animstate layout does NOT match this build (eye yaw %d%%, feet %d%%) - animstate reads and apply are off",
                math_floor(F.y_rate * 100), math_floor(F.goal_rate * 100)))
        end
    end
end

-- everything derived from one sample: realign tracking (layer 3), animstate checks, polarity of the forced values
local function ffi_observe(idx, data, fx, tick)
    data.fx = fx
    data.layers_ok = fx ~= nil and fx.layers == true
    if fx == nil then return end

    if fx.layers then
        local active = fx.adj_act == ACT_BALANCE_ADJUST
        if active then
            data.balance_tick = tick
            if not data.adj_prev_active then
                -- rising edge: the feet start turning towards the eye yaw now
                if data.realign_tick then
                    local gap = (tick - data.realign_tick) * globals_tickinterval()
                    data.realign_gap = data.realign_gap and (data.realign_gap * 0.5 + gap * 0.5) or gap
                end
                data.realign_tick = tick
            end
        end
        data.adj_prev_active = active
    end

    if fx.anim then
        ffi_validate(data, fx)
        data.still_s = fx.a_still
        -- the body yaw the client animstate shows, against the value that was forced while it was produced.
        -- Whether gamesense leaves its forced value in the animstate decides if this means anything: the polarity
        -- is only taken over when the two clearly follow each other.
        local delta = normalize_yaw(fx.a_eye - fx.a_goal)
        data.fx_delta = delta
        local f = R.forced[idx]
        if F.layout == "ok" and f ~= nil and math_abs(f) >= 15 and math_abs(delta) >= 8 then
            local agree = ((f > 0) == (delta > 0)) and 1 or -1
            F.pol_n = F.pol_n + 1
            F.pol_ema = F.pol_ema + (agree - F.pol_ema) * math_max(1 / F.pol_n, 0.04)
            local err = math_abs(math_abs(delta) - math_abs(f))
            F.apply_err = F.apply_err and (F.apply_err * 0.9 + err * 0.1) or err
            if F.pol_n >= 30 and math_abs(F.pol_ema) >= 0.5 then
                F.polarity = F.pol_ema > 0 and 1 or -1
            else
                F.polarity = nil
            end
        end
    end
end

-- experimental: put the resolved body yaw straight into the client animstate (goal + current feet yaw).
-- Never runs unless "Animstate apply" is on and the animstate layout was verified (and re-checked right before the write).
local function ffi_apply(idx, data, value)
    if value == nil or F.disabled or F.layout ~= "ok" or F.y_n < 40 or data.is_shifting then return end
    if not FO[OPT_APPLY] or not (data.fx and data.fx.anim) or not F.get_entity then return end
    local ok, err = pcall(function()
        local ent = F.get_entity(idx)
        if not ptr_ok(ent) then return end
        local a = ffi.cast("sdr_animstate_t**", ffi.cast("uintptr_t", ent) + ANIM_OFF)[0]
        if not ptr_ok(a) then return end
        local eye, pit = a.eye_yaw, a.eye_pitch
        if eye ~= eye or eye < -1e4 or eye > 1e4 or pit ~= pit or pit < -1e4 or pit > 1e4 then return end
        -- the struct must still look like this player's animstate right now, not just when it was verified
        local _, yaw_match, _, pit_match = eye_matches(data, eye, pit)
        if not yaw_match or not pit_match or math_abs(normalize_yaw(eye - a.goal_feet_yaw)) > 62 then return end
        local feet = normalize_yaw(eye - (F.polarity or 1) * clamp(value, -60, 60))
        a.goal_feet_yaw = feet
        a.cur_feet_yaw = feet
        F.writes = F.writes + 1
    end)
    if not ok then ffi_fail(err) end
end

local function ffi_status(data)
    if F.disabled then return "off (errors)" end
    local s = F.layout
    if data and data.layers_ok then s = s .. " +layers" end
    return s
end

-- ── classification: static desync vs jitter (eye yaw or body yaw), current side, predicted next side ─
-- walks a side sequence (newest first) oldest -> newest: side changes, run lengths, length of the current run
local function runs_of(sides, n)
    local flips, runs, run, last = 0, {}, 0, 0
    for i = n, 1, -1 do
        local s = sides[i]
        if s ~= 0 then
            if last ~= 0 and s ~= last then
                flips = flips + 1
                runs[#runs + 1] = run
                run = 0
            end
            last, run = s, run + 1
        end
    end
    return flips, runs, run, last
end

-- period of the flips and whether they are regular. The oldest run is cut by the window, so it is ignored whenever
-- there is enough data.
local function run_period(runs)
    local first = #runs >= 3 and 2 or 1
    local sum, cnt = 0, 0
    for i = first, #runs do sum, cnt = sum + runs[i], cnt + 1 end
    if cnt == 0 then return 1, false, 1 end
    local avg = sum / cnt
    local var = 0
    for i = first, #runs do var = var + (runs[i] - avg) * (runs[i] - avg) end
    var = var / cnt
    return math_max(1, math_floor(avg + 0.5)), cnt >= 2 and var <= math_max(0.35, 0.2 * avg * avg), avg
end

local function predict_next(cur, run, period)
    if cur == 0 then return 0 end
    if run >= period then return -cur end
    return cur
end

local function analyze(data)
    local clean, r = {}, data.records
    for i = #r, 1, -1 do
        if not r[i].def then
            clean[#clean + 1] = r[i]            -- newest first
            if #clean >= profile.window then break end
        end
    end
    local n = #clean
    data.clean_count = n

    local ps = 0
    for i = 1, n do ps = ps + clean[i].pitch end
    data.real_pitch = n > 0 and clamp(ps / n, -89, 89) or 89

    if n < 3 then
        data.is_jitter, data.yaw_jitter, data.spread, data.jitter_flips = false, false, 0, 0
        data.jitter_ratio, data.jitter_side, data.jitter_next = 0, 0, 0
        data.jitter_kind, data.jitter_regular, data.jitter_period = "static", false, 1
        return
    end

    -- unwrap around the newest record so -179 / 179 don't look like a 358 jump
    local base = clean[1].rel
    local vals, lo, hi = {}, math.huge, -math.huge
    for i = 1, n do
        local v = base + normalize_yaw(clean[i].rel - base)
        vals[i] = v
        if v < lo then lo = v end
        if v > hi then hi = v end
    end
    local spread = hi - lo
    local mid = (lo + hi) * 0.5
    local dead = spread * 0.15

    local sides = {}
    for i = 1, n do
        local d = vals[i] - mid
        sides[i] = d > dead and 1 or (d < -dead and -1 or 0)
    end

    local flips, runs, run, last = runs_of(sides, n)
    local period, regular, avg_run = run_period(runs)

    -- eye yaw sitting on 3+ separate values (skitter / multi-way) is not a two-sided jitter
    local sorted = {}
    for i = 1, n do sorted[i] = vals[i] end
    table_sort(sorted)
    local gap, clusters = math_max(8, spread * 0.22), 1
    for i = 2, n do
        if sorted[i] - sorted[i - 1] > gap then clusters = clusters + 1 end
    end

    -- one turn (peek, flick) is a single flip; jitter keeps going back and forth
    local thr = data.yaw_jitter and JIT_EXIT or JIT_ENTER
    local yaw_jitter = spread >= thr and flips >= 2
    data.yaw_jitter = yaw_jitter
    data.spread, data.jitter_flips, data.jitter_run = spread, flips, avg_run
    data.jitter_ratio = flips / (n - 1)
    data.jitter_amp = spread * 0.5

    local cur = sides[1] ~= 0 and sides[1] or last
    local next_side = predict_next(cur, run, period)
    local kind = "static"
    if yaw_jitter then
        kind = clusters >= 3 and "multi" or (regular and "jitter" or "random")
    end

    -- desync jitter: the eye yaw is quiet but the networked body yaw keeps switching sides. The body yaw reading may
    -- just mirror what we forced ourselves, so it only starts counting when our own forced value was NOT flipping
    -- (that could explain the flips); once on it stays on while the flips go on.
    if yaw_jitter then data.pose_jit_on = false end
    if not yaw_jitter and data.pose_ok then
        local psides, pamp, pn = {}, 0, 0
        for i = 1, n do
            local p = clean[i].pose
            if p then
                pn = pn + 1
                if math_abs(p) > pamp then pamp = math_abs(p) end
                psides[i] = p > 8 and 1 or (p < -8 and -1 or 0)
            else
                psides[i] = 0
            end
        end
        local on = false
        if pn >= 5 then
            local pflips, pruns, prun, plast = runs_of(psides, n)
            local own_flips, prev_f = 0, nil
            for i = n, 1, -1 do
                local f = clean[i].fv
                if f ~= nil and prev_f ~= nil and math_abs(f - prev_f) >= 12 then own_flips = own_flips + 1 end
                prev_f = f
            end
            local start = pflips >= 3 and pamp >= 18 and own_flips <= 1
            local keep = data.pose_jit_on == true and pflips >= 2 and pamp >= 18
            if start or keep then
                on = true
                local pperiod, preg = run_period(pruns)
                local pcur = psides[1] ~= 0 and psides[1] or plast
                kind, cur, period, regular = "desync jitter", pcur, pperiod, preg
                next_side = predict_next(pcur, prun, pperiod)
            end
        end
        data.pose_jit_on = on
    end

    data.is_jitter = kind ~= "static"
    data.jitter_kind = kind
    data.jitter_side, data.jitter_next = cur, next_side
    data.jitter_period, data.jitter_regular = period, regular
end

-- ── feet yaw model ───────────────────────────────────────────────────────
-- How the server's animstate moves the feet, run on the netvars. Standing, the feet turn towards the lower body yaw
-- target (100 deg/s); moving, they follow the eye yaw (30-50 deg/s); they are never further than the max body yaw
-- away from the eye yaw. Eye yaw minus feet is the body yaw (desync) of that record.
local function feet_update(data, eye, lby, st, speed, maxd)
    if eye == nil then data.model_ok = false; return end
    local moving = speed > 5 or data.stance == "air"
    local target = moving and eye or lby
    if target == nil then data.model_ok = false; return end
    if data.feet == nil or data.feet_st == nil or st < data.feet_st then
        data.feet, data.feet_st = target, st
    end
    local dt = clamp((st - data.feet_st) * globals_tickinterval(), 0, 0.25)
    data.feet_st = st
    local rate = moving and (30 + 20 * clamp((speed - 70) / 65, 0, 1)) or 100
    data.feet = approach_angle(target, data.feet, rate * dt)
    local d = normalize_yaw(eye - data.feet)
    if d > maxd then
        data.feet = normalize_yaw(eye - maxd)
    elseif d < -maxd then
        data.feet = normalize_yaw(eye + maxd)
    end
    data.model_body = normalize_yaw(eye - data.feet)
    data.model_ok = true
end

-- ── observation: one pass per new network update of an enemy ────────────
local function update_player(idx, me)
    local data = init_player(idx)
    local tick = globals_tickcount()
    local sim = entity_get_prop(idx, "m_flSimulationTime")
    if not sim or sim ~= sim or sim <= 0 or sim > 1e9 then return data end
    local st = tick_of(sim)

    -- a real tickbase shift is at most ~17 ticks; anything bigger is a map change / reconnect
    if data.max_st and st < data.max_st - 32 then
        data.max_st, data.records, data.hist, data.last_sim = nil, {}, {}, nil
        data.feet, data.feet_st, data.act_cache = nil, nil, {}
    end

    -- speed, and the usable desync: it shrinks with speed (and with ducking while moving)
    local vx, vy = entity_get_prop(idx, "m_vecVelocity")
    local speed = (vx and vy) and math_sqrt(vx * vx + vy * vy) or 0
    if speed ~= speed then speed = 0 end
    speed = clamp(speed, 0, 320)
    data.speed = speed
    local duck = entity_get_prop(idx, "m_flDuckAmount") or 0
    local run = clamp(speed / 135, 0, 1)
    local avg = 1 - (0.2 + 0.3 * clamp((speed - 70) / 65, 0, 1)) * run
    if duck > 0 then avg = avg + duck * run * (0.5 - avg) end
    data.max_desync = clamp(math_floor(MAX_YAW * avg + 0.5), 20, MAX_YAW)

    data.new_record = false
    if data.last_sim == nil or st ~= data.last_sim then
        data.new_record = true
        -- the sim time of a shifted update goes back; at high ping allow a tick of slack before calling it a shift
        local shift_tol = profile.shift_tol + (ping.ticks >= 10 and 1 or 0)
        local shifted = data.max_st ~= nil and st + shift_tol <= data.max_st
        if data.max_st and st > data.max_st then
            data.choke = clamp(st - data.max_st - 1, 0, 64)
        end

        local pitch, eye_yaw = entity_get_prop(idx, "m_angEyeAngles")
        local ox, oy, oz = entity_get_prop(idx, "m_vecOrigin")
        local mx, my = entity_get_prop(me, "m_vecOrigin")
        if eye_yaw and not finite(eye_yaw) then eye_yaw = nil end
        if pitch and not finite(pitch) then pitch = nil end
        local lby_ok, lby = pcall(entity_get_prop, idx, "m_flLowerBodyYawTarget")
        if not lby_ok or not finite(lby) then lby = nil end

        -- lag compensation breaker: a jump bigger than the target could have walked since the last update
        local origin_ok = finite(ox) and finite(oy) and finite(oz)
        if not shifted and origin_ok and data.last_origin then
            local dx, dy, dz = ox - data.last_origin[1], oy - data.last_origin[2], oz - data.last_origin[3]
            local legit = speed * (data.choke + 1) * globals_tickinterval() * 1.4 + 20
            local lc_sq = math_max(LC_SQ_BASE + ping.ticks * ping.ticks * 16, legit * legit)
            local lc_window = math_max(LC_TICKS_BASE, 8 + ping.ticks)
            if dx * dx + dy * dy + dz * dz > lc_sq then data.lc_until = tick + lc_window end
        end
        if not shifted and origin_ok then data.last_origin = { ox, oy, oz } end

        -- defensive is decided per update, not as a long blanket window: only the updates whose simulation time went
        -- back (tickbase shift) or whose pitch flicked are defensive. Everything else is their real AA.
        local def_reason
        if shifted then
            def_reason = "tickbase shift"
            data.def_until = math_max(data.def_until, tick + clamp(data.max_st - st + profile.def_pad, 2, DEF_CAP))
        elseif pitch and data.clean_count >= 3 and data.real_pitch > 60 and pitch < data.real_pitch - 45 then
            def_reason = "pitch flick"
            data.def_until = math_max(data.def_until, tick + 2)
        end
        if def_reason then
            data.def_reason = def_reason
        elseif data.def_until > tick + 1 then
            data.def_until = tick + 1      -- sim time caught up again: the shift is over
        end
        data.def_rate = data.def_rate * 0.9 + (def_reason and 0.1 or 0)

        data.stance = get_stance(idx)
        if data.stance ~= data.prev_stance then
            data.prev_stance, data.stance_since = data.stance, tick
        end

        -- networked body yaw (not from shifted updates: those carry nonsense)
        local pose
        if not def_reason then
            pose = read_pose(idx)
            if pose then data.pose = pose end
            data.pose_ok = data.pose ~= nil
        end

        local rec
        if eye_yaw and finite(ox) and finite(oy) and finite(mx) and finite(my) then
            local rel = normalize_yaw(eye_yaw - math.deg(math.atan2(my - oy, mx - ox)) - 180)
            local r = data.records
            rec = {
                rel = rel, pitch = pitch or 0, def = def_reason ~= nil, tick = tick, st = st, pose = pose,
                fv = R.forced[idx], eye = eye_yaw, lby = lby,
            }
            r[#r + 1] = rec
            while #r > RECORDS do table_remove(r, 1) end
        end

        if not shifted then data.max_st = st end

        if not data.fs_tick or tick - data.fs_tick >= FS_INTERVAL or tick < data.fs_tick then
            data.fs_tick = tick
            local ok, side = pcall(freestand_side, idx, me)
            side = ok and side or 0
            -- a new side has to be seen twice in a row, so one odd trace does not flip the first guess
            if data.freestand == 0 or side == data.freestand then
                data.freestand, data.fs_pending = side, 0
            elseif side == data.fs_pending then
                data.freestand, data.fs_pending = side, 0
            else
                data.fs_pending = side
            end
        end

        -- ffi: server animation layers + client animstate of this enemy
        ffi_observe(idx, data, ffi_sample(idx, data), tick)

        -- feet yaw model (not on shifted updates)
        if not def_reason and FO[OPT_MODEL] then
            feet_update(data, eye_yaw, lby, st, speed, data.max_desync)
            if rec then rec.model = data.model_ok and data.model_body or nil end
        end

        local window = math_floor(1.2 / globals_tickinterval())
        local standing_long = data.stance == "stand" and data.stance_since ~= nil and tick - data.stance_since > window
        if data.still_s and F.layout == "ok" then
            standing_long = data.stance == "stand" and data.still_s > 1.2
        end
        -- realigned within the last second: the desync is bigger than ~35. Standing for a while without one: it is
        -- smaller. Only believed when the layers are readable, without them there is no evidence either way.
        data.bal_recent = data.layers_ok == true and data.balance_tick ~= nil and tick - data.balance_tick <= window
        data.low_desync = data.layers_ok == true and standing_long
            and (data.balance_tick == nil or tick - data.balance_tick > window)

        analyze(data)
    end
    data.last_sim = st
    data.is_shifting = tick < data.def_until
    data.pitch_snap = data.is_shifting and data.def_reason == "pitch flick"
    data.lc_break = tick < data.lc_until

    local base_type = "normal"
    if data.is_jitter then
        base_type = data.jitter_kind == "desync jitter" and "d-jitter" or data.jitter_kind
    elseif data.stance == "stand" then
        base_type = "static"
    end
    data.meta_type = data.def_rate > 0.05 and (base_type .. "+def") or base_type
    return data
end


-- ── side tracking ────────────────────────────────────────────────────────
-- A static target sits on one of two sides (+W / -W). Whether it STAYS there after a shot is learned per player and
-- stance from the shot results: how often it switches sides after a hit, and after a miss. That is all that
-- win-stay / lose-shift (a miss at a side means the other side), anti bruteforce (switches after every shot / hit /
-- miss) and shot noise need: a miss that is just noise switches back, a real change does not.
local DYN_PRIOR_HIT, DYN_PRIOR_MISS = 0.08, 0.18     -- chance of a switch before anything is known

local function dyn_state(m, stance)
    local d = m.dyn[stance]
    if not d then
        d = { hit = { n = 0, f = 0 }, miss = { n = 0, f = 0 } }
        m.dyn[stance] = d
    end
    return d
end

-- the side a shot result tells about: a hit at a big enough angle is on that side, a miss at a full size angle is on
-- the other one (smaller angles say nothing about the side)
local function dyn_side(shot, hit)
    local v = shot.value
    if v == nil then return nil end
    local av = math_abs(v)
    if hit then
        if av >= 20 then return v > 0 and 1 or -1 end
    elseif av >= 30 and av >= (shot.maxd or MAX_YAW) * 0.75 then
        return v > 0 and -1 or 1
    end
    return nil
end

local function dyn_observe(m, shot, hit)
    if shot.ctx:sub(1, 1) ~= "s" or shot.shifting then
        for _, d in pairs(m.dyn) do d.prev = nil end        -- a shot that is not read breaks the chain
        return
    end
    local d = dyn_state(m, shot.stance or "stand")
    local s = dyn_side(shot, hit)
    if s == nil then d.prev = nil; return end
    local now = globals_curtime()
    local prev = d.prev
    if prev and shot.seq and prev.seq and shot.seq == prev.seq + 1 and now - prev.t < 8 then
        local flip = (s ~= prev.s) and 1 or 0
        local c = prev.hit and d.hit or d.miss
        local g = prev.hit and R.dyn_global.hit or R.dyn_global.miss
        c.n, c.f = c.n * 0.93 + 1, c.f * 0.93 + flip
        g.n, g.f = g.n * 0.98 + 1, g.f * 0.98 + flip
    end
    if hit then d.w = math_abs(shot.value) end
    d.prev = { s = s, hit = hit, t = now, seq = shot.seq }
end

-- the side (as an angle) the target is expected on for the next shot, and how sure that is
local function dyn_predict(m, stance, maxd)
    local d = m.dyn[stance]
    local prev = d and d.prev
    if not prev or globals_curtime() - prev.t > 8 then return nil end
    local c = prev.hit and d.hit or d.miss
    local g = prev.hit and R.dyn_global.hit or R.dyn_global.miss
    local prior = prev.hit and DYN_PRIOR_HIT or DYN_PRIOR_MISS
    local p = (c.f + 0.3 * g.f + prior * 2) / (c.n + 0.3 * g.n + 2)      -- chance of a switch
    local side = p > 0.5 and -prev.s or prev.s
    return side * math_max(20, math_min(MAX_YAW, d.w or maxd)), math_max(p, 1 - p)
end

-- ── resolving ────────────────────────────────────────────────────────────
-- a target that just got hit with an arm and then dodges it (changes its AA once it is hit) is learned per player:
-- right after a hit its last arm is left out of the pick (except for a probe now and then, to notice it stopped)
local function stay_bias(m, ctx, bias)
    local ah = m.after_hit
    if ah and m.anti_stay and not ah.probe and ah.ctx == ctx and globals_curtime() - ah.t < 5 then
        bias[ah.arm] = (bias[ah.arm] or 0) - 0.30
    end
end

-- the feet yaw model is a candidate when it has a value for this record and it is not just ~0 (that is a situation of
-- its own, see feet_zero)
local function feet_usable(data)
    return data.model_ok and FO[OPT_MODEL] and not data.is_shifting and math_abs(data.model_body) >= 4
end

-- the model puts the feet on the eye yaw (just realigned, or never turned away): no desync right now. Learned apart
-- from the rest (own context) where the zero arm is the model's call; the layer hints do not apply there, the balance
-- adjust that just played is the feet TURNING to the eye yaw.
local function feet_zero(data)
    return data.model_ok and FO[OPT_MODEL] and not data.is_shifting and math_abs(data.model_body) < 4
end

-- how far the model is trusted for this target: where it keeps hitting (this target first, everybody else second)
-- it goes first, where it keeps missing it goes last; a target that chokes moves its feet through updates we never
-- see, so nothing known yet + choke counts against it
local function feet_base(data, m)
    local class = choke_class(data.choke or 0)
    local base = 0
    local rp, rg = feet_rate(m.feet, class), feet_rate(R.feet_global, class)
    if rp then base = base + (rp - 0.5) * 0.5 end
    if rg then base = base + (rg - 0.5) * 0.4 end
    if rp == nil and rg == nil and class ~= "n" then base = base - 0.08 end
    return base
end

-- score offsets of the two polarity arms of the model. Once the animstate showed which way forced values turn out,
-- the right polarity gets the lead.
local function feet_bias(data, m)
    local base = feet_base(data, m)
    local pol = F.polarity
    if pol == 1 then return base + 0.15, base - 0.10 end
    if pol == -1 then return base - 0.10, base + 0.15 end
    return base, base
end

-- first guess goes to the OPEN side (live logs showed the covered side missing);
-- the learning still flips it per player / globally if that turns out wrong
local function hint_side(data)
    return data.freestand ~= 0 and -data.freestand or 1
end

local function remember_pick(data, ctx, arm, n, a, side)
    data.used_ctx, data.used_arm, data.used_n = ctx, arm, n
    data.used_pol, data.used_side, data.used_step, data.used_src = a.pol or 1, side, arm, a.src
end

-- 1) static desync
local function resolve_static(idx, data, m)
    local stance = data.stance
    local zone = feet_zero(data)
    local ctx = zone and ("s|" .. stance .. "|z") or ("s|" .. stance)
    local n = #STATIC_ARMS
    local avail, bias = {}, {}
    for i = 1, n do avail[i], bias[i] = true, STATIC_BIAS[i] or 0 end

    -- animation layers: realigned recently = big desync, standing a while without = small desync
    local ev = (not zone) and (data.low_desync and LOW_BIAS or (data.bal_recent and FULL_BIAS or nil)) or nil
    if ev then
        for i = 1, #ev do bias[i] = bias[i] + ev[i] end
    end
    bias[3], bias[4] = bias[3] + profile.half_bias, bias[4] + profile.half_bias
    if zone then bias[5] = bias[5] + 0.42 + 2 * feet_base(data, m) end

    -- the angle that last hit this player in this stance, and the networked body yaw
    local hv = m.hit_value[stance]
    avail[6] = hv ~= nil
    local side = hint_side(data)
    local pose_arm = data.pose_ok and data.pose ~= nil and math_abs(data.pose) >= 6
    avail[7], avail[8] = pose_arm, pose_arm

    -- the feet yaw model: what the server's animstate logic gives for this record
    local feet_arm = feet_usable(data)
    avail[11], avail[12] = feet_arm, feet_arm
    if feet_arm then bias[11], bias[12] = feet_bias(data, m) end

    avail[13] = O["Native fallback"] == true

    -- which side it is on after the last shot (win-stay / lose-shift / anti bruteforce, as far as this target showed):
    -- the arms that guess a side follow it, the arms that read the animation do not
    local pv, pconf = dyn_predict(m, stance, data.max_desync)
    avail[14] = pv ~= nil
    if pv then
        local k = 0.45 * clamp((pconf - 0.55) / 0.4, 0, 1)
        for _, i in ipairs(GUESS_ARMS) do
            if avail[i] then
                local g = STATIC_ARMS[i]
                local vi = g.src == "db" and hv or g.pol * side * math_floor(data.max_desync * g.frac + 0.5)
                if vi and math_abs(vi) >= 20 then
                    if (vi > 0) == (pv > 0) then
                        bias[i] = bias[i] + k * (math_abs(vi - pv) <= 18 and 1 or 0.5)
                    else
                        bias[i] = bias[i] - k
                    end
                end
            end
        end
        bias[14] = k + 0.02
    end

    local arm, conf = arm_pick(m, ctx, n, bias, avail)
    data.arm_conf = conf
    local a = STATIC_ARMS[arm]
    local value, reason
    if a.src == "native" then
        value, reason = nil, "native"
    elseif a.src == "db" then
        value, reason = hv, "db hit"
    elseif a.src == "dyn" then
        value, reason = pv, "flip pattern"
    elseif a.src == "pose" then
        value, reason = a.pol * data.pose, "pose"
    elseif a.src == "feet" then
        value, reason = a.pol * data.model_body, "feet model"
    else
        value = a.pol * side * math_floor(data.max_desync * a.frac + 0.5)
        reason = arm == 1 and (data.freestand ~= 0 and "freestand" or "desync") or ("brute " .. arm)
    end
    if value ~= nil then value = math_floor(clamp(value, -60, 60) + 0.5) end

    remember_pick(data, ctx, arm, n, a, side)
    if zone and arm == 5 then
        reason = "feet zero"
        data.used_src = "feet"      -- the model's own result: counts for its reliability
    end
    return value, reason
end

-- 2) jitter
local function resolve_jitter(idx, data, m)
    if not O["Jitter fix"] then return nil, "native" end
    local ctx = "j|" .. jit_group(data.stance)
    local n = #JITTER_ARMS
    local avail, bias = {}, {}
    for i = 1, n do avail[i], bias[i] = true, JITTER_BIAS[i] or 0 end

    -- an irregular flip pattern cannot be predicted: "next" is a coin toss, the smaller / centred angles are safer
    if not data.jitter_regular then
        bias[3], bias[4] = bias[3] - 0.10, bias[4] - 0.10
    end
    if data.jitter_kind == "random" or data.jitter_kind == "multi" then
        bias[5], bias[6], bias[7] = bias[5] + 0.08, bias[6] + 0.08, bias[7] + 0.12
    end

    -- the feet yaw model gives the body yaw of the record that is being resolved
    local feet_arm = feet_usable(data)
    avail[8], avail[9] = feet_arm, feet_arm
    if feet_arm then bias[8], bias[9] = feet_bias(data, m) end

    avail[10] = O["Native fallback"] == true
    stay_bias(m, ctx, bias)

    local arm, conf = arm_pick(m, ctx, n, bias, avail)
    data.arm_conf = conf
    local a = JITTER_ARMS[arm]
    local side = a.next and data.jitter_next or data.jitter_side
    if side == 0 then side = data.jitter_side ~= 0 and data.jitter_side or 1 end
    local value, reason = 0, a.frac and a.frac < 1 and "jitter low" or "jitter"
    if a.src == "native" then
        value, reason = nil, "native"
    elseif a.src == "feet" then
        value, reason = a.pol * data.model_body, "feet model"
    elseif a.src ~= "zero" then
        value = a.pol * side * math_floor(data.max_desync * a.frac + 0.5)
    end
    if value ~= nil then value = math_floor(clamp(value, -60, 60) + 0.5) end

    remember_pick(data, ctx, arm, n, a, side)
    return value, reason
end

-- 3) defensive: while the target shifts its tickbase the updates carry nonsense, so the angle is not recomputed from
-- them. It holds what worked right before the shift (or a hedge of it), and what works is learned in its own
-- context so defensive shots never poison the normal arms.
local function resolve_defensive(idx, data, m)
    local tick = globals_tickcount()
    local ctx = data.is_jitter and "d|j" or "d|s"
    local n = #DEF_ARMS
    local lg = data.last_good_value
    local have = lg ~= nil and data.last_good_tick ~= nil and tick - data.last_good_tick <= 192
    local avail, bias = {}, {}
    for i = 1, n do avail[i], bias[i] = true, DEF_BIAS[i] or 0 end
    avail[1], avail[2], avail[3] = have, have, have
    avail[6] = O["Native fallback"] == true

    local arm, conf = arm_pick(m, ctx, n, bias, avail)
    data.def_conf = conf
    local a = DEF_ARMS[arm]
    local value
    if a.src == "hold" then
        value = a.pol * math_floor(lg * a.frac + 0.5)
    elseif a.src == "zero" then
        value = 0
    elseif a.src == "fresh" then
        -- what the normal resolver would pick right now
        value = (data.is_jitter and resolve_jitter or resolve_static)(idx, data, m)
    end

    remember_pick(data, ctx, arm, n, a, 1)
    if value == nil then return nil, "native" end
    return value, "defensive hold"
end

-- the value for this enemy right now (nil = let the native resolver do it)
local function get_override(idx)
    local data, m = init_player(idx)
    data.used_stance = data.stance
    data.used_ctx, data.used_arm, data.used_n = nil, nil, nil
    data.used_pol, data.used_side, data.used_step, data.used_src = nil, nil, nil, nil
    data.arm_conf, data.def_conf = nil, nil

    if data.is_shifting and O["Defensive fix"] then
        return resolve_defensive(idx, data, m)
    end
    if data.is_jitter then
        return resolve_jitter(idx, data, m)
    end
    return resolve_static(idx, data, m)
end

-- ── player list ──────────────────────────────────────────────────────────
local function plist_read(idx, field)
    local ok, a, b = pcall(plist.get, idx, field)
    if not ok then return nil, false end
    return a, true, b
end

local function verify_plist(idx, value)
    if R.plist_verified then return end
    R.plist_verified = true
    local on, ok_on = plist_read(idx, "Force body yaw")
    local v, ok_v = plist_read(idx, "Force body yaw value")
    if not ok_on or not ok_v then
        say("player list check: cannot read the Force body yaw fields - overrides may not apply")
    elseif on ~= true or tonumber(v) ~= value then
        say(string_format("player list check: wrote %d, gamesense reports %s / %s", value, tostring(on), tostring(v)))
    end
end

local function takeover_correction(idx)
    if R.correction_saved[idx] == nil then
        local ok, current = pcall(plist.get, idx, "Correction active")
        R.correction_saved[idx] = { ok = ok, value = current }
    end
    pcall(plist.set, idx, "Correction active", true)
end

local function restore_correction(idx)
    local saved = R.correction_saved[idx]
    if saved then
        if saved.ok then pcall(plist.set, idx, "Correction active", saved.value) end
        R.correction_saved[idx] = nil
    end
end

local function write(idx, value)
    if R.forced[idx] == value then return end
    if value == nil then
        pcall(plist.set, idx, "Force body yaw", false)
        restore_correction(idx)
    else
        takeover_correction(idx)
        pcall(plist.set, idx, "Force body yaw", true)
        pcall(plist.set, idx, "Force body yaw value", value)
        verify_plist(idx, value)
    end
    R.forced[idx] = value
end

local function write_override(store, idx, key, on)
    if (store[idx] or false) == on then return end
    pcall(plist.set, idx, key, on and "On" or "-")
    store[idx] = on or nil
end

-- aim levers besides the angle: safe point / body aim when the resolver is not sure
local function write_extras(idx, data, m)
    local streak = m.streak or 0
    local sa = math_max(1, ui.get(U.safe_after) + profile.sp_off)
    local ba = math_max(1, ui.get(U.baim_after) + profile.ba_off)
    local use_sp, use_ba = O["Safe point on misses"], O["Body aim on misses"]
    local want_sp = use_sp and streak > 0 and streak >= sa
    local want_ba = use_ba and streak > 0 and streak >= ba

    -- every arm of this target keeps failing: stop gambling on the head
    if data.arm_conf ~= nil and (m.resolver_misses or 0) >= 2 then
        if use_sp and data.arm_conf < profile.conf_sp then want_sp = true end
        if use_ba and data.arm_conf < profile.conf_ba then want_ba = true end
    end

    -- shifting: the angle is a guess by definition. After a defensive miss (or when the defensive arms are failing)
    -- play it safe until the target stops shifting.
    if data.is_shifting and O["Defensive fix"] then
        local bad = data.def_conf ~= nil and data.def_conf < 0.40
        if (m.def_misses_round or 0) > 0 or bad then want_sp = true end
        if (m.def_misses_round or 0) > 0 and (bad or (m.def_misses_round or 0) >= 2) then want_ba = true end
    end

    if O["LC: body aim"] and (data.lc_break or (m.lc_misses_round or 0) > 0) then want_ba = true end
    write_override(R.forced_sp, idx, "Override safe point", want_sp and true or false)
    write_override(R.forced_ba, idx, "Override prefer body aim", want_ba and true or false)
end

local function write_pitch(idx, value)
    local cur = R.forced_pitch[idx]
    if value == nil then
        if cur ~= nil then
            pcall(plist.set, idx, "Force pitch", false)
            R.forced_pitch[idx] = nil
        end
        return
    end
    value = math_floor(value + 0.5)
    if cur == value then return end
    local ok = true
    if cur == nil then ok = pcall(plist.set, idx, "Force pitch", true) end
    ok = ok and pcall(plist.set, idx, "Force pitch value", value)
    if ok then ok = select(2, plist_read(idx, "Force pitch value")) == true end
    if not ok and not R.pitch_warned then
        R.pitch_warned = true
        say("Force pitch is not available in the player list - the defensive snap pitch fix is inactive")
    end
    R.forced_pitch[idx] = value
end

local function release_extras(idx)
    write_override(R.forced_sp, idx, "Override safe point", false)
    write_override(R.forced_ba, idx, "Override prefer body aim", false)
    write_pitch(idx, nil)
end

local function release(idx)
    if R.forced[idx] ~= nil then
        pcall(plist.set, idx, "Force body yaw", false)
    end
    R.forced[idx] = nil
    restore_correction(idx)
    release_extras(idx)
end

local function release_all()
    for idx in pairs(R.forced) do
        pcall(plist.set, idx, "Force body yaw", false)
    end
    for idx in pairs(R.correction_saved) do restore_correction(idx) end
    R.forced = {}
    for _, store in ipairs({ R.forced_sp, R.forced_ba, R.forced_pitch }) do
        for idx in pairs(store) do release_extras(idx) end
    end
end

local function anything_forced()
    return next(R.forced) or next(R.forced_sp) or next(R.forced_ba) or next(R.forced_pitch)
end

-- ── the update pass ──────────────────────────────────────────────────────
local function net_update()
    local me = entity_get_local_player()
    if not ui.get(U.enable) or not me then
        if anything_forced() then release_all() end
        return
    end

    refresh_options()
    refresh_ping()

    -- remembered between sessions: written now and then, not on every shot
    if R.dirty and O["Remember learning"] and globals_realtime() - R.last_save > 120 then save_priors() end

    local seen = {}
    -- manual tool: flip the resolved side on the aimbot's current target while the key is held
    local threat = client.current_threat()
    local flip_target = ui.get(U.flip) and threat or nil
    local tick = globals_tickcount()
    for _, idx in ipairs(entity.get_players(true)) do
        if entity.is_alive(idx) and not entity.is_dormant(idx) then
            seen[idx] = true
            local data = update_player(idx, me)
            local m = R.memory[data.mkey]
            local value, reason = get_override(idx)
            if value ~= nil and idx == flip_target then
                value, reason = -value, "manual flip"
                data.used_ctx = nil   -- shots on a manually flipped angle are not learned from
            end
            data.last_reason = reason
            if value ~= nil and not data.is_shifting then
                data.last_good_value, data.last_good_tick, data.last_good_stance = value, tick, data.stance
            end
            write(idx, value)
            ffi_apply(idx, data, value)
            write_extras(idx, data, m)
            if O["Defensive snap fix"] and data.is_shifting then
                write_pitch(idx, data.real_pitch)
            else
                write_pitch(idx, nil)
            end

            -- remember what was applied to this record: a shot at an older (backtracked) record has to be judged by
            -- the angle that record got, not by what is forced by the time we fire
            if data.new_record then
                local hist = data.hist
                hist[#hist + 1] = {
                    st = data.last_sim, tick = tick, value = value, reason = reason,
                    ctx = data.used_ctx, arm = data.used_arm, n = data.used_n, src = data.used_src,
                    pol = data.used_pol, side = data.used_side, step = data.used_step,
                    shifted = data.is_shifting, stance = data.used_stance, cc = choke_class(data.choke or 0),
                    jside = data.jitter_side, jnext = data.jitter_next, maxd = data.max_desync,
                }
                while #hist > HIST_SIZE do table_remove(hist, 1) end
            end

            -- one line per second for the current threat: what the ffi layer sees, for tuning from logs
            if idx == threat and FO[OPT_TELE] and tick % 64 == 0 then
                local fx = data.fx or {}
                local last = data.records[#data.records]
                say(string_format(
                    "ffi %s | adj act %s w %.2f c %.2f | mov w %.2f r %.2f | anim eye %s goal %s d %s still %s | lby %s model %s | forced %s | pol %s n %d err %s | choke %d spd %d %s",
                    ffi_status(data), tostring(fx.adj_act or "-"), fx.adj_w or 0, fx.adj_cycle or 0, fx.mov_w or 0, fx.mov_rate or 0,
                    fx.a_eye and string_format("%.0f", fx.a_eye) or "-", fx.a_goal and string_format("%.0f", fx.a_goal) or "-",
                    data.fx_delta and string_format("%+.0f", data.fx_delta) or "-", fx.a_still and string_format("%.1f", fx.a_still) or "-",
                    last and last.lby and string_format("%.0f", last.lby) or "-",
                    data.model_ok and string_format("%+.0f", data.model_body) or "-",
                    value ~= nil and tostring(value) or "-", tostring(F.polarity or "?"), F.pol_n,
                    F.apply_err and string_format("%.0f", F.apply_err) or "-",
                    data.choke or 0, math_floor(data.speed or 0), data.stance or "?"))
            end
        end
    end

    for idx in pairs(R.forced) do
        if not seen[idx] then release(idx) end
    end
    for _, store in ipairs({ R.forced_sp, R.forced_ba, R.forced_pitch }) do
        for idx in pairs(store) do
            if not seen[idx] then release_extras(idx) end
        end
    end
end


-- ── shots ────────────────────────────────────────────────────────────────
local function shot_backtrack(event)
    local reported = tonumber(event.backtrack) or 0
    if reported > 0 then return reported end
    local target, shot_tick = event.target, tonumber(event.tick)
    if not target or not shot_tick then return 0 end
    local sim = entity_get_prop(target, "m_flSimulationTime")
    if not sim or sim <= 0 then return 0 end
    local diff = tick_of(sim) - shot_tick
    if diff > 0 and diff <= 64 then return diff end
    return 0
end

local function shot_key(event)
    if type(event) ~= "table" then return nil end
    return event.id or event.shot_id or event.command_number
end

local function latest_shot_for_target(idx)
    local best_key, best_time = nil, -math.huge
    for key, shot in pairs(R.shots) do
        if shot.idx == idx and (shot.time or 0) > best_time then
            best_key, best_time = key, shot.time or 0
        end
    end
    return best_key
end

-- the override that was applied to the record a shot went at: `bt` ticks behind the newest one
local function applied_for(data, bt)
    local hist = data.hist
    if not hist or #hist == 0 then return nil end
    if not bt or bt <= 0 or not data.max_st then return hist[#hist] end
    local target = data.max_st - bt
    for i = #hist, 1, -1 do
        local e = hist[i]
        if e.st <= target then
            if target - e.st <= 4 then return e end
            return nil
        end
    end
    return nil
end

local function miss_verdict(shot, why)
    if why == "spread" then return "spread", "hit chance too low for the distance / weapon" end
    if why == "prediction error" then return "prediction", "target changed speed or direction after the shot" end
    if why == "death" or why == "unregistered shot" then return why, "server did not register the shot" end
    if not RESOLVER_MISS[why] then return why, "not caused by the resolver" end
    if not shot then return "resolver", "no shot data" end
    if shot.teleported or shot.extrap then return "lagcomp", "target broke lag compensation" end
    if not shot.ctx then return "native", "native resolver picked the wrong side" end
    local an = arm_name(shot.ctx, shot.arm)
    local v = shot.value ~= nil and tostring(shot.value) or "native"
    if shot.shifting then
        return "defensive", string_format("forced %s (%s) on a shifted record (%s)", v, an, tostring(shot.def_reason))
    end
    if (shot.bt or 0) >= stale_threshold() then
        return "stale record", string_format("%d-tick old record (limit %d), forced %s (%s)", shot.bt, stale_threshold(), v, an)
    end
    if shot.reason == "feet model" or shot.reason == "feet zero" then
        return "feet model", string_format("forced %s (%s), animstate showed %s", v, an,
            shot.fx_delta and string_format("%+d", math_floor(shot.fx_delta + 0.5)) or "n/a")
    end
    if shot.reason == "jitter" or shot.reason == "jitter low" then
        return "jitter", string_format("forced %s (%s, side %d next %d, spread %d)", v, an, shot.jside or 0, shot.jnext or 0, math_floor(shot.spread or 0))
    end
    return "wrong side", string_format("forced %s (%s)", v, an)
end

local function debug_push(kind, shot, why, idx)
    local tag, detail = "hit", ""
    if kind == "miss" then tag, detail = miss_verdict(shot, why) end
    local e = {
        kind = kind, tag = tag, detail = detail, why = why,
        name = entity_get_player_name(idx) or tostring(idx), time = globals_realtime(), shot = shot or {},
    }
    table_insert(R.debug_log, 1, e)
    while #R.debug_log > 6 do table_remove(R.debug_log) end

    if DO.Console then
        local s = shot or {}
        client.color_log(180, 160, 255, "specter resolver  \0")
        client.color_log(kind == "miss" and 255 or 150, kind == "miss" and 125 or 230, kind == "miss" and 125 or 165,
            string_format("%s %s | %s | forced %s (%s / %s) | %s %s spd %d maxd %d choke %d | jit %d%% side %d | bt %d%s | %s ping | model %s anim %s adj %s | %s",
                kind, e.name, tag, s.value ~= nil and tostring(s.value) or "-", s.reason or "native", arm_name(s.ctx, s.arm),
                s.meta or "?", s.stance or "?", math_floor(s.speed or 0), s.maxd or 0, s.choke or 0,
                math_floor((s.jratio or 0) * 100), s.jside or 0, s.bt or 0,
                (s.shifting and (" def:" .. tostring(s.def_reason)) or ""), s.profile or "?",
                s.model and string_format("%+d", math_floor(s.model + 0.5)) or "-",
                s.fx_delta and string_format("%+d", math_floor(s.fx_delta + 0.5)) or "-",
                tostring(s.adj_act or "-"), detail ~= "" and detail or "ok"))
    end
end

local function on_fire(event)
    event = type(event) == "table" and event or {}
    local idx = event.target
    if not idx then return end
    local data, m = init_player(idx)
    local now = globals_curtime()
    for id, s in pairs(R.shots) do
        if now - s.time > 3 then R.shots[id] = nil end
    end
    local key = shot_key(event)
    if key == nil then
        R.next_shot_id = R.next_shot_id + 1
        key = "local:" .. tostring(R.next_shot_id)
    end

    local bt = shot_backtrack(event)
    local e = applied_for(data, bt)
    m.shot_seq = (m.shot_seq or 0) + 1
    local shot = {
        idx = idx, time = now, bt = bt, profile = profile.name, seq = m.shot_seq,
        extrap = event.extrapolated == true, teleported = event.teleported == true,
        lc = data.lc_break, jratio = data.jitter_ratio, spread = data.spread, meta = data.meta_type,
        speed = data.speed, choke = data.choke, hitgroup = event.hitgroup, def_reason = data.def_reason,
        model = data.model_ok and data.model_body or nil, fx_delta = data.fx_delta,
        adj_act = data.fx and data.fx.adj_act or nil,
    }
    if e then
        shot.value, shot.reason = e.value, e.reason or "native"
        shot.stance, shot.shifting = e.stance or data.stance, e.shifted
        shot.ctx, shot.arm, shot.n, shot.src, shot.cc = e.ctx, e.arm, e.n, e.src, e.cc
        shot.pol, shot.side, shot.step = e.pol, e.side, e.step
        shot.jside, shot.jnext, shot.maxd = e.jside, e.jnext, e.maxd
    else
        shot.value, shot.reason = R.forced[idx], data.last_reason or "native"
        shot.stance, shot.shifting = data.used_stance or data.stance, data.is_shifting
        shot.ctx, shot.arm, shot.n, shot.src = data.used_ctx, data.used_arm, data.used_n, data.used_src
        shot.cc = choke_class(data.choke or 0)
        shot.pol, shot.side, shot.step = data.used_pol, data.used_side, data.used_step
        shot.jside, shot.jnext, shot.maxd = data.jitter_side, data.jitter_next, data.max_desync
    end

    -- the first shot with the arm that just hit tells whether this target dodges it once it got hit
    local ah = m.after_hit
    if ah then
        if shot.ctx == ah.ctx and shot.arm == ah.arm and now - ah.t < 5 then shot.after_hit = true end
        m.after_hit = nil
    end

    R.shots[key] = shot
    R.session.shots = R.session.shots + 1
    data.last_shot_time = now
end

-- what a shot result teaches: the arm that was applied to that record, the feet model, whether the target dodges a
-- hit arm, and a streak of misses with one arm makes that arm's good record count for much less
local function learn_outcome(m, shot, hit, weight)
    arm_learn(m, shot.ctx, shot.arm, shot.n, hit, weight)
    dyn_observe(m, shot, hit)

    if shot.src == "feet" and shot.cc then
        feet_learn(m.feet, shot.cc, hit)
        feet_learn(R.feet_global, shot.cc, hit)
    end

    if shot.after_hit then
        local st = m.stay
        st.n, st.ok = st.n * 0.9 + 1, st.ok * 0.9 + (hit and 1 or 0)
        m.anti_stay = st.n >= 2.5 and st.ok / st.n < 0.4
    end

    if hit then
        m.arm_streak[shot.ctx] = nil
    else
        local ast = m.arm_streak[shot.ctx]
        if ast and ast.arm == shot.arm then
            ast.n = ast.n + 1
        else
            ast = { arm = shot.arm, n = 1 }
            m.arm_streak[shot.ctx] = ast
        end
        if ast.n >= 3 then
            local own = arm_table(m.arms, shot.ctx, shot.n)[shot.arm]
            own.s = own.s * 0.3
        end
    end
end

local function on_miss(event)
    event = type(event) == "table" and event or {}
    local key = shot_key(event) or latest_shot_for_target(event.target)
    local shot = key and R.shots[key] or nil
    if key then R.shots[key] = nil end
    local idx = event.target or (shot and shot.idx)
    if not idx then return end
    local data, m = init_player(idx)
    local why = tostring(event.reason or "?")
    local name = entity_get_player_name(idx) or tostring(idx)
    pcall(debug_push, "miss", shot, why, idx)
    R.session.misses = R.session.misses + 1

    if shot and (shot.extrap or shot.teleported) and (RESOLVER_MISS[why] or why == "prediction error") then
        m.lc_misses_round = (m.lc_misses_round or 0) + 1
        log("%s: lag compensation broken - body aim for the rest of the round", name)
        return
    end

    if not RESOLVER_MISS[why] then
        log("%s: missed due to %s - not a resolver miss, nothing learned", name, why)
        return
    end

    R.miss_count[idx] = R.miss_count[idx] + 1
    data.consecutive_misses = data.consecutive_misses + 1
    data.confidence = math_max(data.confidence - 0.25, 0)
    m.resolver_misses = m.resolver_misses + 1
    m.streak = (m.streak or 0) + 1

    if not shot or not shot.ctx then
        log("%s: native resolver missed", name)
        return
    end

    -- how much this miss says about the arm that was applied to that record:
    --  * a shifted record resolved with the normal arms (Defensive fix off) is weak evidence
    --  * an old backtrack record carries lag compensation noise on top
    --  * the call predates the last update of this context (slow feedback at high ping): already acted on
    local weight = profile.miss_w
    local bt = shot.bt or 0
    if shot.shifting then
        if shot.ctx:sub(1, 1) ~= "d" then weight = weight * 0.5 end
        m.def_misses_round = (m.def_misses_round or 0) + 1
    end
    if bt >= 24 then
        weight = weight * 0.4
    elseif bt >= stale_threshold() then
        weight = weight * 0.6
    end
    local last = m.learn_time[shot.ctx]
    if last and shot.time < last then weight = weight * 0.5 end
    m.learn_time[shot.ctx] = globals_curtime()

    learn_outcome(m, shot, false, weight)
    local next_arm = arm_pick(m, shot.ctx, shot.n)
    log("%s: %s missed (%s, %s%s) -> next: %s", name, shot.value ~= nil and tostring(shot.value) or "native", shot.reason or "?",
        arm_name(shot.ctx, shot.arm), shot.shifting and (", defensive: " .. tostring(shot.def_reason)) or "", arm_name(shot.ctx, next_arm))
end

local function on_hit(event)
    event = type(event) == "table" and event or {}
    local key = shot_key(event) or latest_shot_for_target(event.target)
    local shot = key and R.shots[key] or nil
    if key then R.shots[key] = nil end
    local idx = event.target or (shot and shot.idx)
    if not idx then return end
    local data, m = init_player(idx)
    pcall(debug_push, "hit", shot, "hit", idx)
    R.hit_count[idx] = R.hit_count[idx] + 1
    R.session.hits = R.session.hits + 1
    data.consecutive_misses = 0
    data.confidence = math_min(data.confidence + 0.35, 1)
    m.hits = m.hits + 1
    m.streak = 0
    if shot and shot.shifting then
        m.def_misses_round = math_max(0, (m.def_misses_round or 0) - 1)
    end

    if not shot or not shot.ctx then return end
    if shot.value ~= nil then
        data.working_angle = shot.value
        -- a hit on a shifted record says little about the real AA: keep it out of the "last hit" memory
        if shot.ctx:sub(1, 1) ~= "d" then
            m.hit_value[shot.stance or "stand"] = shot.value
        end
    end

    -- body hits say less about the head angle than head hits
    local weight = (event.hitgroup == 1) and 1.5 or 0.5
    m.learn_time[shot.ctx] = globals_curtime()
    learn_outcome(m, shot, true, weight)

    -- the next shot with this arm tells whether the target dodges it now (a probe now and then keeps it honest)
    m.probe = (m.probe or 0) + 1
    m.after_hit = { ctx = shot.ctx, arm = shot.arm, t = globals_curtime(), probe = m.probe % 5 == 0 }

    log("%s: hit with %s (%s, %s)", entity_get_player_name(idx) or tostring(idx), shot.value ~= nil and tostring(shot.value) or "native",
        arm_name(shot.ctx, shot.arm), shot.stance or "?")
end

-- ── lifecycle ────────────────────────────────────────────────────────────
local function reset_player(idx)
    release(idx)
    R.database[idx] = nil
end

local function reset_all(forget)
    release_all()
    R.database, R.shots = {}, {}
    R.miss_count, R.hit_count = {}, {}
    if forget then
        R.memory, R.global, R.feet_global = {}, {}, {}
        R.dyn_global = { hit = { n = 0, f = 0 }, miss = { n = 0, f = 0 } }
        R.session = { shots = 0, hits = 0, misses = 0 }
    end
end

-- keep what was learned, forget per-round punishments
local function new_round()
    for _, m in pairs(R.memory) do
        m.lc_misses_round, m.def_misses_round, m.streak = 0, 0, 0
        m.learn_time, m.after_hit, m.arm_streak = {}, nil, {}
        for _, d in pairs(m.dyn) do d.prev = nil end
    end
    for _, d in pairs(R.database) do
        d.consecutive_misses, d.def_until, d.lc_until, d.last_origin = 0, 0, 0, nil
        d.last_good_value, d.last_good_tick = nil, nil
        d.hist, d.act_cache, d.feet, d.feet_st = {}, {}, nil, nil
    end
    if R.dirty then save_priors() end
end

-- ── debugger: ESP flags and the panel ────────────────────────────────────
local function esp_flag(fn)
    return function(ent)
        if not (ui.get(U.enable) and O["ESP flags"]) then return false end
        local data = R.database[ent]
        return data ~= nil and fn(ent, data) or false
    end
end

local function draw_panel()
    if not DO.Panel or not ui.get(U.enable) then return end

    local sw, sh = client.screen_size()
    local ar, ag, ab = 180, 160, 255
    local x, y, w, GH = 14, math_floor(sh * 0.18), 320, 40
    local threat = client.current_threat()
    local data = threat and R.database[threat]
    local m = data and R.memory[data.mkey]

    local rows = {}
    rows[#rows + 1] = { "ping", string_format("%d ms", math_floor(ping.ms + 0.5)), "profile", string.upper(profile.name) }
    if data then
        local val = R.forced[threat]
        rows[#rows + 1] = { "mode", string_format("%s %s", data.last_reason or "native", val ~= nil and (tostring(val) .. "\194\176") or ""), "type", data.meta_type or "-" }
        rows[#rows + 1] = { "stance", data.stance or "-", "speed", string_format("%d  max %d\194\176", math_floor(data.speed or 0), data.max_desync or MAX_YAW) }
        rows[#rows + 1] = { "yaw", string_format("spread %d  flips %d", math_floor(data.spread or 0), data.jitter_flips or 0), "choke", tostring(data.choke or 0) }
        rows[#rows + 1] = { "side", string_format("cur %d  next %d", data.jitter_side or 0, data.jitter_next or 0), "fs", tostring(data.freestand or 0) }
        rows[#rows + 1] = { "pose", data.pose and string_format("%d\194\176", math_floor(data.pose + 0.5)) or "n/a", "period", string_format("%d%s", data.jitter_period or 1, data.jitter_regular and "" or " ~") }
        rows[#rows + 1] = { "defensive", data.is_shifting and (data.def_reason or "yes") or "-", "rate", string_format("%d%%", math_floor((data.def_rate or 0) * 100)) }
        local lby = not data.layers_ok and "n/a" or (data.balance_tick and string_format("%.1fs ago", (globals_tickcount() - data.balance_tick) * globals_tickinterval()) or "never")
        rows[#rows + 1] = { "lby break", lby, "desync", data.low_desync and "low" or (data.bal_recent and "full" or "?") }
        rows[#rows + 1] = { "ffi", ffi_status(data), "model", data.model_ok and string_format("%+d\194\176", math_floor(data.model_body + 0.5)) or "n/a" }
        rows[#rows + 1] = { "animstate", data.fx_delta and string_format("%+d\194\176", math_floor(data.fx_delta + 0.5)) or "n/a", "polarity",
            F.polarity and (F.polarity > 0 and "+" or "-") or "?" }
        if m and data.used_ctx then
            rows[#rows + 1] = { "arm", arm_name(data.used_ctx, data.used_arm), "score",
                string_format("%.2f", arm_score(m, data.used_ctx, data.used_arm, data.used_n)) }
        end
        if m then
            rows[#rows + 1] = { "shots", string_format("%d hit  %d miss", m.hits, m.resolver_misses), "streak", tostring(m.streak or 0) }
            rows[#rows + 1] = { "dodges", m.anti_stay and "after a hit" or "no", "", "" }
        end
    end

    local shots = R.debug_log
    local shown = math_min(#shots, 4)
    local h = 28 + (data and (#rows * 14 + 22 + GH) or (#rows * 14 + 32)) + (shown > 0 and (18 + shown * 27) or 0) + 4

    renderer.rectangle(x, y, w, h, 12, 12, 16, 235)
    renderer.gradient(x, y, w, 2, ar, ag, ab, 255, ar, ag, ab, 30, true)
    renderer.text(x + 10, y + 9, ar, ag, ab, 255, "b", 0, "desync resolver")
    if threat then
        local nm = entity_get_player_name(threat) or "?"
        renderer.text(x + w - 10 - renderer.measure_text("", nm), y + 9, 235, 235, 240, 255, "", 0, nm)
    end

    local cy = y + 28
    for _, r in ipairs(rows) do
        renderer.text(x + 10, cy, 115, 115, 128, 255, "", 0, r[1])
        renderer.text(x + 78, cy, 230, 230, 235, 255, "", 0, r[2])
        renderer.text(x + 185, cy, 115, 115, 128, 255, "", 0, r[3])
        renderer.text(x + 240, cy, 230, 230, 235, 255, "", 0, r[4])
        cy = cy + 14
    end
    if not data then
        renderer.text(x + 10, cy, 120, 120, 130, 255, "", 0, "no target")
        cy = cy + 18
    else
        cy = cy + 4
        local gx, gw = x + 10, w - 20
        renderer.text(gx, cy, 115, 115, 128, 255, "", 0, string_format("eye yaw (last %d records, red = defensive)", RECORDS))
        cy = cy + 13
        renderer.rectangle(gx, cy, gw, GH, 20, 20, 26, 255)
        renderer.rectangle(gx, cy + GH / 2, gw, 1, 255, 255, 255, 25)
        local recs = data.records
        local px_, py_
        for i = 1, #recs do
            local v = clamp(recs[i].rel, -90, 90)
            local px = gx + 3 + math_floor((i - 1) * (gw - 6) / math_max(1, RECORDS - 1))
            local py = cy + math_floor(GH / 2 - v / 90 * (GH / 2 - 3))
            if px_ then renderer.line(px_, py_, px, py, ar, ag, ab, 140) end
            if recs[i].def then
                renderer.rectangle(px - 2, py - 2, 5, 5, 255, 90, 90, 255)
            else
                renderer.rectangle(px - 1, py - 1, 3, 3, 235, 235, 240, 255)
            end
            px_, py_ = px, py
        end
        cy = cy + GH + 5
    end

    if shown > 0 then
        renderer.rectangle(x + 10, cy + 2, w - 20, 1, 255, 255, 255, 20)
        renderer.text(x + 10, cy + 5, 115, 115, 128, 255, "", 0,
            string_format("recent shots   session %d / %d", R.session.hits, R.session.hits + R.session.misses))
        cy = cy + 18
        for i = 1, shown do
            local e = shots[i]
            local s = e.shot
            local hit = e.kind == "hit"
            local cr, cg, cb = 140, 230, 160
            if not hit then cr, cg, cb = 255, 115, 115 end
            local tag = hit and "HIT" or string.upper(e.tag)
            renderer.text(x + 10, cy, cr, cg, cb, 255, "b", 0, tag)
            local tw = renderer.measure_text("b", tag)
            renderer.text(x + 18 + tw, cy, 230, 230, 235, 255, "", 0, string_format("%s   %s %s   %s   bt %d",
                e.name, s.reason or "native", s.value ~= nil and (tostring(s.value) .. "\194\176") or "", s.stance or "-", s.bt or 0))
            if e.detail ~= "" then
                renderer.text(x + 10, cy + 12, 125, 125, 138, 255, "", 0, e.detail)
            end
            cy = cy + 27
        end
    end
end

-- ── wiring ───────────────────────────────────────────────────────────────
local last_err = -10
local function guarded(name, fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok and globals_realtime() - last_err > 5 then
            last_err = globals_realtime()
            client.error_log("[specter resolver] " .. name .. ": " .. tostring(err))
        end
    end
end

client.set_event_callback("net_update_end", guarded("update", net_update))
client.set_event_callback("paint", guarded("panel", draw_panel))
client.set_event_callback("aim_fire", guarded("aim_fire", on_fire))
client.set_event_callback("aim_hit", guarded("aim_hit", on_hit))
client.set_event_callback("aim_miss", guarded("aim_miss", on_miss))
client.set_event_callback("round_prestart", guarded("round", new_round))
client.set_event_callback("player_spawn", guarded("spawn", function(e)
    local idx = e and e.userid and client.userid_to_entindex(e.userid)
    if idx and idx > 0 then reset_player(idx) end
end))
client.set_event_callback("player_death", guarded("death", function(e)
    local idx = e and e.userid and client.userid_to_entindex(e.userid)
    if idx and idx > 0 then reset_player(idx) end
end))
client.set_event_callback("level_init", guarded("level", function() reset_all(false) end))
client.set_event_callback("shutdown", function()
    pcall(release_all)
    pcall(save_priors)
end)

pcall(client.register_esp_flag, "R", 100, 150, 255, esp_flag(function(ent) return R.forced[ent] ~= nil end))
pcall(client.register_esp_flag, "JIT", 255, 190, 70, esp_flag(function(_, d) return d.is_jitter == true end))
pcall(client.register_esp_flag, "LC", 255, 80, 80, esp_flag(function(_, d) return d.lc_break end))
pcall(client.register_esp_flag, "DEF", 190, 120, 255, esp_flag(function(_, d) return d.is_shifting end))

on_reset_pressed = function()
    reset_all(true)
    say("memory cleared")
end

load_priors()
refresh_options()
say(string_format("v%s loaded - RAGE > Other > Specter desync resolver", VERSION))

-- exported for the tests only
if rawget(_G, "SPECTER_RESOLVER_TEST") then return { R = R, F = F, U = U, PROFILES = PROFILES, STATIC_ARMS = STATIC_ARMS, JITTER_ARMS = JITTER_ARMS, DEF_ARMS = DEF_ARMS,
    net_update = net_update, on_fire = on_fire, on_hit = on_hit, on_miss = on_miss, draw_panel = draw_panel,
    new_round = new_round, reset_all = reset_all, save_priors = save_priors, load_priors = load_priors,
    arm_score = arm_score, applied_for = applied_for } end
