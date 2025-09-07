## Boundary & Canal System — Implementation History + Current Design (Summary)

Overview
- Server-authoritative ponds and canals determine where lanterns can be placed. Terrain edits are done server-side; clients render an up-facing overlay and/or part-based visuals to show the exact perimeter.
- Goals: accurate, stable, cheap visuals; exact parity with server acceptance; no floating visuals; rings show gaps where canals attach (gap cut currently disabled while canal geometry is tuned).

Core Data Types (Shared)
- `PondId` = string; `LakeId` = string
- `Pond` = { id: PondId, pos: Vector2 (world XZ), radius: number }
- `Lake` = { id: LakeId, a: PondId, b: PondId, path: { Vector2 } (centerline), width: number }
- `Snapshot` = { version: number, ponds: { [PondId]: Pond }, lakes: { [LakeId]: Lake } }

Shared Math
- Module: `ReplicatedStorage/Shared/PondFieldMath`
  - Constants: `POND_SCALE = 0.5`, `PAD = 1.25`
  - `Rpond = radius * (1 + POND_SCALE) + PAD`
  - `roff = (width / 2) + PAD` for canals
  - `signedDistance(p, snapshot, PAD)`: min distance to pond discs at `Rpond` and to each canal capsule with `roff`. `isInside` is ≤0.

Server Modules (authoritative)
- `ServerScriptService/Systems/PondNetworkService`
  - Snapshot: `S.snapshot: Types.Snapshot`
  - Policy (tunable): `MinPondRadius=6`, `MaxPondRadius=20`, `DefaultLakeWidth=10`, `PathSampleStep=8`, `AutoLink=true`, `AutoLinkMaxGap=80`, `MaxLakeSpan=600`
  - Public API:
    - `addPond(posXZ: Vector2, radius: number) -> Pond`
      - Emits delta (version++), sculpts terrain (Air-only cylinder), builds rim stones (`workspace/PondRims/<pondId>`). Auto-links based on `edge gap` and span. Debug prints.
    - `connectPonds(aId: string, bId: string, width?: number) -> Lake?`
      - Samples Bezier A→B (seed wobble), then clips the path so it starts/ends at `Rpond` for both ponds (bisection). Writes clipped path + visual width `visW=max(2,baseWidth*0.4)` into snapshot, sculpts canal (Air-only chain), builds canal visuals. Debug prints.
    - `getSnapshot() -> Snapshot`; `setSnapshot(newSnap: Snapshot)` (replace + `{full=true}`).
  - Remotes (ReplicatedStorage/Net/Remotes):
    - `RF_GetPondNetworkSnapshot` (RemoteFunction)
    - `RE_PondNetworkDelta` (RemoteEvent)
    - Dev: `RF_AddPond(posXZ: Vector2, radius: number)`, `RF_LinkPonds(aId, bId, width?)`

- `ServerScriptService/PlacementService.server`
  - Remote: `ReplicatedStorage/Remotes/RF_PlaceLantern`
  - Validations (server):
    - SDF ring (PAD=1.25, POND_SCALE=0.5): `PondFieldMath.isInside(Vector2(pos.X,pos.Z), PondNetworkService.getSnapshot(), PAD)`
    - Terrain: vertical ray from Y+200; ignore rims/oil/boundary; reject Water (`ON_WATER`) and steep slopes (`upDot < 0.85`).
    - Spacing: ≥ 6 studs from tagged `Lantern`.
  - Delegates spawn to `ServerScriptService/Server/LanternService.ApplyPlacement`.

- `ServerScriptService/Server/LanternService`
  - Uses pond-network SDF (vs legacy oil disc) to accept placements visually inside the boundary ring.

- `ServerScriptService/Server/OilService`
  - Oil plane sits below terrain (base ~3.0 under center; top ~0.6 below surface).

- `ServerScriptService/Server/RimBuilder`
  - Campfire-style stones: `StoneCount=32`, slightly larger stones, small arc jitter; radius offset includes stone length.
  - Rims live under `workspace/PondRims/<pondId>`.

Client Modules (visual only)
- `StarterPlayerScripts/Client/Boundaries/*`
  - CanvasManager: up-facing SurfaceGui; uniform height = `peakRimStoneTop + yOffset`; `PPS=24`, `AlwaysOnTop=true`.
  - Geometry2D: circleSample (chord based), resampleByArcLength, offsetPolylineBevel, simplify, aabb.
  - StrokeRenderer2D: frames as segments; 3px odd stroke; integer-pixel snapping; clear() per redraw.
  - Orchestrator: ponds as circles at `Rpond` (gap cut disabled for now), lakes as polylines built from canal Bound parts (not math) — read part endpoints via CFrame; continuous chain `[a1,b1,b2,…]`; clear() before draw; scheduler budgets redraws.

