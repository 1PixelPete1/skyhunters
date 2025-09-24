--!strict

-- POIRegistry: lightweight server-side registry of POI world positions
-- Accessible from worldgen and dev utilities.

local POIRegistry = {}

local _positions: { Vector3 } = {}

function POIRegistry.add(pos: Vector3)
    table.insert(_positions, pos)
end

function POIRegistry.clear()
    table.clear(_positions)
end

function POIRegistry.getAll(): { Vector3 }
    return _positions
end

return POIRegistry

