"""Regression tests for specter_resolver.lua (the standalone desync resolver).

Runs the REAL script under LuaJIT 2.1 (like gamesense) on a mocked gamesense API (tests/standalone/harness.lua):
no os / io / debug libraries, strict globals, real ffi memory for the animstate / animation layers, and a simulated
world where the enemies' anti-aim decides an eye yaw for every tick (with fakelag), a copy of the server's feet
logic turns that into the true body yaw, and an aimbot model shoots with backtrack and ping delayed results.

    pip install lupa
    python3 tests/standalone_regress.py

It checks the logic (learning, classification, safety, menu), not the real game: it cannot tell what the networked
animation data looks like in game. Exit code is non-zero when a check fails.
"""
import os
import sys
import time

import lupa.luajit21 as L

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SRC = open(os.path.join(ROOT, "specter_resolver.lua"), encoding="utf-8").read()

rt = L.LuaRuntime(unpack_returned_tuples=True)
H = rt.eval("function(src) return load(src)() end")(open(os.path.join(HERE, "standalone", "harness.lua")).read())
fails = []
t0 = time.time()


def check(cond, msg):
    if not cond:
        fails.append(msg)
        print("   FAIL:", msg)


def tbl(d):
    return rt.table_from(d)


def run(scn=None, src=None, driver_opts=None, **opts):
    o = dict(opts)
    if scn is not None:
        o["scenario"] = scn
    if driver_opts is not None:
        o["driver_opts"] = tbl(driver_opts)
    return H.run(src if src is not None else SRC, tbl(o))


def lua_list(items):
    return rt.table_from(list(items))


def errors_of(stats):
    return stats.errors + len(list(stats.ctl.errors.values()))


# ── 1. hit rate per anti-aim, two pings, four seeds ─────────────────────────────────────────────────────────────
# (name, driver options, run options, minimum late hit rate at 20 ms, at 80 ms)
# the aimbot model misses 6% of the shots through spread (and not a resolver miss), so ~0.92 is the ceiling
SCENARIOS = [
    ("choke_static",       dict(choke=6), {},                  0.88, 0.88),
    ("choke_static",       dict(choke=2), {},                  0.88, 0.88),
    ("jitter_tick",        dict(),        {},                  0.88, 0.88),
    ("jitter_delay",       dict(period=3), {},                 0.88, 0.88),
    ("jitter_choke",       dict(choke=3), {},                  0.88, 0.88),
    ("lby_flick",          dict(),        {},                  0.88, 0.88),
    ("moving_jitter",      dict(),        {},                  0.88, 0.88),
    ("slow_spin",          dict(),        {},                  0.88, 0.88),
    ("low_delta",          dict(),        {},                  0.88, 0.88),
    ("choke_defensive",    dict(choke=6), {},                  0.88, 0.88),
    # targets that switch sides: it takes a miss to see it, the aim is to take one and not four
    ("choke_random",       dict(choke=6), {},                  0.72, 0.64),
    ("anti_brute",         dict(choke=6), {},                  0.64, 0.46),
    ("anti_miss",          dict(choke=6), {},                  0.72, 0.60),
    ("anti_shot",          dict(choke=6), {},                  0.52, 0.40),
    # one shot in ten missing for reasons that are not the angle must not make a static target look like a switching one
    ("choke_static",       dict(choke=6), dict(noise_p=0.10),  0.78, 0.78),
    ("lby_flick",          dict(),        dict(noise_p=0.10),  0.78, 0.78),
    ("choke_random",       dict(choke=6), dict(noise_p=0.10),  0.56, 0.52),
]
SEEDS = (1, 2, 3, 4)


def label(n, o, r):
    s = n
    if o:
        s += "(" + ",".join(f"{k}={v}" for k, v in o.items()) + ")"
    if r:
        s += "+" + ",".join(f"{k}={v}" for k, v in r.items())
    return s


