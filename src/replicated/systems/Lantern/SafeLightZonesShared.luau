--!strict

-- Grid params + tagging for safe-light emitters on islands.

local SafeLightZonesShared = {}

-- Utility to compute a cell key for a world position.
function SafeLightZonesShared.CellKey(pos: Vector3, cellSize: number): string
    local cx = math.floor(pos.X / cellSize)
    local cy = math.floor(pos.Y / cellSize)
    local cz = math.floor(pos.Z / cellSize)
    return string.format("%d:%d:%d", cx, cy, cz)
end

-- Neighbor keys within a Chebyshev radius (r cells in X/Z, same Y layer)
function SafeLightZonesShared.NeighborKeys(pos: Vector3, cellSize: number, radius: number): { string }
    local cx = math.floor(pos.X / cellSize)
    local cy = math.floor(pos.Y / cellSize)
    local cz = math.floor(pos.Z / cellSize)
    local out = {}
    for dx = -radius, radius do
        for dz = -radius, radius do
            table.insert(out, string.format("%d:%d:%d", cx + dx, cy, cz + dz))
        end
    end
    return out
end

return SafeLightZonesShared

