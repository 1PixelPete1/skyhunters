-- HeadLanternService.lua
-- Manages head lantern plucking, curses, and durability

local HeadLanternService = {}

-- Curse definitions with buffs/debuffs
local CURSES = {
    Greed = {
        Name = "Curse of Greed",
        BuffMultiplier = {Gold = 1.5},
        DebuffMultiplier = {Speed = 0.8},
        Description = "+50% Gold, -20% Movement Speed"
    },
    Shadow = {
        Name = "Shadow's Embrace", 
        BuffMultiplier = {Stealth = 2.0, Speed = 1.2},
        DebuffMultiplier = {MaxHealth = 0.7},
        Description = "Harder to detect, +20% Speed, -30% Health"
    },
    Radiance = {
        Name = "Radiant Overflow",
        BuffMultiplier = {LightRadius = 2.0, Generation = 1.3},
        DebuffMultiplier = {Defense = 0.6},
        Description = "Double light radius, +30% Generation, -40% Defense"
    },
    Fortune = {
        Name = "Fortune's Gamble",
        BuffMultiplier = {VoyageRewards = 2.0},
        DebuffMultiplier = {VoyageChance = 0.5},
        Description = "Double voyage rewards, 50% voyage failure chance"
    },
    Harvest = {
        Name = "Bountiful Harvest",
        BuffMultiplier = {FruitGrowth = 1.5, BurstValue = 1.3},
        DebuffMultiplier = {LanternRange = 0.7},
        Description = "+50% Fruit growth, +30% Burst value, -30% Lantern range"
    }
}

-- Active head lanterns
local activeHeadLanterns = {} -- {playerId = {lanternId, curse, rarity, durability, deathsRemaining}}

function HeadLanternService:PluckLantern(player, plotId, lanternId)
    -- Get lantern data from LanternService
    local lanternData = self:GetLanternData(plotId, lanternId)
    if not lanternData then return false, "Lantern not found" end
    
    -- Check if player already has head lantern
    if activeHeadLanterns[player.UserId] then
        return false, "Already have a head lantern equipped"
    end
    
    -- Apply penalty to source lantern
    self:ApplyPluckPenalty(plotId, lanternId)
    
    -- Roll random curse
    local curseKeys = {}
    for key, _ in pairs(CURSES) do
        table.insert(curseKeys, key)
    end
    local selectedCurse = curseKeys[math.random(#curseKeys)]
    
    -- Calculate durability based on rarity
    local durability = lanternData.rarity or 1 -- Deaths before breaking
    
    -- Equip head lantern
    activeHeadLanterns[player.UserId] = {
        lanternId = lanternId,
        sourcePlot = plotId,
        curse = selectedCurse,
        rarity = lanternData.rarity,
        durability = durability,
        deathsRemaining = durability,
        stats = {
            lightRadius = 20 + (lanternData.rarity * 10),
            lightBrightness = 1 + (lanternData.rarity * 0.5)
        }
    }
    
    -- Apply curse effects
    self:ApplyCurseEffects(player, selectedCurse)
    
    return true, CURSES[selectedCurse]
end

function HeadLanternService:ApplyPluckPenalty(plotId, lanternId)
    -- Reduce lantern effectiveness temporarily
    -- This interfaces with LanternService
    local penalty = {
        rangeMultiplier = 0.5,
        generationMultiplier = 0.5,
        regrowTime = 300 -- 5 minutes to regrow
    }
    
    -- Store penalty with timestamp
    -- LanternService handles the actual application
    return penalty
end

function HeadLanternService:ApplyCurseEffects(player, curseType)
    local curse = CURSES[curseType]
    if not curse then return end
    
    local character = player.Character
    if not character then return end
    
    -- Apply buffs
    for stat, multiplier in pairs(curse.BuffMultiplier) do
        self:ApplyStatModifier(player, stat, multiplier, "Buff")
    end
    
    -- Apply debuffs
    for stat, multiplier in pairs(curse.DebuffMultiplier) do
        self:ApplyStatModifier(player, stat, multiplier, "Debuff")
    end
end

function HeadLanternService:ApplyStatModifier(player, stat, multiplier, modType)
    -- Implementation depends on your stat system
    -- Examples:
    if stat == "Speed" then
        local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = humanoid.WalkSpeed * multiplier
        end
    elseif stat == "MaxHealth" then
        local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.MaxHealth = humanoid.MaxHealth * multiplier
            humanoid.Health = humanoid.Health * multiplier
        end
    elseif stat == "Gold" then
        -- Store multiplier for economic calculations
        player:SetAttribute("GoldMultiplier", multiplier)
    elseif stat == "LightRadius" then
        -- Apply to head lantern light
        local headLantern = activeHeadLanterns[player.UserId]
        if headLantern then
            headLantern.stats.lightRadius = headLantern.stats.lightRadius * multiplier
        end
    end
    -- Add more stat applications as needed
end

function HeadLanternService:OnPlayerDeath(player)
    local headLantern = activeHeadLanterns[player.UserId]
    if not headLantern then return end
    
    -- Reduce durability
    headLantern.deathsRemaining = headLantern.deathsRemaining - 1
    
    if headLantern.deathsRemaining <= 0 then
        -- Break head lantern
        self:RemoveHeadLantern(player)
        
        -- Notify player
        return true, "Head lantern broke!"
    else
        -- Lantern survives
        return false, headLantern.deathsRemaining .. " deaths remaining"
    end
end

function HeadLanternService:RemoveHeadLantern(player)
    local headLantern = activeHeadLanterns[player.UserId]
    if not headLantern then return end
    
    -- Remove curse effects
    self:RemoveCurseEffects(player, headLantern.curse)
    
    -- Clear data
    activeHeadLanterns[player.UserId] = nil
end

function HeadLanternService:RemoveCurseEffects(player, curseType)
    -- Reset all modified stats
    -- This is the inverse of ApplyCurseEffects
    
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            -- Reset to defaults (you'd store originals ideally)
            humanoid.WalkSpeed = 16
            humanoid.MaxHealth = 100
        end
    end
    
    -- Clear attributes
    player:SetAttribute("GoldMultiplier", nil)
end

function HeadLanternService:GetHeadLanternData(player)
    return activeHeadLanterns[player.UserId]
end

return HeadLanternService