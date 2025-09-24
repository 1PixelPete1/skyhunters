-- TestSkyIslandGeneration.server.luau
-- Comprehensive test script to verify the new parkour-style sky island generation system

local SSS = game:GetService("ServerScriptService")
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Config
local ConfigFolder = RS:WaitForChild("Config")
local WorldConfig = require(ConfigFolder:WaitForChild("WorldConfig"))

print("[TestSkyIslandGeneration] Starting comprehensive test...")

-- Try to load the new generation system
local SkyIslandGenerator = nil
local GenerationQueue = nil
local TerrainIslandBuilder = nil

-- Load modules with detailed error reporting
local success, err = pcall(function()
    local worldgenFolder = SSS:WaitForChild("Server"):WaitForChild("Worldgen")
    print("[TestSkyIslandGeneration] Found Worldgen folder:", worldgenFolder:GetFullName())
    
    SkyIslandGenerator = require(worldgenFolder:WaitForChild("SkyIslandGenerator"))
    print("[TestSkyIslandGeneration] Loaded SkyIslandGenerator")
    
    local systemsFolder = SSS:WaitForChild("Systems")
    print("[TestSkyIslandGeneration] Found Systems folder:", systemsFolder:GetFullName())
    
    GenerationQueue = require(systemsFolder:WaitForChild("GenerationQueue"))
    print("[TestSkyIslandGeneration] Loaded GenerationQueue")
    
    TerrainIslandBuilder = require(worldgenFolder:WaitForChild("TerrainIslandBuilder"))
    print("[TestSkyIslandGeneration] Loaded TerrainIslandBuilder")
end)

if not success then
    warn("[TestSkyIslandGeneration] Failed to load modules:", err)
    return
end

print("[TestSkyIslandGeneration] Successfully loaded all modules!")

-- Create generation queue with conservative settings for testing
local genQueue = GenerationQueue.new({
    maxOperationsPerFrame = 2,
    maxTimePerFrame = 0.004,
    priorityLevels = 3
})

print("[TestSkyIslandGeneration] Created generation queue")

-- Create sky island generator
local skyGen = SkyIslandGenerator.new(
    WorldConfig,
    TerrainIslandBuilder,
    genQueue
)

print("[TestSkyIslandGeneration] Created sky island generator")

-- Clear any existing islands for clean test
skyGen:Cleanup()
print("[TestSkyIslandGeneration] Cleaned up existing islands")

-- Start generation
print("[TestSkyIslandGeneration] Starting sky island generation...")
skyGen:Generate()

-- Monitor progress
coroutine.wrap(function()
    local startTime = tick()
    local lastStatsTime = startTime
    
    while skyGen.isGenerating do
        wait(2)  -- Check every 2 seconds
        local currentTime = tick()
        
        if currentTime - lastStatsTime >= 5 then  -- Report every 5 seconds
            local stats = genQueue:GetStats()
            print(string.format("[TestSkyIslandGeneration] Progress: %d operations completed, %d in queue", 
                stats.completedOperations, stats.currentQueueSize))
            lastStatsTime = currentTime
        end
    end
    
    local totalTime = tick() - startTime
    print(string.format("[TestSkyIslandGeneration] Generation completed in %.2f seconds", totalTime))
end)()

-- Set up debug visualization after generation completes
spawn(function()
    while skyGen.isGenerating do
        wait(1)
    end
    
    wait(2)  -- Wait for queue to finish
    
    print("[TestSkyIslandGeneration] Enabling debug visualization...")
    skyGen:DebugVisualize()
    
    -- Report final statistics
    local finalStats = genQueue:GetStats()
    print("[TestSkyIslandGeneration] Final queue stats:")
    print("  - Total operations:", finalStats.totalOperations)
    print("  - Completed operations:", finalStats.completedOperations)
    print("  - Failed operations:", finalStats.failedOperations)
    print("  - Average operation time:", string.format("%.4f seconds", finalStats.averageOperationTime))
    print("  - Peak queue size:", finalStats.peakQueueSize)
    
    -- Report generation statistics
    print("[TestSkyIslandGeneration] Generation statistics:")
    print("  - POIs generated:", #skyGen.pois)
    print("  - Path segments:", #skyGen.pathSegments)
    print("  - Tiny filler islands:", #skyGen.tinyIslands)
    print("  - Medium filler islands:", #skyGen.mediumIslands)
    
    print("[TestSkyIslandGeneration] Test complete! Check workspace for generated islands.")
    print("[TestSkyIslandGeneration] Debug markers: Red=POI zones, Blue=Path segments, Green=Tiny islands, Yellow=Medium islands")
end)

-- Set up admin commands for testing
Players.PlayerAdded:Connect(function(player)
    if player.UserId == game.CreatorId then
        player.Chatted:Connect(function(msg)
            local command = msg:lower()
            if command == "/debugislands" then
                skyGen:DebugVisualize()
                print("[TestSkyIslandGeneration] Debug visualization enabled")
            elseif command == "/clearislands" then
                skyGen:Cleanup()
                print("[TestSkyIslandGeneration] Islands cleared")
            elseif command == "/regenerate" then
                skyGen:Cleanup()
                wait(1)
                skyGen:Generate()
                print("[TestSkyIslandGeneration] Regenerating islands...")
            elseif command == "/stats" then
                local stats = genQueue:GetStats()
                print("[TestSkyIslandGeneration] Current stats:")
                print("  - Queue size:", stats.currentQueueSize)
                print("  - Completed:", stats.completedOperations)
                print("  - Processing:", stats.isProcessing)
                print("  - POIs:", #skyGen.pois)
                print("  - Path segments:", #skyGen.pathSegments)
                print("  - Tiny islands:", #skyGen.tinyIslands)
                print("  - Medium islands:", #skyGen.mediumIslands)
            end
        end)
    end
end)
