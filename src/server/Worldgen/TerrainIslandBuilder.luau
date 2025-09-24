-- TerrainIslandBuilder
-- Clear -> flat rock slab (top at pivot Y) -> vertical pond carve (Air) -> water fill
-- Idempotent across boots via padded Air clear region.
-- Enhanced with terrain marking for cleanup

local TerrainIslandBuilder = {}

local Terrain = workspace.Terrain
local RS = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local WorldConfig = require(RS.Config.WorldConfig)
local TerrainUtil = require(RS.Shared.TerrainUtil)
local UnifiedCarvingUtil = require(RS.Shared.UnifiedCarvingUtil)

-- Sky island content tag for cleanup
local SKY_ISLAND_TAG = "SkyIslandContent"

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

-- Create a terrain marker for cleanup tracking with precise bounds
local function createTerrainMarker(position: Vector3, radius: number, islandType: string?, preciseRegion: Region3?)
    local markersFolder = workspace:FindFirstChild("SkyConstellationMarkers")
    if not markersFolder then
        markersFolder = Instance.new("Folder")
        markersFolder.Name = "SkyConstellationMarkers"
        markersFolder.Parent = workspace
        CollectionService:AddTag(markersFolder, SKY_ISLAND_TAG)
    end
    
    local marker = Instance.new("Part")
    marker.Name = string.format("TerrainMarker_%s_%d", islandType or "Island", tick())
    marker.Anchored = true
    marker.CanCollide = false
    marker.Transparency = 1
    marker.Size = Vector3.new(1, 1, 1)
    marker.Position = position
    marker.Parent = markersFolder
    marker:SetAttribute("IsConstellation", true)
    marker:SetAttribute("Kind", islandType or "TerrainIsland")
    marker:SetAttribute("Radius", radius)
    
    -- Store precise region bounds for box-based clearing
    if preciseRegion then
        local min, max = preciseRegion.CFrame.Position - preciseRegion.Size/2, preciseRegion.CFrame.Position + preciseRegion.Size/2
        marker:SetAttribute("RegionMinX", min.X)
        marker:SetAttribute("RegionMinY", min.Y)
        marker:SetAttribute("RegionMinZ", min.Z)
        marker:SetAttribute("RegionMaxX", max.X)
        marker:SetAttribute("RegionMaxY", max.Y)
        marker:SetAttribute("RegionMaxZ", max.Z)
        print(string.format("[TerrainMarker] Stored precise region: min=%s max=%s", tostring(min), tostring(max)))
    end
    
    CollectionService:AddTag(marker, SKY_ISLAND_TAG)
    
    return marker
end

-- Clear a padded box around the pivot to Air, lay a flat slab with top at pivot Y,
-- then carve a vertical cylinder (Air) and fill slightly smaller with Water.
function TerrainIslandBuilder.buildIslandAt(pivotCF: CFrame, islandType: string?)
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

    -- 3) Carve vertical shallow basin using unified carving for consistency
    if pondDepth > 0 and pondRadius > 0 then
        local pondCenterWorld = pivotCF:PointToWorldSpace(pondOffset)
        local sculptCenter = Vector3.new(pondCenterWorld.X, topY - (pondDepth * 0.5), pondCenterWorld.Z)
        
        -- Use unified carving for consistent bowl shape with default and dynamic ponds
        UnifiedCarvingUtil.carveBowl(sculptCenter, pondRadius, pondDepth, UnifiedCarvingUtil.getDefaultBowlParams())
    end

    -- Decorations toggle (centralized guard)
    local decorEnabled = islands.EnableDecorations == true
    TerrainUtil.setTerrainDecorationEnabled(decorEnabled)
    
    -- Create terrain marker for cleanup (IMPORTANT for removal!)
    -- Calculate precise region that encompasses all terrain operations with generous padding
    local clearPadXZ = 48 -- INCREASED: More generous padding (was 32)
    local clearPadY = 36 -- INCREASED: More generous padding (was 24)
    local totalXZ = math.max(sizeX + 2 * clearPadXZ, (pondRadius * 2) + clearPadXZ)
    local totalY = (heightY + topSkin + pondDepth) + 2 * clearPadY
    
    -- Create precise bounding box for the entire island
    local regionMin = Vector3.new(
        pivotPos.X - totalXZ/2,
        topY - totalY,
        pivotPos.Z - totalXZ/2
    )
    local regionMax = Vector3.new(
        pivotPos.X + totalXZ/2,
        topY + clearPadY,
        pivotPos.Z + totalXZ/2
    )
    local preciseRegion = Region3.new(regionMin, regionMax)
    
    createTerrainMarker(pivotPos, totalXZ/2, islandType, preciseRegion)

    print(("[Terrain] Sculpted flat slab size=%s height=%s top=%s pondR=%s pondD=%s decor=%s region=%s")
		:format(tostring(WorldConfig.ISLANDS.SizeStuds), tostring(heightY), tostring(topMaterial.Name), tostring(pondRadius), tostring(pondDepth), tostring(decorEnabled), tostring(preciseRegion.Size)))
end

-- Enhanced version that creates terrain markers for all islands
function TerrainIslandBuilder.buildIslandAtWithMarker(pivotCF: CFrame, islandType: string, customRadius: number?)
    TerrainIslandBuilder.buildIslandAt(pivotCF, islandType)
    
    -- Additional marker if custom radius specified
    if customRadius then
        createTerrainMarker(pivotCF.Position, customRadius, islandType .. "_Custom")
    end
end

return TerrainIslandBuilder