print("== late hit rate (second half of the run), mean of %d seeds   (native resolver alone: ~0.25)" % len(SEEDS))
print(f"{'scenario':<38}{'20 ms':>8}{'80 ms':>8}")
for name, dopts, ropts, min20, min80 in SCENARIOS:
    cells = []
    for ping, floor in ((20, min20), (80, min80)):
        vals = []
        for sd in SEEDS:
            do = dict(dopts)
            do["seed"] = 7 + sd * 13
            s = run(name, driver_opts=do, ticks=4000, ping=ping, seed=sd, **ropts)
            check(errors_of(s) == 0, f"{label(name, dopts, ropts)} {ping}ms seed {sd}: errors {list(s.ctl.errors.values())[:2]}")
            vals.append(s.late_rate)
        mean = sum(vals) / len(vals)
        check(mean >= floor, f"{label(name, dopts, ropts)} {ping}ms: late hit rate {mean:.2f} < {floor:.2f}")
        cells.append(mean)
    print(f"{label(name, dopts, ropts):<38}{cells[0]:>8.2f}{cells[1]:>8.2f}")


# ── 2. the pieces must matter: switch one off, the scenario that needs it gets worse ───────────────────────────
print("== ablations (a piece off must cost hit rate where it matters)")


def mean_rate(scn, dopts=None, seeds=(1, 2), **kw):
    vals = []
    for sd in seeds:
        d = dict(dopts or {})
        d["seed"] = 7 + sd * 13
        vals.append(run(scn, driver_opts=d, ticks=4000, ping=20, seed=sd, **kw).late_rate)
    return sum(vals) / len(vals)


def no_model(ctl, S):
    ctl.set_ffi(lua_list([]))


full = mean_rate("lby_flick")
off = mean_rate("lby_flick", configure=no_model)
print(f"  lby_flick  feet model on {full:.2f}   off {off:.2f}")
check(full - off >= 0.15, f"the feet model must carry lby_flick ({full:.2f} vs {off:.2f})")

pose_on = mean_rate("choke_static", dict(choke=6), pose_real=True)
print(f"  choke_static with a real pose parameter {pose_on:.2f}")
check(pose_on >= 0.88, f"real pose parameter must not hurt ({pose_on:.2f})")


def no_native(ctl, S):
    items = [o for o in ["Jitter fix", "Defensive fix", "Defensive snap fix", "LC: body aim", "Safe point on misses",
                         "Body aim on misses", "Remember learning", "Log"]]
    ctl.set_options(lua_list(items))


nat_off = mean_rate("choke_static", dict(choke=6), configure=no_native)
print(f"  native fallback arm off {nat_off:.2f}")
check(nat_off >= 0.88, f"static target without the native arm {nat_off:.2f}")


# ── 3. garbage in must never throw ───────────────────────────────────────────────────────────────────────────────
print("== garbage netvars (nan / inf / huge / nil), animstate garbage, null entities")
GARBAGE = rt.eval("""function(tick, ent, name)
    local r = (tick * 7 + ent * 13 + #name) % 23
    if r == 0 then return 0/0 end
    if r == 1 then return math.huge end
    if r == 2 then return -1e30 end
    if r == 3 then return nil end
    return nil
end""")
for scn, dopts in (("choke_static", dict(choke=6)), ("jitter_tick", {}), ("choke_defensive", dict(choke=6)),
                   ("lby_flick", {}), ("moving_jitter", {})):
    s = run(scn, driver_opts=dopts, ticks=3000, ping=40, garbage=GARBAGE, panel=True)
    check(errors_of(s) == 0, f"garbage props {scn}: {list(s.ctl.errors.values())[:2]}")

for mode in ("bad", "zero"):
    s = run("choke_static", driver_opts=dict(choke=6), ticks=2500, anim=mode,
            configure=lambda ctl, S: ctl.set_ffi(lua_list(["Animation layers", "Feet model", "Animstate apply (experimental)", "Telemetry"])))
    check(errors_of(s) == 0, f"animstate memory '{mode}': {list(s.ctl.errors.values())[:2]}")
    check(s.S.F.writes == 0, f"animstate memory '{mode}': the script wrote {s.S.F.writes} times into memory it could not verify")
    check(s.late_rate >= 0.85, f"animstate memory '{mode}': resolver degraded to {s.late_rate:.2f}")
    print(f"  animstate '{mode}': layout {s.S.F.layout}, writes {s.S.F.writes}, late rate {s.late_rate:.2f}")

