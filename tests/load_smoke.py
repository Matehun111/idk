"""Smoke test: does specter_cloud.lua load in a gamesense-like sandbox?

Runs the WHOLE script (auth gate, integrity monitor, menu creation, resolver, FFI helpers ...) under LuaJIT 2.1 with
- no os / io / debug libraries (like gamesense),
- a "ghost" API: every gamesense table (client, entity, ui, ...) answers any field access with a callable object that
  survives arithmetic and comparisons, so load-time code runs without a game,
- strict globals: reading a global that does not exist is an error (catches typos),
- real ffi memory for the signature scans / vtables the script reads at load.

It only proves that the top-level code runs through and that the callbacks the script registered can be invoked
without hitting an undefined global. It does NOT prove that anything works in game.

    pip install lupa
    python3 tests/load_smoke.py [--dev]        (--dev: load through specter_dev.lua with a fake readfile)
"""
import os
import sys

import lupa.luajit21 as L

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

LUA = r'''
return function(src, dev_src, opts)
    local ffi = require("ffi")
    pcall(function() require("jit").off() end)     -- compiled loops would not call the budget hook
    local real_G = _G
    local errors, logs, callbacks = {}, {}, {}

    -- ghosts -------------------------------------------------------------------------------------------------
    local ghost_mt = {}
    local function G() return setmetatable({}, ghost_mt) end
    ghost_mt.__index = function(t, k)
        if type(k) == "number" then return nil end          -- ipairs / # over a ghost ends at once
        local v = G()
        rawset(t, k, v)                                      -- stable identity: client.x == client.x
        return v
    end
    ghost_mt.__call = function(self, ...) return G(), G(), G() end
    for _, ev in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm" }) do
        ghost_mt[ev] = function() return G() end
    end
    ghost_mt.__concat = function() return "ghost" end
    ghost_mt.__len = function() return 0 end
    ghost_mt.__lt = function() return false end
    ghost_mt.__le = function() return false end
    ghost_mt.__eq = function() return false end
    ghost_mt.__tostring = function() return "ghost" end

    -- real memory for the pointers the ffi helpers read at load
    local keep = {}
    local fake_vtable = ffi.new("void*[128]")
    local fake_holder = ffi.new("void*[4]")
    fake_holder[0] = ffi.cast("void*", fake_vtable)
    keep[#keep + 1] = fake_vtable; keep[#keep + 1] = fake_holder
    local function sig_buffer()
        local b = ffi.new("char[64]")
        -- a pointer to the fake holder at +1 (the user_input vtable scan reads it from there)
        ffi.cast("uintptr_t*", b + 1)[0] = ffi.cast("uintptr_t", fake_holder)
        keep[#keep + 1] = b
        return ffi.cast("void*", b)
    end

    local env = {}
    local allowed_nil = { LPH_OBFUSCATED = true, SPECTER_SHARED = true, debug = true, os = true, io = true, jit = true }
    local function gamesense_table(extra)
        local t = G()
        for k, v in pairs(extra or {}) do rawset(t, k, v) end
        return t
    end

    env.client = gamesense_table({
        unix_time = function() return opts.now end,
        timestamp = function() return opts.now * 1000 end,
        system_time = function() return 12, 30, 15, 0 end,
        error_log = function(m) errors[#errors + 1] = "error_log: " .. tostring(m) end,
        color_log = function(r, g, b, m) logs[#logs + 1] = tostring(m) end,
        log = function(m) logs[#logs + 1] = tostring(m) end,
        set_event_callback = function(name, fn) callbacks[#callbacks + 1] = { name = name, fn = fn } end,
        unset_event_callback = function() end,
        delay_call = function() end,
        random_int = function(a, b) return a or 0 end,
        random_float = function(a, b) return a or 0 end,
        screen_size = function() return 1920, 1080 end,
        latency = function() return 0.02 end,
        find_signature = function() return sig_buffer() end,
        create_interface = function() return ffi.cast("void*", fake_holder) end,
        register_esp_flag = function() end,
        current_threat = function() return nil end,
    })
    env.entity = gamesense_table({ get_local_player = function() return nil end, get_players = function() return {} end })
    env.globals = gamesense_table({
        tickcount = function() return 1000 end, tickinterval = function() return 1 / 64 end,
        curtime = function() return 15.6 end, realtime = function() return 20 end,
        frametime = function() return 0.01 end, maxplayers = function() return 64 end, mapname = function() return "de_dust2" end,
    })
    env.ui = gamesense_table()
    env.renderer = gamesense_table()
    env.database = gamesense_table({ read = function() return nil end, write = function() end })
    env.plist = gamesense_table()
    env.cvar = gamesense_table()
    env.materials = gamesense_table()
    env.panorama = gamesense_table()
    env.vtable_bind = function() return function() return ffi.cast("void*", 0) end end
    env.vtable_thunk = function() return function() return ffi.cast("void*", 0) end end
    env.vtable_entry = function() return ffi.cast("void*", 0) end
    env.toticks = function(t) return math.floor(0.5 + (t or 0) * 64) end
    env.totime = function(t) return (t or 0) / 64 end
    env.readfile = function(name) if opts.dev and name == "lua/specter_cloud.lua" then return src end end
    env.writefile = function() end
    env.print = function(...) end

    -- standard library, without os / io / debug (gamesense has none of them) and with a safe string.format
    for _, name in ipairs({ "assert", "error", "ipairs", "pairs", "next", "pcall", "xpcall", "select", "tonumber", "tostring",
                            "type", "unpack", "rawget", "rawset", "rawequal", "setmetatable", "getmetatable",
                            "math", "string", "table", "bit", "coroutine", "collectgarbage", "gcinfo", "newproxy" }) do
        env[name] = real_G[name]
    end
    -- gamesense scripts share one global table: chunks compiled at runtime run in the same environment
    env.loadstring = function(code, name)
        local f, e = real_G.loadstring(code, name)
        if f then setfenv(f, env) end
        return f, e
    end
    env.load = env.loadstring
    local libs = {}
    env.require = function(name)
        if name == "ffi" or name == "bit" then return real_G.require(name) end
        local m = libs[name]
        if not m then m = G(); libs[name] = m end
        return m
    end
    env._G = env
    setmetatable(env, { __index = function(t, k)
        if allowed_nil[k] then return nil end
        error("undefined global read: " .. tostring(k), 2)
    end })

    -- the script writes some globals (LPH_*, SPECTER_SHARED, _USER_NAME ...): plain assignments on env
    local function run(code, name)
        local chunk, err = loadstring(code, name)
        if not chunk then return false, "syntax: " .. tostring(err) end
        setfenv(chunk, env)
        return xpcall(chunk, function(e) return tostring(e) .. "\n" .. real_G.debug.traceback("", 2) end)
    end

    -- runaway guard: instruction budget and memory budget (ghosts allocate on every access)
    local function budget(instr_millions, mem_mb)
        local n = 0
        real_G.debug.sethook(function()
            n = n + 1
            if n > instr_millions * 1000 then error("timeout (instruction budget)\n" .. real_G.debug.traceback("", 2)) end
            if n % 20 == 0 and collectgarbage("count") > mem_mb * 1024 then
                error("memory budget exceeded\n" .. real_G.debug.traceback("", 2))
            end
        end, "", 1000)
    end
    budget(300, 900)

    local result = { loaded = false }
    if opts.dev then
        -- through the dev loader, exactly like gamesense runs it
        local ok, err = run(dev_src, "@specter_dev")
        result.loaded, result.error = ok, err
    else
        rawset(env, "_auth_ok", true); rawset(env, "_auth_alive", true); rawset(env, "_auth_ts", opts.now)
        rawset(env, "_auth_user", "tester"); rawset(env, "_auth_key", "KEY"); rawset(env, "_auth_hwid", "HWID")
        rawset(env, "BUILD_VERSION", opts.plan or "debug"); rawset(env, "_server_url", "https://example.invalid")
        local ok, err = run(src, "@specter_cloud")
        result.loaded, result.error = ok, err
    end
    real_G.debug.sethook()

    -- invoke every registered callback once: undefined globals / typos show up, ghost arithmetic does not matter
    local cb_errors = {}
    if result.loaded and opts.callbacks then
        for _, cb in ipairs(callbacks) do
            budget(50, 900)
            local ok, err = pcall(cb.fn, G())
            real_G.debug.sethook()
            if not ok and tostring(err):find("undefined global read", 1, true) then
                cb_errors[#cb_errors + 1] = cb.name .. ": " .. tostring(err)
            end
        end
    end
    result.callbacks = #callbacks
    result.cb_errors = cb_errors
    result.errors = errors
    result.logs = logs
    result.auth_wiped = rawget(env, "_auth_ok") == nil and rawget(env, "_auth_key") == nil
    return result
end
'''


