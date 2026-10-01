"""Regression tests for the resolver block of specter_cloud.lua.

Runs the real code (the part between the `-- [resolver:begin]` / `-- [resolver:end]` markers) on a mocked
gamesense API with a simulated enemy (see resolver_sim.lua), under LuaJIT 2.1 like gamesense uses.

    pip install lupa
    python3 tests/resolver_regress.py

This checks the learning logic, not the real game: it cannot tell whether e.g. the networked pose parameter
carries real data in-game. Exit code is non-zero when a check fails.
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

rt = L.LuaRuntime(unpack_returned_tuples=True)
sim = rt.eval("function(src) return load(src)() end")(open(os.path.join(HERE, "resolver_sim.lua")).read())

fails = []


def check(cond, msg):
    if not cond:
        fails.append(msg)


def run(scn, **opts):
    return sim.run(BLOCK, scn, rt.table_from(opts))


SCENARIOS = ["static_pos", "static_neg", "static_fs", "static_mid", "static_low", "static_tiny", "moving_static",
             "air_static", "jitter_pos", "jitter_neg", "jitter_p3", "jitter_random", "desync_jitter", "def_static",
             "static_flip", "mapchange"]

print("== late hit rate (second half of the run) per scenario / ping / apply lag")
print(f"{'scenario':<16}" + "".join(f"{p:>6}ms/l{l}" for p, l in ((20, 0), (80, 0), (20, 1), (150, 0))))
for scn in SCENARIOS:
    cells = []
    for ping, lag in ((20, 0), (80, 0), (20, 1), (150, 0)):
        n = run(scn, ping=ping, apply_lag=lag)
        check(n.errors == 0, f"{scn} {ping}/{lag}: {n.errors} errors")
        # random jitter is a coin flip when the value applies one record late
        if scn != "jitter_random" or lag == 0:
            if not (scn in ("jitter_random", "desync_jitter") and lag == 1):
                check(n.late_rate >= 0.9, f"{scn} {ping}ms lag{lag}: late hit rate {n.late_rate:.2f} < 0.90")
        cells.append(f"{n.late_rate:>10.2f}")
    print(f"{scn:<16}" + "".join(cells))

print("== garbage input (NaN / inf / nil props), must never throw")
for scn in ("static_pos", "jitter_pos", "desync_jitter", "def_static", "moving_static"):
    n = run(scn, ping=40, fuzz=0.2, ticks=6000, ffi=True, balance_every=70, panel=True)
    check(n.errors == 0, f"fuzz {scn}: {n.errors} errors")

print("== shots are judged by the angle the targeted record really got")
for scn in ("static_pos", "jitter_pos", "jitter_p3", "def_static"):
    n = run(scn, ping=60)
    check(n.attr_ok >= 0.99 * n.attr_total, f"attribution {scn}: {n.attr_ok}/{n.attr_total}")

print("== ping profile: auto switch at 35 ms with hysteresis")
def profile_after(fn, **kw):
    return run("static_pos", ticks=1600, ping_fn=fn, **kw).profile
check(profile_after(lambda k: 20) == "low", "20 ms must stay low")
check(profile_after(lambda k: 34) == "low", "34 ms must stay low")
check(profile_after(lambda k: 36) == "high", "36 ms must be high")
check(profile_after(lambda k: 20 if k < 600 else 80) == "high", "20 -> 80 ms must end high")
check(profile_after(lambda k: 80 if k < 600 else 20) == "low", "80 -> 20 ms must end low")
n = run("static_pos", ticks=1600, ping_fn=lambda k: 33 if (k // 40) % 2 == 0 else 37)
check(n.profile_switches <= 2, f"ping hovering around 35 ms flaps ({n.profile_switches} switches)")
check(profile_after(lambda k: 10, ping_mode="High ping") == "high", "forced high")
check(profile_after(lambda k: 150, ping_mode="Low ping") == "low", "forced low")
check(profile_after(lambda k: 45, ping_threshold=50) == "low", "threshold 50 / ping 45 must be low")
check(profile_after(lambda k: 55, ping_threshold=50) == "high", "threshold 50 / ping 55 must be high")

print("== animation layers (balance adjust) steer small / big desync")
check(run("static_tiny", ping=20, tol=9, ffi=True).late_rate >= 0.9, "T=-12 with layers")
check(run("static_tiny", ping=20, tol=9).late_rate >= 0.9, "T=-12 without layers")
check(run("static_pos", ping=20, tol=9, ffi=True).late_rate >= 0.9, "T=58 with layers saying 'small' must still be found")
check(run("static_pos", ping=20, ffi=True, balance_every=70).late_rate >= 0.9, "T=58 with balance adjust")

print("== body yaw pose: real vs a mere echo of what we forced")
check(run("pose_static", ping=20, tol=8).late_rate >= 0.9, "real pose must be usable (tol 8)")
for scn in ("static_pos", "static_fs", "jitter_pos", "def_static"):
    check(run(scn, ping=40, pose_echo=True).late_rate >= 0.9, f"echo pose broke {scn}")

print("== safe point / body aim levers")
n = run("static_pos", ping=20)
check((n.ba_ticks or 0) == 0 and (n.sp_ticks or 0) == 0, "easy target must not get safe point / body aim")
n = run("nopose_static", ping=20, tol=8)
check((n.ba_ticks or 0) > 1500, "target where every arm fails must end on body aim")

print("== lifecycle")
n = run("jitter_pos", ping=40, ticks=600)
res = n.resolver
res.new_round()
res.reset_player(2)
res.reset_all()
res.net_update()

print()
if fails:
    print("FAILURES:")
    for f in fails:
        print(" -", f)
    sys.exit(1)
print("ALL CHECKS PASSED")
