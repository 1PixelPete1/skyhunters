# Technical Implementation Guide - Lantern Industry & Economics

## Reservoir System Architecture

### Core Economic Engine
```lua
-- ReservoirService.lua (Server)
local ReservoirService = {}
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

-- Configuration
local RESERVOIR_CONFIG = {
    MAX_CAPACITY = 100, -- 100% is the soft cap
    DEPRECIATION_CURVE = {
        -- Piecewise function for diminishing returns past 100%
        {threshold = 100, multiplier = 1.0},
        {threshold = 150, multiplier = 0.8},
        {threshold = 200, multiplier = 0.6},
        {threshold = 300, multiplier = 0.4},
        {threshold = math.huge, multiplier = 0.2}
    },
    GOLD_CONVERSION_RATE = 10, -- 1 reservoir unit = 10 gold base
    UPDATE_INTERVAL = 1 -- seconds
}

-- Global state
local reservoirData = {
    totalLevel = 0,
    lastUpdate = tick(),
    contributorData = {}, -- {player_id = {contribution, lastContribution}}
    machineMultipliers = {} -- {position = {type, multiplier, radius}}
}

-- Data persistence
local ReservoirDataStore = DataStoreService:GetDataStore("ReservoirSystem")

function ReservoirService.initialize()
    -- Load persistent reservoir data
    local success, data = pcall(function()
        return ReservoirDataStore:GetAsync("GlobalReservoir")
    end)
    
    if success and data then
        reservoirData.totalLevel = data.totalLevel or 0
        reservoirData.contributorData = data.contributorData or {}
    end
    
    -- Start update cycle
    RunService.Heartbeat:Connect(function()
        local now = tick()
        if now - reservoirData.lastUpdate >= RESERVOIR_CONFIG.UPDATE_INTERVAL then
            ReservoirService.updateReservoir()
            reservoirData.lastUpdate = now
        end
    end)
end

function ReservoirService.addResource(player, amount, sourcePosition)
    local playerId = tostring(player.UserId)
    
    -- Apply machine multipliers if near source
    local multipliedAmount = amount
    if sourcePosition then
        local multiplier = calculateMultiplierAtPosition(sourcePosition)
        multipliedAmount = amount * multiplier
    end
    
    -- Update reservoir
    reservoirData.totalLevel = reservoirData.totalLevel + multipliedAmount
    
    -- Track player contribution
    if not reservoirData.contributorData[playerId] then
        reservoirData.contributorData[playerId] = {contribution = 0, lastContribution = 0}
    end
    
    reservoirData.contributorData[playerId].contribution = 
        reservoirData.contributorData[playerId].contribution + multipliedAmount
    reservoirData.contributorData[playerId].lastContribution = tick()
    
    -- Notify clients of reservoir update
    game.ReplicatedStorage.ReservoirUpdate:FireAllClients(
        reservoirData.totalLevel, 
        getReservoirPercentage()
    )
    
    return multipliedAmount -- Return actual amount added after multipliers
end

function ReservoirService.sellReservoir(player, percentage)
    percentage = math.clamp(percentage or 100, 0, 100)
    local playerId = tostring(player.UserId)
    
    if not reservoirData.contributorData[playerId] then
        return 0 -- No contribution to sell
    end
    
    local playerContribution = reservoirData.contributorData[playerId].contribution
    local sellAmount = (playerContribution * percentage) / 100
    
    -- Calculate gold value with depreciation
    local goldValue = calculateDepreciatedValue(sellAmount)
    
    -- Update reservoir and player data
    reservoirData.totalLevel = math.max(0, reservoirData.totalLevel - sellAmount)
    reservoirData.contributorData[playerId].contribution = playerContribution - sellAmount
    
    -- Award gold to player
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats and leaderstats:FindFirstChild("Gold") then
        leaderstats.Gold.Value = leaderstats.Gold.Value + goldValue
    end
    
    -- Save updated data
    saveReservoirData()
    
    return goldValue
end

function ReservoirService.startVoyage(player)
    local playerId = tostring(player.UserId)
    
    if not reservoirData.contributorData[playerId] then
        return false, "No reservoir contribution to convert"
    end
    
    local contribution = reservoirData.contributorData[playerId].contribution
    if contribution < 10 then -- Minimum voyage requirement
        return false, "Insufficient reservoir level for voyage"
    end
    
    -- Convert reservoir to voyage currency
    local voyageCurrency = math.floor(contribution / 2) -- 2:1 conversion rate
    
    -- Empty player's reservoir contribution
    reservoirData.totalLevel = reservoirData.totalLevel - contribution
    reservoirData.contributorData[playerId].contribution = 0
    
    -- Start voyage instance (handled by VoyageService)
    local VoyageService = require(script.Parent.VoyageService)
    return VoyageService.createVoyage(player, voyageCurrency)
end

-- Helper functions
local function calculateMultiplierAtPosition(position)
    local totalMultiplier = 1.0
    
    for machinePos, machineData in pairs(reservoirData.machineMultipliers) do
        local distance = (position - machinePos).Magnitude
        if distance <= machineData.radius then
            -- Apply machine effect with distance falloff
            local falloff = math.max(0.5, 1 - (distance / machineData.radius))
            totalMultiplier = totalMultiplier + (machineData.multiplier - 1) * falloff
        end
    end
    
    return totalMultiplier
end

local function calculateDepreciatedValue(amount)
    local baseValue = amount * RESERVOIR_CONFIG.GOLD_CONVERSION_RATE
    local currentPercentage = getReservoirPercentage()
    
    -- No depreciation under 100%
    if currentPercentage <= 100 then
        return baseValue
    end
    
    -- Apply depreciation curve
    local multiplier = 1.0
    for _, curve in ipairs(RESERVOIR_CONFIG.DEPRECIATION_CURVE) do
        if currentPercentage >= curve.threshold then
            multiplier = curve.multiplier
        else
            break
        end
    end
    
    return math.floor(baseValue * multiplier)
end

local function getReservoirPercentage()
    return (reservoirData.totalLevel / RESERVOIR_CONFIG.MAX_CAPACITY) * 100
end

-- Data persistence
local function saveReservoirData()
    spawn(function()
        pcall(function()
            ReservoirDataStore:SetAsync("GlobalReservoir", {
                totalLevel = reservoirData.totalLevel,
                contributorData = reservoirData.contributorData,
                lastSave = tick()
            })
        end)
    end)
end

return ReservoirService
```