def main():
    import resource
    resource.setrlimit(resource.RLIMIT_AS, (6 * 1024 ** 3, 6 * 1024 ** 3))   # fail with an error instead of being OOM-killed
    dev = "--dev" in sys.argv
    plan = "debug"
    for a in sys.argv[1:]:
        if a.startswith("--plan="):
            plan = a.split("=", 1)[1]
    src = open(os.path.join(ROOT, "specter_cloud.lua"), encoding="utf-8").read()
    dev_src = open(os.path.join(ROOT, "specter_dev.lua"), encoding="utf-8").read()
    rt = L.LuaRuntime(unpack_returned_tuples=True)
    runner = rt.eval("function(code) return load(code)() end")(LUA)
    res = runner(src, dev_src, rt.table_from({"now": 1700000000, "dev": dev, "plan": plan, "callbacks": True}))
    print(f"mode: {'dev loader' if dev else 'direct'}   plan: {plan}")
    print("loaded:", res.loaded)
    if not res.loaded:
        print("ERROR:", res.error)
    print("callbacks registered:", res.callbacks)
    print("auth globals wiped after load:", res.auth_wiped)
    for e in res.errors.values():
        print("  script reported:", e)
    for e in res.cb_errors.values():
        print("  callback problem:", e)
    ok = bool(res.loaded) and len(res.cb_errors) == 0
    print("SMOKE TEST", "PASSED" if ok else "FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
