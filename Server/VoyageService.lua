-- VoyageService.lua
-- Handles voyage initiation and machine rewards

local VoyageService = {}

-- Constants
local VOYAGE_DURATION = 30 -- seconds for a voyage
local MACHINE_TYPES = {
    Condenser = {
        Name = "Condenser",
        Rarity = {1, 2, 3}, -- Available in rarities
        RadiusMultiplier = {1.2, 1.35, 1.5},
        MaxStack = 3
    },
    Collector = {
        Name = "Collector", 
        Rarity = {2, 3, 4},
        GlobalMultiplier = {1.1, 1.2, 1.3},
        MaxStack = 5
    },
    Amplifier = {
        Name = "Amplifier",
        Rarity = {3, 4, 5},
        GenerationBonus = {0.05, 0.1, 0.15},
        MaxStack = 3
    }
}

-- Voyage loot tables
local LOOT_TABLES = {
    [1] = { -- 0-100 resources
        {Type = "Gold", Amount = {100, 500}, Weight = 60},
        {Type = "Machine", Machine = "Condenser", Rarity = 1, Weight = 30},
        {Type = "Nothing", Weight = 10}
    },
    [2] = { -- 100-500 resources
        {Type = "Gold", Amount = {500, 2000}, Weight = 40},
        {Type = "Machine", Machine = "Condenser", Rarity = {1, 2}, Weight = 30},
        {Type = "Machine", Machine = "Collector", Rarity = 2, Weight = 20},
        {Type = "LanternUpgrade", Weight = 10}
    },
    [3] = { -- 500+ resources
        {Type = "Gold", Amount = {2000, 10000}, Weight = 30},
        {Type = "Machine", Machine = "Collector", Rarity = {2, 3}, Weight = 25},
        {Type = "Machine", Machine = "Amplifier", Rarity = 3, Weight = 20},
        {Type = "Machine", Machine = "Condenser", Rarity = {2, 3}, Weight = 15},
        {Type = "RareLantern", Weight = 10}
    }
}

-- Active voyages
local activeVoyages = {} -- {playerId = {startTime, resourceAmount, plotId}}

function VoyageService:StartVoyage(player, plotId, resourceAmount)
    -- Check if already on voyage
    if activeVoyages[player.UserId] then
        return false, "Voyage already in progress"
    end
    
    -- Validate resources (handled by LanternService)
    
    -- Start voyage
    activeVoyages[player.UserId] = {
        startTime = tick(),
        resourceAmount = resourceAmount,
        plotId = plotId,
        tier = self:GetLootTier(resourceAmount)
    }
    
    -- Schedule completion
    task.wait(VOYAGE_DURATION)
    self:CompleteVoyage(player)
    
    return true
end

function VoyageService:CompleteVoyage(player)
    local voyage = activeVoyages[player.UserId]
    if not voyage then return end
    
    -- Roll loot
    local rewards = self:RollRewards(voyage.tier)
    
    -- Grant rewards
    self:GrantRewards(player, rewards)
    
    -- Clean up
    activeVoyages[player.UserId] = nil
    
    return rewards
end

function VoyageService:CancelVoyage(player)
    if activeVoyages[player.UserId] then
        activeVoyages[player.UserId] = nil
        return true
    end
    return false
end

function VoyageService:GetLootTier(resourceAmount)
    if resourceAmount < 100 then
        return 1
    elseif resourceAmount < 500 then
        return 2
    else
        return 3
    end
end

function VoyageService:RollRewards(tier)
    local lootTable = LOOT_TABLES[tier]
    local totalWeight = 0
    
    for _, entry in ipairs(lootTable) do
        totalWeight = totalWeight + entry.Weight
    end
    
    local roll = math.random() * totalWeight
    local currentWeight = 0
    
    for _, entry in ipairs(lootTable) do
        currentWeight = currentWeight + entry.Weight
        if roll <= currentWeight then
            return self:GenerateReward(entry)
        end
    end
    
    return {Type = "Nothing"}
end

function VoyageService:GenerateReward(entry)
    local reward = {Type = entry.Type}
    
    if entry.Type == "Gold" then
        reward.Amount = math.random(entry.Amount[1], entry.Amount[2])
    elseif entry.Type == "Machine" then
        reward.Machine = entry.Machine
        if type(entry.Rarity) == "table" then
            reward.Rarity = entry.Rarity[math.random(#entry.Rarity)]
        else
            reward.Rarity = entry.Rarity
        end
    elseif entry.Type == "LanternUpgrade" then
        reward.UpgradeType = "RandomStat"
        reward.Multiplier = 1.2
    elseif entry.Type == "RareLantern" then
        reward.LanternRarity = math.random(3, 4)
    end
    
    return reward
end

function VoyageService:GrantRewards(player, rewards)
    -- Implementation depends on your inventory/economy system
    -- This would interface with ProfileService, inventory management, etc.
    
    print(player.Name .. " received:", rewards)
end

return VoyageService