--!strict

local Config
if script and script.Parent then
    Config = require(script.Parent.Parent.Parent.shared.Config)
else
    Config = require("Config")
end

local Economy = {}

local function now()
    if type(time) == "function" then
        return time()
    end
    return os.clock()
end

local function ensure(player)
    player.crumbs = player.crumbs or 0
    player.inventory = player.inventory or {}
    player.upgrades = player.upgrades or {}
    player.aether = player.aether or { current = 0, target = 20, decayRate = 0.08, purityBase = 0.55 }
    player.timestamps = player.timestamps or {}
end

local function withinRateLimit(player)
    local cfg = Config.Economy
    local window = cfg.CRUMBS_RATE_LIMIT_WINDOW_SEC
    local nowTs = now()
    local ts = player.timestamps
    local j, n = 1, #ts
    for i = 1, n do
        if nowTs - ts[i] <= window then
            ts[j] = ts[i]
            j = j + 1
        end
    end
    for k = j, n do
        ts[k] = nil
    end
    if #ts >= cfg.CRUMBS_RATE_LIMIT_WINDOW_N then
        return false
    end
    ts[#ts + 1] = nowTs
    return true
end

function Economy.ApplyCrumbsDelta(player, delta, reason)
    ensure(player)
    local cfg = Config.Economy
    if not cfg.REASONS[reason] then
        return false
    end
    if not withinRateLimit(player) then
        return false
    end
    player.crumbs = player.crumbs + delta
    return true
end

function Economy.SellAether(player)
    ensure(player)
    local cfg = Config.Economy
    local a = player.aether
    local gain = math.floor((a.current or 0) * (a.purityBase or 0.55) * cfg.AETHER_PER_UNIT_PRICE)
    a.current = 0
    if gain <= 0 then
        return 0
    end
    if Economy.ApplyCrumbsDelta(player, gain, "sell_aether") then
        return gain
    end
    return 0
end

function Economy.SellItem(player, itemId, count)
    ensure(player)
    local cfg = Config.Economy
    count = math.max(0, math.floor(count or 0))
    if count == 0 then
        return 0
    end
    local itemCfg = cfg.Items[itemId]
    if not itemCfg then
        return 0
    end
    local inv = player.inventory
    local have = inv[itemId] or 0
    if have < count then
        return 0
    end
    local gain = itemCfg.price * count
    inv[itemId] = have - count
    if Economy.ApplyCrumbsDelta(player, gain, "sell_item") then
        return gain
    else
        inv[itemId] = have
        return 0
    end
end

function Economy.PurchaseUpgrade(player, upgradeId)
    ensure(player)
    local cfg = Config.Economy
    local up = cfg.Upgrades[upgradeId]
    if not up then
        return false
    end
    if player.upgrades[upgradeId] then
        return false
    end
    if player.crumbs < up.cost then
        return false
    end
    if not Economy.ApplyCrumbsDelta(player, -up.cost, "grant") then
        return false
    end
    player.upgrades[upgradeId] = true
    player.aether.purityBase = (player.aether.purityBase or 0.55) + (up.purityDelta or 0)
    return true
end

return Economy

