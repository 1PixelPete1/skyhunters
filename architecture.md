# Wailing Winds — Architecture Overview (LLM‑friendly)
## BUILDING SECTION ##

This document describes the current systems implemented in the repo, the contract between client and server, remotes, data flows, and any known redundancies or legacy artifacts left behind by AI prompt stacking. Use this as the single source of truth when extending or refactoring systems.

## Source Layout

- `src/server` → ServerScriptService/Server and ServerScriptService/Systems
- `src/client` → StarterPlayer/StarterPlayerScripts/Client
- `src/replicated` → ReplicatedStorage/Config, ReplicatedStorage/Net
- `src/shared` → ReplicatedStorage/Shared (pure helpers and math; no side effects)

## High‑Level Systems

- World bootstrap
  - File: `src/server/WorldBootstrap.server.luau`
  - Builds the main island (SmoothTerrain) at a fixed pivot using `TerrainIslandBuilder`.
  - Seeds a default pond (authoritative) and initializes boundary publishing (`BoundaryPublisher`).
  - Initializes per‑plot oil baseline and restores persisted lanterns and oil reservoirs.

- Boundary graph + renderers
  - Server: `Server/Boundary/*` publishes a polyline “soup” via Net to clients.
  - Client renderer: `src/client/Boundary/BoundaryRenderer.client.luau` (strategy = DottedMarkers only).
  - Mask: `src/client/Boundary/BoundaryMask.luau` provides point‑in‑region checks for ghosts/UI.
  - Strategy: `src/client/Boundary/RenderStrategies/DottedMarkers.luau`
    - Pooled BillboardGui squares (“dots”).
    - Dynamic LOD: inserts extra dots per segment near the camera; throttled refresh on camera motion.
    - Respects pool caps and distance‑based alpha.

- Pond network
  - File: `src/server/Systems/PondNetworkService.luau`
  - Authoritative snapshot of ponds and canals (lakes), auto‑linking, and carving calls.
  - Publishes boundary deltas/batches; reconstructs visuals (rims) and maintains connectivity.

- Placement flow (authoritative)
  - Client placement driver: `src/client/PlacementClient.client.luau` (lanterns, ponds dev, oil reservoirs).
  - Server entry: `src/server/PlacementService.server.luau`
    - Remote: `RF_PlaceLantern` (multi‑use: lanterns and oil reservoirs; preset allowlist derived from `WorldConfig`).
    - Validates: plot bounds hard‑gate, placement policy via `PlacementTransaction`, slope/water/spacing.
    - Delegates to `LanternService.ApplyPlacement` (lanterns) or `OilReservoirService.ApplyPlacement` (oil) based on preset.
  - Legacy/parallel path: `Systems/PlacementGateway.luau` + `Systems/ApplyGateway.luau`
    - Implement a validate/apply split with idempotency and rate limits; currently not used by the client, but bound on server boot. Keep in sync or retire (see “Redundant/Legacy”).

- Lanterns
  - Server: `src/server/LanternService.luau`
    - Spawns models using `Shared/LanternModelKit`, tags `Lantern`, persists to `LanternSaveStore`.
    - Restores from save and re‑tags/attributes for clients.
  - Persistence: `src/server/LanternSaveStore.luau` (DataStore `Lanterns_v1`).

- Oil system
  - Server: `src/server/OilService.luau`
    - Maintains per‑plot oil capacity/amount.
    - Visuals: a terrain‑wide “oil layer” (flat Part) with height based on fill; and a cylindrical gauge with inner neon column indicating fill.
    - Public API: `setOilAmount(pk, amount)`, `getOilAmount(pk)`, `getOilCapacity(pk)`, `addCapacityForPlot(pk, add)`, etc.
  - Oil reservoirs (capacity increase): `src/server/OilReservoirService.luau`
    - Build/restore/remove oil reservoirs with `Shared/OilReservoirModelKit`.
    - Persists to `src/server/OilReservoirSaveStore.luau` (DataStore `OilReservoirs_v1`).
  - Studio dev remotes (server‑verified): `OilAddAmountRemote`, `OilSetAmountRemote` wired in `StudioDevRemotes.luau`.

