-- IntegrationTest.server.luau
-- Simple test script to verify enhanced systems are working
-- Place this in ServerScriptService temporarily for testing

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Only run in Studio
if not RunService:IsStudio() then
    return
end

local IntegrationTest = {}

-- Test results storage
local testResults = {}

-- Helper function to run a test
local function runTest(testName, testFunction)
    print(string.format("🧪 [TEST] Running: %s", testName))
    
    local success, result = pcall(testFunction)
    
    if success then
        if result then
            testResults[testName] = { success = true, message = "PASS" }
            print(string.format("✅ [TEST] %s: PASS", testName))
        else
            testResults[testName] = { success = false, message = "FAIL - Test returned false" }
            print(string.format("❌ [TEST] %s: FAIL - Test returned false", testName))
        end
    else
        testResults[testName] = { success = false, message = result }
        print(string.format("❌ [TEST] %s: ERROR - %s", testName, result))
    end
end

-- Test 1: Check if all enhanced systems are loaded
runTest("Enhanced Systems Loaded", function()
    local systems = game.ServerScriptService:FindFirstChild("Systems")
    if not systems then return false end
    
    local requiredSystems = {
        "EnhancedRemovalSystem",
        "AsyncLoadingSystem", 
        "EnhancedCanalStones",
        "StudioDevRemotes"
    }
    
    for _, systemName in pairs(requiredSystems) do
        local system = systems:FindFirstChild(systemName)
        if not system then
            print(string.format("  ❌ Missing: %s", systemName))
            return false
        end
        print(string.format("  ✅ Found: %s", systemName))
    end
    
    return true
end)

-- Test 2: Check if client files exist
runTest("Client Files Exist", function()
    local clientLocations = {
        game.StarterPlayer.StarterPlayerScripts:FindFirstChild("Client"),
        game.StarterGui:FindFirstChild("Client"),
        game.ReplicatedFirst:FindFirstChild("Client"),
        game.ServerScriptService:FindFirstChild("client"), -- Fallback for testing
        game.ServerScriptService:FindFirstChild("src") and game.ServerScriptService.src:FindFirstChild("client")
    }
    
    local client = nil
    for _, location in pairs(clientLocations) do
        if location then
            client = location
            break
        end
    end
    
    if not client then
        print("  ❌ Client folder not found in any expected location")
        return false
    end
    
    print("  ✅ Found client folder at:", client:GetFullName())
    
    local requiredClientFiles = {
        "StudioDevUI",
        "LoadingScreen"
    }
    
    for _, fileName in pairs(requiredClientFiles) do
        local file = client:FindFirstChild(fileName)
        if not file then
            print(string.format("  ❌ Missing client file: %s", fileName))
            return false
        end
        print(string.format("  ✅ Found client file: %s (%s)", fileName, file.ClassName))
    end
    
    -- Check for UI folder and OilHUD
    local uiFolder = client:FindFirstChild("UI")
    if uiFolder then
        local oilHUD = uiFolder:FindFirstChild("OilHUD")
        if oilHUD then
            print(string.format("  ✅ Found OilHUD: %s (%s)", oilHUD.Name, oilHUD.ClassName))
        else
            print("  ⚠️ OilHUD not found in UI folder (optional)")
        end
    else
        print("  ⚠️ UI folder not found (optional)")
    end
    
    return true
end)

-- Test 3: Check if remotes are set up
runTest("Remotes Setup", function()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then
        print("  ❌ Remotes folder not found in ReplicatedStorage")
        return false
    end
    
    local requiredRemotes = {
        "GrantItemRemote",
        "WipePlotRemote", 
        "LoadingProgressRemote"
    }
    
    for _, remoteName in pairs(requiredRemotes) do
        local remote = remotes:FindFirstChild(remoteName)
        if not remote then
            print(string.format("  ❌ Missing remote: %s", remoteName))
            return false
        end
        print(string.format("  ✅ Found remote: %s", remoteName))
    end
    
    return true
end)

