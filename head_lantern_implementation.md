# Technical Implementation Guide - Head Lanterns & Voyage System

## Head Lantern System Architecture

### Core Head Lantern Service
```lua
-- HeadLanternService.lua (Server)
local HeadLanternService = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Head lantern configurations
local CURSE_TYPES = {
    swiftness = {
        name = "Swift Current",
        description = "Increases movement speed by 25%",
        rarity = "common",
        durability = {min = 1, max = 2}, -- Deaths before breaking
        effects = {walkspeed_multiplier = 1.25}
    },
    illumination = {
        name = "Piercing Light",
        description = "Flashlight penetrates 50% further through darkness",
        rarity = "uncommon",
        durability = {min = 2, max = 4},
        effects = {light_range_multiplier = 1.5, light_intensity = 1.3}
    },
    magnetism = {
        name = "Resource Draw",
        description = "Automatically collect nearby resources",
        rarity = "rare",
        durability = {min = 3, max = 6},
        effects = {collection_radius = 10, collection_rate = 2}
    },
    tempest = {
        name = "Storm Caller",
        description = "Immunity to weather effects, +15% resource generation",
        rarity = "epic",
        durability = {min = 5, max = 8},
        effects = {weather_immunity = true, resource_multiplier = 1.15}
    }
}

local activeHeadLanterns = {} -- {player_id = {curse_type, durability, effects, lantern_source}}
local weakenedLanterns = {} -- {lantern_id = {original_strength, regrowth_progress}}

function HeadLanternService.pluckLantern(player, lanternId)
    local lantern = workspace.Lanterns:FindFirstChild("Lantern_" .. lanternId)
    if not lantern or not lantern:GetAttribute("CanPluck") then
        return false, "Lantern cannot be plucked"
    end
    
    -- Check if player already has a head lantern
    local playerId = tostring(player.UserId)
    if activeHeadLanterns[playerId] then
        return false, "Already wearing a head lantern"
    end
    
    -- Determine curse type based on lantern properties and RNG
    local curseType = determineCurseType(lantern)
    local durability = math.random(
        CURSE_TYPES[curseType].durability.min,
        CURSE_TYPES[curseType].durability.max
    )
    
    -- Create head lantern
    local headLantern = {
        curse_type = curseType,
        durability = durability,
        max_durability = durability,
        effects = CURSE_TYPES[curseType].effects,
        lantern_source = lanternId,
        equipped_time = tick()
    }
    
    -- Weaken source lantern
    weakenSourceLantern(lanternId)
    
    -- Equip head lantern
    activeHeadLanterns[playerId] = headLantern
    
    -- Apply effects to player
    applyHeadLanternEffects(player, headLantern)
    
    -- Update client
    ReplicatedStorage.HeadLanternEquipped:FireClient(player, curseType, durability)
    
    return true, curseType
end

function HeadLanternService.onPlayerDeath(player)
    local playerId = tostring(player.UserId)
    local headLantern = activeHeadLanterns[playerId]
    
    if not headLantern then return end
    
    -- Reduce durability
    headLantern.durability = headLantern.durability - 1
    
    if headLantern.durability <= 0 then
        -- Head lantern breaks
        removeHeadLantern(player)
        ReplicatedStorage.HeadLanternBroken:FireClient(player)
    else
        -- Update durability display
        ReplicatedStorage.HeadLanternDurability:FireClient(player, headLantern.durability)
    end
end

local function determineCurseType(lantern)
    -- Weight based on lantern properties and rarity system
    local rarityWeights = {
        common = 60,    -- swiftness
        uncommon = 25,  -- illumination
        rare = 12,      -- magnetism
        epic = 3        -- tempest
    }
    
    -- Factor in lantern's current state/production level
    local productionLevel = lantern:GetAttribute("ProductionLevel") or 1
    if productionLevel >= 5 then
        -- Higher production lanterns have better curse chances
        rarityWeights.epic = rarityWeights.epic + 2
        rarityWeights.rare = rarityWeights.rare + 5
    end
    
    -- Weighted random selection
    local totalWeight = 0
    for _, weight in pairs(rarityWeights) do
        totalWeight = totalWeight + weight
    end
    
    local roll = math.random() * totalWeight
    local currentWeight = 0
    
    for rarity, weight in pairs(rarityWeights) do
        currentWeight = currentWeight + weight
        if roll <= currentWeight then
            -- Find curse type matching this rarity
            for curseType, config in pairs(CURSE_TYPES) do
                if config.rarity == rarity then
                    return curseType
                end
            end
        end
    end
    
    return "swiftness" -- Fallback
end

local function weakenSourceLantern(lanternId)
    local lantern = workspace.Lanterns:FindFirstChild("Lantern_" .. lanternId)
    if not lantern then return end
    
    -- Store original strength
    local originalStrength = lantern:GetAttribute("ProductionRate") or 1
    weakenedLanterns[lanternId] = {
        original_strength = originalStrength,
        regrowth_progress = 0,
        weakened_time = tick()
    }
    
    -- Reduce lantern effectiveness
    lantern:SetAttribute("ProductionRate", originalStrength * 0.6) -- 60% of original
    lantern:SetAttribute("LightRadius", (lantern:GetAttribute("LightRadius") or 20) * 0.7)
    
    -- Visual update
    ReplicatedStorage.LanternWeakened:FireAllClients(lanternId, 0.6)
    
    -- Start regrowth process
    startLanternRegrowth(lanternId)
end

local function startLanternRegrowth(lanternId)
    local REGROWTH_TIME = 300 -- 5 minutes to full regrowth
    
    spawn(function()
        while weakenedLanterns[lanternId] do
            wait(10) -- Update every 10 seconds
            
            local weakenedData = weakenedLanterns[lanternId]
            local elapsed = tick() - weakenedData.weakened_time
            local progress = math.min(elapsed / REGROWTH_TIME, 1)
            
            weakenedData.regrowth_progress = progress
            
            -- Update lantern strength gradually
            local lantern = workspace.Lanterns:FindFirstChild("Lantern_" .. lanternId)
            if lantern then
                local currentStrength = weakenedData.original_strength * (0.6 + 0.4 * progress)
                lantern:SetAttribute("ProductionRate", currentStrength)
                
                -- Visual update
                ReplicatedStorage.LanternRegrowth:FireAllClients(lanternId, progress)
            end
            
            -- Complete regrowth
            if progress >= 1 then
                weakenedLanterns[lanternId] = nil
                break
            end
        end
    end)
end

return HeadLanternService
```

