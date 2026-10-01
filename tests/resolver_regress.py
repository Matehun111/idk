"""Regression tests for the resolver block of specter_cloud.lua (desync resolver + jitter resolver in one module).

Runs the real code (the part between the `-- [resolver:begin]` / `-- [resolver:end]` markers) on a mocked gamesense API
with simulated enemies (tests/resolver_world.lua: hidden tick level AA, a copy of the server feet logic for the true body
yaw, fakelag, tickbase shifts, an aimbot with backtrack and ping delayed results), under LuaJIT 2.1 like gamesense uses.

    pip install lupa
    python3 tests/resolver_regress.py

This checks the learning and the player list handling, not the real game. Exit code is non-zero when a check fails.
Native alone (nothing forced) hits ~0.23 in this world; the ceiling is ~0.92 (6% spread misses + the tolerance).
"""
import os
import re
import sys

import lupa.luajit21 as L

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

src = open(os.path.join(ROOT, "specter_cloud.lua"), encoding="utf-8").read()
m = re.search(r"-- \[resolver:begin\]\n(.*?)\n\s*-- \[resolver:end\]", src, re.S)
if not m:
    sys.exit("resolver markers not found in specter_cloud.lua")
BLOCK = m.group(1)

# what the main script gives the block: the `resolver` table, the menu items (config.resolver), the logger; and the
# event wiring of the main script (miscellaneous:aim_* -> resolver.on_*, round start -> resolver.new_round)
PRELUDE = '''
local resolver = {}
local enable_item = ui.new_checkbox("RAGE", "Other", "Resolver")
local parts_item = ui.new_multiselect("RAGE", "Other", "Resolver parts", { "Desync resolver", "Jitter resolver", "Neural network", "Log" })
ui.set(parts_item, { "Desync resolver", "Jitter resolver" })
local function wrap(it) return { get = function() return ui.get(it) end } end
local config = { resolver = { enabled = wrap(enable_item), parts = wrap(parts_item) } }
local c_logger = { log = function(fmt, ...) client.color_log(255, 255, 255, string.format(fmt, ...)) end }
local hooks = { fire = 0, hit = 0, miss = 0 }
resolver.stats_hook = function(kind) hooks[kind] = hooks[kind] + 1 end
'''
EPILOGUE = '''
client.set_event_callback("aim_fire", function(e) resolver.on_fire(e) end)
client.set_event_callback("aim_hit", function(e) resolver.on_hit(e) end)
client.set_event_callback("aim_miss", function(e) resolver.on_miss(e) end)
client.set_event_callback("round_prestart", function() resolver.new_round() end)
return { resolver = resolver, hooks = hooks }
'''
SCRIPT = PRELUDE + BLOCK + EPILOGUE

rt = L.LuaRuntime(unpack_returned_tuples=True)
H = rt.eval("function(src) return load(src)() end")(open(os.path.join(HERE, "resolver_world.lua")).read())
lua = rt.eval

fails = []


def check(cond, msg):
    if not cond:
        fails.append(msg)
        print("   FAIL:", msg)


def errors_of(s):
    return list(s.ctl.errors.values())


def run(scn=None, driver=None, **kw):
    o = dict(kw)
    if scn:
        o["scenario"] = scn
        o["driver_opts"] = rt.table_from(driver or {})
    return H.run(SCRIPT, rt.table_from(o))


def avg(scn, d, ping, seeds=(1, 2, 3), **kw):
    vals = []
    for sd in seeds:
        s = run(scn, dict(d, seed=7 + sd * 13), ticks=4000, ping=ping, seed=sd, **kw)
        check(s.errors == 0 and not errors_of(s), f"{scn}{d} {ping}ms: errors {errors_of(s)[:2]}")
        vals.append(s.late_rate)
    return sum(vals) / len(vals)


def pl(s, idx, field):
    t = s.ctl.plist[idx]
    return t[field] if t is not None else None


def parts(*names):
    t = "{" + ", ".join(f'"{n}"' for n in names) + "}"
    return lua(f"function(ctl) ctl.item('Resolver parts').value = {t} end")


