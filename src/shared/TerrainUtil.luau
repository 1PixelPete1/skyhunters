local TerrainUtil = {}

local Terrain = workspace.Terrain
local CELL = 4 -- default voxel resolution (studs)

-- Tolerant setter for Terrain.Decoration (no-op if unsupported)
function TerrainUtil.setTerrainDecorationEnabled(enabled: boolean)
    pcall(function()
        Terrain.Decoration = enabled
    end)
end

-- Returns true if the voxel under 'pos' (within 'radius') is mostly Water
function TerrainUtil.isWaterAt(pos: Vector3, radius: number?): boolean
    local r = radius or CELL
    local ok, materials = pcall(function()
        local region = Region3.new(
            pos - Vector3.new(r, CELL, r),
            pos + Vector3.new(r, CELL, r)
        ):ExpandToGrid(CELL)
        local mats, _ = Terrain:ReadVoxels(region, CELL)
        return mats
    end)
    if not ok or type(materials) ~= "table" then
        return false
    end
    local nx = #materials
    if nx == 0 then return false end
    local ny = #materials[1]
    if ny == 0 then return false end
    local nz = #materials[1][1]
    if nz == 0 then return false end
    local cx = math.floor(nx/2) + 1
    local cy = math.floor(ny/2) + 1
    local cz = math.floor(nz/2) + 1
    local mat = materials[cx][cy][cz]
    return mat == Enum.Material.Water
end

return TerrainUtil
