-- IntegrationTest_LoadingFixes.server.luau
-- Tests the loading screen and rim optimization fixes

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function testLoadingScreenIntegration()
    print("=== TESTING LOADING SCREEN INTEGRATION ===")
    
    -- Check if LoadingProgressRemote exists
    local Net = ReplicatedStorage:FindFirstChild("Net")
    local Remotes = Net and Net:FindFirstChild("Remotes")
    local progressRemote = Remotes and Remotes:FindFirstChild("LoadingProgressRemote")
    
    if progressRemote then
        print("✅ LoadingProgressRemote found")
        
        -- Test progress broadcast
        progressRemote:FireAllClients({
            progress = 0.5,
            status = "Testing",
            detail = "Integration test progress",
            isLoading = true
        })
        
        wait(2)
        
        -- Test completion signal
        progressRemote:FireAllClients({
            progress = 1,
            status = "Complete",
            detail = "Integration test complete",
            isLoading = false,
            completed = true
        })
        
        print("✅ Loading screen progress test complete")
    else
        warn("❌ LoadingProgressRemote not found")
    end
end

local function testRimOptimization()
    print("=== TESTING RIM OPTIMIZATION ===")
    
    -- Check if UnifiedRimSystem exists
    local ok, UnifiedRimSystem = pcall(function()
        return require(script.Parent:WaitForChild("src"):WaitForChild("server"):WaitForChild("UnifiedRimSystem"))
    end)
    
    if ok and UnifiedRimSystem then
        print("✅ UnifiedRimSystem loaded")
        
        -- Test rim analysis
        if UnifiedRimSystem.analyzeRims then
            local analysis = UnifiedRimSystem.analyzeRims()
            print("✅ Rim analysis complete")
        end
        
        -- Test configuration
        local config = UnifiedRimSystem.getConfig()
        if config and config.StoneCount == 8 then
            print("✅ Optimized stone count confirmed (8 stones)")
        else
            warn("❌ Stone count not optimized")
        end
    else
        warn("❌ UnifiedRimSystem not found")
    end
    
    -- Check RimBuilder optimization
    local ok2, RimBuilder = pcall(function()
        return require(script.Parent:WaitForChild("src"):WaitForChild("server"):WaitForChild("RimBuilder"))
    end)
    
    if ok2 and RimBuilder then
        print("✅ RimBuilder loaded")
        
        if RimBuilder.analyzePerformance then
            local analysis = RimBuilder.analyzePerformance()
            print("✅ RimBuilder analysis complete")
        end
    end
end

local function testAsyncPondLoader()
    print("=== TESTING ASYNC POND LOADER ===")
    
    local ok, AsyncPondLoader = pcall(function()
        return require(script.Parent:WaitForChild("src"):WaitForChild("server"):WaitForChild("Systems"):WaitForChild("AsyncPondLoader"))
    end)
    
    if ok and AsyncPondLoader then
        print("✅ AsyncPondLoader loaded")
        
        -- Check status
        local status = AsyncPondLoader.getStatus()
        print(`Current loading status: {status.status} ({status.progress * 100:.1f}%)`)
        
        print("✅ AsyncPondLoader integration confirmed")
    else
        warn("❌ AsyncPondLoader not found")
    end
end

-- Run tests when first player joins
local hasRun = false
Players.PlayerAdded:Connect(function(player)
    if hasRun then return end
    hasRun = true
    
    -- Wait for systems to initialize
    wait(5)
    
    print("[IntegrationTest] Starting loading system integration tests...")
    
    testLoadingScreenIntegration()
    testRimOptimization() 
    testAsyncPondLoader()
    
    print("[IntegrationTest] All tests complete!")
end)

-- Immediate test in Studio
if RunService:IsStudio() then
    wait(1)
    print("[IntegrationTest] Running immediate Studio tests...")
    
    testLoadingScreenIntegration()
    testRimOptimization()
    testAsyncPondLoader()
end
