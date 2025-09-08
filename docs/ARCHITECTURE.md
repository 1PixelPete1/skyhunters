# Wailing Winds – System Architecture (V3 Boundary Dots)

## Overview

Wailing Winds is a shared‑world building game centered on placing lanterns and shaping water features (ponds and canals) on small island plots. The server is authoritative over all economy‑relevant actions and spatial state (terrain sculpting, pond/canal network, boundary geometry). Clients render the current world state using a lightweight, pooled dot renderer (DottedMarkers) that reads an authoritative "dot soup" published by the server. The dot soup encodes pond rims and canal rails, with optional junction markers that precisely define where canals meet pond rims.

```mermaid
flowchart LR
  subgraph Server
    S1[WorldBootstrap]
    S2[TerrainIslandBuilder]
    S3[PlacementService]
    S4[PondNetworkService]
    S5[BoundaryGraph]
    S6[BoundaryGeometry]
    S7[BoundaryPublisher]
    S8[BoundaryDev / PondDevCommands]
  end
  subgraph ReplicatedStorage
    R1[Net/Remotes]
    R2[Shared Config & Types]
  end
  subgraph Client
    C1[BoundaryRenderer (DottedMarkers)]
    C2[BoundaryHUD]
    C3[BoundaryMask (scaffold)]
    C4[PlacementClient]
    C5[PondNetworkClient / LakeTool / PondTool]
  end
  S2 --> S4 --> S5 --> S6 --> S7
  S3 --> S7
  S7 <--> C1
  C2 -->|reads| C1
  C4 <--> R1
  C5 <--> R1
  S1 --> R1
  R2 <--> S4
  R2 <--> S6
  R2 <--> C1
```

## Runtime Topology

- Terrain
  - `ServerScriptService/Server/TerrainIslandBuilder`: Sculpt island slab, carve initial pond bowl, enable/disable terrain decorations.
- Placement
  - `ServerScriptService/Server/PlacementService`: Validates lantern placements server‑side; writes persistence; exposes `RF_PlaceLantern`.
  - `StarterPlayer/StarterPlayerScripts/PlacementClient.client.luau`: Aims a ghost, calls `RF_PlaceLantern`, colors inside/outside via `BoundaryMask` (scaffold).
- Pond/Lake Network
  - `ServerScriptService/Systems/PondNetworkService.luau`: Authoritative pond/lake graph; add ponds; auto‑link canals (occlusion‑aware); emits deltas; creates remotes.
  - `ServerScriptService/Server/CanalBuilder.luau`: Centerline clipping/utility for canals.
  - `Players/.../PlayerScripts/Client/PondNetworkClient.luau`, `Tools/PondTool.client.luau`, `Tools/LakeTool.client.luau`: Dev/test clients for pond add/link; tolerant to missing remotes.
- Boundary System (authoritative geometry + client rendering)
  - `ServerScriptService/Server/Boundary/BoundaryGraph.luau`: Versioned snapshot of ponds/lakes for geometry builds.
  - `ServerScriptService/Server/Boundary/BoundaryGeometry.luau`: Samples dot soup (pond rims, canal rails); computes rim gaps; validates soup.
  - `ServerScriptService/Server/Boundary/BoundaryPublisher.luau`: Builds and publishes dot soup full and deltas via `RE_BoundaryDelta`; answers `RF_BoundaryGetSoup`.
  - `Players/.../PlayerScripts/Client/Boundary/BoundaryRenderer.client.luau`: Queues payloads; renders soup via DottedMarkers; stats to HUD; watchdog logs.
  - `Players/.../PlayerScripts/Client/Boundary/BoundaryHUD.client.luau`: Overlay with version, counts, timings.
  - `Players/.../PlayerScripts/Client/Boundary/BoundaryMask.client.luau`: Scaffold; tracks soup; currently defers inclusion tests to SDF.
