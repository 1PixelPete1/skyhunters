--!strict
-- UnifiedRimSystem: Ensures consistent rim density between dynamic and persistent pond loading
-- This fixes the issue where dynamic ponds had few rim stones but persistent ponds had many

local UnifiedRimSystem = {}
local SSS = game:GetService("ServerScriptService")
local RimBuilder = require(SSS:WaitForChild("Server"):WaitForChild("RimBuilder"))

-- Global configuration for consistent rim creation
local UNIFIED_RIM_CONFIG = {
    StoneCount = 8,  -- Consistent across all rim creation
    InnerGap = 1.25,
    ArcJitter = 0.0,
    YawJitter = 8,
    RollJitter = 3,
    StoneSize = Vector3.new(4.5, 2.0, 2.2),
    SizeJitter = Vector3.new(1.0, 0.6, 0.8),
    Color = Color3.fromRGB(118, 116, 112),
    Material = Enum.Material.Rock,
}

-- Track created rims to prevent duplicates
local createdRims = {}

-- Main unified rim creation function
function UnifiedRimSystem.createRim(pondId: string, centerPos: Vector3, radius: number, forceRecreate: boolean?)
    forceRecreate = forceRecreate or false
    
    -- Prevent duplicate rims unless forced
    if createdRims[pondId] and not forceRecreate then
        print(`[UnifiedRimSystem] Rim already exists for pond {pondId}, skipping`)
        return createdRims[pondId]
    end
    
    print(`[UnifiedRimSystem] Creating unified rim for pond {pondId} (radius: {radius})`)
    
    -- Clear existing rim stones for this pond
    UnifiedRimSystem.clearRimForPond(pondId)
    
    -- Create rim container
    local rimContainer = UnifiedRimSystem._getOrCreateRimContainer(pondId)
    
    -- Use RimBuilder with unified configuration
    RimBuilder.build(rimContainer, centerPos, radius, UNIFIED_RIM_CONFIG)
    
    -- Track the created rim
    createdRims[pondId] = {
        container = rimContainer,
        centerPos = centerPos,
        radius = radius,
        stoneCount = UNIFIED_RIM_CONFIG.StoneCount,
        createdAt = tick()
    }
    
    print(`[UnifiedRimSystem] Created rim with {UNIFIED_RIM_CONFIG.StoneCount} stones for pond {pondId}`)
    return createdRims[pondId]
end

-- Create rim from persistent data (ignores old dense save data)
function UnifiedRimSystem.createRimFromPersistence(pondId: string, centerPos: Vector3, radius: number, savedRimData: any?)
    print(`[UnifiedRimSystem] Loading rim from persistence for pond {pondId}`)
    
    -- ALWAYS use unified creation regardless of saved data format
    -- This ensures consistency between old dense saves and new optimized rims
    local rim = UnifiedRimSystem.createRim(pondId, centerPos, radius, true)
    
    print(`[UnifiedRimSystem] Loaded rim with unified format ({UNIFIED_RIM_CONFIG.StoneCount} stones)`)
    return rim
end

-- Get or create rim container for a specific pond
function UnifiedRimSystem._getOrCreateRimContainer(pondId: string)
    local pondRims = workspace:FindFirstChild("PondRims")
    if not pondRims then
        pondRims = Instance.new("Folder")
        pondRims.Name = "PondRims"
        pondRims.Parent = workspace
    end
    
    local rimContainer = pondRims:FindFirstChild(pondId)
    if not rimContainer then
        rimContainer = Instance.new("Folder")
        rimContainer.Name = pondId
        rimContainer.Parent = pondRims
    end
    
    return rimContainer
end

-- Clear rim stones for a specific pond
function UnifiedRimSystem.clearRimForPond(pondId: string)
    local pondRims = workspace:FindFirstChild("PondRims")
    if not pondRims then return end
    
    local rimContainer = pondRims:FindFirstChild(pondId)
    if rimContainer then
        -- Clear all rim stones
        for _, child in ipairs(rimContainer:GetChildren()) do
            if child.Name == "RimStone" then
                child:Destroy()
            end
        end
        print(`[UnifiedRimSystem] Cleared existing rim stones for pond {pondId}`)
    end
    
    -- Remove from tracking
    createdRims[pondId] = nil
end