# ── hit rates ───────────────────────────────────────────────────────────────────
print("== late hit rate (second half of the run), 3 seeds")
RATES = [
    # static desync -> desync part
    ("choke_static", dict(choke=6), 0.88), ("choke_static", dict(choke=2), 0.88), ("low_delta", {}, 0.88),
    ("choke_defensive", dict(choke=6), 0.80), ("lby_flick", {}, 0.88), ("lby_flick", dict(flick=60), 0.88),
    # side switching: on hit / on miss / on every shot (anti-bruteforce), at random moments -> side tracking
    ("anti_brute", dict(choke=6), 0.88), ("anti_brute", dict(choke=2), 0.88), ("anti_miss", dict(choke=6), 0.86),
    ("anti_miss", dict(choke=2), 0.88), ("anti_shot", dict(choke=6), 0.75), ("choke_random", dict(choke=6), 0.66),
    # jitter -> jitter part
    ("jitter_tick", {}, 0.88), ("jitter_tick", dict(amp=58), 0.88), ("jitter_delay", dict(period=3), 0.88),
    ("jitter_delay", dict(period=5), 0.88), ("jitter_choke", dict(choke=3), 0.88), ("moving_jitter", {}, 0.88),
    ("jitter_random", {}, 0.85), ("jitter_rperiod", {}, 0.88), ("jitter_drift", {}, 0.88), ("jitter_multi", {}, 0.80),
    ("aa_sim", dict(scheme="current"), 0.85),
]
print(f"{'scenario':<34}{'20ms':>7}{'80ms':>7}")
for scn, d, need in RATES:
    cells = [avg(scn, d, ping) for ping in (20, 80)]
    print(f"{scn + (str(d) if d else ''):<34}" + "".join(f"{c:>7.2f}" for c in cells))
    for ping, c in zip((20, 80), cells):
        check(c >= need, f"{scn}{d} {ping}ms: hit rate {c:.2f} < {need}")

# ── side tracking: the enemy reacts later (its own ping + choke), shots with noise ──────
print("== side tracking: enemy reaction delay (calibrated per player), noise")
for scn, need in (("anti_brute", 0.88), ("anti_miss", 0.86), ("anti_shot", 0.65)):
    cells = []
    for rd in (4, 10):
        for ping in (20, 80):
            c = avg(scn, dict(choke=6), ping, react_delay=rd)
            cells.append(c)
            check(c >= need, f"{scn} reaction delay {rd} {ping}ms: hit rate {c:.2f} < {need}")
    print(f"   {scn:<12} delay 4: {cells[0]:.2f} / {cells[1]:.2f}   delay 10: {cells[2]:.2f} / {cells[3]:.2f}  (20 / 80 ms)")
# 15% spread + 10% misses for other reasons: the static targets keep their (lower) ceiling, side tracking does not fall apart
for scn, need in (("choke_static", 0.70), ("anti_brute", 0.50), ("anti_miss", 0.50), ("choke_random", 0.45)):
    c = avg(scn, dict(choke=6), 20, spread_p=0.15, noise_p=0.10)
    print(f"   noise {scn:<12} {c:.2f}")
    check(c >= need, f"noise {scn}: hit rate {c:.2f} < {need}")
for scn in ("anti_brute", "lby_flick"):
    c = avg(scn, dict(choke=6), 20, truth_pol=-1)
    print(f"   inverted sign {scn:<12} {c:.2f}")
    check(c >= 0.88, f"inverted sign {scn}: hit rate {c:.2f}")

G0 = lua('''function(tick, ent, name)
    local r = (tick * 7 + ent * 13 + #name) % 19
    if r == 0 then return 0/0 elseif r == 1 then return math.huge elseif r == 2 then return -1e30 end
    return nil
end''')

