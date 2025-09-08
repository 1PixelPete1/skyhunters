
# Wailing Winds — Agent Guidelines

This document defines the principles, constraints, and operating rules for anyone (human or agent) contributing to the Wailing Winds codebase. It encodes our **design ideals**, **security posture**, **authoritative server model**, and **performance standards**, so changes align with the game’s core loop and long-term goals.

## Game Pillars

**Clarity over clutter**

* Systems should be readable and debuggable at a glance. Single source of truth for rules and math.

**Server-authoritative gameplay**

* All economy-relevant actions (placement, accrual, AI affecting resources, persistence) are validated and computed on the server.

**Lantern loop first**

* The lantern placement and progression loop is the spine: preview → validate → place → accrue → persist → load.

**Shared world, predictable rules**

* Islands/terrains are consistent per session. Players can’t grief core world state; changes are gated by server policies and rare items/events.
Before I use your microbriefs, I am getting this roblox error:

  12:02:55.790  Attempted to call require with invalid argument(s).  -  Server - PlacementService:19
  12:02:55.790  Stack Begin  -  Studio
  12:02:55.790  Script 'ServerScriptService.Server.PlacementService', Line 19  -  Studio - PlacementService:19
  12:02:55.790  Stack End  -  Studio
  12:02:55.791  Attempted to call require with invalid argument(s).  -  Server - WorldBootstrap:50
  12:02:55.791  Stack Begin  -  Studio
  12:02:55.791  Script 'ServerScriptService.Server.WorldBootstrap', Line 50  -  Studio - WorldBootstrap:50
  12:02:55.791  Stack End  -  Studio
  12:02:55.791  Attempted to call require with invalid argument(s).  -  Server - OilService:5
  12:02:55.791  Stack Begin  -  Studio
  12:02:55.791  Script 'ServerScriptService.Server.OilService', Line 5  -  Studio - OilService:5
  12:02:55.792  Stack End  -  Studio
  12:02:55.792  Attempted to call require with invalid argument(s).  -  Server - LanternService:11
  12:02:55.792  Stack Begin  -  Studio
  12:02:55.792  Script 'ServerScriptService.Server.LanternService', Line 11  -  Studio - LanternService:11
  12:02:55.792  Stack End  -  Studio
  12:02:55.794  GATEWAY PlacementGateway bound=true reason=nil  -  Server - Server:159
  12:02:55.794  GATEWAY ApplyGateway bound=true reason=nil  -  Server - Server:163
  12:02:55.794  BOOT ok=26 degraded=0 skipped=0 failures=[]  -  Server - Server:208
  12:02:55.898  Plot assigned: P1  -  Client - UIRouter:11
  12:02:55.898  Balances: 0 0  -  Client - UIRouter:15
  12:02:56.308  [Load] plot=P1 restored=2 skipped=0  -  Server - SaveService:119

these are for local PondFieldService = require(SSS.Server.PondFieldService)
local SaveStore = require(SSS.Server.LanternSaveStore)

these are the lines roblox is attributing the issues to, maybe some more.
**Performance by design**

* Event-driven recompute over per-frame loops. Spatial/locality limits. Memory pools where it matters. Low-end devices remain viable.

---

## Repository Layout (invariants)

* `src/server` → `ServerScriptService/Server` (authoritative logic, validation, persistence)
* `src/client` → client-only UI, input, camera, VFX (no authority)
* `src/replicated/Config` → `ReplicatedStorage/Config` (read-only config; safe to require on both sides)
* `src/replicated/...` → shared data registries and read-only assets
* `src/shared` → `ReplicatedStorage/Shared` (pure utility: math, transforms, types; no side effects)
* `src/serverstorage/...` → server-only content

**Remotes:** live under `ReplicatedStorage/Net/Remotes` with `RF_*` (RemoteFunction) and `RE_*` (RemoteEvent) prefixes.

---

## Security Model (assume hostile clients)

**Threats we always assume**

* Spoofed position/normal, replayed requests, spam, UI tampering, forged ghost previews.

**Defenses we always apply**

* Server recompute/validation for every gameplay action.
* Allowlists for presets and actions.
* Rate limits and “pending” race guards.
* Idempotent operations (replays don’t duplicate state).
* Minimal, structured logs (no PII).

**Never allowed**

* Trusting client raycast results for authority.
* Writing to persistent state from the client.
* Spawning gameplay objects outside the approved creation path.

---

## Authoritative Placement Contract (Lanterns)

**Rules live here**

* `PlacementPolicy` (pure): bounds, slope, spacing, surface (water) checks, reason codes.
* `TransformUtil` (pure): island-relative bounds (`inIslandBoundsAt(position, presetKey, islandCFrame)`).
* `PresetUtil` / `WorldConfig`: canonical dimensions, half-sizes.

**Server flow**

1. Client proposes a `CFrame` and preset (whitelisted).
2. Server resolves island context (preset key + island CFrame).
3. Server calls `PlacementPolicy.validateLantern`.
4. On pass: spawn via `ApplyCore.place(presetKey, cframe)`, tag `"Lantern"`, parent to server folder.
5. On fail: return a reason code.

