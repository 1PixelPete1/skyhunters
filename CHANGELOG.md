# Changelog — Wailing Winds (Boundary V3 Dots)

## [2025-09-08] M1.4 (Fixes for Y positioning, canal connections, default pond tracking)

Fixed
- Oil dots now use terrain raycast for Y positioning instead of fixed plane calculation.
- Stone rail segments now properly connect to pond rims instead of going center-to-center.
- Default pond markers now appear on startup (boundary system now tracks existing ponds).
- Preview positioning fixed to use proper terrain height.

Added
- Boundary markers toggle with 'M' key (similar to lantern ghost 'B' key toggle).
- Canal path clipping to pond ring circumferences for proper visual connections.
- Terrain raycast positioning for all boundary dots (ponds and canals).

Changed
- All boundary dots (pond rims and canal rails) now use terrain raycast + lift instead of fixed Y.
- Canal geometry properly clips to pond boundaries using ring radius calculations.
- WorldBootstrap initializes boundary publisher after default pond creation and ensures tracking.

Notes for QA
- Press 'M' to toggle boundary markers visibility.
- Default pond should now have visible markers on startup.
- Canal segments should now connect cleanly to pond rims without gaps.
- All markers should sit properly on terrain surface regardless of height variations.

## [2025-09-08] M1.3 (Junction Markers groundwork, soup v3)

Added
- soupVer=3 and junctionsVer=1 are attached to every `RE_BoundaryDelta` payload.
- Lakes persist deterministic junctions at both ends: `{ pondId, lakeId, theta, arcHalfWidth, capLength=0.75, y }`.
- `BoundaryConfig.useJunctions=true` gate for junction mode (default on).
- Auto-link visibility logs: `[Boundary/Link] candidates|choose|occluded|none`.

Changed
- Junction discipline: with `useJunctions=true`, rim gaps are built only from persisted lake.junctions; no geometric gap inference.
- Delta packet ordering: `junctionsRemove -> junctionsAdd -> adds -> removes` to avoid flicker.
- Canal “river” visuals disabled on server; stone rails are driven by dot soup (client).

Fixed
- PondNetworkService parse error (helpers after `return S`): removed code after return; helpers live above `connectPonds`.
- Prevented phantom gaps when no lake exists: computePondGaps returns `{}` if no junctions for pond.

Removed
- Legacy canal body build path (river meshes) disabled by default.

Notes for QA
- Cold boot: `[Boundary/Publisher] init`, first publish contains `soupVer=3 junctionsVer=1`.
- Add pond B (no link): both ponds keep full halos; logs include `[Boundary/Link] none ...` if not chosen.
- If link is chosen: expect two junctions and four adds (A rim, B rim, lake_L, lake_R).

Migration / Flags
- `BoundaryConfig.useJunctions=true` must be enabled (default). Legacy polyline soup remains for back‑compat.

## [2025-09-08] M1.2.2 (Gap dedupe + crash guards)

Added
- Degree-cap dedupe: if `arcs_merged > degree(pond)`, drop narrowest arcs; log `[Boundary/Gaps] dedupe ...`.

Fixed
- `segCircleHits` nil/degenerate guards — never throws; returns empty hits.
- Sanitized canal centerlines to Vector2; skipped short paths with logs.
- Publisher per‑id pcall isolation: keep last batches on build error; log `[Boundary/Publish] skip id=...`.

Notes for QA
- No “invalid argument (Vector2 expected)” crashes.
- Rims never disappear on partial recompute; previous batches persist.

## [2025-09-08] M1.2.1 (Wrap-safe merge + thin-rim protection)

Changed
- Wrap-safe arc merging on [-π,π) then map to [0,2π); robust around seam.
- Densify rim when remaining dots < 6; never blank full rims. Log `[Boundary/Rim] skip_thin ...` if skip.

## [2025-09-08] M1.2 (Defensive gap sampling + isolation)

Added
- Fallback to nearest-point-on-polyline only when no circle hits; never combine with hit.

Fixed
- No combined fallback+hit duplicates; one gap per (pond,lake).

## [2025-09-08] M1.1 (Rim alignment + occlusion-aware auto-link)

Added
- Auto-link occlusion test: skip candidates whose A→B segment intersects another pond’s expanded disk.
- Logs: `[Boundary/Link] occluded ...`.

Changed
- (Interim) Rim notch direction based on ring intersection; superseded by junctions in M1.3.

## [2025-09-08] M1 (Dot soup + deltas)

Added
- Server builds DotBatches for pond rims and canal rails; publishes full soup once, then deltas on graph changes.
- Delta suppression if empty; adaptive spacing if dots exceed `maxDotsPerPublish`.
- Telemetry: `[Boundary/Publish] ... ms_build ms_validate ms_send`.

## [2025-09-07] M0 (Client renderer hardening)

Added
- BoundaryRenderer forced to DottedMarkers; nil-guarded `State.set`; watchdog logs; renderer stats HUD.
- BoundaryMask scaffold; PlacementClient tolerates mask missing and legacy remotes.

Fixed
- Client infinite-yield hazards: replaced strict WaitForChild with timed waits and fallbacks.

---

Legend
- M#.# — minor/feature milestones; M1.x tracks Dot Soup + Boundary V3.
- JM-# — Junction Markers implementation phases.