for shift in (4, 8, -4, 12):
    s = run("lby_flick", ticks=2500, anim="ok", anim_shift=shift,
            configure=lambda ctl, S: ctl.set_ffi(lua_list(["Animation layers", "Feet model", "Animstate apply (experimental)"])))
    check(errors_of(s) == 0, f"animstate shifted by {shift}: {list(s.ctl.errors.values())[:2]}")
    check(s.S.F.writes == 0, f"animstate shifted by {shift}: {s.S.F.writes} writes although the layout cannot match")
    print(f"  animstate shifted by {shift:+d}: layout {s.S.F.layout}, writes {s.S.F.writes}")

s = run("lby_flick", ticks=3000, anim="ok",
        configure=lambda ctl, S: ctl.set_ffi(lua_list(["Animation layers", "Feet model", "Animstate apply (experimental)"])))
check(errors_of(s) == 0, f"animstate ok: {list(s.ctl.errors.values())[:2]}")
check(s.S.F.layout == "ok", f"a correct animstate layout is recognised ({s.S.F.layout})")
print(f"  animstate ok: layout {s.S.F.layout}, polarity {s.S.F.polarity}, writes {s.S.F.writes}, late rate {s.late_rate:.2f}")
check(s.late_rate >= 0.85, f"verified animstate apply must not hurt ({s.late_rate:.2f})")

s = run("choke_static", driver_opts=dict(choke=6), ticks=1500, garbage=rt.eval("function() return nil end"))
check(errors_of(s) == 0, "nil props everywhere")


# ── 4. what is written to the player list ───────────────────────────────────────────────────────────────────────
print("== player list")
s = run("choke_static", driver_opts=dict(choke=6), ticks=800, disabled=True)
check(len(list(s.ctl.plist.keys())) == 0, "disabled: nothing is written to the player list")

s = run("choke_static", driver_opts=dict(choke=6), ticks=800)
pl = s.ctl.plist[2]
check(pl["Force body yaw"] is True and pl["Correction active"] is True, "enabled: body yaw forced with correction on")
check(abs(pl["Force body yaw value"]) <= 60, "forced value within +-60")
s.fire("shutdown")
pl = s.ctl.plist[2]
check(pl["Force body yaw"] is False, "shutdown releases the forced body yaw")
check(pl["Override safe point"] in (None, "-") and pl["Override prefer body aim"] in (None, "-"), "shutdown releases safe point / body aim")

# turning the script off in the menu releases everything on the next update
s = run("choke_static", driver_opts=dict(choke=6), ticks=800)
en = s.ctl.item("Specter desync resolver")
H_set = rt.eval("function(ctl, name, v) local it = ctl.item(name); it.value = v end")
H_set(s.ctl, "Specter desync resolver", False)
s.ctl.tick = s.ctl.tick + 1
for fn in s.ctl.callbacks["net_update_end"].values():
    fn()
check(s.ctl.plist[2]["Force body yaw"] is False, "disabling the script releases the player list")


# ── 5. menu ───────────────────────────────────────────────────────────────────────────────────────────────────────
print("== menu")
s = run("choke_static", driver_opts=dict(choke=6), ticks=100)
names = [it.name for it in s.ctl["items"].values()]
for need in ("Specter desync resolver", "Resolver options", "Safe point after misses", "Body aim after misses", "Ping profile",
             "High ping from", "FFI resolver", "Flip side on target", "Resolver debugger", "Reset resolver memory"):
    check(need in names, f"menu item missing: {need}")
check(all(it.tab == "RAGE" and it.box == "Other" for it in s.ctl["items"].values()), "all items in RAGE > Other")
thr = s.ctl.item("High ping from")
check(thr.min == 15 and thr.max == 120 and thr.value == 35, "high ping threshold: 15-120, default 35")
check(s.ctl.item("Ping profile").value == "Auto", "ping profile defaults to Auto")
rst = s.ctl.item("Reset resolver memory")
check(len(list(s.S.R.memory.keys())) > 0, "memory exists before the reset")
rst.cb(rst)
check(len(list(s.S.R.memory.keys())) == 0, "reset button clears the memory")


# ── 6. ping profile ───────────────────────────────────────────────────────────────────────────────────────────────
print("== ping profile")


def logs_with(s, text):
    return [l for l in s.ctl.logs.values() if text in l]


def profile_run(fn, **kw):
    return run("choke_static", driver_opts=dict(choke=6), ticks=1600, ping_fn=fn, **kw)