- `StarterPlayerScripts/Client/PlacementClient.client`
  - Default lantern ghost can toggle via `RE_DevToggleGhost`.
  - Ghost validity: `PondFieldMath.isInside` with PAD=1.25 (matches server gate).

- `StarterPlayerScripts/Client/PondNetworkClient` (ModuleScript)
  - Fetches `Snapshot` (RF) and applies deltas (RE); exposes `Changed` + `snapshot`.

- `StarterPack/PondTool`
  - Visual ghosts while equipped:
    - Red cylinder = pond, white cylinder = placement ring.
    - Green canal preview: translucent blocks sampling a Bezier from nearest pond to cursor.
  - Activation invokes `RF_AddPond(Vector2, radius)` (server allows in Studio).

Remotes Summary
- Core: `RF_GetPondNetworkSnapshot`, `RE_PondNetworkDelta`
- Legacy alias: `RF_GetPondDisc` (in `/Remotes` and `/Net/Remotes`) logs deprecation once.
- Dev: `RF_AddPond`, `RF_LinkPonds`, `RE_DevToggleGhost`, `RE_DevBoundaryDebug`

Validation & Constants
- `PAD = 1.25` (absolute), `POND_SCALE = 0.5` (relative pond growth)
- Spacing: ≥ 6 studs; slope threshold: ≥ 0.85 up-dot; Terrain only (no Water)

Studio Commands
- `/mode pond` — hides default ghost and equips PondTool.
- `/ghost on|off` — toggles default lantern ghost.
- `/boundary debug on|off` — client prints segment counts and bbox per recompute.
- `/pond add x z r` — adds a pond; sculpts terrain; builds rim.
- `/wipe plot` — wipes current plot’s lantern save and clears spawned lanterns.

World Config (for testing)
- `ISLANDS.SizeStuds = 192`, `ISLANDS.HeightStuds = 48`.
- Defaults: `ISLANDS.Pond { Radius=15, Depth=2 }`, `DefaultHeightY` used for sculpt pivot.

Performance Notes
- Boundary avoids full-field marching when lakes exist; uses two constant-offset polylines along A→B.
- Ponds render as circles (72 segments). Sculpting uses cylinders (fast enough for Studio iteration).

Potential Next
- Expose `POND_SCALE`/`PAD` in Shared.Config.
- Add canal end-caps (capsules) and bank smoothing.
- Scale rim density with circumference for very large ponds.

Up-Facing 2D Boundary Canvas (No Beams) — Clarifications

- Pixels-per-stud is global: use a single PPS for all canvases so stroke thickness is identical across ponds/lakes.
- AABB includes stroke pad:
  - Ponds: expand by `(R + strokeHalfWidth/PPS)` where `R = radius * (1 + POND_SCALE) + PAD`.
  - Lakes: compute min/max over the offset rims (left/right), not just the centerline.
- World→canvas axis: consistently map X→px, Z→py as `py = (maxZ - z) * PPS` (flip so “north” is up). Document once and reuse.
- Y elevation: place canvases a tiny, fixed offset above water/terrain to avoid z-fighting; keep this in config alongside PPS and stroke.
- Preview tick, not per-frame: update the preview ghost at a fixed Hz (e.g., 15–20); never tie rebuild to `RenderStepped`.
- Segment caps and resampling:
  - Clamp pond segments by `pondMinSeg/pondMaxSeg`.
  - Resample lakes by arc length with `lakeStepNear/lakeStepFar`.
  - Enforce `maxSegmentsPerCanvas` and `maxTotalSegments`.
- Work scheduler: process at most `maxRedrawsPerFrame` canvases each frame; queue the rest to avoid spikes.
- Tiling only when needed: split lakes whose AABB exceeds `tileMaxCanvasSizeStuds` into 2–3 tiles with a 1 px overlap to prevent seam gaps.
- Edge cases:
  - Tiny/huge ponds: clamp segments so tiny rings don’t vanish; cap large ones.
  - Sharp canal turns: bevel joins only; collapse degenerates before offsetting.
  - Self-intersections: drop segments < 1 px to prune micro-zigs/overdraw bursts.
- Visibility modes: default ghost-only; if persistent overlays are enabled, add distance/frustum culling and coarser LOD at range.
- Instrumentation:
  - Per rebuild, log or HUD: `shapeId`, type (pond/lake), canvas px size, segments, ms in Geometry2D/CanvasManager/StrokeRenderer, pool usage, queued canvases; totals for active canvases and segments.