- Admin/Dev
  - `ServerScriptService/Server/Boundary/BoundaryDev.server.luau`: `/boundary` commands (stats, validate, timing, ceiling, capture, selfcheck, dump pond).
  - `ServerScriptService/Server/Admin/PondDevCommands.luau`: Dev tooling for ponds.

Boot order
- `WorldBootstrap` and `Server` initialize core services, Terrain sculpting, and Pond network.
- `BoundaryPublisher` creates remotes (`RF_BoundaryGetSoup`, `RE_BoundaryDelta`) at module load, before requiring geometry/graph, so clients can wait safely.
- `PondNetworkService` creates legacy remotes (`RF_GetPondNetworkSnapshot`, `RE_PondNetworkDelta`, `RF_AddPond`, `RF_LinkPonds`) on load.
- Clients begin listening; HUD/Renderer fetch `RF_BoundaryGetSoup` once, then consume `RE_BoundaryDelta`.

## Networking Contract

Remotes (ReplicatedStorage/Net/Remotes)

- `RF_BoundaryGetSoup : () -> Soup`
  - Returns latest authoritative soup (see Payloads below). Includes `soupVer` and `junctionsVer` fields in the root when present.
  - Error modes: returns minimal/empty soup if geometry fails; server logs reason.
  - Call sites: `BoundaryRenderer.client.luau`, `BoundaryHUD.client.luau`, `BoundaryMask.client.luau` (scaffold).

- `RE_BoundaryDelta : (DeltaPayload)`
  - Event payload for full replace or delta apply.
  - Ordering guarantees: server emits in pub_id order; a delta's fields are ordered as `junctionsRemove -> junctionsAdd -> adds -> removes` to avoid flicker. Empty deltas are suppressed.
  - Idempotency: per‑id pcall isolation ensures a failing id keeps its previous batch; client may receive repeat adds (replace semantics by id).

- `RF_GetPondNetworkSnapshot : () -> PondSnapshot`
  - Returns current pond/lake snapshot for dev tooling.

- `RE_PondNetworkDelta : (PondDelta)`
  - Event for pond/lake create/update/remove (dev path).

- `RF_AddPond : (posXZ: Vector2, radius: number) -> {id,...}?`
  - Dev add; server guards overlap; returns new pond on success.

- `RF_LinkPonds : (aId: string, bId: string, width?: number) -> {id,...}?`
  - Dev link; server auto‑clips and persists junctions;

- `RF_PlaceLantern : (cframe: CFrame, presetKey: string) -> (boolean, reason|string)`
  - Place lantern; server authoritative checks; persistence deferred/batched.

Versions
- `soupVer=3`, `junctionsVer=1` are included in `RE_BoundaryDelta` payloads and should be mirrored in client logs for correlation.

## Boundary System (Authoritative Model)

Data model (server)
- Pond: `{ id: string, posXZ: Vector2, radius: number }`
- Lake (canal): `{ id: string, a: pondId, b: pondId, path: {Vector2} }`
- Junction (authoritative notch): `{ pondId, lakeId, theta, arcHalfWidth, capLength, y }`
- DotBatch (soup unit): `{ kind: "pond_rim"|"canal_left"|"canal_right", id: string, style?: { size_hint?: number, alpha?: number, color_hint?: [r,g,b] }, points: { {x,y,z} } }`

Publish protocol
- Full (replace):
  - `{ pub_id, version, soup, full: { batches: DotBatch[] }, soupVer: 3, junctionsVer: 1 }`
  - Soup includes polyline soup for back‑compat; full.junctions will be added as JM‑1 completes.
- Delta (ordered groups):
  - `{ pub_id, version, delta: { junctionsRemove?: JunctionId[], junctionsAdd?: Junction[], adds?: DotBatch[], removes?: string[] }, soupVer: 3, junctionsVer: 1 }`
  - Ordering: junctionsRemove → junctionsAdd → adds → removes.
