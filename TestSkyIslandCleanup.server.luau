-- TestSkyIslandCleanup.server.luau
-- Test script to validate the enhanced sky island cleanup system

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

-- Import the cleanup system
local SkyIslandCleanupEnhanced = require(script.Parent.Worldgen.SkyIslandCleanupEnhanced)
local SkyIslandGenerator = require(script.Parent.Worldgen.SkyIslandGenerator)

local TestSkyIslandCleanup = {}

-- Create some test sky island content to verify cleanup
function TestSkyIslandCleanup.createTestContent()
    print("[TestCleanup] Creating test sky island content...")
    
    -- Create test folders
    local testFolder = Instance.new("Folder")
    testFolder.Name = "SkyConstellations"
    testFolder.Parent = workspace
    CollectionService:AddTag(testFolder, "SkyIslandContent")
    
    -- Create test models
    for i = 1, 3 do
        local testModel = Instance.new("Model")
        testModel.Name = "TestSkyIsland_" .. i
        testModel.Parent = testFolder
        
        local testPart = Instance.new("Part")
        testPart.Name = "TestPart"
        testPart.Size = Vector3.new(10, 10, 10)
        testPart.Position = Vector3.new(i * 300, 100, 0) -- Far from spawn
        testPart.Anchored = true
        testPart.Material = Enum.Material.Neon
        testPart.BrickColor = BrickColor.new("Bright red")
        testPart.Parent = testModel
        
        CollectionService:AddTag(testModel, "SkyIslandContent")
    end
    
    -- Create test terrain at known locations using boxes instead of spheres
    local terrain = workspace.Terrain
    local testRegions = {
        {
            position = Vector3.new(500, 100, 0),
            size = Vector3.new(60, 60, 60) -- Box dimensions
        },
        {
            position = Vector3.new(0, 100, 500),
            size = Vector3.new(40, 40, 40)
        },
        {
            position = Vector3.new(-500, 100, 0),
            size = Vector3.new(80, 80, 80)
        }
    }
    
    -- Create markers folder
    local markersFolder = Instance.new("Folder")
    markersFolder.Name = "SkyConstellationMarkers"
    markersFolder.Parent = workspace
    CollectionService:AddTag(markersFolder, "SkyIslandContent")
    
    for i, regionData in ipairs(testRegions) do
        local pos = regionData.position
        local size = regionData.size
        
        -- Create terrain using FillBlock for precise box shapes
        terrain:FillBlock(CFrame.new(pos), size, Enum.Material.Rock)
        
        -- Create marker with precise region bounds
        local marker = Instance.new("Part")
        marker.Name = "TestMarker_" .. i
        marker.Anchored = true
        marker.CanCollide = false
        marker.Transparency = 1
        marker.Size = Vector3.new(1, 1, 1)
        marker.Position = pos
        marker.Parent = markersFolder
        marker:SetAttribute("Radius", math.max(size.X, size.Y, size.Z) / 2)
        
        -- Store precise region bounds
        local min = pos - size/2
        local max = pos + size/2
        marker:SetAttribute("RegionMinX", min.X)
        marker:SetAttribute("RegionMinY", min.Y)
        marker:SetAttribute("RegionMinZ", min.Z)
        marker:SetAttribute("RegionMaxX", max.X)
        marker:SetAttribute("RegionMaxY", max.Y)
        marker:SetAttribute("RegionMaxZ", max.Z)
        
        CollectionService:AddTag(marker, "SkyIslandContent")
    end
    
    print("[TestCleanup] Created test content - 3 models, 3 terrain boxes, markers with precise regions")
end

