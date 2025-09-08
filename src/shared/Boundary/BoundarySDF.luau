--!strict
-- BoundarySDF: pure helpers for boundary inclusion using PondNetwork snapshot

local RS = game:GetService("ReplicatedStorage")
local BoundaryConfig = require(RS.Shared.Boundary.BoundaryConfig)

local SDF = {}

local function distPointSeg2D(p: Vector2, a: Vector2, b: Vector2): number
    local ab = b - a
    local denom = ab:Dot(ab)
    local t = 0
    if denom > 0 then
        t = math.clamp((p - a):Dot(ab)/denom, 0, 1)
    end
    local proj = a + ab * t
    return (p - proj).Magnitude
end

local function signedDistance(p: Vector2, snapshot: any): number
    local best = math.huge
    local POND_SCALE = BoundaryConfig.pond_scale
    local PAD = BoundaryConfig.pad
    for _, pond in pairs(snapshot.ponds or {}) do
        local R = (pond.radius or 0) * (1 + POND_SCALE) + PAD
        local d = (p - pond.pos).Magnitude - (pond.radius + R - pond.radius)
        if d < best then best = d end
    end
    for _, lake in pairs(snapshot.lakes or {}) do
        local half = ((lake.width or BoundaryConfig.canal_width_default) * 0.5) + PAD
        local path = lake.path or {}
        for i = 1, #path - 1 do
            local d = distPointSeg2D(p, path[i], path[i+1]) - half
            if d < best then best = d end
        end
    end
    return best
end

function SDF.isInside(posXZ: Vector2, snapshot: any): boolean
    return signedDistance(posXZ, snapshot) <= 0
end

return SDF

