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
- `http.post` has no content-type support — use `http.get` with query params for all API calls
- `client.latency()` returns one-way latency in seconds
- Use `pui` library for UI elements
- LPH directives: `LPH_NO_VIRTUALIZE`, `LPH_CRASH`, `LPH_ENCSTR` (Luraph obfuscator)

## Tier System
4-tier feature gating: `debug` (full) > `specter` (no AA stealer) > `nightly` (no resolver) > `beta` (minimal)

## Resolver
- Multi-armed bandit with Bayesian scoring
- Base max_desync: 44° (not 58°)
- Low-desync cap: 22°
- STATIC_ARMS: fs full, opp full, fs half, opp half, zero
- JITTER_ARMS: 0.8x fraction (full), 0.45x (low)
- LOW_BIAS: { -0.15, -0.15, 0.20, 0.20, 0.05 }