- Removal flow
  - Client tool: `src/client/Tools/RemovalTool.client.luau`
    - Activates on equipping ItemId `removal_tool` (no Delete‐key required).
    - Hover highlighting: Highlights (no color mutation) for ponds (rim parts) and lanterns (model‑wide).
    - Hold‑to‑delete UI cancels on mouse up or pointer leaving the target.
    - Never highlights or removes the default pond.
  - Server: `src/server/Systems/RemovalSystem.luau`
    - Remotes: `RF_RemovePond`, `RF_RemoveLantern`, `RF_RemoveOilReservoir`, `RF_CanRemovePond` (preflight).
    - Preflight blocks default pond and checks for dependent lanterns within pond ring or connected canals.
    - On pond removal, updates snapshot, removes connected canals, and repairs terrain (flat top fill).

- Plot service
  - File: `src/server/Systems/PlotService.luau`
  - Assigns simple plot IDs (`P1`, …) and reports origin and AABB. Placement is gated to the plot rectangle on both client and server.

- Tools and inventory (dev‑phase)
  - Tools: `src/server/Systems/ToolService.luau` creates in‑hand proxies with attributes (`ItemId`, `ItemType`).
  - Inventory: `src/server/Systems/InventoryService.luau` (basic counters for items).
  - Client tool runner: `src/client/ToolHandler.client.luau` attaches to tools and infers attributes for legacy tool names.
  - Studio dev UI: `src/client/StudioDevUI.client.luau` uses `StudioDevRemotes` to grant items, wipe/teleport, and now adjusts oil.

- Config and policy
  - `src/replicated/Config/WorldConfig.luau` — canonical sizes, preset definitions (lantern presets, `oil_reservoir_*`).
  - `src/shared/PlacementPolicy.luau` — quantization, tolerances, lantern validation rules.
  - `src/shared/PlacementCore.luau` / `src/shared/ApplyCore.luau` — shared plan/validate helpers.

## Net/Remotes (main)

- Placement
  - `RF_PlaceLantern` (server validates; supports lanterns and oil reservoirs)
  - Studio/testing: `RF_AddPond` (Studio only)

- Removal
  - `RF_RemovePond`, `RF_RemoveLantern`, `RF_RemoveOilReservoir`
  - `RF_CanRemovePond` (preflight)

- Boundary
  - `RF_BoundaryGetSoup`, `RE_BoundaryDelta`

- Oil (Studio only)
  - `OilAddAmountRemote`, `OilSetAmountRemote`

- Studio dev: see `src/server/Systems/StudioDevRemotes.luau` for complete list.

## Persistence

- Lanterns: DataStore `Lanterns_v1` (per plot key). Record shape `{ id, pk, p, r, t, u, seed?, seg?, lanternType? }`.
- Oil reservoirs: DataStore `OilReservoirs_v1` (per plot key). Record shape `{ id, pk, p, size, capacity, t, u }`.
- Pond graph persistence is handled by pond subsystems (outside the scope of the lantern/oil stores).

## Reason Codes (common)

- Placement: `OUT_OF_BOUNDS`, `TOO_STEEP`, `ON_WATER`, `TOO_CLOSE`, `PRESET_FORBIDDEN`, `BAD_PARAMS`, `SERVER_BUSY`, `CREATE_FAILED`.
- Removal: `POND_NOT_FOUND`, `LANTERNS_IN_BOUNDARY`, `LANTERNS_IN_CANAL`, `DEFAULT_POND`, `SERVICE_UNAVAILABLE`.

## Security Posture (authoritative server)

- All economy‑relevant actions recomputed/validated server‑side (position, slope, bounds, spacing, allowlists).
- Preset allowlist derived from `WorldConfig` (lantern_* and `PlaceableType == "OilReservoir"`).
- Rate limits present in gateways (unused by current client) and soft throttling in services.
- No client writes to persistence; server batch writes/reads with validation and de‑dupe.

## Implemented LOD for Markers

- Strategy inserts extra dots between existing batch points when the camera is near a segment.
- Re‑render throttled by time and camera movement (> 4 studs), respecting a max dot pool.
- Dot alpha attenuates by distance; density scales up near the camera, down at distance.

## Redundant / Legacy / Unused (to triage)

- PlacementGateway / ApplyGateway
  - These implement a validate/apply split with idempotency and request caching. Current client path uses `PlacementService.server.luau` + `RF_PlaceLantern`. Keep gateways for future evolution or cleanly retire after migrating client.

- Boundary Renderer hotkeys
  - Older “M key” toggle was removed. Markers now auto‑enable only during placement tool equip. Any references to manual toggles can be deleted.