## Machine System Implementation

### Machine Management & Effects
```lua
-- MachineService.lua (Server)
local MachineService = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

-- Machine configurations
local MACHINE_TYPES = {
    Condenser = {
        baseMultiplier = 1.3,
        radius = 15,
        maxLevel = 5,
        cost = {base = 50, scaling = 1.5}, -- Cost increases exponentially
        description = "Increases lantern resource generation in radius"
    },
    Collector = {
        baseMultiplier = 1.2,
        radius = 25,
        maxLevel = 3,
        cost = {base = 75, scaling = 2.0},
        description = "Collects resources from distant lanterns"
    },
    Amplifier = {
        baseMultiplier = 1.1,
        radius = 50, -- Global effect
        maxLevel = 10,
        cost = {base = 100, scaling = 1.8},
        description = "Provides global resource amplification"
    }
}

-- Global machine registry
local placedMachines = {} -- {machine_id = {type, position, level, owner, effects}}
local machineCounter = 0

function MachineService.placeMachine(player, machineType, position, level)
    level = level or 1
    
    if not MACHINE_TYPES[machineType] then
        return false, "Invalid machine type"
    end
    
    local config = MACHINE_TYPES[machineType]
    if level > config.maxLevel then
        return false, "Level exceeds maximum"
    end
    
    -- Calculate cost
    local cost = math.floor(config.cost.base * (config.cost.scaling ^ (level - 1)))
    
    -- Check if player can afford it (implementation depends on your currency system)
    if not canAffordMachine(player, cost) then
        return false, "Insufficient funds"
    end
    
    -- Check placement restrictions (distance from other machines, etc.)
    if not isValidPlacement(position, machineType) then
        return false, "Invalid placement location"
    end
    
    -- Create machine
    machineCounter = machineCounter + 1
    local machineId = "machine_" .. machineCounter
    
    placedMachines[machineId] = {
        type = machineType,
        position = position,
        level = level,
        owner = player.UserId,
        effects = calculateMachineEffects(machineType, level),
        placedTime = tick()
    }
    
    -- Deduct cost and create physical representation
    deductMachineCost(player, cost)
    createMachineModel(machineId, machineType, position, level)
    
    -- Update reservoir multipliers
    updateReservoirMultipliers()
    
    return true, machineId
end

function MachineService.upgradeMachine(player, machineId)
    local machine = placedMachines[machineId]
    if not machine or machine.owner ~= player.UserId then
        return false, "Machine not found or not owned"
    end
    
    local config = MACHINE_TYPES[machine.type]
    local newLevel = machine.level + 1
    
    if newLevel > config.maxLevel then
        return false, "Machine already at maximum level"
    end
    
    -- Calculate upgrade cost
    local cost = math.floor(config.cost.base * (config.cost.scaling ^ (newLevel - 1)) * 0.7) -- 70% of full cost
    
    if not canAffordMachine(player, cost) then
        return false, "Insufficient funds for upgrade"
    end
    
    -- Perform upgrade
    machine.level = newLevel
    machine.effects = calculateMachineEffects(machine.type, newLevel)
    
    deductMachineCost(player, cost)
    updateMachineModel(machineId, newLevel)
    updateReservoirMultipliers()
    
    return true, newLevel
end

-- Helper functions
local function calculateMachineEffects(machineType, level)
    local config = MACHINE_TYPES[machineType]
    local baseMultiplier = config.baseMultiplier
    
    -- Diminishing returns on level scaling
    local levelMultiplier = 1 + (level - 1) * 0.1 / math.sqrt(level)
    local finalMultiplier = 1 + (baseMultiplier - 1) * levelMultiplier
    
    return {
        resourceMultiplier = finalMultiplier,
        radius = config.radius * (1 + (level - 1) * 0.1), -- Slight radius increase per level
        level = level
    }
end

local function calculateStackingBonus(machinesInRadius)
    -- Multiple machines of same type have diminishing returns
    local typeCount = {}
    
    for _, machine in pairs(machinesInRadius) do
        typeCount[machine.type] = (typeCount[machine.type] or 0) + 1
    end
    
    local totalBonus = 1.0
    for machineType, count in pairs(typeCount) do
        local config = MACHINE_TYPES[machineType]
        -- Diminishing returns: 100%, 70%, 50%, 35%, 25%...
        local stackingBonus = 0
        for i = 1, count do
            stackingBonus = stackingBonus + (config.baseMultiplier - 1) / math.sqrt(i)
        end
        totalBonus = totalBonus + stackingBonus
    end
    
    return totalBonus
end

local function updateReservoirMultipliers()
    local ReservoirService = require(script.Parent.ReservoirService)
    local multipliers = {}
    
    for machineId, machine in pairs(placedMachines) do
        multipliers[machine.position] = {
            type = machine.type,
            multiplier = machine.effects.resourceMultiplier,
            radius = machine.effects.radius
        }
    end
    
    ReservoirService.setMachineMultipliers(multipliers)
end

return MachineService
```

