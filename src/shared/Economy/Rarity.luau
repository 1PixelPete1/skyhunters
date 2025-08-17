--!strict
-- Rarity utility functions. Maps rarity strings to growth multipliers used by
-- GrowthService when computing growth rate or total time.

local Rarity = {}

local multipliers = {
    Common = 1.00,
    Uncommon = 0.95,
    Rare = 0.90,
    Epic = 0.85,
    Legendary = 0.80,
}

function Rarity.GetGrowthMultiplier(rarity)
    return multipliers[rarity] or 1.0
end

return Rarity