# ── neural network ─────────────────────────────────────────────────────────────
print("== neural network (Parts > Neural network)")
NNON = lua('function(ctl) ctl.item("Resolver parts").value = { "Desync resolver", "Jitter resolver", "Neural network" } end')
NNACC = lua('''function(acc)
    return function(k, e, r, hit, ctl, S)
        if k <= 2000 then return end
        local best, bt = nil, -1
        for _, s in pairs(S.resolver.shots) do if s.time > bt then best, bt = s, s.time end end
        if best and best.nnv ~= nil then
            acc.n = acc.n + 1
            if math.abs(best.nnv - r.T) <= 12 then acc.ok = acc.ok + 1 end
        end
    end
end''')
for scn, d, need_acc in (("choke_static", dict(choke=6), 0.9), ("anti_brute", dict(choke=6), 0.9), ("jitter_tick", {}, 0.9),
                         ("jitter_choke", dict(choke=3), 0.9), ("lby_flick", {}, 0.75)):
    off, on = avg(scn, d, 20), avg(scn, d, 20, configure=NNON)
    acc = lua("function() return { n = 0, ok = 0 } end")()
    run(scn, dict(d), ticks=4000, ping=20, configure=NNON, on_shot=NNACC(acc))
    a = acc.ok / max(1, acc.n)
    print(f"   {scn:<14} hit rate off {off:.2f} / on {on:.2f}   the network's own call on the head: {a:.2f} ({int(acc.n)} shots)")
    check(on >= off - 0.02, f"neural network on {scn}: {on:.2f} < off {off:.2f}")
    check(acc.n > 100 and a >= need_acc, f"neural network accuracy {scn}: {a:.2f} over {int(acc.n)} shots")

# kept between sessions (database), a broken save starts over, Reset memory clears it
db = lua("function() return {} end")()
s = run("jitter_tick", {}, ticks=2500, configure=NNON, db=db)
n1 = s.S.resolver.nn_info()[0]
s.fire("shutdown")
check(n1 >= 30 and db["specter_nn_resolver"] is not None, f"network saved on shutdown ({n1} results)")
s = run("jitter_tick", {}, ticks=10, configure=NNON, db=db)
check(s.S.resolver.nn_info()[0] == n1, f"network loaded in the next session: {s.S.resolver.nn_info()[0]} vs {n1}")
s.S.resolver.reset_all()
check(s.S.resolver.nn_info()[0] == 0 and db["specter_nn_resolver"] is None, "Reset memory clears the network and its save")
bad = lua('function() return { specter_nn_resolver = { version = 1, w1 = { 0/0 }, w2 = {}, b1 = {}, b2 = {}, n = 50, agree = 0.5 } } end')()
# a save whose replay buffer has broken entries: they are dropped at load, learning goes on without errors
bad2 = lua('function(src) local t = {}; for k, v in pairs(src) do t[k] = v end; t.buffer = { { x = { 1, 2 }, v = 5, hit = true }, "junk", { x = {}, v = 0/0, hit = false } }; return { specter_nn_resolver = t } end')
saved_ok = run("jitter_tick", {}, ticks=2500, configure=NNON, db=lua("function() return {} end")())
saved_ok.fire("shutdown")
s = run("jitter_tick", {}, ticks=1500, configure=NNON, db=bad2(saved_ok.ctl.db["specter_nn_resolver"]))
check(s.errors == 0 and not errors_of(s), f"save with broken replay entries: {errors_of(s)[:2]}")
s = run("jitter_tick", {}, ticks=5, configure=NNON, db=bad)
check(s.S.resolver.nn_info()[0] == 0, "broken save: a new network")
s = run("jitter_tick", {}, ticks=1500, configure=NNON, db=bad)
check(s.errors == 0 and not errors_of(s), f"broken save: {errors_of(s)[:2]}")
s = run("choke_static", dict(choke=6), ticks=3000, configure=NNON, garbage=G0)
check(s.errors == 0 and not errors_of(s), f"neural network with garbage netvars: {errors_of(s)[:2]}")
print(f"   saved / loaded between sessions ({n1} results), broken save and reset handled")

# ── parts ───────────────────────────────────────────────────────────────────────
print("== parts")
s = run("choke_static", dict(choke=6), ticks=3000, configure=parts("Jitter resolver"))
check(not pl(s, 2, "Force body yaw"), "jitter part only: a static target must be left to the native resolver")
check(s.late_rate < 0.40, f"jitter part only, static target: {s.late_rate:.2f} should be native-like")
s = run("jitter_tick", {}, ticks=3000, configure=parts("Desync resolver"))
check(pl(s, 2, "Force body yaw") is True, "desync part only: a jittering target is still forced by the desync part")
check(s.S.resolver.database[2].mode == "d", "desync part only: the jitter part must be off (records resolved by the desync part)")
s = run("jitter_tick", {}, ticks=3000, configure=parts())
check(not pl(s, 2, "Force body yaw"), "no parts: nothing forced")
r_both = avg("jitter_tick", {}, 20)
print(f"   jitter_tick: both parts {r_both:.2f}")