## Lantern Visual System

### Fruit Growth & Opal Burst Effects
```lua
-- LanternVisualController.lua (Client)
local LanternVisualController = {}
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Visual states for lantern fruit
local FRUIT_STATES = {
    empty = {scale = 0, transparency = 1, color = Color3.new(0.5, 0.5, 0.5)},
    growing = {scale = 0.5, transparency = 0.7, color = Color3.new(0.8, 0.6, 0.4)},
    mature = {scale = 1, transparency = 0.2, color = Color3.new(1, 0.9, 0.6)},
    opal = {scale = 1.2, transparency = 0, color = Color3.new(0.9, 0.95, 1)}
}

local lanternVisuals = {} -- {lantern_id = {fruit, particles, state}}

-- Initialize visual system
function LanternVisualController.initialize()
    -- Listen for reservoir updates
    ReplicatedStorage.ReservoirUpdate.OnClientEvent:Connect(function(totalLevel, percentage)
        updateAllLanternVisuals(percentage)
    end)
    
    -- Listen for individual lantern updates
    ReplicatedStorage.LanternUpdate.OnClientEvent:Connect(function(lanternId, newState, data)
        updateLanternVisual(lanternId, newState, data)
    end)
end

function LanternVisualController.updateLanternVisual(lanternId, state, data)
    local lantern = workspace.Lanterns:FindFirstChild("Lantern_" .. lanternId)
    if not lantern then return end
    
    -- Get or create visual elements
    local visualData = getOrCreateVisualElements(lantern, lanternId)
    
    if state == "fruit_growth" then
        animateFruitGrowth(visualData, data.growthPercentage)
    elseif state == "opal_burst" then
        playOpalBurstEffect(visualData, data.currency)
    elseif state == "plucked" then
        showPluckedState(visualData)
    elseif state == "regrowing" then
        animateRegrowth(visualData, data.regrowthPercentage)
    end
    
    lanternVisuals[lanternId] = visualData
end

local function animateFruitGrowth(visualData, growthPercentage)
    local targetState = FRUIT_STATES.growing
    if growthPercentage >= 100 then
        targetState = FRUIT_STATES.mature
    elseif growthPercentage <= 0 then
        targetState = FRUIT_STATES.empty
    end
    
    -- Smooth transition to new state
    local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    
    local scaleTween = TweenService:Create(
        visualData.fruit,
        tweenInfo,
        {Size = Vector3.new(1,1,1) * targetState.scale}
    )
    
    local transparencyTween = TweenService:Create(
        visualData.fruit,
        tweenInfo,
        {Transparency = targetState.transparency}
    )
    
    local colorTween = TweenService:Create(
        visualData.fruit.Material, -- Assuming neon or similar
        tweenInfo,
        {Color = targetState.color}
    )
    
    scaleTween:Play()
    transparencyTween:Play()
    colorTween:Play()
    
    -- Update glow effect
    if visualData.glowEffect then
        local glowTween = TweenService:Create(
            visualData.glowEffect,
            tweenInfo,
            {Brightness = targetState.scale * 2}
        )
        glowTween:Play()
    end
end

local function playOpalBurstEffect(visualData, currencyAmount)
    -- Pre-burst: Scale up fruit to opal state
    local opalState = FRUIT_STATES.opal
    local prepTween = TweenService:Create(
        visualData.fruit,
        TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {
            Size = Vector3.new(1,1,1) * opalState.scale,
            Transparency = opalState.transparency
        }
    )
    
    prepTween:Play()
    prepTween.Completed:Connect(function()
        -- Burst effect
        createOpalParticles(visualData.fruit.Position, currencyAmount)
        
        -- Scale down fruit to empty state
        local burstTween = TweenService:Create(
            visualData.fruit,
            TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
            {
                Size = Vector3.new(1,1,1) * 0.1,
                Transparency = 1
            }
        )
        burstTween:Play()
    end)
end

local function createOpalParticles(position, amount)
    -- Create temporary particle emitter
    local emitter = Instance.new("Attachment")
    emitter.Position = position
    emitter.Parent = workspace
    
    local particles = Instance.new("ParticleEmitter")
    particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    particles.Color = ColorSequence.new(Color3.new(0.9, 0.95, 1))
    particles.Rate = math.min(amount * 10, 200) -- Scale with currency amount
    particles.Lifetime = NumberRange.new(1, 2)
    particles.Speed = NumberRange.new(5, 15)
    particles.Parent = emitter
    
    -- Burst duration based on currency amount
    local duration = math.min(amount * 0.1, 3)
    
    game:GetService("Debris"):AddItem(emitter, duration + 2)
    
    -- Stop emission after burst
    wait(duration)
    particles.Enabled = false
end

-- Performance optimization: Update visuals in batches
local visualUpdateQueue = {}
local BATCH_SIZE = 5
local batchUpdateRunning = false

local function processBatchUpdates()
    if batchUpdateRunning or #visualUpdateQueue == 0 then return end
    
    batchUpdateRunning = true
    
    for i = 1, math.min(BATCH_SIZE, #visualUpdateQueue) do
        local update = table.remove(visualUpdateQueue, 1)
        if update then
            LanternVisualController.updateLanternVisual(
                update.lanternId, 
                update.state, 
                update.data
            )
        end
    end
    
    batchUpdateRunning = false
    
    -- Continue processing if more updates remain
    if #visualUpdateQueue > 0 then
        wait(0.1) -- Small delay to prevent frame drops
        processBatchUpdates()
    end
end

-- Auto-process batch updates
RunService.Heartbeat:Connect(function()
    if #visualUpdateQueue > 0 and not batchUpdateRunning then
        processBatchUpdates()
    end
end)

return LanternVisualController
```

This economic system implementation provides the foundation for M1 development, focusing on reservoir management, machine effects, and visual feedback systems. The modular design allows for easy testing and gradual feature rollout.
