-- ScatteredSkyIslands.luau (PATHS + ISLANDS SYSTEM)
-- Combines floating bridge paths with natural islands for accessible exploration
-- Floating bridges provide safe routes, natural islands add variety and height challenges

local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WorldConfig = require(RS:WaitForChild("Config"):WaitForChild("WorldConfig"))
local OrganicIslandBuilder = require(script.Parent:WaitForChild("OrganicIslandBuilder"))
local DiamondIslandBuilder = require(script.Parent:WaitForChild("DiamondIslandBuilder"))
local POIRegistry = require(RS:WaitForChild("Shared"):WaitForChild("POIRegistry"))

local ScatteredSkyIslands = {}
local currentHubPos: Vector3 = Vector3.new(0, 0, 0)

-- Import CollectionService for tagging
local CollectionService = game:GetService("CollectionService")
local SKY_ISLAND_TAG = "SkyIslandContent"
local SCATTERED_TAG = "ScatteredSkyIsland"

-- Tag any scattered sky island content for cleanup
local function tagScatteredContent(item, contentType)
    if not item then return end
    CollectionService:AddTag(item, SKY_ISLAND_TAG)
    CollectionService:AddTag(item, SCATTERED_TAG)
    item:SetAttribute("IsScatteredSkyIsland", true)
    if contentType then
        item:SetAttribute("ScatteredType", contentType)
    end
end

export type ElementType = "Tiny" | "Small" | "Medium" | "Large" | "POI" | "Path"

export type PathData = {
    position: Vector3,
    endPosition: Vector3,
    width: number,
    segments: number,
    direction: Vector3,
    type: "Path",
    model: Model?,
    visible: boolean,
}

export type IslandData = {
    position: Vector3,
    radius: number,
    height: number,
    type: ElementType,
    model: Model?,
    visible: boolean,
    terrainRadius: number?,
}

export type ElementData = PathData | IslandData

export type ScatteredConfig = {
    -- Generation bounds
    MinRadius: number?,      
    MaxRadius: number?,      
    MinHeight: number?,      
    MaxHeight: number?,      
    POIMinRadius: number?,   -- Minimum distance for POIs (800+ studs for better separation)
    
    -- Element distribution
    TinyIslandCount: number?,    
    SmallIslandCount: number?,   
    MediumIslandCount: number?,  
    LargeIslandCount: number?,   
    POICount: number?,
    PathSegmentCount: number?,   -- NEW: Number of path segments per tentacle
    
    -- Pattern control
    LayoutMode: string?,         -- "organic" | "tentacles" | "banded"
    TentacleCount: number?,      
    TentacleWidth: number?,      
    TentacleTaper: number?,      
    OrganicClumping: number?,    
    
    -- Path configuration
    PathWidth: number?,          -- Width of floating bridges
    PathLength: number?,         -- Length of each path segment
    PathHeightVariation: number?, -- Height variation for paths
    
    -- Island configuration  
    IslandHeightVariation: number?, -- NEW: More height variation for obby feel
    IslandSpacing: number?,         -- NEW: Better spacing between islands
    
    -- Performance
    RenderDistance: number?,     
    LowLODDistance: number?,     
    UsePartIslands: boolean?,    
    
    Seed: number?,
}

-- Enhanced default configuration
local DEFAULT_CONFIG: ScatteredConfig = {
    MinRadius = 300,          
    POIMinRadius = 800,       -- INCREASED: Better POI separation
    MaxRadius = 2500,         -- INCREASED: More exploration space
    MinHeight = 50,           
    MaxHeight = 300,          
    
    -- Reduced island counts for better spacing
    TinyIslandCount = 80,     -- REDUCED: Less cluttered
    SmallIslandCount = 25,    
    MediumIslandCount = 10,   
    LargeIslandCount = 6,     
    POICount = 3,             
    PathSegmentCount = 8,     -- NEW: Path segments per tentacle
    
    LayoutMode = "tentacles",
    TentacleCount = 4,        
    TentacleWidth = 200,      -- INCREASED: Wider tentacles for paths
    TentacleTaper = 0.7,      
    OrganicClumping = 0.3,    
    
    -- NEW: Path configuration (WIDER BRIDGES)
    PathWidth = 16,           -- INCREASED: Wider floating bridges (was 8)
    PathLength = 80,          -- INCREASED: Longer bridge segments (was 60)
    PathHeightVariation = 15, -- Height variation for paths
    
    -- NEW: Island configuration
    IslandHeightVariation = 25, -- More dramatic height differences
    IslandSpacing = 50,         -- Better spacing between islands
    
    RenderDistance = 1000,    
    LowLODDistance = 500,     
    UsePartIslands = true,    -- USE PARTS: For floating bridges (terrain islands always created)
    
    Seed = 12345,
}