# ── player list handling ──────────────────────────────────────────────────────
print("== player list")
s = run("choke_static", dict(choke=6), ticks=500, disabled=True)
check(len(list(s.ctl.plist.keys())) == 0, "disabled: the player list must not be touched")

# Correction active is given back with the value it had (false here), also when it was false
CORR = lua('''function(ctl) ctl.plist[2] = { ["Correction active"] = false } end''')
TOGGLE = lua('''function(state)
    return function(k, ctl, S)
        if k == 1500 then ctl.item("Resolver").value = false end
        if k == 1499 then state.mid = { ctl.plist[2]["Force body yaw"], ctl.plist[2]["Correction active"] } end
        if k == 1600 then state.off = { ctl.plist[2]["Force body yaw"], ctl.plist[2]["Correction active"] } end
    end
end''')
state = lua("function() return {} end")()
s = run("choke_static", dict(choke=6), ticks=1700, configure=CORR, on_tick=TOGGLE(state))
check(state.mid[1] is True and state.mid[2] is True, f"enabled: forced + correction on ({state.mid[1]}, {state.mid[2]})")
check(state.off[1] is False and state.off[2] is False, f"disabled mid-game: released, correction back to false ({state.off[1]}, {state.off[2]})")

# dead / dormant players are released (gamesense does not list them), forced again when they are back
for what in ("dead_fn", "dormant_fn"):
    state = lua("function() return {} end")()
    WATCH = lua('''function(state)
        return function(k, ctl, S)
            if k == 1100 then state.during = ctl.plist[2]["Force body yaw"] end
            if k == 1400 then state.after = ctl.plist[2]["Force body yaw"] end
        end
    end''')(state)
    gone = lua("function(tick, idx) return tick >= 1000 and tick < 1200 end")
    s = run("choke_static", dict(choke=6), ticks=2500, on_tick=WATCH, **{what: gone})
    check(s.errors == 0 and not errors_of(s), f"{what}: errors {errors_of(s)[:2]}")
    check(state.during is False, f"{what}: must be released while gone (Force body yaw = {state.during})")
    check(state.after is True, f"{what}: must be forced again when back (Force body yaw = {state.after})")
    check(s.late_rate >= 0.85, f"{what}: hit rate after coming back {s.late_rate:.2f}")
    print(f"   {what}: released while gone, back after; late rate {s.late_rate:.2f}")

s = run("choke_static", dict(choke=6), ticks=800)
check(pl(s, 2, "Force body yaw") is True, "forced while running")
s.fire("shutdown")
check(pl(s, 2, "Force body yaw") is False, "shutdown releases")

# ── shot attribution: a shot is judged by the value its record got ───────────
print("== shot attribution (half of the shots go at backtracked records)")
ATTR = lua('''function(acc)
    return function(k, e, r, hit, ctl, S)
        local best, bt = nil, -1
        for _, s in pairs(S.resolver.shots) do if s.time > bt then best, bt = s, s.time end end
        if best and best.mode and r.applied ~= nil then
            acc.n = acc.n + 1
            if best.value ~= r.applied then acc.bad = acc.bad + 1 end
            if best.bt > 0 then acc.bt = acc.bt + 1 end
        end
    end
end''')
for scn, d in (("choke_static", dict(choke=6)), ("choke_random", dict(choke=6)), ("anti_brute", dict(choke=6)), ("jitter_rperiod", {}), ("lby_flick", {})):
    acc = lua("function() return { n = 0, bad = 0, bt = 0 } end")()
    for ping in (20, 80):
        run(scn, dict(d), ticks=3000, ping=ping, on_shot=ATTR(acc))
    print(f"   {scn}: {acc.n} shots ({acc.bt} backtracked), {acc.bad} judged by a different value than their record got")
    check(acc.n > 100 and acc.bt > 30, f"{scn}: too few shots to judge attribution")
    check(acc.bad == 0, f"{scn}: {acc.bad} shots judged by the wrong value")