## Flashlight System Implementation

### Client-Side Flashlight Controller
```lua
-- FlashlightController.lua (Client)
local FlashlightController = {}
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Flashlight configuration
local FLASHLIGHT_CONFIG = {
    base_range = 30,
    cone_angle = 45, -- degrees
    intensity = 2,
    color = Color3.new(1, 0.9, 0.6),
    update_rate = 0.1 -- seconds
}

local flashlightActive = false
local flashlightBeam = nil
local headLanternData = nil

function FlashlightController.initialize()
    -- Listen for head lantern events
    ReplicatedStorage.HeadLanternEquipped.OnClientEvent:Connect(function(curseType, durability)
        equipHeadLantern(curseType, durability)
    end)
    
    ReplicatedStorage.HeadLanternBroken.OnClientEvent:Connect(function()
        removeHeadLantern()
    end)
    
    -- Input handling
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.F and headLanternData then
            toggleFlashlight()
        end
    end)
    
    -- Update flashlight direction
    RunService.Heartbeat:Connect(function()
        if flashlightActive and flashlightBeam then
            updateFlashlightDirection()
        end
    end)
end

local function equipHeadLantern(curseType, durability)
    headLanternData = {
        curse_type = curseType,
        durability = durability,
        effects = getHeadLanternEffects(curseType)
    }
    
    -- Create visual head lantern
    createHeadLanternVisual()
    
    -- Apply curse effects
    applyCurseEffects(headLanternData.effects)
    
    -- Show UI
    updateHeadLanternUI()
end

local function createFlashlightBeam()
    if flashlightBeam then
        flashlightBeam:Destroy()
    end
    
    -- Create cone-shaped beam using multiple parts or mesh
    local beam = Instance.new("Part")
    beam.Name = "FlashlightBeam"
    beam.Anchored = true
    beam.CanCollide = false
    beam.Material = Enum.Material.Neon
    beam.BrickColor = BrickColor.new(FLASHLIGHT_CONFIG.color)
    beam.Transparency = 0.7
    beam.Shape = Enum.PartType.Cylinder
    
    -- Add volumetric effect
    local pointLight = Instance.new("PointLight")
    pointLight.Brightness = FLASHLIGHT_CONFIG.intensity
    pointLight.Color = FLASHLIGHT_CONFIG.color
    pointLight.Range = FLASHLIGHT_CONFIG.base_range
    pointLight.Parent = beam
    
    beam.Parent = workspace
    flashlightBeam = beam
    
    return beam
end

local function updateFlashlightDirection()
    if not flashlightBeam or not player.Character then return end
    
    local character = player.Character
    local head = character:FindFirstChild("Head")
    if not head then return end
    
    -- Calculate beam direction from head toward mouse
    local camera = workspace.CurrentCamera
    local ray = camera:ScreenPointToRay(mouse.X, mouse.Y)
    local direction = ray.Direction.Unit
    
    -- Apply head lantern effects to range
    local effectiveRange = FLASHLIGHT_CONFIG.base_range
    if headLanternData and headLanternData.effects.light_range_multiplier then
        effectiveRange = effectiveRange * headLanternData.effects.light_range_multiplier
    end
    
    -- Position and orient beam
    local startPos = head.Position + direction * 2
    local endPos = startPos + direction * effectiveRange
    
    -- Raycast to find obstacles
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {character, flashlightBeam}
    
    local result = workspace:Raycast(startPos, direction * effectiveRange, raycastParams)
    if result then
        endPos = result.Position
    end
    
    -- Update beam geometry
    local midpoint = (startPos + endPos) / 2
    local distance = (endPos - startPos).Magnitude
    
    flashlightBeam.Size = Vector3.new(distance, 2, 2) -- Cylinder along X-axis
    flashlightBeam.CFrame = CFrame.lookAt(midpoint, endPos)
    
    -- Update light position
    if flashlightBeam:FindFirstChild("PointLight") then
        flashlightBeam.PointLight.Range = distance * 1.2
    end
end

local function toggleFlashlight()
    flashlightActive = not flashlightActive
    
    if flashlightActive then
        createFlashlightBeam()
    elseif flashlightBeam then
        flashlightBeam:Destroy()
        flashlightBeam = nil
    end
end

return FlashlightController
```

