--!strict
-- PondFieldMath: SDF utilities for ponds + lakes

local PondFieldMath = {}

function PondFieldMath.distPointSeg2D(p: Vector2, a: Vector2, b: Vector2): number
    local ab = b - a
    local denom = ab:Dot(ab)
    local t = 0
    if denom > 0 then
        t = math.clamp((p - a):Dot(ab)/denom, 0, 1)
    end
    local proj = a + ab * t
    return (p - proj).Magnitude
end

-- Signed distance to union (pond discs dilated by pad) U (lake capsules dilated by pad)
-- pad is an absolute epsilon in studs; ponds are additionally scaled by POND_SCALE
local POND_SCALE = 0.5 -- enlarge pond discs by +50%

function PondFieldMath.signedDistance(p: Vector2, snapshot: any, pad: number): number
    local best = math.huge

    for _, pond in pairs(snapshot.ponds or {}) do
        local grow = (pond.radius * POND_SCALE) + (pad or 0)
        local d = (p - pond.pos).Magnitude - (pond.radius + grow)
        if d < best then best = d end
    end

    for _, lake in pairs(snapshot.lakes or {}) do
        local w = ((lake.width or 10) * 0.5) + (pad or 0)
        local path = lake.path or {}
        for i = 1, #path - 1 do
            local d = PondFieldMath.distPointSeg2D(p, path[i], path[i+1]) - w
            if d < best then best = d end
        end
    end

    return best
end

-- Boolean membership using same rule as SDF (pad used both client/server)
function PondFieldMath.isInside(p: Vector2, snapshot: any, pad: number): boolean
    return PondFieldMath.signedDistance(p, snapshot, pad) <= 0
end

return PondFieldMath