- pub_id semantics: monotonically increasing; the atomic tx id for apply ordering on the client.
- Build isolation: per‑id pcall; on failure, keep last good batch for that id; log `[Boundary/Publish] skip id=<id> reason=build_error`.
- Empty delta suppression: if all groups empty, nothing is emitted.

## Geometry & Sampling

- Junction mode (useJunctions=true):
  - Gaps are derived only from persisted Junctions (`lake.junctions`) that reference the pond; there is no geometric fallback inference in this mode.
  - Arcs are built from `[theta - arcHalfWidth, theta + arcHalfWidth]`, wrap‑merged on [-π,π), mapped to [0,2π). Degree‑cap drops narrowest arcs if `arcs_merged > degree(pond)`.
  - Densify rim segments when remaining dots < 6; never blank a rim. Full rims (no arcs) sample the whole circle directly.
- Rail sampling (stone rails):
  - Centerline resampled by `dotSpacing`.
  - Left/Right rails computed by unit normals offset by `canalHalfWidth`.
  - End caps (JM‑2): extend rails by `capLength` toward pond centers (overlap into rims for clean joins).
- Performance knobs:
  - `dotSpacing` controls both rim and rail dot density (default: 3.5 studs).
  - Adaptive spacing: if total dots > `maxDotsPerPublish` (default: 6000), spacing scales up; logged via `[Boundary/Publish] rebalance spacing_up=...`.
  - Validate fast‑path (planned): skip heavy checks when no canals exist.

## Pond/Lake Logic

- Add pond
  - Overlap guard: reject if `dist(center_new, center_i) < ringR(new)+ringR(i)+0.5` (ringR uses pond_scale+pad). Logs `[Boundary/Place] pond_overlap ...`.
  - Auto‑link (if enabled): candidate ponds ordered by center distance; segment A→B must not intersect any other pond’s expanded disk (`ringR(C)+canalHalfWidth+clearance`).
    - Logs: `[Boundary/Link] candidates ...`, then either `[Boundary/Link] choose ... reason=visible` or `[Boundary/Link] none ...`.
  - If linked: create lake, clip to rings, persist `lake.junctions` (2 ends), and emit soup deltas (rims + rails).
- Remove/edit lake
  - On removal: emit `junctionsRemove` and remove rails; recompute rims (close arcs). On edit: recompute and emit `junctionsAdd` for both ends.

Logging taxonomy
- `[Boundary/Link] candidates/choose/occluded/none`
- `[Boundary/Junction] pond=<id> degree=<d> juncs=<n> arcs=<m> totalsDeg=<sum>`
- `[Boundary/Gaps] dedupe ...` and `[Boundary/Rail] ...`
- `[Boundary/Publish] ... ms_build= ... ms_validate= ... ms_send= ...`

## Client Rendering

- BoundaryRenderer
  - Queues full/replace payloads from `RE_BoundaryDelta`; fetches once from `RF_BoundaryGetSoup`.
  - Renders via DottedMarkers strategy: acquires pooled BillboardGui dots, projects to terrain, lifts by `dotLiftY`.
  - Stats to HUD; watchdog logs for queue stalls and missing soup.
- DottedMarkers strategy
  - Renders DotBatch lists (full replace). Rail batches appear as stones; pond_rim as rings. Pool grows up to caps; preview batches dropped first under pressure.
- BoundaryMask (scaffold)
  - Tracks soup; currently defers inside tests to SDF helper. JM‑3 will rebuild mask from junction arcs to eliminate desync.
- Flicker prevention (planned JM‑3)
  - Two‑phase apply: junctions→adds stage→removes→commit. Skip remove if no matching add this tick.

## Configuration & Feature Flags

- `useJunctions = true` (default): No geometric gap inference; only junction arcs carve rims.
- Visuals
  - Stone rails (client) enabled; legacy river meshes disabled (server does not build them).