-- Test the cleanup system
function TestSkyIslandCleanup.testCleanup()
    print("[TestCleanup] ===== TESTING SKY ISLAND CLEANUP SYSTEM =====")
    
    -- First create test content
    TestSkyIslandCleanup.createTestContent()
    wait(1)
    
    -- Count tagged items before cleanup
    local beforeCount = #CollectionService:GetTagged("SkyIslandContent")
    print(string.format("[TestCleanup] Items before cleanup: %d", beforeCount))
    
    -- Run the enhanced cleanup
    local stats = SkyIslandCleanupEnhanced.cleanupAll()
    
    -- Count tagged items after cleanup
    wait(1)
    local afterCount = #CollectionService:GetTagged("SkyIslandContent")
    print(string.format("[TestCleanup] Items after cleanup: %d", afterCount))
    
    -- Check if folders were removed
    local testFolders = {
        "SkyConstellations",
        "SkyConstellationMarkers",
        "SkyElements"
    }
    
    for _, folderName in ipairs(testFolders) do
        local folder = workspace:FindFirstChild(folderName)
        if folder then
            print(string.format("[TestCleanup] WARNING: Folder '%s' still exists!", folderName))
        else
            print(string.format("[TestCleanup] ✓ Folder '%s' properly removed", folderName))
        end
    end
    
    -- Verify terrain was cleared (check if terrain exists at test positions)
    local terrain = workspace.Terrain
    local testRegions = {
        {
            position = Vector3.new(500, 100, 0),
            size = Vector3.new(60, 60, 60)
        },
        {
            position = Vector3.new(0, 100, 500),
            size = Vector3.new(40, 40, 40)
        },
        {
            position = Vector3.new(-500, 100, 0),
            size = Vector3.new(80, 80, 80)
        }
    }
    
    for i, regionData in ipairs(testRegions) do
        local pos = regionData.position
        local size = regionData.size
        local region = Region3.new(pos - size/2, pos + size/2):ExpandToGrid(4)
        local materials, occupancies = terrain:ReadVoxels(region, 4)
        
        local hasNonAir = false
        for x = 1, materials.Size.X do
            for y = 1, materials.Size.Y do
                for z = 1, materials.Size.Z do
                    if materials[x][y][z] ~= Enum.Material.Air and occupancies[x][y][z] > 0 then
                        hasNonAir = true
                        break
                    end
                end
                if hasNonAir then break end
            end
            if hasNonAir then break end
        end
        
        if hasNonAir then
            print(string.format("[TestCleanup] WARNING: Terrain at position %s was not cleared!", tostring(pos)))
        else
            print(string.format("[TestCleanup] ✓ Terrain box at position %s properly cleared", tostring(pos)))
        end
    end
    
    print(string.format("[TestCleanup] ===== TEST COMPLETE ====="))
    print(string.format("[TestCleanup] Tagged models removed: %d", stats.taggedModels))
    print(string.format("[TestCleanup] Terrain chunks cleared: %d", stats.terrainChunks))
    
    if beforeCount > 0 and afterCount == 0 then
        print("[TestCleanup] ✅ SUCCESS: All tagged content was properly removed!")
    else
        print(string.format("[TestCleanup] ❌ ISSUE: Some content may not have been removed (before: %d, after: %d)", beforeCount, afterCount))
    end
end

-- Test sky island generator cleanup
function TestSkyIslandCleanup.testGeneratorCleanup()
    print("[TestCleanup] ===== TESTING SKY ISLAND GENERATOR CLEANUP =====")
    
    -- Create a sky island generator instance
    local generator = SkyIslandGenerator.new()
    
    -- Generate some test content
    TestSkyIslandCleanup.createTestContent()
    wait(1)
    
    local beforeCount = #CollectionService:GetTagged("SkyIslandContent")
    print(string.format("[TestCleanup] Items before generator cleanup: %d", beforeCount))
    
    -- Use generator's cleanup method
    local stats = generator:Cleanup()
    
    wait(1)
    local afterCount = #CollectionService:GetTagged("SkyIslandContent")
    print(string.format("[TestCleanup] Items after generator cleanup: %d", afterCount))
    
    if beforeCount > 0 and afterCount == 0 then
        print("[TestCleanup] ✅ SUCCESS: Generator cleanup worked properly!")
    else
        print(string.format("[TestCleanup] ❌ ISSUE: Generator cleanup incomplete (before: %d, after: %d)", beforeCount, afterCount))
    end
end

-- Auto-run tests when script loads
if game:GetService("RunService"):IsStudio() then
    wait(5) -- Wait for other systems to load
    
    print("[TestCleanup] Starting sky island cleanup tests...")
    
    -- Test the standalone cleanup system
    TestSkyIslandCleanup.testCleanup()
    
    wait(2)
    
    -- Test the generator's cleanup method
    TestSkyIslandCleanup.testGeneratorCleanup()
    
    print("[TestCleanup] All tests completed!")
end

return TestSkyIslandCleanup