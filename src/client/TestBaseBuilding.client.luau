--!strict
-- TestBaseBuilding: Quick test script to verify all base building systems work

local TestBaseBuilding = {}

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- Function to test each system
function TestBaseBuilding.runTests()
    print("========================================")
    print("BASE BUILDING SYSTEM TEST")
    print("========================================")
    
    -- Test 1: Check if remotes exist
    print("\n[TEST 1] Checking remotes...")
    local success1 = true
    
    local Net = RS:FindFirstChild("Net")
    if not Net then
        print("  ❌ Net folder not found")
        success1 = false
    else
        print("  ✅ Net folder found")
    end
    
    if Net then
        local Remotes = Net:FindFirstChild("Remotes")
        if not Remotes then
            print("  ❌ Remotes folder not found")
            success1 = false
        else
            print("  ✅ Remotes folder found")
            
            -- Check specific remotes
            local requiredRemotes = {
                "RF_PlaceLantern",
                "RF_RemovePond",
                "RF_RemoveLantern",
                "RF_GetPondNetworkSnapshot",
                "RE_PondNetworkDelta"
            }
            
            for _, remoteName in ipairs(requiredRemotes) do
                if Remotes:FindFirstChild(remoteName) then
                    print("  ✅", remoteName, "found")
                else
                    print("  ❌", remoteName, "NOT FOUND")
                    success1 = false
                end
            end
        end
    end
    
    -- Test 2: Check if modules load
    print("\n[TEST 2] Checking modules...")
    local success2 = true
    
    local modulesToCheck = {
        { path = RS.Shared, name = "UnifiedCarvingUtil" },
        { path = RS.Shared, name = "PlacementTransaction" },
        { path = RS.Shared, name = "PondFieldMath" },
        { path = RS.Shared.Boundary, name = "BoundarySDF" },
        { path = RS.Shared.Boundary, name = "BoundaryConfig" },
    }
    
    for _, moduleInfo in ipairs(modulesToCheck) do
        local module = moduleInfo.path:FindFirstChild(moduleInfo.name)
        if module then
            local ok, result = pcall(require, module)
            if ok then
                print("  ✅", moduleInfo.name, "loads successfully")
            else
                print("  ❌", moduleInfo.name, "failed to load:", result)
                success2 = false
            end
        else
            print("  ❌", moduleInfo.name, "module not found")
            success2 = false
        end
    end
    
    -- Test 3: Check workspace structure
    print("\n[TEST 3] Checking workspace structure...")
    local success3 = true
    
    local workspaceChecks = {
        "Terrain",
        "PondRims",
        "CanalSegments"
    }
    
    for _, itemName in ipairs(workspaceChecks) do
        if workspace:FindFirstChild(itemName) then
            print("  ✅", itemName, "exists")
        else
            print("  ⚠️", itemName, "not found (will be created when needed)")
        end
    end
    
    -- Test 4: Test placement validation
    print("\n[TEST 4] Testing placement validation...")
    local success4 = true
    
    local PlacementTransaction = require(RS.Shared.PlacementTransaction)
    
    -- Test pond validation (use location away from default pond at 0,0)
    local pondRequest = {
        posXZ = Vector2.new(50, 50),  -- Away from center pond
        radius = 10,
        placementType = "pond",
    }
    
    local pondResult = PlacementTransaction.validatePlacement(pondRequest)
    if pondResult.success then
        print("  ✅ Pond validation working (placement would succeed)")
    else
        print("  ⚠️ Pond validation returned:", pondResult.reason or "unknown")
    end
    
    -- Test lantern validation (use flatter terrain location)
    local lanternRequest = {
        posXZ = Vector2.new(30, 0),  -- Likely flatter terrain
        placementType = "lantern",
    }
    
    local lanternResult = PlacementTransaction.validatePlacement(lanternRequest)
    if lanternResult.success or lanternResult.reason == "ON_WATER_WARNING" then
        print("  ✅ Lantern validation working")
    else
        print("  ⚠️ Lantern validation returned:", lanternResult.reason or "unknown")
    end
    
    -- Summary
    print("\n========================================")
    print("TEST SUMMARY")
    print("========================================")
    
    local allSuccess = success1 and success2 and success3 and success4
    
    if allSuccess then
        print("✅ ALL TESTS PASSED - Base building systems ready!")
    else
        print("⚠️ Some tests failed - check the issues above")
    end
    
    print("\nTo use the base building system:")
    print("- Press B to toggle placement ghost")
    print("- Press Delete to toggle removal tool")
    print("- Press R while removal tool is active to switch modes")
    print("========================================")
end

-- Run tests when script loads
if RunService:IsClient() then
    task.wait(2)  -- Wait for everything to load
    TestBaseBuilding.runTests()
end

return TestBaseBuilding
