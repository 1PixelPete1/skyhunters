local ok, Config = pcall(function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    return require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
end)
if not ok then
    Config = require("Config")
end

local okAether, Aether = pcall(function()
    if script and script.Parent then
        return require(script.Parent:WaitForChild("Aether"))
    else
        return require("Aether")
    end
end)
if not okAether then
    Aether = require("Aether")
end

local MAX_DELTA = 1e9
local RATE_WINDOW = 5
local RATE_MAX = 10

local rateLimits = {}
local lastAetherSell = {}

local function clamp(value, min, max)
    if value < min then
        return min
    end
    if value > max then
        return max
    end
    return value
end

local Economy = {}

function Economy.ApplyCrumbsDelta(player, delta, reason)
    if not Config.ReasonWhitelist[reason] then
        return false
    end
    if math.abs(delta) > MAX_DELTA then
        return false
    end
    local now = os.clock()
    local bucket = rateLimits[player] or {}
    local newBucket = {}
    for _, t in ipairs(bucket) do
        if now - t < RATE_WINDOW then
            table.insert(newBucket, t)
        end
    end
    if #newBucket >= RATE_MAX then
        rateLimits[player] = newBucket
        return false
    end
    table.insert(newBucket, now)
    rateLimits[player] = newBucket

    player.crumbs = (player.crumbs or 0) + delta
    print("ApplyCrumbsDelta", player.id or "unknown", delta, reason)
    return true
end

function Economy.SellAether(player)
    local aether = player.aether or {}
    local current = aether.current or 0
    if current <= 0 then
        return 0
    end
    local now = os.clock()
    local last = lastAetherSell[player]
    if last and now - last < 0.5 then
        return 0
    end
    local stats = Aether.GetEffectiveStats(player)
    local purity = clamp(stats.purity, 0.10, 1.00)
    local gain = math.floor(current * purity * Config.SELL_MULT)
    if gain <= 0 then
        return 0
    end
    local success = Economy.ApplyCrumbsDelta(player, gain, "sell_aether")
    if success then
        aether.current = 0
        aether.lastSettleTs = time()
        lastAetherSell[player] = now
        return gain
    end
    return 0
end

function Economy.SellItem(player, itemId, qty)
    if qty <= 0 then
        return 0
    end
    local item = Config.ItemById[itemId]
    if not item then
        return 0
    end
    local inv = player.inventory or {}
    local have = inv[itemId] or 0
    if have < qty then
        return 0
    end
    local gain = item.sell_value * qty
    inv[itemId] = have - qty
    local success = Economy.ApplyCrumbsDelta(player, gain, "sell_item")
    if not success then
        inv[itemId] = have
        return 0
    end
    return gain
end

function Economy.PurchaseUpgrade(player, upgradeId)
    local upgrade = Config.UpgradeById[upgradeId]
    if not upgrade then
        return false
    end
    local prereq = upgrade.prereq
    if prereq and not player.upgrades[prereq] then
        return false
    end
    if player.upgrades[upgradeId] then
        return false
    end
    local cost = upgrade.cost
    if player.crumbs < cost then
        return false
    end
    local ok = Economy.ApplyCrumbsDelta(player, -cost, "purchase")
    if not ok then
        return false
    end
    local aether = player.aether
    if upgrade.affects == "target" then
        aether.target = (aether.target or 0) + upgrade.value
    elseif upgrade.affects == "purityBase" then
        aether.purityBase = (aether.purityBase or 0) + upgrade.value
    elseif upgrade.affects == "decayRate" then
        aether.decayRate = (aether.decayRate or 0) + upgrade.value
    end
    player.upgrades[upgradeId] = true
    return true
end

return Economy