-- Test 4: Try to require enhanced systems
runTest("Enhanced Systems Require", function()
    local systems = game.ServerScriptService:FindFirstChild("Systems")
    local serverFolder = game.ServerScriptService:FindFirstChild("Server") or game.ServerScriptService:FindFirstChild("src") and game.ServerScriptService.src:FindFirstChild("server")
    
    if not systems then return false end
    
    local systemTests = {
        {
            name = "EnhancedRemovalSystem",
            location = systems,
            testFunction = function(module)
                return type(module.RemovePond) == "function" and 
                       type(module.WipePlot) == "function"
            end
        },
        {
            name = "AsyncLoadingSystem", 
            location = systems,
            testFunction = function(module)
                return type(module.ProcessItemsAsync) == "function" and
                       type(module.LoadWithProgress) == "function"
            end
        },
        {
            name = "EnhancedCanalStones",
            location = systems,
            testFunction = function(module)
                return type(module.CreateCanalStones) == "function" and
                       type(module.ReconstructCanalStones) == "function"
            end
        },
        {
            name = "EnhancedRimBuilder",
            location = serverFolder,
            testFunction = function(module)
                return type(module.CreateRimStones) == "function" and
                       type(module.build) == "function"
            end
        }
    }
    
    for _, test in pairs(systemTests) do
        local system = test.location and test.location:FindFirstChild(test.name)
        if not system then
            print(string.format("  ❌ System not found: %s (looked in %s)", test.name, test.location and test.location:GetFullName() or "nil"))
            return false
        end
        
        local success, module = pcall(function()
            return require(system)
        end)
        
        if not success then
            print(string.format("  ❌ Failed to require %s: %s", test.name, module))
            return false
        end
        
        if not test.testFunction(module) then
            print(string.format("  ❌ %s module doesn't have expected functions", test.name))
            return false
        end
        
        print(string.format("  ✅ %s: Required and validated", test.name))
    end
    
    return true
end)

-- Test 5: Test that WorldBootstrap fix worked
runTest("WorldBootstrap Fix", function()
    local worldBootstrap = game.ServerScriptService:FindFirstChild("WorldBootstrap")
    if not worldBootstrap then
        print("  ❌ WorldBootstrap not found")
        return false
    end
    
    -- Read the source to check for the PondNetworkService require
    local source = worldBootstrap.Source
    if source:find("local PondNetworkService = require") then
        print("  ✅ PondNetworkService require found in WorldBootstrap")
        return true
    else
        print("  ❌ PondNetworkService require not found in WorldBootstrap")
        return false
    end
end)

-- Wait a moment for systems to load, then run tests
wait(2)

print("\n🚀 QuietWinds FIXES Integration Test Starting...")
print("Testing fixes for: Canal stones, Dev UI remotes, Oil loading bar")
print("=" .. string.rep("=", 70))

-- Run all tests
-- (Tests are run by the runTest calls above)

-- Print summary
print("\n📊 Test Summary:")
print("=" .. string.rep("=", 50))

local passCount = 0
local totalCount = 0

for testName, result in pairs(testResults) do
    totalCount = totalCount + 1
    if result.success then
        passCount = passCount + 1
        print(string.format("✅ %s", testName))
    else
        print(string.format("❌ %s: %s", testName, result.message))
    end
end

print(string.rep("=", 50))
print(string.format("📈 Results: %d/%d tests passed (%.1f%%)", 
    passCount, totalCount, (passCount/totalCount)*100))

if passCount == totalCount then
    print("🎉 All tests passed! Fixes working correctly!")
    print("\n🎮 Next steps:")
    print("  1. Look for blue 'Dev Tools' button in top-right corner (no F1 needed)")
    print("  2. Test canal stone rotation - create 2 ponds and link them")
    print("  3. Check oil loading bar in top-left (should animate)")
    print("  4. Test dev UI buttons - should print to server console")
    print("  5. Enable 'Allow Studio Access to API Services' in Game Settings > Security")
else
    print("⚠️  Some tests failed. Check the errors above and fix before proceeding.")
    print("\n🔧 Focus on these fixes:")
    print("  1. Canal stones should now rotate along canal curves")
    print("  2. Dev UI should use top-right button (no F1 keybind)")
    print("  3. Oil display should be a loading bar, not just numbers")
    print("  4. Server should respond to dev UI button clicks")
end

print("\n🧪 Integration test complete!")

return IntegrationTest