- Oil HUD (client/UI)
  - Some UI modules (`client/init.client.luau` references OilHUD) are not part of the current design. Oil visuals are world geometry (oil plane + gauge). These UI pieces can be removed if not used elsewhere.

- Duplicate or verbose bootstrap code
  - `WorldBootstrap.server.luau` contains duplicate requires/logs for boundary initialization. Safe but could be consolidated for clarity.

- Legacy tool detection
  - `ToolHandler.client.luau` now infers ItemId/ItemType for legacy tool names to avoid log spam. Prefer tools with explicit attributes.

## Conventions

- Modules: PascalCase. Locals/functions: camelCase. Constants: UPPER_SNAKE.
- Remotes live under `ReplicatedStorage/Net/Remotes` and use `RF_*` / `RE_*` prefixes.
- Shared modules are pure; server modules own side effects.

## Extension Guidelines

- Extend placement rules centrally (`PlacementPolicy`, `TransformUtil`, `WorldConfig`) — do not scatter ad‑hoc math.
- Use `PlacementService.server.luau` as the canonical server entry for item placement unless/until a full migrate to Gateways is completed.
- For new economy objects: define presets in `WorldConfig`, enforce allowlists, add a dedicated service with persistence, and wire into `StudioDevRemotes` for test affordances.

## COMBAT SYSTEM ##

### Overview
The combat system implements distance-based progression through themed rounds on floating sky islands, featuring swarm-based enemies with server-light validation and client-predicted movement. See `docs/combat-system-design.md` for detailed architecture.

### Core Services

- **RoundProgressionService** (Server)
  - File: `src/server/Systems/RoundProgressionService.luau` (planned)
  - Manages round transitions and theme enforcement
  - Synchronizes round seeds globally via MemoryStore
  - Publishes theme changes to clients

- **SkyIslandService** (Server)
  - File: `src/server/Systems/SkyIslandService.luau` (planned)
  - Generates floating islands using Poisson disk sampling
  - Streams islands based on player proximity
  - Categories: Small (stepping stones), Medium (loot/combat), Large (semi-dungeons)

- **EnemyOrchestrator** (Server)
  - File: `src/server/Systems/EnemyOrchestrator.luau` (planned)
  - Spawns enemy waves with macroscopic validation
  - Validates deaths and loot drops
  - Reconciles position for anti-cheat

- **EnemyBehaviorClient** (Client)
  - File: `src/client/Combat/EnemyBehaviorClient.luau` (planned)
  - Local enemy AI and movement
  - Enemy types: BeamSniper (ranged tracking), Leaper (gap-closing), Swarmer (melee groups)
  - Client prediction with server reconciliation

- **DungeonController** (Server + Client)
  - File: `src/server/Systems/DungeonController.luau` (planned)
  - Manages large island semi-dungeons
  - Multi-stage encounters with minibosses
  - Environmental hazards and guaranteed high-tier loot

### Network Architecture

- **CombatNetworkOptimizer** (Shared)
  - Position quantization to 0.1 stud grid
  - Delta compression for movement updates
  - Interest management (500 stud sync radius)
  - Target bandwidth: <5 KB/s per player

### Enemy Design Philosophy

- **Low TTK, High Numbers**: Enemies die quickly but spawn in large groups
- **Macroscopic Validation**: Server validates spawns/deaths/loot, not individual movement
- **Client Authority**: Enemy AI runs client-side with server reconciliation
- **Swarm Mechanics**: Threat through numbers and coverage, not individual strength

### Round System

- **Distance-Based Progression**: Difficulty scales with horizontal distance from spawn
- **Themed Rounds**: Each round locks together materials, weather, enemies, and loot
- **Global Synchronization**: Round seeds shared across all servers via MemoryStore

### Integration Points

- **LanternService**: Enemies drop lantern fragments, bosses drop special lanterns
- **OilService**: Oil wells on islands, enemies drop oil canisters
- **PlotService**: Sky plots for aerial bases, portal system ground-to-sky
- **PondNetworkService**: Sky ponds for navigation, canal bridges between islands

### Performance Targets

- Max enemies per player: 50
- Max enemies per server: 500
- Enemy despawn distance: 600 studs
- Island LOD levels: Near (0-200), Medium (200-500), Far (500-1000), Culled (>1000)
- Dynamic scaling based on server FPS

### Security Measures

- Movement validation (max 300 studs/second)
- Teleport detection (>50 stud instant movement)
- Damage validation against weapon stats
- Server-authoritative loot drops
- Line-of-sight checks for ranged attacks