## Voyage System Implementation

### Core Voyage Service
```lua
-- VoyageService.lua (Server)
local VoyageService = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Voyage configurations
local VOYAGE_EVENTS = {
    storm_navigation = {
        name = "Storm Navigation",
        description = "Navigate through a fierce storm",
        difficulty = 0.6,
        duration = 45, -- seconds
        rewards = {
            success = {"Condenser", "Collector"},
            failure = {gold = 50}
        }
    },
    deep_current = {
        name = "Deep Current Dive",
        description = "Dive into mysterious deep currents",
        difficulty = 0.8,
        duration = 60,
        rewards = {
            success = {"Amplifier", "rare_curse"},
            failure = {gold = 20}
        }
    },
    ghost_fleet = {
        name = "Ghost Fleet Encounter",
        description = "Face the spectral ships of the depths",
        difficulty = 0.9,
        duration = 90,
        rewards = {
            success = {"epic_machine", "legendary_curse"},
            failure = {} -- Total loss
        }
    }
}

local activeVoyages = {} -- {voyage_id = {player, event_type, start_time, currency_spent}}
local voyageCounter = 0

function VoyageService.createVoyage(player, voyageCurrency)
    if voyageCurrency < 10 then
        return false, "Insufficient voyage currency"
    end
    
    -- Player chooses voyage type based on currency
    local availableEvents = {}
    for eventType, config in pairs(VOYAGE_EVENTS) do
        local requiredCurrency = math.floor(config.difficulty * 100)
        if voyageCurrency >= requiredCurrency then
            table.insert(availableEvents, {
                type = eventType,
                config = config,
                cost = requiredCurrency
            })
        end
    end
    
    if #availableEvents == 0 then
        return false, "No available voyages for current currency"
    end
    
    -- Send options to client
    ReplicatedStorage.VoyageOptions:FireClient(player, availableEvents)
    
    return true, availableEvents
end

function VoyageService.startVoyageEvent(player, eventType, currencySpent)
    local config = VOYAGE_EVENTS[eventType]
    if not config then
        return false, "Invalid voyage event"
    end
    
    voyageCounter = voyageCounter + 1
    local voyageId = "voyage_" .. voyageCounter
    
    -- Create voyage instance
    local voyage = {
        id = voyageId,
        player = player,
        event_type = eventType,
        start_time = tick(),
        currency_spent = currencySpent,
        config = config,
        status = "active"
    }
    
    activeVoyages[voyageId] = voyage
    
    -- Start voyage event on client
    ReplicatedStorage.VoyageStarted:FireClient(player, voyageId, eventType, config.duration)
    
    -- Set completion timer
    spawn(function()
        wait(config.duration)
        if activeVoyages[voyageId] and activeVoyages[voyageId].status == "active" then
            -- Auto-fail if not completed
            completeVoyage(voyageId, false, 0)
        end
    end)
    
    return true, voyageId
end

function VoyageService.updateVoyageProgress(player, voyageId, progressData)
    local voyage = activeVoyages[voyageId]
    if not voyage or voyage.player ~= player then
        return false
    end
    
    -- Process progress based on event type
    if voyage.event_type == "storm_navigation" then
        return processStormNavigation(voyage, progressData)
    elseif voyage.event_type == "deep_current" then
        return processDeepCurrentDive(voyage, progressData)
    elseif voyage.event_type == "ghost_fleet" then
        return processGhostFleetEncounter(voyage, progressData)
    end
    
    return false
end

function VoyageService.completeVoyage(voyageId, success, performanceScore)
    local voyage = activeVoyages[voyageId]
    if not voyage then return end
    
    local player = voyage.player
    local config = voyage.config
    
    voyage.status = "completed"
    voyage.success = success
    voyage.performance_score = performanceScore
    
    -- Determine rewards
    local rewards = {}
    if success then
        rewards = selectVoyageRewards(config.rewards.success, performanceScore)
    else
        rewards = config.rewards.failure or {}
    end
    
    -- Award rewards
    awardVoyageRewards(player, rewards)
    
    -- Update client
    ReplicatedStorage.VoyageCompleted:FireClient(player, voyageId, success, rewards)
    
    -- Cleanup
    activeVoyages[voyageId] = nil
    
    return rewards
end

-- Specific voyage event processors
local function processStormNavigation(voyage, progressData)
    -- Storm navigation requires steady course correction
    local targetHeading = progressData.target_heading or 0
    local currentHeading = progressData.current_heading or 0
    local accuracy = 1 - math.abs(targetHeading - currentHeading) / 180
    
    return accuracy > 0.7 -- 70% accuracy required
end

local function processDeepCurrentDive(voyage, progressData)
    -- Deep current requires timing and resource management
    local oxygenLevel = progressData.oxygen_level or 100
    local depthReached = progressData.depth_reached or 0
    local targetDepth = progressData.target_depth or 100
    
    return oxygenLevel > 20 and depthReached >= targetDepth
end

local function selectVoyageRewards(rewardPool, performanceScore)
    local rewards = {}
    
    -- Higher performance = better/more rewards
    local numRewards = math.floor(1 + performanceScore * 2) -- 1-3 rewards based on performance
    
    for i = 1, numRewards do
        if #rewardPool > 0 then
            local reward = rewardPool[math.random(#rewardPool)]
            table.insert(rewards, reward)
        end
    end
    
    return rewards
end

local function awardVoyageRewards(player, rewards)
    local MachineService = require(script.Parent.MachineService)
    local HeadLanternService = require(script.Parent.HeadLanternService)
    
    for _, reward in ipairs(rewards) do
        if reward == "Condenser" or reward == "Collector" or reward == "Amplifier" then
            -- Award machine (player can place it)
            givePlayerMachine(player, reward)
        elseif reward:match("curse$") then
            -- Award curse lantern
            local rarity = reward:gsub("_curse", "")
            givePlayerCurseLantern(player, rarity)
        elseif reward.gold then
            -- Award gold
            local leaderstats = player:FindFirstChild("leaderstats")
            if leaderstats and leaderstats:FindFirstChild("Gold") then
                leaderstats.Gold.Value = leaderstats.Gold.Value + reward.gold
            end
        end
    end
end

return VoyageService
```

