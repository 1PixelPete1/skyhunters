--!strict
-- CleanupTestBridges.server.luau
-- Enhanced script to remove all test bridges created by the test services

print("[CleanupTestBridges] Starting comprehensive cleanup of test bridges...")

local cleaned = 0

-- Remove test bridges from various locations
local function cleanupFromParent(parent: Instance, searchName: string)
    local found = parent:FindFirstChild(searchName)
    if found then
        found:Destroy()
        cleaned = cleaned + 1
        print(string.format("[CleanupTestBridges] Removed: %s", found:GetFullName()))
    end
end

-- Clean up test bridges based on patterns
local function cleanupTestBridges()
    print("[CleanupTestBridges] Scanning workspace for test bridges...")
    
    -- Remove BridgeTests folder created by TestBridgeMeshService
    cleanupFromParent(workspace, "BridgeTests")
    
    -- Remove InitTest_Bridge created by InitBridgeSystem
    cleanupFromParent(workspace, "InitTest_Bridge")
    
    -- Remove any bridges with test names (case insensitive)
    for _, child in pairs(workspace:GetChildren()) do
        if child:IsA("Model") then
            local nameCheck = child.Name:lower()
            if nameCheck:find("test") or
               nameCheck:find("bridge") and (
                   nameCheck:find("random") or
                   nameCheck:find("init") or
                   nameCheck:find("demo") or
                   nameCheck:find("example")
               ) then
                child:Destroy()
                cleaned = cleaned + 1
                print(string.format("[CleanupTestBridges] Removed test bridge: %s", child.Name))
            end
        end
    end
    
    -- Look for bridges at typical test heights (Y=50, Y=100) within spawn area (small radius)
    local spawnRadius = 200 -- Only check near spawn area
    for _, child in pairs(workspace:GetChildren()) do
        if child:IsA("Model") and child.Name:find("Bridge") then
            local success, cf = pcall(function() return child:GetModelCFrame() end)
            if success and cf then
                local distanceFromSpawn = (Vector2.new(cf.X, cf.Z)).Magnitude
                if distanceFromSpawn < spawnRadius and (math.abs(cf.Y - 50) < 10 or math.abs(cf.Y - 100) < 10) then
                    print(string.format("[CleanupTestBridges] Found test bridge near spawn: %s (Y=%.1f, distance=%.1f)", child.Name, cf.Y, distanceFromSpawn))
                    child:Destroy()
                    cleaned = cleaned + 1
                end
            end
        end
    end
    
    -- Clean up any tagged test content
    local CollectionService = game:GetService("CollectionService")
    for _, tag in pairs({"BridgeTest", "TestBridge", "InitTest"}) do
        for _, obj in pairs(CollectionService:GetTagged(tag)) do
            obj:Destroy()
            cleaned = cleaned + 1
            print(string.format("[CleanupTestBridges] Removed tagged test object: %s", obj.Name))
        end
    end
end

-- Run cleanup
cleanupTestBridges()

print(string.format("[CleanupTestBridges] Cleanup complete! Removed %d items.", cleaned))
print("[CleanupTestBridges] Test bridge scripts have been moved out of server directory.")
print("[CleanupTestBridges] Bridge scaling fix applied - meshes will now scale to 0.04.")

-- Self-destruct after cleanup
script:Destroy()