**Valid reason codes**

* `OUT_OF_BOUNDS`, `TOO_STEEP`, `ON_WATER`, `TOO_CLOSE`, `PRESET_FORBIDDEN`, `CREATE_FAILED`, `SERVER_BUSY`.

**Client ghost**

* Cosmetic only. May tint based on local raycast material, but **never** overrides server decisions.

---

## Terrain Policy (SmoothTerrain islands)

**Default island**

* SmoothTerrain slab with a **flat top at pivot Y**.
* Clean pond carved as a **vertical cylinder** (Air carve, Water fill with a slightly smaller radius).
* Idempotent sculpting: clear a padded region to **Air** before rebuilds (no accumulation).

**Bounds vs surface**

* **Bounds** are rectangular from preset half-sizes (island footprint).
* **Water** and steep slopes are **invalid surfaces**, not bounds changes.

**Config knobs**

* `UseTerrain` (bool)
* `SizeStuds`, `HeightStuds`
* `Pond { Radius, Depth, Offset }`
* `TopMaterial`, `CoreMaterial`, `TopSkinThickness`
* `EnableDecorations` (drives `workspace.Terrain.Decoration`)

---

## Persistence (M0.3 baseline)

**Scope**

* Lantern instances only (for now).

**Keying**

* Save per `PlotId` (preferred) or `UserId` fallback.

**Record schema (v1)**

* `id` (deterministic; based on `{presetKey, quantized position, plotId}`)
* `presetKey`
* `cframe` (compact serialization)
* `placedAt` (unix seconds)
* `ownerUserId` (optional)

**Write path**

* After server validates and spawns, append to an in-memory list.
* Batch writes (N placements or M seconds).
* Single-flight guard; exponential backoff on throttles.

**Load path**

* On boot or plot assignment, read blob, validate, spawn via `ApplyCore.place`, tag, parent.
* Keep a spawned-ids set; skip duplicates.
* Skip invalid/now-out-of-policy records (log and continue).

**Budgets & safety**

* Compact payloads; quantize numbers.
* No per-placement immediate writes.
* Logs: `[Save] plot=<id> items=<n>`, `[Load] plot=<id> restored=<n> skipped=<m>`.

---

## Performance Requirements

* Event-driven updates; no long per-frame loops for core systems.
* Spatial scans start linear with small caps; graduate to Octree/SpatialHash when counts warrant.
* Memory pools for hot paths (AI, placement preview models, effects).
* Backpressure: degrade politely and reject expensive actions with `SERVER_BUSY` if tick budgets are breached.

---

## Naming & Style

* Luau, LF, UTF-8.
* Modules: PascalCase. Locals/functions: `camelCase`. Constants: `UPPER_SNAKE`.
* Remote names: `RF_*`/`RE_*`, verb-based, specific (`RF_PlaceLantern`).
* Shared modules are **pure** (no Roblox services, no side effects).

---

## Logging & Observability

* Single-line, structured logs, no PII. Examples:

  * `[Place] lantern uid=<user> plot=<id> result=<code>`
  * `[Terrain] Sculpted flat slab size=<S> height=<H> top=<TopMaterial> pondR=<R> pondD=<D> decor=<bool>`
* Debug toggles are server-only; keep default logs minimal for release.

---

## Review Checklist (must pass before merge)

* New remotes documented (name, args, limits, reason codes).
* Server recomputes outcomes; no client-trusted paths.
* `PlacementPolicy` used for all placement decisions; no ad-hoc math.
* Preset allowlist enforced; unknown presets rejected.
* Rate limiting present for new remotes.
* Persistence writes are batched; loads validate and dedupe; schema versioned.
* No ModuleScript cycles; clean boot logs.
* Tests include exploit attempts (spam, replay, off-island, water, spacing).

---

## Testing Guidance (security-first)

**Unit**

* `PlacementPolicy`: table-driven bounds/slope/water/spacing edges.
* `TransformUtil.inIslandBoundsAt`: rotated/translated pivot cases.

**Property-based**

* Random points around edges; policy never returns true out of bounds or on water.

**Integration**

* Two clients attempt near-simultaneous placements within min spacing → exactly one success.

**Persistence**

* Restart restores once; corrupted record skipped; duplicates not respawned.

**Fuzz**

* Remote spam at 5–20 rps per player for 10s; rate limits trigger; no crashes.

---

## Agent Operating Rules

* Prefer **small, scoped tasks** with explicit acceptance criteria.
* Keep rules centralized: modify `PlacementPolicy`, `TransformUtil`, `WorldConfig`, or `PresetUtil` rather than scattering logic.
* Use the approved spawn path (`ApplyCore.place`), tagging, and parenting for all gameplay objects.
* When changing terrain behavior, preserve idempotence (clear → sculpt → carve/fill) and keep the top flat at pivot Y.
* When touching persistence, maintain versioning and idempotent IDs; never trust data over current policy.