s = profile_run(rt.eval("function(k) return 20 end"))
check(not logs_with(s, "profile"), "20 ms stays on the low ping profile")
s = profile_run(rt.eval("function(k) return 34 end"))
check(not logs_with(s, "profile"), "34 ms stays on the low ping profile")
s = profile_run(rt.eval("function(k) return 36 end"))
check(any("high ping profile" in l for l in logs_with(s, "profile")), "36 ms switches to the high ping profile")
s = profile_run(rt.eval("function(k) if k < 600 then return 20 end return 80 end"))
check(any("high ping profile" in l for l in logs_with(s, "profile")), "20 -> 80 ms switches to high")
s = profile_run(rt.eval("function(k) if k < 600 then return 80 end return 20 end"))
ls = logs_with(s, "profile")
check(len(ls) == 2 and "low ping profile" in ls[-1], f"80 -> 20 ms ends on low ({ls})")
s = profile_run(rt.eval("function(k) if math.floor(k / 40) % 2 == 0 then return 33 else return 37 end end"))
check(len(logs_with(s, "profile")) <= 2, f"ping hovering around 35 ms flaps ({len(logs_with(s, 'profile'))} switches)")
s = profile_run(rt.eval("function(k) return 10 end"), configure=rt.eval("function(ctl) ctl.item('Ping profile').value = 'High ping' end"))
check(any("high ping profile" in l for l in logs_with(s, "profile")), "Ping profile: High ping forces it")
s = profile_run(rt.eval("function(k) return 100 end"), configure=rt.eval("function(ctl) ctl.item('Ping profile').value = 'Low ping' end"))
check(not logs_with(s, "profile"), "Ping profile: Low ping forces it")
s = profile_run(rt.eval("function(k) return 50 end"), configure=rt.eval("function(ctl) ctl.item('High ping from').value = 60 end"))
check(not logs_with(s, "profile"), "a higher threshold keeps 50 ms on the low profile")

for ping in (20, 60, 120):
    r = run("choke_static", driver_opts=dict(choke=6), ticks=4000, ping=ping)
    check(r.late_rate >= 0.85, f"static target at {ping} ms: {r.late_rate:.2f}")


# ── 7. shots are judged by the angle the targeted record really got ──────────────────────────────────────────────
print("== learning is attributed to the record that was shot at")
s = run("choke_static", driver_opts=dict(choke=6), ticks=3000, ping=80)
check(s.late_rate >= 0.85, f"static at 80 ms {s.late_rate:.2f}")


# ── 8. several enemies, each with its own AA ────────────────────────────────────────────────────────────────────
print("== several enemies")
ENEMIES = rt.eval("""function(drivers)
    local specs = {}
    for i, name in ipairs({ 'choke_static', 'jitter_tick', 'lby_flick', 'choke_defensive', 'jitter_delay' }) do
        specs[i] = { driver = drivers[name]({ choke = 6, period = 3, seed = 40 + i }), name = 'enemy' .. i }
    end
    return specs
end""")(H.drivers)
s = run(None, enemies=ENEMIES, ticks=9000, ping=30, shoot_every=4)
check(errors_of(s) == 0, f"multi enemy errors: {list(s.ctl.errors.values())[:2]}")
per = s.per
for i in range(2, 7):
    p = per[i]
    print(f"  enemy{i - 1}: shots {p.late_shots:>4}  late rate {p.late_rate:.2f}")
    check(p.late_rate >= 0.80, f"enemy{i - 1}: late rate {p.late_rate:.2f}")
check(len(list(s.S.R.memory.keys())) == 5, "one memory per enemy (steam id)")


# ── 9. learning is remembered between sessions ──────────────────────────────────────────────────────────────────
print("== remembered learning")
db = rt.table_from({})
s1 = run("choke_static", driver_opts=dict(choke=6, side=-1), ticks=2500, db=db)
s1.fire("shutdown")
saved = list(db.keys())
check("specter_desync_resolver_priors" in saved, "priors are written on shutdown")


cold = [run("choke_static", driver_opts=dict(choke=6, side=-1), ticks=500, warm=0, seed=sd).hits for sd in range(1, 7)]
warm = [run("choke_static", driver_opts=dict(choke=6, side=-1), ticks=500, warm=0, seed=sd, db=db).hits for sd in range(1, 7)]
print(f"  hits in the first 500 ticks: cold {sum(cold)}   with remembered priors {sum(warm)}")
check(sum(warm) >= sum(cold), "remembered priors must not make the first shots worse")