-- Analyze rim performance across all ponds
function UnifiedRimSystem.analyzeRims()
    local analysis = {
        totalPonds = 0,
        totalStones = 0,
        averageStonesPerPond = 0,
        unifiedPonds = 0,  -- Ponds using unified system
        legacyPonds = 0,   -- Ponds with old dense rims
        recommendation = ""
    }
    
    local pondRims = workspace:FindFirstChild("PondRims")
    if not pondRims then
        print("[UnifiedRimSystem] No PondRims folder found")
        return analysis
    end
    
    for _, rimContainer in ipairs(pondRims:GetChildren()) do
        if rimContainer:IsA("Folder") then
            analysis.totalPonds = analysis.totalPonds + 1
            local stoneCount = 0
            
            for _, child in ipairs(rimContainer:GetChildren()) do
                if child.Name == "RimStone" then
                    stoneCount = stoneCount + 1
                end
            end
            
            analysis.totalStones = analysis.totalStones + stoneCount
            
            -- Classify as unified or legacy
            if stoneCount <= 12 then
                analysis.unifiedPonds = analysis.unifiedPonds + 1
            else
                analysis.legacyPonds = analysis.legacyPonds + 1
            end
        end
    end
    
    if analysis.totalPonds > 0 then
        analysis.averageStonesPerPond = analysis.totalStones / analysis.totalPonds
    end
    
    -- Generate recommendations
    if analysis.legacyPonds > 0 then
        analysis.recommendation = `MIGRATE: {analysis.legacyPonds} ponds need unified rim conversion`
    elseif analysis.averageStonesPerPond > 10 then
        analysis.recommendation = "OPTIMIZE: Consider reducing rim stone count further"
    else
        analysis.recommendation = "GOOD: All rims are using optimized unified system"
    end
    
    print("[UnifiedRimSystem] Rim Analysis:")
    print(`  Total ponds: {analysis.totalPonds}`)
    print(`  Total rim stones: {analysis.totalStones}`)
    print(string.format("  Average stones per pond: %.1f", analysis.averageStonesPerPond))
    print(`  Unified ponds: {analysis.unifiedPonds}`)
    print(`  Legacy ponds: {analysis.legacyPonds}`)
    print(`  Recommendation: {analysis.recommendation}`)
    
    return analysis
end

-- Migrate legacy rims to unified system
function UnifiedRimSystem.migrateLegacyRims()
    local migrated = 0
    local pondRims = workspace:FindFirstChild("PondRims")
    if not pondRims then return migrated end
    
    for _, rimContainer in ipairs(pondRims:GetChildren()) do
        if rimContainer:IsA("Folder") then
            local stoneCount = 0
            local firstStone = nil
            
            -- Count stones and find a reference stone for position/radius estimation
            for _, child in ipairs(rimContainer:GetChildren()) do
                if child.Name == "RimStone" then
                    stoneCount = stoneCount + 1
                    if not firstStone then firstStone = child end
                end
            end
            
            -- If pond has more than 12 stones, convert to unified
            if stoneCount > 12 and firstStone then
                print(`[UnifiedRimSystem] Migrating legacy rim {rimContainer.Name} ({stoneCount} -> {UNIFIED_RIM_CONFIG.StoneCount} stones)`)
                
                -- Estimate center and radius from first stone position
                local stonePos = firstStone.Position
                local estimatedCenter = Vector3.new(stonePos.X, stonePos.Y - 2, stonePos.Z) -- Rough estimate
                local estimatedRadius = 10 -- Default radius
                
                -- Recreate with unified system
                UnifiedRimSystem.createRim(rimContainer.Name, estimatedCenter, estimatedRadius, true)
                migrated = migrated + 1
            end
        end
    end
    
    print(`[UnifiedRimSystem] Migrated {migrated} legacy rims to unified system`)
    return migrated
end

-- Get global rim configuration
function UnifiedRimSystem.getConfig()
    return UNIFIED_RIM_CONFIG
end

-- Update global rim configuration
function UnifiedRimSystem.setConfig(newConfig: {[string]: any})
    for key, value in pairs(newConfig) do
        if UNIFIED_RIM_CONFIG[key] ~= nil then
            UNIFIED_RIM_CONFIG[key] = value
        end
    end
    print("[UnifiedRimSystem] Updated rim configuration")
end

return UnifiedRimSystem