# ── robustness ────────────────────────────────────────────────────────────────
print("== robustness")
G = lua('''function(tick, ent, name)
    local r = (tick * 7 + ent * 13 + #name) % 19
    if r == 0 then return 0/0 elseif r == 1 then return math.huge elseif r == 2 then return -1e30 end
    return nil
end''')
for scn, d in (("choke_static", dict(choke=6)), ("jitter_tick", {}), ("jitter_choke", dict(choke=3)), ("moving_jitter", {})):
    s = run(scn, d, ticks=3000, ping=40, garbage=G)
    check(s.errors == 0 and not errors_of(s), f"garbage props {scn}: {errors_of(s)[:2]}")
print("   garbage netvars (NaN / inf / huge): no errors")

s = run("jitter_tick", {}, ticks=3000, no_ids=True)
check(s.errors == 0 and s.late_rate >= 0.85, f"shots without ids: {s.late_rate:.2f} {errors_of(s)[:2]}")

ENEMIES = lua('''function(drivers)
    local specs = {}
    for i, name in ipairs({ 'choke_static', 'jitter_tick', 'jitter_delay', 'moving_jitter', 'jitter_rperiod' }) do
        specs[i] = { driver = drivers[name]({ period = 3, choke = 6, seed = 40 + i }), name = 'enemy' .. i }
    end
    return specs
end''')(H.drivers)
s = run(enemies=ENEMIES, ticks=12000, ping=30, shoot_every=4)
rates = [s.per[i].late_rate for i in range(2, 7)]
print("   5 enemies (static, jitter x4):", [round(x, 2) for x in rates])
check(s.errors == 0 and not errors_of(s), f"5 enemies: {errors_of(s)[:2]}")
check(min(rates) >= 0.85, f"5 enemies: lowest {min(rates):.2f}")
check(len(list(s.S.resolver.memory.keys())) == 5, "5 enemies: one memory per player")

# a new player in the slot of one who left (another steam id): a new memory, not the old one's
SID = lua('function(tick, idx) if tick >= 2000 then return "76561198999999999" end return "7656119800000000" .. idx end')
s = run("choke_static", dict(choke=6), ticks=3000, steam_fn=SID)
keys = sorted(s.S.resolver.memory.keys())
check(len(keys) == 2 and s.S.resolver.database[2].key == "id76561198999999999", f"slot reuse: keys {keys}")

# sim time jumping back (map change) and a long gap: the records start over, no errors
JUMP = lua('''function(drivers)
    local d = drivers.jitter_tick({})
    d.shift = function(k) if k == 1500 then return { back = 40, theta = 0 } end return nil end
    return { { driver = d, name = 'enemy1' } }
end''')(H.drivers)
s = run(enemies=JUMP, ticks=3000)
check(s.errors == 0 and s.late_rate >= 0.85, f"sim time jump: {s.late_rate:.2f} {errors_of(s)[:2]}")

# round reset, memory reset mid-game (results of shots fired before it arrive after it)
RESETS = lua('''function(k, ctl, S)
    if k == 1200 then for _, fn in ipairs(ctl.callbacks.round_prestart or {}) do fn() end end
    if k == 1700 then S.resolver.reset_all() end
end''')
s = run("jitter_tick", {}, ticks=4000, on_tick=RESETS)
check(s.errors == 0 and not errors_of(s), f"round / memory reset: {errors_of(s)[:2]}")
check(s.late_rate >= 0.85, f"after round / memory reset: {s.late_rate:.2f}")
check(s.S.hooks.fire == s.shots, f"stats hook: {s.S.hooks.fire} fire calls for {s.shots} shots")
check(s.S.hooks.hit + s.S.hooks.miss > 0.9 * s.shots, "stats hook: hit / miss calls")
print(f"   round + memory reset: {s.late_rate:.2f}; stats hook fire {s.S.hooks.fire} / {s.shots} shots")

# log only when the option is on
s = run("jitter_tick", {}, ticks=1500)
check(len(list(s.ctl.logs.values())) == 0, "log off: nothing printed")
s = run("jitter_tick", {}, ticks=1500, configure=parts("Desync resolver", "Jitter resolver", "Log"))
logs = list(s.ctl.logs.values())
check(len(logs) > 10 and any("jitter" in x for x in logs), f"log on: {logs[:2]}")
print("   log line:", logs[0] if logs else "-")

print()
if fails:
    print(f"{len(fails)} CHECK(S) FAILED")
    sys.exit(1)
print("ALL CHECKS PASSED")