bad_db = rt.table_from({"specter_desync_resolver_priors": rt.table_from({"v": 3, "arms": "garbage", "feet": 5})})
s = run("choke_static", driver_opts=dict(choke=6), ticks=800, db=bad_db)
check(errors_of(s) == 0, "a broken saved table is ignored")
bad_db2 = rt.table_from({"specter_desync_resolver_priors": 12345})
s = run("choke_static", driver_opts=dict(choke=6), ticks=800, db=bad_db2)
check(errors_of(s) == 0, "a saved number instead of a table is ignored")


# ── 10. options ──────────────────────────────────────────────────────────────────────────────────────────────────
print("== options")


def only_options(opts):
    return rt.eval("function(ctl, S) ctl.set_options(%s) end" % ("{" + ",".join("'%s'" % o for o in opts) + "}"))


s = run("jitter_tick", ticks=1500, configure=only_options(["Native fallback", "Log"]))
check(s.ctl.plist[2]["Force body yaw"] is False, "Jitter fix off: a jitter target is left to the native resolver")
s = run("choke_defensive", driver_opts=dict(choke=6), ticks=3000, configure=only_options(["Jitter fix", "Native fallback", "Log"]))
check(errors_of(s) == 0, "Defensive fix off runs")
s = run("choke_static", driver_opts=dict(choke=6), ticks=2500, configure=only_options(["Safe point on misses", "Body aim on misses"]))
print(f"  safe point / body aim ticks on a static target: {s.sp_ticks if s.sp_ticks else 0} / {s.ba_ticks if s.ba_ticks else 0}")
check(errors_of(s) == 0, "safe point / body aim options run")
s = run("anti_brute", driver_opts=dict(choke=6), ticks=3000, configure=only_options(["Safe point on misses", "Body aim on misses", "Native fallback"]))
check((s.sp_ticks or 0) > 0, "safe point is used when the resolver keeps missing")
print(f"  anti_brute: safe point ticks {s.sp_ticks}, body aim ticks {s.ba_ticks}")


# ── 11. panel / flags / events ──────────────────────────────────────────────────────────────────────────────────
print("== panel, flags, events")
s = run("choke_static", driver_opts=dict(choke=6), ticks=2000, panel=True,
        configure=rt.eval("function(ctl) ctl.item('Resolver debugger').value = { 'Panel', 'Console' } end"))
check(errors_of(s) == 0, f"panel + console debugger: {list(s.ctl.errors.values())[:2]}")
check(any("hit" in l or "miss" in l for l in s.ctl.logs.values()), "console debugger prints shots")
s.fire("round_prestart")
s.fire("level_init")
s.fire("player_death", rt.table_from({"userid": 2}))
s.fire("player_spawn", rt.table_from({"userid": 2}))
check(errors_of(s) == 0, "round / level / death / spawn events run")

s = run("choke_static", driver_opts=dict(choke=6), ticks=900)
flip = s.ctl.item("Flip side on target")
before = s.ctl.plist[2]["Force body yaw value"]
flip.value = True
s.ctl.tick = s.ctl.tick + 1
for fn in s.ctl.callbacks["net_update_end"].values():
    fn()
after = s.ctl.plist[2]["Force body yaw value"]
check(abs(before) > 20 and after == -before, f"flip hotkey negates the forced value ({before} -> {after})")


# ── 12. weird time / map change ──────────────────────────────────────────────────────────────────────────────────
print("== map change (simulation time jumps back)")
JUMP = rt.eval("""function(k, ctl, S)
    if k == 1500 then for _, e in ipairs(ctl.enemies) do e.rec = {}; e.recent = {}; e.max_st = 0 end end
end""")
s = run("choke_static", driver_opts=dict(choke=6), ticks=3000, on_tick=JUMP)
check(errors_of(s) == 0, "no errors around a reset of the targets")

print(f"\n{'ALL CHECKS PASSED' if not fails else str(len(fails)) + ' CHECK(S) FAILED'}  ({time.time() - t0:.0f}s)")
sys.exit(1 if fails else 0)
