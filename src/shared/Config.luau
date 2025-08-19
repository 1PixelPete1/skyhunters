--!strict

local Config = {}

Config.Economy = {
    AETHER_PER_UNIT_PRICE = 8,
    CRUMBS_RATE_LIMIT_WINDOW_N = 10,
    CRUMBS_RATE_LIMIT_WINDOW_SEC = 60,
    REASONS = {
        grant = true,
        purchase_refund = true,
        sell_aether = true,
        sell_item = true,
    },
    Items = {
        polished_crystal = { price = 150 },
    },
    Upgrades = {
        purity_plus005 = { cost = 200, purityDelta = 0.05 },
    },
}

return Config