-- Island configurations with better spacing
local ISLAND_CONFIGS = {
    Tiny = { 
        radius = {8, 15}, 
        height = {4, 8}, 
        terrainRadius = {25, 35},  -- INCREASED: Better collision detection
        heightVariation = {-8, 12}, -- NEW: Height offset range
    },        
    Small = { 
        radius = {18, 25}, 
        height = {6, 12}, 
        terrainRadius = {40, 55},
        heightVariation = {-12, 18},
    },     
    Medium = { 
        radius = {30, 45}, 
        height = {8, 16}, 
        terrainRadius = {60, 85},
        heightVariation = {-15, 25},
    },    
    Large = { 
        radius = {50, 75}, 
        height = {10, 20}, 
        terrainRadius = {90, 125},
        heightVariation = {-20, 30},
    },    
    POI = { 
        radius = {80, 120}, 
        height = {12, 24}, 
        terrainRadius = {140, 200}, -- MUCH LARGER: No POI overlaps
        heightVariation = {-10, 40},
    },     
}

local activeElements: {ElementData} = {}
local spatialGrid: {[string]: {ElementData}} = {}
local GRID_SIZE = 40

-- Element priority system
local ELEMENT_PRIORITY = {
    Path = 6,    -- Highest priority - paths get best placement
    POI = 5,
    Large = 4,
    Medium = 3,
    Small = 2,
    Tiny = 1,
}

-- Utility: compute Y with height variation
local function computeYAtRadius(rand: Random, radius: number, minR: number, maxR: number, heightVariation: {number}?)
    local baseY = currentHubPos.Y
    
    if heightVariation then
        local heightOffset = rand:NextNumber(heightVariation[1], heightVariation[2])
        return baseY + heightOffset
    end
    
    -- Fallback to existing logic
    local useRel = (WorldConfig.WORLDGEN and WorldConfig.WORLDGEN.SkyIslands and WorldConfig.WORLDGEN.SkyIslands.UseRelativeHeights) == true
    if useRel then
        local cfg = WorldConfig.WORLDGEN.SkyIslands
        local s = if maxR > minR then (radius - minR) / (maxR - minR) else 0
        s = math.clamp(s, 0, 1)
        local offMin = cfg.HeightOffsetMin or -12
        local offMax = cfg.HeightOffsetMax or 6
        local jitter = cfg.HeightJitter or 3
        local offset = offMin + (offMax - offMin) * s + rand:NextNumber(-jitter, jitter)
        return baseY + offset
    else
        local minH = (WorldConfig.WORLDGEN and WorldConfig.WORLDGEN.SkyIslands and WorldConfig.WORLDGEN.SkyIslands.MinHeight) or DEFAULT_CONFIG.MinHeight
        local maxH = (WorldConfig.WORLDGEN and WorldConfig.WORLDGEN.SkyIslands and WorldConfig.WORLDGEN.SkyIslands.MaxHeight) or DEFAULT_CONFIG.MaxHeight
        return rand:NextNumber(minH, maxH)
    end
end

-- Add element to spatial grid
local function addToSpatialGrid(element: ElementData)
    local gridX = math.floor(element.position.X / GRID_SIZE)
    local gridZ = math.floor(element.position.Z / GRID_SIZE)
    local key = gridX .. "," .. gridZ
    
    if not spatialGrid[key] then
        spatialGrid[key] = {}
    end
    table.insert(spatialGrid[key], element)
end

-- Remove element from spatial grid and activeElements
local function removeElement(elementToRemove: ElementData)
    local gridX = math.floor(elementToRemove.position.X / GRID_SIZE)
    local gridZ = math.floor(elementToRemove.position.Z / GRID_SIZE)
    local key = gridX .. "," .. gridZ
    local nearby = spatialGrid[key]
    if nearby then
        for j = #nearby, 1, -1 do
            if nearby[j] == elementToRemove then
                table.remove(nearby, j)
                break
            end
        end
    end
    
    for k = #activeElements, 1, -1 do
        if activeElements[k] == elementToRemove then
            table.remove(activeElements, k)
            break
        end
    end
