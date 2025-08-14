local Config = {}

Config.ReasonWhitelist = {
    sell_aether = true,
    sell_item = true,
    purchase = true,
    refund = true,
    grant = true,
}

Config.SELL_MULT = 8

Config.ItemConfig = {
    { id = "shiny_pebble", displayName = "Shiny Pebble", sell_value = 10, stackable = true },
    { id = "copper_nugget", displayName = "Copper Nugget", sell_value = 20, stackable = true },
    { id = "silver_chunk", displayName = "Silver Chunk", sell_value = 50, stackable = true },
    { id = "gold_ingot", displayName = "Gold Ingot", sell_value = 100, stackable = true },
    { id = "polished_crystal", displayName = "Polished Crystal", sell_value = 150, stackable = true },
}

Config.ItemById = {}
for _, item in ipairs(Config.ItemConfig) do
    Config.ItemById[item.id] = item
end

Config.UpgradeConfig = {
    { id = "target_plus10", affects = "target", value = 10, cost = 100 },
    { id = "purity_plus005", affects = "purityBase", value = 0.05, cost = 200 },
    { id = "decay_minus001", affects = "decayRate", value = -0.01, cost = 150 },
}

Config.UpgradeById = {}
for _, up in ipairs(Config.UpgradeConfig) do
    Config.UpgradeById[up.id] = up
end

return Config
