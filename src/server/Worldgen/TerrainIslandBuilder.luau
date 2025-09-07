-- TerrainIslandBuilder
-- Clear -> flat rock slab (top at pivot Y) -> vertical pond carve (Air) -> water fill
-- Idempotent across boots via padded Air clear region.

local TerrainIslandBuilder = {}

local Terrain = workspace.Terrain
local RS = game:GetService("ReplicatedStorage")
local WorldConfig = require(RS.Config.WorldConfig)
local TerrainUtil = require(RS.Shared.TerrainUtil)

local function numberOr(x: any, d: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return d
end

local function vec3Or(x: any, d: Vector3): Vector3
	if typeof(x) == "Vector3" then
		return x
	end
	return d
end

local function matFromString(s: any, fallback: Enum.Material): Enum.Material
    if typeof(s) == "EnumItem" then
        return s :: Enum.Material
    end
    if type(s) == "string" then
        local ok, mat = pcall(function() return Enum.Material[s] end)
        if ok and typeof(mat) == "EnumItem" then
            return mat :: Enum.Material
        end
    end
    return fallback
end

local function getFootprintXZ(): (number, number)
	local s = (WorldConfig.ISLANDS and WorldConfig.ISLANDS.SizeStuds) or 64
	if type(s) == "number" then
		return s, s
	end
	if typeof(s) == "Vector3" then
		return numberOr(s.X, 64), numberOr(s.Z, 64)
	end
	-- Vector2 or unknown
	local vx = (typeof(s) == "Vector2") and s.X or 64
	local vz = (typeof(s) == "Vector2") and s.Y or 64
	return numberOr(vx, 64), numberOr(vz, 64)
end

-- Clear a padded box around the pivot to Air, lay a flat slab with top at pivot Y,
-- then carve a vertical cylinder (Air) and fill slightly smaller with Water.
function TerrainIslandBuilder.buildIslandAt(pivotCF: CFrame)
	local islands = WorldConfig.ISLANDS or {}
	local pond = islands.Pond or {}

	local sizeX, sizeZ = getFootprintXZ()
    local heightY = numberOr(islands.HeightStuds, 16)
    local topSkin = math.max(0, numberOr(islands.TopSkinThickness, 2))

    -- Map materials safely with fallbacks
    local topMaterial = matFromString(islands.TopMaterial, Enum.Material.Ground)
    local coreMaterial = matFromString(islands.CoreMaterial, Enum.Material.Rock)

	local pondRadius = numberOr(pond.Radius, 10)
	local pondDepth = math.max(0, numberOr(pond.Depth, 8))
	local pondOffset = vec3Or(pond.Offset, Vector3.new())

	local pivotPos = pivotCF.Position
	local topY = pivotPos.Y

    -- Yaw-only rotation for slab and clear box so rotated pivot keeps bounds aligned
    local rx, ry, rz = pivotCF:ToOrientation()
    local yawCF = CFrame.new(0, 0, 0) * CFrame.Angles(0, ry, 0)

	-- 1) Clear padded region to Air (prevents accumulation across boots)
	do
		local padXZ = 32
		local padY = 24
		local clearX = sizeX + 2 * padXZ
		local clearZ = sizeZ + 2 * padXZ
		local clearY = (heightY + topSkin + pondDepth) + 2 * padY
		local clearCenterY = topY - (heightY + topSkin + pondDepth) * 0.5
		local clearCF = CFrame.new(Vector3.new(pivotPos.X, clearCenterY, pivotPos.Z)) * yawCF
		Terrain:FillBlock(clearCF, Vector3.new(clearX, clearY, clearZ), Enum.Material.Air)
	end

	-- 2) Core slab just below top cap; cap's top at pivot Y
	do
		local centerY = topY - topSkin - (heightY * 0.5)
		local slabCF = CFrame.new(Vector3.new(pivotPos.X, centerY, pivotPos.Z)) * yawCF
		Terrain:FillBlock(slabCF, Vector3.new(sizeX, heightY, sizeZ), coreMaterial)
	end

	-- 2.5) Thin top cap at the surface with chosen top material
	if topSkin > 0 then
		local capCenterY = topY - (topSkin * 0.5)
		local capCF = CFrame.new(Vector3.new(pivotPos.X, capCenterY, pivotPos.Z)) * yawCF
		Terrain:FillBlock(capCF, Vector3.new(sizeX, topSkin, sizeZ), topMaterial)
	end

    -- 3) Carve vertical shallow basin (Air) only; no Water fill
    if pondDepth > 0 and pondRadius > 0 then
        local pondCenterWorld = pivotCF:PointToWorldSpace(pondOffset)
        local cylCenterY = topY - (pondDepth * 0.5)
        local cylCF = CFrame.new(Vector3.new(pondCenterWorld.X, cylCenterY, pondCenterWorld.Z))

        -- Carve slightly larger radius to ensure a clean rim; leave empty (Air) for shallow dry basin
        local rimGap = 0.5
        Terrain:FillCylinder(cylCF, pondDepth, pondRadius + rimGap, Enum.Material.Air)
    end

    -- Decorations toggle (centralized guard)
    local decorEnabled = islands.EnableDecorations == true
    TerrainUtil.setTerrainDecorationEnabled(decorEnabled)

    print(("[Terrain] Sculpted flat slab size=%s height=%s top=%s pondR=%s pondD=%s decor=%s")
		:format(tostring(WorldConfig.ISLANDS.SizeStuds), tostring(heightY), tostring(topMaterial.Name), tostring(pondRadius), tostring(pondDepth), tostring(decorEnabled)))
end

return TerrainIslandBuilder
