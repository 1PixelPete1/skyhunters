--!strict
-- Shared BoundaryConfig: single source of truth for boundary constants

local BoundaryConfig = {
    -- Pond ring scale relative to pond radius (additive factor): R_ring = radius * (1 + pond_scale) + pad
    pond_scale = 0.5,

    -- Global padding applied to ponds and canal half-widths in world space (studs)
    pad = 1.25,

    -- Default canal width (studs) used when a width is not provided
    canal_width_default = 10,

    -- Polyline offset join style and clamps
    -- offset_join may be: "bevel" (current), future: "miter"/"round"
    offset_join = "bevel",
    -- Optional join angle clamp (degrees); consumers may ignore if unsupported
    offset_join_angle_clamp_deg = 75,

    -- Pixels per stud used by all boundary canvases (global)
    pps_global = 24,

    -- Budget: maximum redraw jobs processed per frame on client
    max_redraws_per_frame = 4,

    -- Validation guardrails
    validate_segments_ceiling = 12000, -- skip heavy intersection checks beyond this

    -- Angle merge epsilon (radians) for gap unioning and seam handling
    angle_epsilon = 1e-4,
    -- Coverage tolerance (radians) when comparing expected vs emitted pond arcs
    area_epsilon = 0.05,
    -- Full-ring sampling step in pixels (converted to studs via pps)
    ring_px_step = 6,

    -- Telemetry toggles (server logs + HUD metrics)
    telemetry_enabled = false,
    debug_enabled = false,
    debug_rate_limit_per_s = 20,
    client_log_heartbeat_ms = 500,
    capture_max_points_per_poly = 5,

    -- Feature flags
    boundary_renderer_enabled = true, -- flip to use unified BoundaryRenderer
    useJunctions = true, -- V3: enable junction-based rims/rails

    -- Renderer strategy + LOD policy (client)
    strategy_default = "DottedMarkers",
    strategy_near = "Canvas2D",
    strategy_tool = "BeamRibbon",
    lod_near_distance = 40, -- studs
    lod_far_distance = 120,  -- studs
    -- Pool growth rate for dotted markers to avoid spike on first render
    dot_pool_grow_per_frame = 64,
    -- Budgets per strategy
    max_beams_total = 1500,
    max_dots_total = 3000,
    dot_spacing_studs = 3.5,

    -- Hint toggles
    hints_enabled = false,
    halo_enabled = false,

    -- V3 Dots defaults (authoritative keys)
    dotSpacing = 3.5,
    dotSizeMin = 0.25,
    dotSizeMax = 0.6,
    dotAlpha = 0.8,
    canalHalfWidth = 2.0, -- studs offset from centerline
    maxDegreePerPond = 2,
    maxTotalCanals = nil, -- off unless set
    publishMinIntervalMs = 120,
    maxDotsPerPublish = 6000,
    previewAlpha = 0.6,
    previewTimeoutS = 2.0,
    logRateWarnPerSec = 4,
    dotLiftY = 0.8,
}

return BoundaryConfig
