-- Resolver simulation harness: runs a resolver block (old or new) against a simulated enemy.
-- usage: sim = load(this)(); sim.run(block_src, scenario, opts) -> stats
local M = {}

local function make_env()
    local env = setmetatable({}, { __index = _G })
    return env
end

-- scenario builders: each returns function(k, st) -> {rel=, T=, pose=, shifted=bool, st=}
-- k = arrival tick (1 record per tick), T = true body yaw of that record
local function sgn(x) return x >= 0 and 1 or -1 end

M.scenarios = {
    static_pos = function() return function(k) return { rel = 0, T = 58 } end end,
    static_neg = function() return function(k) return { rel = 0, T = -58 } end end,
    -- freestand mock gives fs=+1 -> hint side is -1 -> T=-58 is "fs full"
    static_fs = function() return function(k) return { rel = 0, T = -58 } end end,
    static_mid = function() return function(k) return { rel = 0, T = 29 } end end,
    static_tiny = function() return function(k) return { rel = 0, T = -12 } end end,
    static_low = function() return function(k) return { rel = 0, T = 14 } end end,
    jitter_pos = function()
        return function(k) local s = (k % 2 == 0) and 1 or -1; return { rel = 35 * s, T = 58 * s } end
    end,
    jitter_neg = function()
        return function(k) local s = (k % 2 == 0) and 1 or -1; return { rel = 35 * s, T = -58 * s } end
    end,
    jitter_p3 = function()
        return function(k) local s = (math.floor(k / 3) % 2 == 0) and 1 or -1; return { rel = 35 * s, T = 58 * s } end
    end,
    jitter_random = function()
        local rng, s = 12345, 1
        return function(k)
            rng = (rng * 1103515245 + 12345) % 2147483648
            if rng % 3 ~= 0 then s = -s end
            return { rel = 35 * s, T = 58 * s }
        end
    end,
    -- eye yaw is quiet, only the body yaw flips (and the networked pose shows it)
    desync_jitter = function()
        return function(k) local s = (math.floor(k / 2) % 2 == 0) and 1 or -1; return { rel = 0, T = 58 * s, pose = 58 * s } end
    end,
    -- static desync with tickbase shifts: during the shifted records the real desync is ~0
    def_static = function()
        return function(k)
            local phase = k % 48
            if phase >= 40 and phase < 46 then
                return { rel = 0, T = 0, shifted = true }
            end
            return { rel = 0, T = 58 }
        end
    end,
    moving_static = function() return function(k) return { rel = 0, T = -29, vel = 250 } end end,
    air_static = function() return function(k) return { rel = 0, T = 29, vel = 250, air = true } end end,
    pose_static = function() return function(k) return { rel = 0, T = -45, pose = -45 } end end,
    nopose_static = function() return function(k) return { rel = 0, T = -45 } end end,
    mapchange = function() return function(k) if k >= 1000 then return { rel = 0, T = 58, st = k - 900 } end return { rel = 0, T = 58 } end end,
    -- server-style physics: the true body yaw comes from the feet yaw logic of the animstate (see srv_update),
    -- the resolver only sees eye yaw / lower body yaw target / velocity
    phys_stand_jitter = function() return function(k) return { rel = (k % 2 == 0) and 25 or -40, phys = true } end end,
    phys_lby_flick = function() return function(k) return { rel = (k % 80 < 60) and 0 or 50, phys = true } end end,
    phys_move_jitter = function() return function(k) return { rel = (k % 2 == 0) and 35 or -35, vel = 200, phys = true } end end,
    phys_slow_turn = function() return function(k) return { rel = ((k * 1.5) % 360) - 180, phys = true } end end,
    -- desync that depends on the freestand-ish side, then flips mid-run (player changes AA)
    static_flip = function()
        return function(k) return { rel = 0, T = (k < 900) and 58 or -58 } end
    end,
}

local function norm(a)
    while a > 180 do a = a - 360 end
    while a < -180 do a = a + 360 end
    return a
end
local function approach(target, value, step)
    local d = norm(target - value)
    if d > step then return norm(value + step) end
    if d < -step then return norm(value - step) end
    return norm(target)