- Defaults
  - `dotSpacing = 3.5`, `canalHalfWidth = 2.0`, `capLength = 0.75`, `dotLiftY = 0.05`
  - `rimPad = max(0.25, dotSpacing*0.25)`, `epsRad cap = 0.035`
  - Throttles: `publishMinIntervalMs = 120`, `maxDotsPerPublish = 6000`

## Error Handling & Invariants

- Server build isolation: Per‑id pcall keeps last good batch; failed ids log and do not blank visuals.
- Client remove‑without‑add guard (planned): remove skipped if add not staged this tick.
- Junctions invariant: With `useJunctions=true`, no junctions ⇒ no rim gaps. Full rim must be emitted and rendered.

Known failure modes & symptoms
- PondNetworkService syntax error: no remotes; clients see infinite yields; resolved by file end cleanup.
- Nil helper during connectPonds: no lakes created; rims remain full; logs show `[Boundary/Link] none`.
- Excessive notch width: verify `dotSpacing`, `canalHalfWidth`, and caps; degree‑cap ensures arcs ≤ degree.

## Performance & Telemetry

- Server timings: `[Boundary/Geometry] stage=build ...`, `[Boundary/Validate] stage=validate ...`, `[Boundary/Publish] ... ms_send=...`.
- Client draw: `[Boundary/Renderer] strategy=... pub_id=... draws=... queue=... ms_draw=...`.
- Budgets: `max_redraws_per_frame`, `maxDotsPerPublish`, pool sizes (HUD: pool/batches/dots).

## Developer Operations

Smoke checklist (cold boot)
- `[Boundary/Publisher] init` logged, remotes present under `ReplicatedStorage/Net/Remotes`.
- First publish shows `soupVer=3 junctionsVer=1`.
- Single pond: full ring; no junctions.

Dev commands (chat)
- `/boundary soup|validate|timing on|off|ceiling <int>|capture [latest]|dump pond <id>|selfcheck`
- `boundary.debug on|off`, `boundary.stats`, `boundary.dots on|off`

Reproducing auto‑link occlusion
- Drop three ponds in a line; middle pond occludes; expect `[Boundary/Link] occluded ...` and no A↔C link.

## Appendix

### Payloads (examples)

Full (replace):
```jsonc
{
  "pub_id": 3,
  "version": 3,
  "soupVer": 3,
  "junctionsVer": 1,
  "soup": { "polylines": [ /* legacy polyline soup (back-compat) */ ] },
  "full": {
    "batches": [
      { "kind": "pond_rim", "id": "pond_...", "style": {"size_hint": 0.55}, "points": [{"x":0,"y":100,"z":0} ...] },
      { "kind": "canal_left",  "id": "lake_..._L", "points": [ ... ] },
      { "kind": "canal_right", "id": "lake_..._R", "points": [ ... ] }
    ]
    // (JM-1) full.junctions will be included here when wired
  }
}
```

Delta (ordered groups):
```jsonc
{
  "pub_id": 4,
  "version": 4,
  "soupVer": 3,
  "junctionsVer": 1,
  "delta": {
    "junctionsRemove": ["pond_A|lake_X", "pond_B|lake_X"],
    "junctionsAdd": [
      {"pondId":"pond_A","lakeId":"lake_X","theta":1.57,"arcHalfWidth":0.22,"capLength":0.75,"y":100.05},
      {"pondId":"pond_B","lakeId":"lake_X","theta":-1.57,"arcHalfWidth":0.22,"capLength":0.75,"y":100.05}
    ],
    "adds": [ {"kind":"pond_rim","id":"pond_A", "points":[...]}, {"kind":"canal_left", "id":"lake_X_L", "points":[...]} ],
    "removes": ["lake_X_R"]
  }
}
```

### Glossary
- Rim: dot ring around a pond at ring radius.
- Rail: dot line offset from a canal centerline (left/right).
- Junction: declarative notch at pond/canal interface; carries theta & width.
- Soup: published batches of dots for client rendering.
- pub_id: server emit sequence id; groups all delta parts atomically.
- Degree: number of lakes attached to a pond.

