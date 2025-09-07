--!strict

-- Shared constants, enums, tuning tables for Lanterns V2.
-- Numbers intentionally symbolic where noted; tune via a server-side config if needed.

local LanternShared = {}

LanternShared.PERF = {
    fxStepHzDefault = 10,         -- stepped FX/UI rate
    maxActiveLanternFX = 8,       -- per client LOD cap
    uiMinInterval = 0.1,          -- GUI recompute cadence
}

LanternShared.ECON = {
    baseBurnRate = nil,           -- units per min (set in server config)
    minionScatterCooldown = nil,  -- seconds (set in server config)
}

LanternShared.VIS = {
    radiusMax = nil,              -- studs visual (set in server config)
    vignetteTightenAt = 0.15,
    flickerHzNearEmpty = { min = nil, max = nil },
}

LanternShared.NET = {
    batchInterval = nil,          -- seconds (set in server config)
    sendDeltas = true,
}

LanternShared.ZONES = {
    cellSize = nil,               -- studs (set in server config)
    maxQueryCells = nil,          -- clamp queries (set in server config)
}

LanternShared.Enums = {
    ScatterReason = {
        Depleted = "Depleted",
        Event = "Event",
    },
}

return LanternShared