end
-- server side, once per tick: feet follow the lower body yaw target standing, the eye yaw moving; the lower body
-- yaw target is set to the eye yaw when the realign timer is up and the feet are more than 35 away.
local function srv_update(s, eye, moving, speed, t, ti)
    if moving then
        local w2r = math.max(0, math.min(1, (speed - 70) / 65))
        s.feet = approach(eye, s.feet, ti * (30 + 20 * w2r))
        s.lby = eye
        s.timer = t + 0.22
    else
        s.feet = approach(s.lby, s.feet, ti * 100)
        if t > s.timer and math.abs(norm(s.feet - eye)) > 35 then
            s.timer = t + 1.1
            s.lby = eye
        end
    end
    local d = norm(eye - s.feet)
    if d > 58 then s.feet = norm(eye - 58) elseif d < -58 then s.feet = norm(eye + 58) end
    return norm(eye - s.feet)
end

function M.run(block_src, scenario_name, opts)
    opts = opts or {}
    local ping_ms = opts.ping or 20
    local ping_ticks = math.ceil(ping_ms / 1000 / (1 / 64))
    local apply_lag = opts.apply_lag or 0
    local ticks = opts.ticks or 2400
    local shoot_every = opts.shoot_every or 9
    local TOL = opts.tol or 15
    local verbose = opts.verbose
    local ping_fn = opts.ping_fn

    local TI = 1 / 64
    local tickcount = 0
    local curtime = 0
    local ENEMY, ME, PR = 2, 1, 99

    local state = {
        rec = nil, plist = {}, logs = {}, forced_sp = {}, newest_arrival = 0,
        eye_yaw = 0, sim = 0, pitch = 89, pose = 0.5, vel = 0, flags = 1, duck = 0,
    }
    local plist_store = {}
    local cfg_opts = opts.options or { "Jitter fix", "Defensive fix", "Defensive snap fix", "LC: body aim", "Safe point on misses", "Body aim on misses", "Log" }
    local cur_ping = ping_ms

    local function clamp(v, min, max)
        if v == nil then return min or 0 end
        if min == nil then min = v end
        if max == nil then max = v end
        if v > max then return max elseif v < min then return min end
        return v
    end
    local function normalize_yaw(a)
        while a > 180 do a = a - 360 end
        while a < -180 do a = a + 360 end
        return a
    end

    local function item(getv) return { get = function() return getv() end, rawget = function() return false end } end
    local config = {
        resolver = {
            enabled = item(function() return true end),
            options = item(function() return cfg_opts end),
            safe_after = item(function() return 2 end),
            baim_after = item(function() return 3 end),
            debugger = item(function() return opts.panel and { "Panel", "Console" } or {} end),
            flip = { get = function() return false end, rawget = function() return opts.flip == true end },
            ping_mode = item(function() return opts.ping_mode or "Auto" end),
            ping_threshold = item(function() return opts.ping_threshold or 35 end),
            ffi = item(function() return opts.ffi_opts or { "Animation layers", "Feet model" } end),
        },
        visuals = {},
    }

    local W = {}
    W.entity = {
        get_players = function(enemies) return { ENEMY } end,
        is_alive = function() return true end,
        is_dormant = function() return false end,
        get_player_resource = function() return PR end,
        hitbox_position = function(idx, hb) return 500, 0, 64 end,
        get_local_player = function() return ME end,
        get_prop = function(ent, name, i)
            local g = state.garbage
            if g and ent == ENEMY then
                local nan, inf = 0/0, 1/0
                if g == 0 and name == "m_angEyeAngles" then return nan, nan end
                if g == 1 and name == "m_angEyeAngles" then return 89, inf end
                if g == 2 and name == "m_flSimulationTime" then return nil end
                if g == 3 and name == "m_flSimulationTime" then return inf end
                if g == 4 and name == "m_vecOrigin" then return nil end
                if g == 5 and name == "m_vecVelocity" then return nan, nan end
                if g == 6 and name == "m_flPoseParameter" then return nan end
                if g == 7 and name == "m_angEyeAngles" then return nil end
                if g == 8 and name == "m_flPoseParameter" then return 7 end
            end
            if ent == PR and name == "m_iPing" then return cur_ping end
            if ent == ME then
                if name == "m_vecOrigin" then return 0, 0, 0 end
                return 0
            end
            if name == "m_flLowerBodyYawTarget" then return state.lby or 0 end
            if name == "m_flSimulationTime" then return state.sim * TI end
            if name == "m_angEyeAngles" then return state.pitch, state.eye_yaw end
            if name == "m_vecOrigin" then return 500, 0, 0 end
            if name == "m_vecVelocity" then return state.vel, 0, 0 end
            if name == "m_fFlags" then return state.flags end
            if name == "m_flDuckAmount" then return state.duck end
            if name == "m_flPoseParameter" then
                if i == 11 then
                    if opts.pose_echo then return ((plist_store["Force body yaw value"] or 0) + 60) / 120 end
                    return state.pose
                end
                return 0
            end
            return 0
        end,
        get_player_name = function(idx) return "enemy" end,
    }
    W.client = {
        screen_size = function() return 1920, 1080 end,
        latency = function() return cur_ping / 2000 end,
        eye_position = function() return 0, 0, 64 end,
        -- freestand mock: left side (y<0) is covered -> fs = +1
        trace_line = function(me, x1, y1, z1, x2, y2, z2) if y1 < 0 then return 0.4 end return 1.0 end,
        current_threat = function() return ENEMY end,
        set_event_callback = function() end,
        register_esp_flag = function() end,
        error_log = function(m) print("ERR: " .. tostring(m)) end,
        color_log = function() end,
        screen_size = function() return 1920, 1080 end,
        system_time = function() return 0, 0, 0 end,
        random_int = function(a, b) return a end,
    }
    W.plist = {
        get = function(idx, field) return plist_store[field] end,
        set = function(idx, field, v)
            plist_store[field] = v
            if field == "Override safe point" then state.forced_sp[idx] = v end
        end,
    }
    W.globals = {
        tickcount = function() return tickcount end,
        tickinterval = function() return TI end,
        curtime = function() return curtime end,
        realtime = function() return curtime end,
    }
    W.renderer = setmetatable({ measure_text = function() return 40 end }, { __index = function() return function() end end })
    local ffi = require("ffi")
    if not pcall(ffi.typeof, "bt_animlayer_t") then
        ffi.cdef[[ typedef struct { float anim_time; float fade_out_time; int nil_; int activty; int priority; int order;
                                    int sequence; float prev_cycle; float weight; float weight_delta_rate; float playback_rate;
                                    float cycle; int owner; int bits; } bt_animlayer_t; ]]
    end
    local layer_buf = ffi.new("bt_animlayer_t[13]")
    local anim_buf = ffi.new("char[?]", 0x400)
    local act_map = { [12] = 979 }        -- sequence 12 is the balance adjust activity in this fake model
    local ffi_helpers = nil
    if opts.ffi or opts.anim then
        ffi_helpers = {
            get_client_entity = function(idx)
                if opts.ent_null then return ffi.cast("void*", 0) end
                return ffi.cast("void*", layer_buf)
            end,
            animlayers = { get = function(self, idx)
                if opts.ent_null then error("layers helper reached with a NULL entity") end
                if opts.layers_null then return nil end
                return ffi.cast("bt_animlayer_t*", layer_buf)
            end },
            activity = { get = function(self, seq, idx) return act_map[seq] or 0 end },
        }
        if opts.anim then
            ffi_helpers.animstate = { get = function(self, idx)
                if opts.ent_null then error("animstate helper reached with a NULL entity") end
                if opts.anim_throw then error("animstate read failed") end
                if opts.anim == "null" then return nil end
                return ffi.cast("void*", anim_buf)
            end }
        end
    end
    state.layer3 = layer_buf[3]
    state.layer6 = layer_buf[6]
    local srv = { feet = 0, lby = 0, timer = 0 }
    state.srv = srv
    local logs = {}
    local c_logger = { log = function(fmt, ...) logs[#logs + 1] = string.format(fmt, ...) end }
    local c_table = { contains = function(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end }
    local c_math = { clamp = clamp, normalize_yaw = normalize_yaw }

    local prelude = [[
local W, config, c_math, c_table, c_logger, TIER, ffi_helpers = ...
local ffi = require("ffi")
local entity, client, plist, globals, renderer = W.entity, W.client, W.plist, W.globals, W.renderer
local math_abs, math_min, math_max, math_sqrt, math_floor, math_ceil = math.abs, math.min, math.max, math.sqrt, math.floor, math.ceil
local table_insert, table_remove, table_sort, table_concat = table.insert, table.remove, table.sort, table.concat
local string_format = string.format
local entity_get_local_player, entity_get_prop, entity_get_player_name = entity.get_local_player, entity.get_prop, entity.get_player_name
local globals_tickcount, globals_curtime, globals_tickinterval = globals.tickcount, globals.curtime, globals.tickinterval
local client_trace_line = client.trace_line
local resolver = {}
]]
    local chunk, err = loadstring(prelude .. block_src .. "\nreturn resolver", "=resolver")
    assert(chunk, err)
    local env = make_env()
    setfenv(chunk, env)
    local resolver = chunk(W, config, c_math, c_table, c_logger, { HAS_RESOLVER = true }, ffi_helpers)

    local scn = M.scenarios[scenario_name](opts)
    local rec = {}        -- arrival tick -> { T, applied, shifted, st }
    local pending = {}
    state.last_goal = 0
    local stats = { shots = 0, hits = 0, misses_res = 0, hits_late = 0, shots_late = 0, errors = 0, def_shots = 0, def_hits = 0, normal_shots = 0, normal_hits = 0 }
    local shot_id = 0
    local max_st = 0
    local prev_value = nil
    local profile_switches = 0
    local last_profile = nil
    local rng = 987654321
    local function rand()
        rng = (rng * 1103515245 + 12345) % 2147483648
        return rng / 2147483648
    end

    for k = 1, ticks do
        tickcount = k
        curtime = k * TI
        if ping_fn then cur_ping = ping_fn(k) end

        local r = scn(k)
        local st = k
        local fz = opts.fuzz and rand() < opts.fuzz and math.floor(rand() * 9) or nil
        if r.shifted then st = k - 3 end
        if r.st then st = r.st end
        state.sim = st
        state.eye_yaw = r.rel
        state.pose = r.pose and ((r.pose + 60) / 120) or 0.5
        if not r.shifted then max_st = st end
        state.pitch = r.shifted and -89 or 89
        state.vel = r.vel or 0
        state.flags = r.air and 0 or 1
        state.garbage = fz

        if r.phys then
            local moving = (r.vel or 0) > 5
            r.T = srv_update(srv, r.rel, moving, r.vel or 0, k * TI, TI)
            if opts.truth_pol then r.T = r.T * opts.truth_pol end
            state.lby = srv.lby
        end
        if opts.balance_every then
            local ph = k % opts.balance_every
            state.layer3.weight = (ph < 6) and 1 or 0
            state.layer3.sequence = (ph < 6) and 12 or 0
            state.layer3.cycle = (ph < 6) and (ph / 6) or 0
        end
        state.layer6.weight = ((r.vel or 0) > 5) and 1 or 0
        state.layer6.cycle = 0.3
        local ok, err2 = pcall(resolver.net_update)

        -- the client animation pass that runs after the net update: what the animstate shows from now on
        if opts.anim and pcall(ffi.typeof, "fres_animstate_t") then
            local a = ffi.cast("fres_animstate_t*", ffi.cast("char*", anim_buf) + (opts.anim_shift or 0))
            local fv = plist_store["Force body yaw"] and plist_store["Force body yaw value"] or nil
            if opts.anim == "bad" then
                for i = 0, 0x3FF do anim_buf[i] = (i * 37 + k) % 251 end
            elseif opts.anim == "zero" then
                ffi.fill(anim_buf, 0x400, 0)
            elseif opts.anim == "nan" then
                a.eye_yaw, a.goal_feet_yaw = 0/0, 1/0
            elseif opts.anim ~= "null" then
                a.eye_yaw = r.rel
                a.eye_pitch = 89
                local goal
                if opts.anim == "forced" and fv ~= nil then
                    goal = norm(r.rel - (opts.anim_pol or 1) * fv)      -- gamesense left our forced value in the animstate
                elseif r.phys then
                    goal = srv.feet                                       -- the engine's own copy of the server logic
                else
                    goal = norm(r.rel - (r.T or 0))
                end
                -- remember what the resolver wrote before the engine overwrites it
                if opts.apply_check then
                    stats.apply_seen = (stats.apply_seen or 0) + 1
                    if math.abs(norm(a.goal_feet_yaw - state.last_goal)) > 0.01 then stats.apply_changed = (stats.apply_changed or 0) + 1 end
                end
                a.goal_feet_yaw = goal
                a.cur_feet_yaw = goal
                state.last_goal = goal
                a.duration_still = ((r.vel or 0) > 5) and 0 or (k * TI)
                a.duration_moving = ((r.vel or 0) > 5) and (k * TI) or 0
                a.vel_len_xy = r.vel or 0
                a.on_ground = r.air and 0 or 1
            end
        end
        if opts.panel and k % 40 == 0 then
            local okp, ep = pcall(resolver.draw_debugger)
            if not okp then stats.errors = stats.errors + 1; print("draw_debugger error:", ep) end
        end
        if not ok then stats.errors = stats.errors + 1; if verbose then print("net_update error:", err2) end end

        local fb = plist_store["Force body yaw"]
        local value = fb and plist_store["Force body yaw value"] or nil
        local applied
        if apply_lag == 0 then applied = value else applied = prev_value end
        prev_value = value
        rec[k] = { T = r.T, applied = applied, shifted = r.shifted or false }
        if plist_store["Override prefer body aim"] == "On" then stats.ba_ticks = (stats.ba_ticks or 0) + 1 end
        if plist_store["Override safe point"] == "On" then stats.sp_ticks = (stats.sp_ticks or 0) + 1 end
        if plist_store["Force pitch"] == true and r.shifted then stats.pitch_ticks = (stats.pitch_ticks or 0) + 1 end

        if resolver.profile and resolver.profile.name ~= last_profile then
            last_profile = resolver.profile.name
            profile_switches = profile_switches + 1
        end

        -- results arrive after the ping
        local i = 1
        while i <= #pending do
            local p = pending[i]
            if p.at <= k then
                local okc, e3
                if p.kind == "hit" then okc, e3 = pcall(resolver.on_hit, p.ev)
                else okc, e3 = pcall(resolver.on_miss, p.ev) end
                if not okc then stats.errors = stats.errors + 1; if verbose then print("result error:", e3) end end
                table.remove(pending, i)
            else
                i = i + 1
            end
        end

        -- the aimbot fires
        if k > 20 and k % shoot_every == 0 then
            local bt = 0
            if rand() < 0.5 then bt = math.floor(rand() * (ping_ticks + 6)) end
            local target_k = math.max(1, k - bt)
            local rr = rec[target_k]
            shot_id = shot_id + 1
            local ev = { target = ENEMY, id = shot_id, backtrack = bt, tick = k, hitgroup = 1, hit_chance = 80 }
            local okf, e4 = pcall(resolver.on_fire, ev)
            if not okf then stats.errors = stats.errors + 1; if verbose then print("on_fire error:", e4) end end
            do
                local sh = resolver.shots[shot_id]
                if sh and sh.value ~= nil and rr.applied ~= nil then
                    stats.attr_total = (stats.attr_total or 0) + 1
                    if sh.value == rr.applied then stats.attr_ok = (stats.attr_ok or 0) + 1 end
                end
            end
            stats.shots = stats.shots + 1
            local late = k > ticks / 2
            if late then stats.shots_late = stats.shots_late + 1 end
            local hit
            if rr.applied == nil then hit = rand() < 0.4 else hit = math.abs(rr.applied - rr.T) <= TOL end
            if rr.shifted then stats.def_shots = stats.def_shots + 1 else stats.normal_shots = stats.normal_shots + 1 end
            if hit then
                stats.run = (stats.run or 0) + 1
                if stats.run >= 5 and not stats.conv then stats.conv = stats.shots end
            else
                stats.run = 0
            end
            if hit then
                stats.hits = stats.hits + 1
                if late then stats.hits_late = stats.hits_late + 1 end
                if rr.shifted then stats.def_hits = stats.def_hits + 1 else stats.normal_hits = stats.normal_hits + 1 end
                pending[#pending + 1] = { at = k + ping_ticks, kind = "hit", ev = { target = ENEMY, id = shot_id, damage = 50, hitgroup = 1 } }
            else
                stats.misses_res = stats.misses_res + 1
                pending[#pending + 1] = { at = k + ping_ticks, kind = "miss", ev = { target = ENEMY, id = shot_id, reason = "?" } }
            end
        end
    end

    stats.rate = stats.shots > 0 and stats.hits / stats.shots or 0
    stats.late_rate = stats.shots_late > 0 and stats.hits_late / stats.shots_late or 0
    stats.def_rate = stats.def_shots > 0 and stats.def_hits / stats.def_shots or -1
    stats.normal_rate = stats.normal_shots > 0 and stats.normal_hits / stats.normal_shots or -1
    stats.profile = resolver.profile and resolver.profile.name or "-"
    stats.profile_switches = profile_switches
    stats.logs = logs
    stats.resolver = resolver
    stats.plist = plist_store
    stats.forced_sp = state.forced_sp
    return stats
end

return M