end

-- Enhanced placement validation with proper conflict resolution
local function canPlaceWithOverwrite(pos: Vector3, element: ElementData, config: ScatteredConfig): boolean
    local distance = (Vector2.new(pos.X, pos.Z) - Vector2.new(currentHubPos.X, currentHubPos.Z)).Magnitude
    
    -- Check POI minimum distance constraint
    if element.type == "POI" then
        local poiMinRadius = config.POIMinRadius or DEFAULT_CONFIG.POIMinRadius
        if distance < poiMinRadius then
            return false
        end
    end
    
    local gridX = math.floor(pos.X / GRID_SIZE)
    local gridZ = math.floor(pos.Z / GRID_SIZE)
    
    local elementsToRemove = {}
    local blocked = false
    
    -- Calculate collision radius based on element type
    local checkRadius = 0
    if element.type == "Path" then
        local pathData = element :: PathData
        checkRadius = pathData.width * 2 -- Paths need more space
    else
        local islandData = element :: IslandData
        checkRadius = islandData.terrainRadius or islandData.radius
    end
    
    -- Check collision area
    for dx = -3, 3 do
        for dz = -3, 3 do
            local key = (gridX + dx) .. "," .. (gridZ + dz)
            local nearby = spatialGrid[key]
            if nearby then
                for _, existingElement in ipairs(nearby) do
                    local elementDist = (pos - existingElement.position).Magnitude
                    
                    local existingRadius = 0
                    if existingElement.type == "Path" then
                        local existingPath = existingElement :: PathData
                        existingRadius = existingPath.width * 2
                    else
                        local existingIsland = existingElement :: IslandData
                        existingRadius = existingIsland.terrainRadius or existingIsland.radius
                    end
                    
                    local spacing = config.IslandSpacing or DEFAULT_CONFIG.IslandSpacing
                    local minDist = checkRadius + existingRadius + spacing
                    
                    if elementDist < minDist then
                        -- Check priority for overwriting
                        if ELEMENT_PRIORITY[element.type] > ELEMENT_PRIORITY[existingElement.type] then
                            table.insert(elementsToRemove, existingElement)
                        else
                            blocked = true
                        end
                    end
                end
            end
        end
    end
    
    if blocked then
        return false
    end
    
    -- Remove conflicting elements
    for _, elementToRemove in ipairs(elementsToRemove) do
        removeElement(elementToRemove)
        print(string.format("  [Overwrite] %s overwriting %s", element.type, elementToRemove.type))
    end
    
    return true
end

-- Create floating bridge path model
local function createPathModel(pathData: PathData, parent: Instance): Model
    local model = Instance.new("Model")
    model.Name = string.format("FloatingBridge_%d", tick())
    model.Parent = parent
    
    -- Tag the bridge model for cleanup
    tagScatteredContent(model, "FloatingBridge")
    
    local segments = pathData.segments
    local direction = pathData.direction.Unit
    local segmentLength = pathData.width -- Each segment is roughly square
    
    for i = 1, segments do
        local segmentPos = pathData.position + direction * segmentLength * (i - 1)
        
        -- Main bridge segment
        local segment = Instance.new("Part")
        segment.Name = "BridgeSegment_" .. i
        segment.Size = Vector3.new(pathData.width, 2, pathData.width)
        segment.Position = segmentPos
        segment.Anchored = true
        segment.Material = Enum.Material.Wood
        segment.BrickColor = BrickColor.new("Dark orange")
        segment.Parent = model
        
        -- Add railings for safety
        for side = -1, 1, 2 do
            local railing = Instance.new("Part")
            railing.Name = "Railing_" .. i .. "_" .. side
            railing.Size = Vector3.new(0.5, 3, pathData.width)
            railing.Position = segmentPos + Vector3.new(side * pathData.width/2, 1.5, 0)
            railing.Anchored = true
            railing.Material = Enum.Material.Wood
            railing.BrickColor = BrickColor.new("Brown")
            railing.Parent = model
        end
    end
    
    return model
end

