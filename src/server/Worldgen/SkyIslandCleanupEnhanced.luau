-- SkyIslandCleanupEnhanced.luau
-- Comprehensive cleanup system for ALL sky island terrain and models
-- Handles multiple generation systems: SkyIslandGenerator, ScatteredSkyIslands, TerrainIslandBuilder

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local SkyIslandCleanupEnhanced = {}

-- Tags used by different systems
local TAGS = {
    "SkyIslandContent",      -- Main tag from SkyIslandGenerator
    "ScatteredSkyIsland",    -- Tag for ScatteredSkyIslands system
    "POI_Building",          -- POI buildings
    "PathSegment",           -- Path segments
}

-- Configuration
local CONFIG = {
    SPAWN_RADIUS = 200,           -- Protected spawn area radius
    TERRAIN_CLEAR_HEIGHT = 600,   -- Height range to clear terrain
    TERRAIN_CLEAR_RADIUS = 3000,  -- Horizontal radius to clear terrain
    CHUNK_SIZE = 512,             -- Size of terrain clearing chunks
    PRESERVE_SPAWN_BUFFER = 50,   -- Extra buffer around spawn area
}

-- Enhanced cleanup that handles ALL terrain types
function SkyIslandCleanupEnhanced.cleanupAll(worldConfig)
    print("[SkyIslandCleanup] ===== STARTING COMPREHENSIVE CLEANUP =====")
    local startTime = tick()
    
    local stats = {
        taggedModels = 0,
        terrainChunks = 0,
        preservedItems = 0
    }
    
    -- Update spawn radius from config if available
    local spawnRadius = CONFIG.SPAWN_RADIUS
    if worldConfig and worldConfig.HUB and worldConfig.HUB.Radius then
        spawnRadius = worldConfig.HUB.Radius
    end
    print(string.format("[SkyIslandCleanup] Using spawn radius: %d", spawnRadius))
    
    -- Step 0: Extract terrain regions BEFORE deleting markers
    print("[SkyIslandCleanup] ===== STEP 0: EXTRACTING TERRAIN REGIONS =====")
    local terrainRegions = SkyIslandCleanupEnhanced._extractTerrainRegions(spawnRadius)
    print(string.format("[SkyIslandCleanup] Step 0 complete: %d terrain regions extracted", #terrainRegions))
    
    -- Step 1: Remove all tagged models/folders
    print("[SkyIslandCleanup] ===== STEP 1: REMOVING TAGGED MODELS =====")
    stats.taggedModels = SkyIslandCleanupEnhanced._removeTaggedContent(spawnRadius)
    print(string.format("[SkyIslandCleanup] Step 1 complete: %d tagged models removed", stats.taggedModels))
    
    -- Step 2: Remove sky island folders even if not tagged
    print("[SkyIslandCleanup] ===== STEP 2: REMOVING SKY ISLAND FOLDERS =====")
    local folderCount = SkyIslandCleanupEnhanced._removeSkyIslandFolders(spawnRadius)
    stats.taggedModels = stats.taggedModels + folderCount
    print(string.format("[SkyIslandCleanup] Step 2 complete: %d folders removed", folderCount))
    
    -- Step 3: Clear terrain using extracted regions
    print("[SkyIslandCleanup] ===== STEP 3: CLEARING TERRAIN =====")
    stats.terrainChunks = SkyIslandCleanupEnhanced._clearExtractedTerrainRegions(terrainRegions)
    print(string.format("[SkyIslandCleanup] Step 3 complete: %d terrain regions cleared", stats.terrainChunks))
    
    -- Step 4: Clean up debug visualization
    print("[SkyIslandCleanup] ===== STEP 4: CLEANING DEBUG VISUALIZATION =====")
    SkyIslandCleanupEnhanced._clearDebugVisualization()
    print("[SkyIslandCleanup] Step 4 complete: debug visualization cleared")
    
    local elapsed = (tick() - startTime) * 1000
    print("[SkyIslandCleanup] ===== CLEANUP COMPLETE =====")
    print(string.format("[SkyIslandCleanup] Total time: %.1fms", elapsed))
    print(string.format("  - Tagged models removed: %d", stats.taggedModels))
    print(string.format("  - Terrain regions cleared: %d", stats.terrainChunks))
    print(string.format("  - Spawn area preserved (radius: %d)", spawnRadius))
    
    return stats
end

-- Remove all tagged content
function SkyIslandCleanupEnhanced._removeTaggedContent(spawnRadius)
    local removed = 0
    
    for _, tag in ipairs(TAGS) do
        local taggedItems = CollectionService:GetTagged(tag)
        print(string.format("[SkyIslandCleanup] Found %d items with tag '%s'", #taggedItems, tag))
        
        for _, item in ipairs(taggedItems) do
            if item and item.Parent then
                if SkyIslandCleanupEnhanced._isInSpawnArea(item, spawnRadius) then
                    print(string.format("[SkyIslandCleanup] Preserved spawn area item: %s (%s)", item.Name, tag))
                else
                    item:Destroy()
                    removed = removed + 1
                end
            end
        end
    end
    
    return removed
end

-- Extract terrain regions BEFORE deleting markers (to avoid losing the data)
function SkyIslandCleanupEnhanced._extractTerrainRegions(spawnRadius)
    local terrainRegions = {}
    
    print("[SkyIslandCleanup] Extracting terrain regions before marker deletion...")
    
    -- Find all terrain markers with stored regions
    local markersFolder = workspace:FindFirstChild("SkyConstellationMarkers")
    if not markersFolder then
        print("[SkyIslandCleanup] No terrain markers folder found for extraction!")
        return terrainRegions
    end
    
    local markerChildren = markersFolder:GetChildren()
    print(string.format("[SkyIslandCleanup] Found markers folder with %d children for extraction", #markerChildren))
    
    for i, marker in ipairs(markerChildren) do
        if marker:IsA("BasePart") then
            local pos = marker.Position
            local distanceFromSpawn = (Vector2.new(pos.X, pos.Z)).Magnitude
            
            -- Skip if too close to spawn
            if distanceFromSpawn <= spawnRadius + CONFIG.PRESERVE_SPAWN_BUFFER then
                print(string.format("[SkyIslandCleanup] Skipping spawn area marker: %s", marker.Name))
                continue
            end
            
            -- Get stored region data from marker attributes
            local regionMinX = marker:GetAttribute("RegionMinX")
            local regionMinY = marker:GetAttribute("RegionMinY") 
            local regionMinZ = marker:GetAttribute("RegionMinZ")
            local regionMaxX = marker:GetAttribute("RegionMaxX")
            local regionMaxY = marker:GetAttribute("RegionMaxY")
            local regionMaxZ = marker:GetAttribute("RegionMaxZ")
            
            local region = nil
            if regionMinX and regionMinY and regionMinZ and regionMaxX and regionMaxY and regionMaxZ then
                -- Use stored precise region
                region = Region3.new(
                    Vector3.new(regionMinX, regionMinY, regionMinZ),
                    Vector3.new(regionMaxX, regionMaxY, regionMaxZ)
                ):ExpandToGrid(4)
                print(string.format("[SkyIslandCleanup] Extracted precise region from %s: size=%s", marker.Name, tostring(region.Size)))
            else
                -- Fallback: create box region from radius with EXTRA padding to catch residue
                local radius = marker:GetAttribute("Radius") or 30
                local size = radius * 3 -- INCREASED: More generous fallback (was 2)
                region = Region3.new(
                    pos - Vector3.new(size/2, size/2, size/2),
                    pos + Vector3.new(size/2, size/2, size/2)
                ):ExpandToGrid(4)
                print(string.format("[SkyIslandCleanup] Extracted fallback region from %s: radius=%.1f, size=%.1f", marker.Name, radius, size))
            end
            
            if region then
                table.insert(terrainRegions, {
                    region = region,
                    position = pos,
                    markerName = marker.Name
                })
            end
        end
    end
    
    print(string.format("[SkyIslandCleanup] Extracted %d terrain regions for clearing", #terrainRegions))
    return terrainRegions
end

-- Clear terrain using pre-extracted regions
function SkyIslandCleanupEnhanced._clearExtractedTerrainRegions(terrainRegions)
    local terrain = workspace.Terrain
    local clearedRegions = 0
    
    print(string.format("[SkyIslandCleanup] Clearing %d extracted terrain regions...", #terrainRegions))
    
    for i, regionData in ipairs(terrainRegions) do
        local region = regionData.region
        local pos = regionData.position
        local markerName = regionData.markerName
        
        print(string.format("[SkyIslandCleanup] Clearing region %d/%d from %s at %s", i, #terrainRegions, markerName, tostring(pos)))
        
        -- Clear the terrain region
        local success, err = pcall(function()
            terrain:FillRegion(region, 4, Enum.Material.Air)
        end)
        
        if success then
            clearedRegions = clearedRegions + 1
            print(string.format("[SkyIslandCleanup] ✓ Cleared terrain region from %s", markerName))
        else
            print(string.format("[SkyIslandCleanup] ❌ Failed to clear terrain from %s: %s", markerName, tostring(err)))
        end
    end
    
    print(string.format("[SkyIslandCleanup] Terrain clearing complete: %d/%d regions cleared successfully", clearedRegions, #terrainRegions))
    return clearedRegions
end

-- Remove known sky island folders even if not tagged
function SkyIslandCleanupEnhanced._removeSkyIslandFolders(spawnRadius)
    local removed = 0
    local folderNames = {
        "SkyConstellations",
        "SkyConstellationMarkers", 
        "SkyElements",
        "FloatingPaths",
        "SkyIslands",
        "SkyIslandDebug"
    }
    
    for _, folderName in ipairs(folderNames) do
        local folder = workspace:FindFirstChild(folderName)
        if folder then
            -- Check if folder is in spawn area
            if folder:IsA("Model") and folder.PrimaryPart then
                if SkyIslandCleanupEnhanced._isInSpawnArea(folder.PrimaryPart, spawnRadius) then
                    print(string.format("[SkyIslandCleanup] Preserved spawn folder: %s", folderName))
                    continue
                end
            elseif folder:IsA("Folder") then
                -- For folders, check if any child parts are in spawn area
                local hasSpawnContent = false
                for _, child in ipairs(folder:GetDescendants()) do
                    if child:IsA("BasePart") and SkyIslandCleanupEnhanced._isInSpawnArea(child, spawnRadius) then
                        hasSpawnContent = true
                        break
                    end
                end
                if hasSpawnContent then
                    print(string.format("[SkyIslandCleanup] Preserved spawn folder: %s", folderName))
                    continue
                end
            end
            
            folder:Destroy()
            removed = removed + 1
            print(string.format("[SkyIslandCleanup] Removed sky island folder: %s", folderName))
        end
    end
    
    return removed
end

-- Precise terrain clearing using stored regions instead of chunked approach
function SkyIslandCleanupEnhanced._clearSkyTerrain(spawnRadius)
    local terrain = workspace.Terrain
    local clearedRegions = 0
    
    print("[SkyIslandCleanup] Clearing terrain using stored regions (spawn radius: " .. spawnRadius .. ")")
    
    -- Find all terrain markers with stored regions
    local markersFolder = workspace:FindFirstChild("SkyConstellationMarkers")
    if not markersFolder then
        print("[SkyIslandCleanup] No terrain markers folder found!")
        return 0
    end
    
    local markerChildren = markersFolder:GetChildren()
    print(string.format("[SkyIslandCleanup] Found markers folder with %d children", #markerChildren))
    
    for i, marker in ipairs(markerChildren) do
        print(string.format("[SkyIslandCleanup] Processing marker %d: %s (Type: %s)", i, marker.Name, marker.ClassName))
        
        if marker:IsA("BasePart") then
            local pos = marker.Position
            local distanceFromSpawn = (Vector2.new(pos.X, pos.Z)).Magnitude
            
            print(string.format("[SkyIslandCleanup] Marker at %s, distance from spawn: %.1f", tostring(pos), distanceFromSpawn))
            
            -- Skip if too close to spawn
            if distanceFromSpawn <= spawnRadius + CONFIG.PRESERVE_SPAWN_BUFFER then
                print(string.format("[SkyIslandCleanup] Preserved spawn area terrain at %s (too close)", tostring(pos)))
                continue
            end
            
            -- Get stored region data from marker attributes
            local regionMinX = marker:GetAttribute("RegionMinX")
            local regionMinY = marker:GetAttribute("RegionMinY") 
            local regionMinZ = marker:GetAttribute("RegionMinZ")
            local regionMaxX = marker:GetAttribute("RegionMaxX")
            local regionMaxY = marker:GetAttribute("RegionMaxY")
            local regionMaxZ = marker:GetAttribute("RegionMaxZ")
            
            print(string.format("[SkyIslandCleanup] Marker attributes - MinX: %s, MaxX: %s, Radius: %s", 
                tostring(regionMinX), tostring(regionMaxX), tostring(marker:GetAttribute("Radius"))))
            
            local region = nil
            if regionMinX and regionMinY and regionMinZ and regionMaxX and regionMaxY and regionMaxZ then
                -- Use stored precise region
                region = Region3.new(
                    Vector3.new(regionMinX, regionMinY, regionMinZ),
                    Vector3.new(regionMaxX, regionMaxY, regionMaxZ)
                ):ExpandToGrid(4)
                print(string.format("[SkyIslandCleanup] Using precise region: size=%s", tostring(region.Size)))
            else
                -- Fallback: create box region from radius
                local radius = marker:GetAttribute("Radius") or 30
                local size = radius * 2
                region = Region3.new(
                    pos - Vector3.new(size/2, size/2, size/2),
                    pos + Vector3.new(size/2, size/2, size/2)
                ):ExpandToGrid(4)
                print(string.format("[SkyIslandCleanup] Using fallback region: radius=%.1f, size=%s", radius, tostring(region.Size)))
            end
            
            -- Clear the terrain region
            local success, err = pcall(function()
                terrain:FillRegion(region, 4, Enum.Material.Air)
            end)
            
            if success then
                clearedRegions = clearedRegions + 1
                print(string.format("[SkyIslandCleanup] ✓ Cleared terrain region at %s", tostring(pos)))
            else
                print(string.format("[SkyIslandCleanup] ❌ Failed to clear terrain at %s: %s", tostring(pos), tostring(err)))
            end
        else
            print(string.format("[SkyIslandCleanup] Skipping non-part: %s", marker.Name))
        end
    end
    
    print(string.format("[SkyIslandCleanup] Terrain clearing complete: %d regions processed", clearedRegions))
    return clearedRegions
end

-- Clear debug visualization
function SkyIslandCleanupEnhanced._clearDebugVisualization()
    -- Remove debug parts that might not be in folders
    for _, item in ipairs(workspace:GetChildren()) do
        if item:IsA("BasePart") and (
            string.find(item.Name, "Debug_") or 
            string.find(item.Name, "SkyIsland") or
            string.find(item.Name, "PathDirection") or
            string.find(item.Name, "Marker_")
        ) then
            item:Destroy()
        end
    end
end

-- Check if an item is in the spawn area
function SkyIslandCleanupEnhanced._isInSpawnArea(item, spawnRadius)
    if not item:IsA("BasePart") then
        return false
    end
    
    local distance = (item.Position - Vector3.new(0, 0, 0)).Magnitude
    return distance < spawnRadius + CONFIG.PRESERVE_SPAWN_BUFFER
end

-- Quick cleanup function that focuses on models only (faster)
function SkyIslandCleanupEnhanced.quickCleanup(worldConfig)
    print("[SkyIslandCleanup] Starting quick cleanup (models only)...")
    local startTime = tick()
    
    local spawnRadius = CONFIG.SPAWN_RADIUS
    if worldConfig and worldConfig.HUB and worldConfig.HUB.Radius then
        spawnRadius = worldConfig.HUB.Radius
    end
    
    local removed = SkyIslandCleanupEnhanced._removeTaggedContent(spawnRadius)
    removed = removed + SkyIslandCleanupEnhanced._removeSkyIslandFolders(spawnRadius)
    SkyIslandCleanupEnhanced._clearDebugVisualization()
    
    local elapsed = (tick() - startTime) * 1000
    print(string.format("[SkyIslandCleanup] Quick cleanup complete in %.1fms - removed %d items", elapsed, removed))
    
    return { taggedModels = removed, terrainChunks = 0 }
end

-- Enhanced terrain-only cleanup for when models are already removed
function SkyIslandCleanupEnhanced.terrainOnlyCleanup(worldConfig)
    print("[SkyIslandCleanup] Starting terrain-only cleanup...")
    local startTime = tick()
    
    local spawnRadius = CONFIG.SPAWN_RADIUS
    if worldConfig and worldConfig.HUB and worldConfig.HUB.Radius then
        spawnRadius = worldConfig.HUB.Radius
    end
    
    local regions = SkyIslandCleanupEnhanced._clearSkyTerrain(spawnRadius)
    
    local elapsed = (tick() - startTime) * 1000
    print(string.format("[SkyIslandCleanup] Terrain cleanup complete in %.1fms - cleared %d regions", elapsed, regions))
    
    return { taggedModels = 0, terrainChunks = regions }
end

return SkyIslandCleanupEnhanced