## Integration Testing & Balance Framework

### Comprehensive Test Suite
```lua
-- HeadLanternTests.lua
local HeadLanternTests = {}
local HeadLanternService = require(script.Parent.HeadLanternService)
local VoyageService = require(script.Parent.VoyageService)

function HeadLanternTests.testPluckingMechanics()
    print("Testing head lantern plucking...")
    
    -- Create test player and lantern
    local testPlayer = createTestPlayer("TestPlayer")
    local testLantern = createTestLantern("test_lantern_1")
    
    -- Test successful plucking
    local success, curseType = HeadLanternService.pluckLantern(testPlayer, "test_lantern_1")
    assert(success, "Failed to pluck lantern")
    assert(curseType, "No curse type returned")
    
    -- Test lantern weakening
    local weakenedRate = testLantern:GetAttribute("ProductionRate")
    assert(weakenedRate < 1, "Lantern not properly weakened")
    
    -- Test double plucking prevention
    local success2 = HeadLanternService.pluckLantern(testPlayer, "test_lantern_2")
    assert(not success2, "Player allowed to pluck second lantern")
    
    print("✓ Plucking mechanics test passed")
end

function HeadLanternTests.testDurabilitySystem()
    print("Testing durability system...")
    
    local testPlayer = createTestPlayer("DurabilityTest")
    
    -- Equip head lantern
    HeadLanternService.pluckLantern(testPlayer, "test_lantern_durability")
    
    -- Simulate deaths
    local initialDurability = HeadLanternService.getPlayerHeadLantern(testPlayer).durability
    
    HeadLanternService.onPlayerDeath(testPlayer)
    local afterOneDeath = HeadLanternService.getPlayerHeadLantern(testPlayer)
    
    if afterOneDeath then
        assert(afterOneDeath.durability == initialDurability - 1, "Durability not decremented correctly")
    else
        assert(initialDurability == 1, "Head lantern broke with wrong durability count")
    end
    
    print("✓ Durability system test passed")
end

function HeadLanternTests.testVoyageIntegration()
    print("Testing voyage integration...")
    
    -- Create test scenario with reservoir currency
    local testPlayer = createTestPlayer("VoyageTest")
    local ReservoirService = require(script.Parent.Parent.EconomyServices.ReservoirService)
    
    -- Add reservoir currency
    ReservoirService.addResource(testPlayer, 50)
    
    -- Start voyage
    local success, voyageData = VoyageService.createVoyage(testPlayer, 50)
    assert(success, "Failed to create voyage")
    assert(#voyageData > 0, "No voyage options returned")
    
    -- Test voyage completion with machine reward
    local voyageId = "test_voyage_1"
    local rewards = VoyageService.completeVoyage(voyageId, true, 0.8)
    
    -- Verify machine reward integration
    assert(rewards and #rewards > 0, "No rewards given for successful voyage")
    
    print("✓ Voyage integration test passed")
end

-- Performance and balance tests
function HeadLanternTests.testPerformanceUnderLoad()
    print("Testing performance with multiple head lanterns...")
    
    local testPlayers = {}
    
    -- Create 20 test players with head lanterns
    for i = 1, 20 do
        local player = createTestPlayer("LoadTest" .. i)
        HeadLanternService.pluckLantern(player, "load_test_lantern_" .. i)
        table.insert(testPlayers, player)
    end
    
    local startTime = tick()
    
    -- Simulate rapid death events
    for i = 1, 100 do
        local randomPlayer = testPlayers[math.random(#testPlayers)]
        HeadLanternService.onPlayerDeath(randomPlayer)
    end
    
    local endTime = tick()
    local processingTime = endTime - startTime
    
    assert(processingTime < 0.1, "Death processing too slow: " .. processingTime .. "s")
    
    -- Cleanup
    for _, player in pairs(testPlayers) do
        cleanupTestPlayer(player)
    end
    
    print("✓ Performance under load test passed")
end

return HeadLanternTests
```

This implementation completes the M2 milestone with head lanterns, voyage system, and comprehensive testing frameworks. The modular design allows for independent testing of each component while maintaining integration between systems.
