"""Performance profile of the whole script with many players (mock game in tests/perf/mock.lua).

    pip install lupa
    python3 tests/perf_profile.py                 cost per callback for 2 / 10 / 20 enemies, default settings and everything on
    python3 tests/perf_profile.py --hot 20        + where the time goes (sampled lines) with 20 enemies, everything on
    python3 tests/perf_profile.py --file=specter_cloud.lua   (default: specter_dev.lua, no login needed)

Numbers are LuaJIT under lupa on this machine: compare them with each other (before / after a change), not with the game.
"""
import os
import sys

import lupa.luajit21 as L

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)


def load_world(rt, src, **opts):
    M = rt.eval("function(src) return load(src)() end")(open(os.path.join(HERE, "perf", "mock.lua")).read())
    w = M.new(src, rt.table_from(opts))
    if not w.loaded:
        raise SystemExit("script did not load: " + str(w.load_error))
    return w


def run(rt, src, enemies, everything, ticks=640, menu_open=False):
    w = load_world(rt, src, enemies=enemies, mates=4)
    for _ in range(40):                       # start-up (delay_call initialisation, first records)
        w.tick(); w.frame(); w.frame()
    if everything:
        w.everything_on()
    w.menu_open = menu_open
    for _ in range(64):
        w.tick(); w.frame(); w.frame()
    for k in list(w.timers.keys()):
        w.timers[k] = 0
        w.calls[k] = 0
    for k in list(w.api.keys()):
        w.api[k] = 0
    n0 = len(w.errors)
    for i in range(ticks):
        w.tick(); w.frame(); w.frame()
        if i % 40 == 0:
            w.shoot(w.enemies[1 + (i // 40) % enemies], i % 80 == 0)
    errs = list(w.errors.values())[n0:]
    return w, errs


def report(w, ticks):
    rows = []
    total = 0
    for name, t in w.timers.items():
        calls = w.calls[name]
        if calls == 0:
            continue
        per_tick = t / ticks * 1000
        total += per_tick
        rows.append((per_tick, name, t / calls * 1e6))
    rows.sort(reverse=True)
    return total, rows


def main():
    import resource
    resource.setrlimit(resource.RLIMIT_AS, (6 * 1024 ** 3, 6 * 1024 ** 3))
    fname = "specter_dev.lua"
    hot = None
    for a in sys.argv[1:]:
        if a.startswith("--file="):
            fname = a.split("=", 1)[1]
        if a == "--hot":
            hot = 20
    if "--hot" in sys.argv:
        i = sys.argv.index("--hot")
        if i + 1 < len(sys.argv) and sys.argv[i + 1].isdigit():
            hot = int(sys.argv[i + 1])
    src = open(os.path.join(ROOT, fname), encoding="utf-8").read()
    ticks = 640

    print(f"file: {fname}   {ticks} ticks, 2 frames per tick; ms of script time per game tick")
    for everything in (False, True):
        for enemies in (2, 10, 20):
            rt = L.LuaRuntime(unpack_returned_tuples=True)
            w, errs = run(rt, src, enemies, everything, ticks)
            total, rows = report(w, ticks)
            label = "everything on" if everything else "defaults"
            print(f"\n== {label}, {enemies} enemies: {total:.3f} ms per tick")
            for per_tick, name, per_call in rows[:8]:
                print(f"   {name:<16} {per_tick:8.3f} ms/tick   {per_call:8.1f} us/call")
            api = sorted(((v / ticks, k) for k, v in w.api.items()), reverse=True)
            print("   game API calls per tick: " + ", ".join(f"{k} {n:.1f}" for n, k in api[:14]))
            uniq = sorted(set(e.split("\n")[0][:160] for e in errs))
            for e in uniq[:6]:
                print("   error:", e)

    if hot:
        rt = L.LuaRuntime(unpack_returned_tuples=True)
        prof = rt.eval(r'''
        function(w, ticks, enemies, shoot)
            pcall(function() require("jit").off() end)
            local counts, fcounts = {}, {}
            debug.sethook(function()
                local info = debug.getinfo(2, "Sl")
                if info and info.source == "@script" then
                    local k = info.currentline
                    counts[k] = (counts[k] or 0) + 1
                    local f = info.linedefined
                    fcounts[f] = (fcounts[f] or 0) + 1
                end
            end, "", 200)
            for i = 1, ticks do
                w.tick(); w.frame(); w.frame()
                if i % 40 == 0 then w.shoot(w.enemies[1 + math.floor(i / 40) % enemies], i % 80 == 0) end
            end
            debug.sethook()
            local lines, funcs = {}, {}
            for k, v in pairs(counts) do lines[#lines + 1] = { k, v } end
            for k, v in pairs(fcounts) do funcs[#funcs + 1] = { k, v } end
            table.sort(lines, function(a, b) return a[2] > b[2] end)
            table.sort(funcs, function(a, b) return a[2] > b[2] end)
            return lines, funcs
        end''')
        enemies = hot
        w = load_world(rt, src, enemies=enemies, mates=4)
        for _ in range(40):
            w.tick(); w.frame(); w.frame()
        w.everything_on()
        for _ in range(64):
            w.tick(); w.frame(); w.frame()
        lines, funcs = prof(w, 320, enemies, True)
        src_lines = src.split("\n")
        total = sum(v[2] for v in lines.values())
        print(f"\n== hottest functions ({enemies} enemies, everything on), share of sampled instructions")
        for i in range(1, min(25, len(funcs)) + 1):
            ln, c = funcs[i][1], funcs[i][2]
            print(f"   {100 * c / total:5.1f}%  function at line {ln}: {src_lines[ln - 1].strip()[:110] if ln > 0 else '(main chunk)'}")
        print(f"\n== hottest lines")
        for i in range(1, min(30, len(lines)) + 1):
            ln, c = lines[i][1], lines[i][2]
            print(f"   {100 * c / total:5.1f}%  {ln:6d}: {src_lines[ln - 1].strip()[:120]}")


if __name__ == "__main__":
    main()