-- Create terrain island (same as before but with height variation and markers)
local function createTerrainIsland(island: IslandData)
    local topPos = island.position
    local radius = island.terrainRadius or island.radius
    local height = math.max(4, island.height)
    
    -- Material selection based on island type
    local topMaterial, coreMaterial
    if island.type == "POI" then
        topMaterial = Enum.Material.Neon
        coreMaterial = Enum.Material.Neon
    elseif island.type == "Large" then
        topMaterial = Enum.Material.Ground
        coreMaterial = Enum.Material.Rock
    elseif island.type == "Medium" then
        topMaterial = Enum.Material.Sand
        coreMaterial = Enum.Material.Sandstone
    elseif island.type == "Small" then
        topMaterial = Enum.Material.Sand
        coreMaterial = Enum.Material.Sandstone
    else -- Tiny
        topMaterial = Enum.Material.Ground
        coreMaterial = Enum.Material.Rock
    end
    
    -- Build diamond island with flat top
    DiamondIslandBuilder.buildAt(topPos, radius, height, {
        topSkin = 2,
        topMaterial = topMaterial,
        coreMaterial = coreMaterial,
    })
    
    -- Register POI for dev teleport
    if island.type == "POI" then
        pcall(function()
            POIRegistry.add(topPos)
        end)
    end
    -- Create terrain marker for cleanup with precise region
    local markersFolder = workspace:FindFirstChild("SkyConstellationMarkers")
    if not markersFolder then
        markersFolder = Instance.new("Folder")
        markersFolder.Name = "SkyConstellationMarkers"
        markersFolder.Parent = workspace
        tagScatteredContent(markersFolder, "MarkersFolder")
    end
    
    -- Calculate precise bounding box for the diamond island with extra padding
    local size = radius * 6 -- INCREASED: More generous bounds for diamond shapes (was 4)
    local preciseRegion = Region3.new(
        topPos - Vector3.new(size/2, size/2, size/2),
        topPos + Vector3.new(size/2, size/2, size/2)
    )
    
    local marker = Instance.new("Part")
    marker.Name = string.format("ScatteredIsland_%s_%d", island.type, tick())
    marker.Anchored = true
    marker.CanCollide = false
    marker.Transparency = 1
    marker.Size = Vector3.new(1, 1, 1)
    marker.Position = topPos
    marker.Parent = markersFolder
    marker:SetAttribute("IsScatteredIsland", true)
    marker:SetAttribute("IslandType", island.type)
    marker:SetAttribute("Radius", radius)
    
    -- Store precise region bounds for box-based clearing
    local min, max = preciseRegion.CFrame.Position - preciseRegion.Size/2, preciseRegion.CFrame.Position + preciseRegion.Size/2
    marker:SetAttribute("RegionMinX", min.X)
    marker:SetAttribute("RegionMinY", min.Y)
    marker:SetAttribute("RegionMinZ", min.Z)
    marker:SetAttribute("RegionMaxX", max.X)
    marker:SetAttribute("RegionMaxY", max.Y)
    marker:SetAttribute("RegionMaxZ", max.Z)
    
    tagScatteredContent(marker, "TerrainMarker")
    
    print(string.format("[ScatteredSkyIslands] Created %s island with precise region: %s", island.type, tostring(preciseRegion.Size)))
end

