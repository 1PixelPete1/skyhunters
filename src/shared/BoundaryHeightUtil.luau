--!strict
-- BoundaryHeightUtil: Single source of truth for boundary marker heights
-- SIMPLIFIED: Uses consistent plot height + 2 studs for all markers

local BoundaryHeightUtil = {}

local RS = game:GetService("ReplicatedStorage")
local WorldConfig = require(RS.Config.WorldConfig)

-- SIMPLIFIED: Get consistent marker height (plot height + 2 studs)
local function getStandardMarkerHeight(): number
    local plotHeight = (WorldConfig.ISLANDS and WorldConfig.ISLANDS.DefaultHeightY) or 1
    return plotHeight + 2  -- Simple: plot height + 2 studs
end

-- Get the authoritative rendering Y for boundary elements
-- SIMPLIFIED: All markers use the same height for consistency
function BoundaryHeightUtil.getBoundaryRenderY(elementType: string, centerXZ: Vector2, elementId: string?): number
    return getStandardMarkerHeight()
end

-- Get Y coordinate for pond centers (used by boundary geometry)
function BoundaryHeightUtil.getPondCenterY(pondId: string, centerXZ: Vector2): number
    return getStandardMarkerHeight()
end

-- Get Y coordinate for canal rails
function BoundaryHeightUtil.getCanalRailY(lakeId: string, pathMidpoint: Vector2): number
    return getStandardMarkerHeight()
end

-- Get Y coordinate for canal stones (same height for consistency)
function BoundaryHeightUtil.getCanalStoneY(lakeId: string, stonePos: Vector2): number
    return getStandardMarkerHeight()
end

-- No-op for compatibility (no cache needed with simple height calculation)
function BoundaryHeightUtil.clearCache()
    -- Nothing to clear with simple height calculation
end

return BoundaryHeightUtil