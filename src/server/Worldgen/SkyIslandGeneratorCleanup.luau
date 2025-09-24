-- SkyIslandGeneratorCleanup.luau
-- Tag-based cleanup function for SkyIslandGenerator (EXTERNAL VERSION)

local CollectionService = game:GetService("CollectionService")

-- Universal tag for all sky island content
local SKY_ISLAND_TAG = "SkyIslandContent"

-- External cleanup function that can be called independently
function SkyIslandGeneratorCleanup(skyIslandGenerator)
    print("[SkyIslandGeneratorCleanup] Starting external tag-based cleanup...")
    
    local startTime = tick()
    local cleanupStats = {
        taggedItems = 0,
        terrainRegions = 0
    }
    
    -- Step 1: Remove ALL tagged constellation content
    local taggedItems = CollectionService:GetTagged(SKY_ISLAND_TAG)
    cleanupStats.taggedItems = #taggedItems
    
    print(string.format("[SkyIslandGeneratorCleanup] Found %d tagged items for removal", cleanupStats.taggedItems))
    
    -- Get spawn radius from generator config or use default
    local spawnRadius = 200
    if skyIslandGenerator and skyIslandGenerator.worldConfig then
        spawnRadius = (skyIslandGenerator.worldConfig.HUB and skyIslandGenerator.worldConfig.HUB.Radius) or 200
    end
    
    for _, item in ipairs(taggedItems) do
        if item and item.Parent then
            -- Preserve spawn area items
            local isInSpawn = false
            if item:IsA("BasePart") then
                local distanceFromSpawn = (item.Position - Vector3.new(0, 0, 0)).Magnitude
                isInSpawn = distanceFromSpawn < spawnRadius
            end
            
            if not isInSpawn then
                item:Destroy()
            else
                print(string.format("[SkyIslandGeneratorCleanup] Preserved spawn area item: %s", item.Name))
            end
        end
    end
    
    -- Step 2: Clear terrain using markers (precise, spawn-aware removal)
    local markersFolder = workspace:FindFirstChild("SkyConstellationMarkers")
    if markersFolder then
        local terrain = workspace.Terrain
        
        for _, marker in ipairs(markersFolder:GetChildren()) do
            if marker:IsA("BasePart") and marker:GetAttribute("Radius") then
                local pos = marker.Position
                local radius = marker:GetAttribute("Radius")
                
                -- Only clear terrain outside spawn area
                local distanceFromSpawn = (Vector2.new(pos.X, pos.Z)).Magnitude
                if distanceFromSpawn > spawnRadius + 50 then -- 50 stud buffer
                    terrain:FillBall(pos, radius * 1.5, Enum.Material.Air)
                    cleanupStats.terrainRegions = cleanupStats.terrainRegions + 1
                end
            end
        end
        
        -- Clear all markers
        markersFolder:ClearAllChildren()
    end
    
    -- Step 3: Clear debug visualization
    local debugFolder = workspace:FindFirstChild("SkyIslandDebug")
    if debugFolder then
        debugFolder:Destroy()
    end
    
    -- Step 4: Reset generator internal state if provided
    if skyIslandGenerator then
        skyIslandGenerator.spatialHash = {}
        skyIslandGenerator.pois = {}
        skyIslandGenerator.pathSegments = {}
        skyIslandGenerator.tinyIslands = {}
        skyIslandGenerator.pitstops = {}
        skyIslandGenerator.pseudoPois = {}
        skyIslandGenerator.connections = {}
        skyIslandGenerator._roots = nil -- Force recreation
        
        skyIslandGenerator._dbg = {
            poiPolar = {},
            quadrantCounts = { North = 0, East = 0, South = 0, West = 0 },
            pairChecks = 0,
            rejects = { tooShort = 0, tooLong = 0, quadrant = 0 },
            accepts = 0,
            connectRDeltaSum = 0,
            connectRDeltaCount = 0,
        }
    end
    
    -- Print cleanup statistics
    local elapsed = tick() - startTime
    print(string.format("[SkyIslandGeneratorCleanup] External cleanup complete in %.2fms", elapsed * 1000))
    print(string.format("  - Tagged items removed: %d", cleanupStats.taggedItems))
    print(string.format("  - Terrain regions cleared: %d", cleanupStats.terrainRegions))
    print("[SkyIslandGeneratorCleanup] Spawn area preserved, ready for regeneration")
end

return SkyIslandGeneratorCleanup