-- PATHS + ISLANDS: Generate tentacles with mixed floating bridges and natural islands
local function generateTentacles(rng: Random, config: ScatteredConfig)
    local minR = config.MinRadius or DEFAULT_CONFIG.MinRadius
    local maxR = config.MaxRadius or DEFAULT_CONFIG.MaxRadius
    local tentacleCount = config.TentacleCount or DEFAULT_CONFIG.TentacleCount
    local baseWidth = config.TentacleWidth or DEFAULT_CONFIG.TentacleWidth
    
    -- Element counts
    local remaining = {
        POI = config.POICount or DEFAULT_CONFIG.POICount,
        Large = config.LargeIslandCount or DEFAULT_CONFIG.LargeIslandCount,
        Medium = config.MediumIslandCount or DEFAULT_CONFIG.MediumIslandCount,
        Small = config.SmallIslandCount or DEFAULT_CONFIG.SmallIslandCount,
        Tiny = config.TinyIslandCount or DEFAULT_CONFIG.TinyIslandCount,
        Path = config.PathSegmentCount or DEFAULT_CONFIG.PathSegmentCount,
    }
    
    -- Generate tentacle angles
    local tentacleAngles = {}
    local baseAngleOffset = rng:NextNumber(0, 2 * math.pi)
    local angleStep = (2 * math.pi) / tentacleCount
    
    for t = 1, tentacleCount do
        local angle = baseAngleOffset + (t - 1) * angleStep
        angle = angle + rng:NextNumber(-angleStep * 0.1, angleStep * 0.1)
        table.insert(tentacleAngles, angle)
    end
    
    -- PRIORITY ORDER: Paths first (for good placement), then islands, POIs last
    local generationOrder = {"Path", "Tiny", "Small", "Medium", "Large", "POI"}
    
    for _, elementType in ipairs(generationOrder) do
        local typeRemaining = remaining[elementType]
        if typeRemaining <= 0 then continue end
        
        print(string.format("[ScatteredSkyIslands] Placing %d %s elements (priority %d)...", typeRemaining, elementType, ELEMENT_PRIORITY[elementType]))
        
        if elementType == "Path" then
            -- Generate floating bridge paths
            local pathsPerTentacle = math.ceil(typeRemaining / tentacleCount)
            
            for t = 1, tentacleCount do
                local tentacleAngle = tentacleAngles[t]
                local direction = Vector3.new(math.cos(tentacleAngle), 0, math.sin(tentacleAngle))
                
                -- Place paths at specific intervals along tentacle
                for p = 1, pathsPerTentacle do
                    if remaining.Path <= 0 then break end
                    
                    -- Space paths along tentacle length
                    local pathProgress = p / (pathsPerTentacle + 1)
                    local pathDist = minR + (maxR - minR) * pathProgress
                    
                    -- Skip if too close to spawn
                    if pathDist < minR + 100 then continue end
                    
                    local pathWidth = config.PathWidth or DEFAULT_CONFIG.PathWidth
                    local pathLength = config.PathLength or DEFAULT_CONFIG.PathLength
                    local pathHeightVar = config.PathHeightVariation or DEFAULT_CONFIG.PathHeightVariation
                    
                    local startPos = currentHubPos + direction * pathDist
                    startPos = Vector3.new(startPos.X, currentHubPos.Y + rng:NextNumber(-pathHeightVar, pathHeightVar), startPos.Z)
                    
                    local endPos = startPos + direction * pathLength
                    local segments = math.ceil(pathLength / pathWidth)
                    
                    local pathData: PathData = {
                        position = startPos,
                        endPosition = endPos,
                        width = pathWidth,
                        segments = segments,
                        direction = direction,
                        type = "Path",
                        model = nil,
                        visible = false,
                    }
                    
                    if canPlaceWithOverwrite(startPos, pathData, config) then
                        table.insert(activeElements, pathData)
                        addToSpatialGrid(pathData)
                        remaining.Path -= 1
                    end
                end
            end
            
        elseif elementType == "POI" then
            -- POIs: Clean positioning at tentacle ends
            local poisPerTentacle = math.ceil(typeRemaining / tentacleCount)
            
            for t = 1, tentacleCount do
                local tentacleAngle = tentacleAngles[t]
                
                for p = 1, poisPerTentacle do
                    if remaining.POI <= 0 then break end
                    
                    local poiMinRadius = config.POIMinRadius or DEFAULT_CONFIG.POIMinRadius
                    local effectiveMinR = math.max(minR, poiMinRadius)
                    local poiDist = effectiveMinR + (maxR - effectiveMinR) * (0.8 + 0.15 * (p - 1) / math.max(1, poisPerTentacle - 1))
                    
                    local x = currentHubPos.X + math.cos(tentacleAngle) * poiDist
                    local z = currentHubPos.Z + math.sin(tentacleAngle) * poiDist
                    
                    local sizeConfig = ISLAND_CONFIGS.POI
                    local y = computeYAtRadius(rng, poiDist, minR, maxR, sizeConfig.heightVariation)
                    
                    local pos = Vector3.new(x, y, z)
                    local radius = rng:NextNumber(sizeConfig.radius[1], sizeConfig.radius[2])
                    local height = rng:NextNumber(sizeConfig.height[1], sizeConfig.height[2])
                    local terrainRadius = rng:NextNumber(sizeConfig.terrainRadius[1], sizeConfig.terrainRadius[2])
                    
                    local island: IslandData = {
                        position = pos,
                        radius = radius,
                        height = height,
                        type = "POI",
                        model = nil,
                        visible = false,
                        terrainRadius = terrainRadius,
                    }
                    
                    if canPlaceWithOverwrite(pos, island, config) then
                        table.insert(activeElements, island)
                        addToSpatialGrid(island)
                        remaining.POI -= 1
                    end
                end
            end
            
        else -- Regular islands (Tiny, Small, Medium, Large)
            local islandsPerTentacle = math.ceil(typeRemaining / tentacleCount)
            
            for t = 1, tentacleCount do
                local tentacleAngle = tentacleAngles[t]
                local curvature = rng:NextNumber(-0.03, 0.03)
                
                -- Distribute islands along tentacle with better spacing
                for i = 1, islandsPerTentacle do
                    if remaining[elementType] <= 0 then break end
                    
                    local progress = i / islandsPerTentacle
                    local currentDist = minR + (maxR - minR) * progress
                    
                    -- Skip areas with paths (rough check)
                    local skipForPath = false
                    for _, element in ipairs(activeElements) do
                        if element.type == "Path" then
                            local pathElement = element :: PathData
                            local distToPath = (Vector2.new(currentDist * math.cos(tentacleAngle), currentDist * math.sin(tentacleAngle)) - 
                                             Vector2.new(pathElement.position.X - currentHubPos.X, pathElement.position.Z - currentHubPos.Z)).Magnitude
                            if distToPath < 80 then
                                skipForPath = true
                                break
                            end
                        end
                    end
                    
                    if skipForPath then continue end
                    
                    local tentacleProgress = (currentDist - minR) / (maxR - minR)
                    local currentWidth = baseWidth * (1 - 0.3 * tentacleProgress)
                    
                    local curvedAngle = tentacleAngle + curvature * tentacleProgress
                    local lateralOffset = rng:NextNumber(-currentWidth/2, currentWidth/2)
                    local perpAngle = curvedAngle + math.pi/2
                    
                    local x = currentHubPos.X + math.cos(curvedAngle) * currentDist + math.cos(perpAngle) * lateralOffset
                    local z = currentHubPos.Z + math.sin(curvedAngle) * currentDist + math.sin(perpAngle) * lateralOffset
                    
                    local sizeConfig = ISLAND_CONFIGS[elementType]
                    local y = computeYAtRadius(rng, currentDist, minR, maxR, sizeConfig.heightVariation)
                    
                    local pos = Vector3.new(x, y, z)
                    local radius = rng:NextNumber(sizeConfig.radius[1], sizeConfig.radius[2])
                    local height = rng:NextNumber(sizeConfig.height[1], sizeConfig.height[2])
                    local terrainRadius = rng:NextNumber(sizeConfig.terrainRadius[1], sizeConfig.terrainRadius[2])
                    
                    local island: IslandData = {
                        position = pos,
                        radius = radius,
                        height = height,
                        type = elementType,
                        model = nil,
                        visible = false,
                        terrainRadius = terrainRadius,
                    }
                    
                    if canPlaceWithOverwrite(pos, island, config) then
                        table.insert(activeElements, island)
                        addToSpatialGrid(island)
                        remaining[elementType] -= 1
                    end
                end
            end
        end
        
        print(string.format("[ScatteredSkyIslands] Placed %s elements: %d remaining, total elements: %d", elementType, remaining[elementType], #activeElements))
    end
    
    print(string.format("[ScatteredSkyIslands] Generated %d tentacles with %d total elements", tentacleCount, #activeElements))
end

-- Main generation function
function ScatteredSkyIslands.generate(rootFolder: Instance, hubPos: Vector3, config: ScatteredConfig?)
    local finalConfig = config or {}
    currentHubPos = hubPos
    
    -- Apply defaults
    for key, value in pairs(DEFAULT_CONFIG) do
        if finalConfig[key] == nil then
            finalConfig[key] = value
        end
    end
    
    -- Clear existing data
    activeElements = {}
    -- Clear POI registry on regeneration
    pcall(function() POIRegistry.clear() end)
    spatialGrid = {}
    
    local rng = Random.new(finalConfig.Seed)
    
    print("[ScatteredSkyIslands] Starting PATHS + ISLANDS generation...")
    
    -- Generate tentacles with mixed paths and islands
    generateTentacles(rng, finalConfig)
    
    -- Create elements folder
    local elementsFolder = rootFolder:FindFirstChild("SkyElements") or Instance.new("Folder")
    elementsFolder.Name = "SkyElements"
    elementsFolder.Parent = rootFolder
    tagScatteredContent(elementsFolder, "ElementsRoot")
    
    local pathsFolder = Instance.new("Folder")
    pathsFolder.Name = "FloatingPaths"
    pathsFolder.Parent = elementsFolder
    tagScatteredContent(pathsFolder, "PathsFolder")
    
    local islandsFolder = Instance.new("Folder")
    islandsFolder.Name = "SkyIslands" 
    islandsFolder.Parent = elementsFolder
    tagScatteredContent(islandsFolder, "IslandsFolder")
    
    print(string.format("[ScatteredSkyIslands] Generated %d total elements", #activeElements))
    
    -- Create elements based on type
    local pathCount = 0
    local islandCount = 0
    
    for _, element in ipairs(activeElements) do
        if element.type == "Path" then
            local pathData = element :: PathData
            pathData.model = createPathModel(pathData, pathsFolder)
            pathData.visible = true
            pathCount += 1
        else
            local islandData = element :: IslandData
            if not finalConfig.UsePartIslands then
                createTerrainIsland(islandData)
            end
            islandData.visible = true
            islandCount += 1
        end
    end
    
    print(string.format("[ScatteredSkyIslands] Created %d floating bridges and %d terrain islands", pathCount, islandCount))
    
    -- Extract just the islands for backwards compatibility
    local islandsOnly = {}
    for _, element in ipairs(activeElements) do
        if element.type ~= "Path" then
            table.insert(islandsOnly, element)
        end
    end
    
    return {
        elements = activeElements,     -- NEW: All elements (paths + islands)
        islands = islandsOnly,         -- BACKWARDS COMPATIBLE: Just the islands
        spatialGrid = spatialGrid,
        config = finalConfig,
        totalCount = #activeElements,
        pathCount = pathCount,
        islandCount = islandCount,
    }
end

-- Get elements data
function ScatteredSkyIslands.getElements()
    return activeElements
end

-- Enhanced debug visualization
function ScatteredSkyIslands.debugVisualize()
    for i, element in ipairs(activeElements) do
        local part = Instance.new("Part")
        part.Name = "Debug_" .. element.type .. "_" .. i
        part.Size = Vector3.new(6, 6, 6)
        part.Position = element.position + Vector3.new(0, 15, 0)
        part.Anchored = true
        part.CanCollide = false
        part.Transparency = 0.3
        
        -- Color by type
        local colors = {
            Path = BrickColor.new("Bright violet"),   -- Priority 6
            POI = BrickColor.new("Bright blue"),      -- Priority 5
            Large = BrickColor.new("Bright green"),   -- Priority 4
            Medium = BrickColor.new("Bright yellow"), -- Priority 3
            Small = BrickColor.new("Bright orange"),  -- Priority 2
            Tiny = BrickColor.new("Bright red"),      -- Priority 1
        }
        part.BrickColor = colors[element.type] or BrickColor.new("White")
        part.Parent = workspace
        
        -- Add direction indicator for paths
        if element.type == "Path" then
            local pathData = element :: PathData
            local arrow = Instance.new("Part")
            arrow.Name = "PathDirection"
            arrow.Size = Vector3.new(2, 1, 10)
            arrow.Position = element.position + pathData.direction * 20 + Vector3.new(0, 15, 0)
            arrow.CFrame = CFrame.lookAt(arrow.Position, arrow.Position + pathData.direction)
            arrow.Anchored = true
            arrow.CanCollide = false
            arrow.Transparency = 0.5
            arrow.BrickColor = BrickColor.new("Really black")
            arrow.Parent = workspace
        end
        
        -- Add text label
        local gui = Instance.new("BillboardGui")
        gui.Size = UDim2.new(0, 100, 0, 50)
        gui.Adornee = part
        gui.Parent = part
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = string.format("%s\\nP%d", element.type, ELEMENT_PRIORITY[element.type])
        label.TextColor3 = Color3.new(1, 1, 1)
        label.TextStrokeTransparency = 0
        label.TextScaled = true
        label.Parent = gui
    end
    
    print(string.format("[ScatteredSkyIslands] Debug visualization: %d elements with paths + islands system", #activeElements))
end

return ScatteredSkyIslands
