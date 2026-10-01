# Specter Project Guidelines

## Language
The owner speaks Hungarian. Respond in Hungarian when they write in Hungarian.

## File Structure
- `specter_cloud.lua` — Main script (resolver, AA, visuals, cloud config, anti-tamper)
- `specter_dev.lua` — Dev loader (loads specter_cloud.lua locally, no auth)
- `specter_loader.lua` — Production loader (auth + cloud fetch from server)
- `server.js` — License server (Express + Upstash Redis)

## Editing Rules
When editing `specter_cloud.lua`, ALWAYS also update:
- `specter_dev.lua` — sync version, feature list header, startup log lines
- `server.js` — if the change adds/changes API endpoints or auth globals
- `specter_loader.lua` — if the change affects auth globals or loading flow

## Gamesense Lua Constraints
- `ui.new_combobox` items are fixed at creation — cannot be updated dynamically
- `http.post` has no content-type support — use `http.get` with query params for all API calls. A URL cannot carry a whole config
  (it is tens of KB, Node's header limit is 16 KB), so cloud config uploads go through `GET /configs/upload_part` in 3000 char parts
  (the server keeps the parts in memory until the last one arrives)
- `client.latency()` returns one-way latency in seconds
- Use `pui` library for UI elements
- LPH directives: `LPH_NO_VIRTUALIZE`, `LPH_CRASH`, `LPH_ENCSTR` (Luraph obfuscator)
- There is NO `os`, `io` or `debug` library in gamesense. Time: `client.unix_time()` (the auth gate in `specter_cloud.lua` and the prefix
  in `server.js` read the clock with the exact same expression), files: `readfile` / `writefile`, compile with `loadstring`.
- Scripts share one global table; chunks compiled with `loadstring` see the loader's globals.

## Tier System
4-tier feature gating: `debug` (full) > `specter` (no AA stealer) > `nightly` (no resolver) > `beta` (minimal)

## Resolver (rewritten: desync -> jitter -> defensive, automatic ping profile)
- Code lives between the `-- [resolver:begin]` / `-- [resolver:end]` markers in `specter_cloud.lua`. Keep the markers (tests extract the block).
- Three learned contexts (multi-armed bandit, Beta scoring, per player + session-wide prior):
  `s|<stance>` static desync, `j|ground/air` jitter, `d|s` / `d|j` defensive (only while the target shifts tickbase).
- STATIC_ARMS: fs/opp full, fs/opp half, zero, `db hit` (last angle that hit), `pose`/`pose inv` (networked body yaw pose param, only a hint:
  the arms decide whether it is real), fs/opp low (~14 deg). JITTER_ARMS: cur/next +/-, low variants, zero. DEF_ARMS: hold, hold half, hold flip, zero, fresh.
- Max desync is the true 58 deg x speed/duck factor. Animation layer 3 (balance adjust, 979) only biases arms (soft, no hard caps):
  recent = desync > 35, standing for a while without = small desync. Without readable layers there is no low-desync inference.
- Shots are judged by the override that was applied to the *targeted record* (`data.hist`, `resolver.applied_for`, `event.backtrack`),
  not by what is forced at fire time.
- Ping profile: `PROFILES.low` / `PROFILES.high` hold every tunable. Auto switches to high at the "High ping from" slider (default 35 ms,
  scoreboard ping), back 4 ms below it; menu can force Low / High. High = slower decay, bigger prior, hedged half angles,
  safe point / body aim one miss earlier, wider shift tolerance.
- Defensive: while shifting the angle is not recomputed from the shifted updates (hold the last good value), learned in its own context,
  safe point + body aim after a defensive miss or when the defensive arms keep failing.
- FFI resolver (`fres` in the resolver block, menu: Resolver > FFI resolver, options in `SPECTER_SHARED.resolver_ffi_opts`):
  * reads the server animation layers (adjust layer 3 / activity 979 = realign, move layer 6) and the client animstate
    (`fres_animstate_t`, eye yaw 0x78, goal feet yaw 0x80, ... up to on_ground 0x108) through ffi; offsets are checked against the netvars
    (`fres_validate`: yaw AND pitch must match, only samples where the netvar is not ~0 count) before anything is trusted
  * every read goes through `ptr_ok`, a NULL entity never reaches the offset helpers, 25 errors switch the whole FFI part off
  * feet yaw model (`feet_update`): copy of the server's goal feet yaw logic on netvars (standing: feet turn to `m_flLowerBodyYawTarget`
    at 100 deg/s, moving: follow the eye yaw, clamp to max body yaw); its body yaw feeds the `feet` / `feet inv` arms (static + jitter)
  * polarity of the forced value (does +v turn into +body yaw?) is learned from the animstate (`fres.polarity`) and only biases the arms
  * "Animstate apply (experimental)" writes goal/current feet yaw; default OFF, only runs when the layout was verified (>= 40 informative
    samples) and re-checks the struct right before every write. "Telemetry" prints one line per second for the current threat.
  * backup of the code before the FFI work: `backup/specter_cloud.pre-ffi.lua`
- Tests: `pip install lupa && python3 tests/resolver_regress.py` runs the real block on a mocked gamesense API (LuaJIT 2.1, real ffi memory
  for layers / animstate) with a simulated enemy, including a server-style feet physics enemy and adversarial memory (garbage, zeros, wrong offsets).
- Load smoke test: `python3 tests/load_smoke.py [--dev] [--plan=nightly|beta|specter]` runs the whole script (or the dev loader) in a
  gamesense-like sandbox (no os / io / debug, strict globals, ghost API). Run it after every change that touches load-time code,
  the loaders or the auth gate.
  Run it after every resolver change; it checks learning logic, not in-game behaviour.
