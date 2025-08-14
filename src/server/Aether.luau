local ok, ReplicatedStorage = pcall(function()
    return game:GetService("ReplicatedStorage")
end)
local okHttp, HttpServiceInst = pcall(function()
    return game:GetService("HttpService")
end)
local HttpService = okHttp and HttpServiceInst or {
    GenerateGUID = function()
        return tostring(math.random(1, 1e8))
    end
}

local Aether = {}

local InventoryBridge
if script and script.Parent then
    InventoryBridge = require(script.Parent:WaitForChild("InventoryBridge"))
else
    InventoryBridge = require("InventoryBridge")
end

local function MakeUid()
    return HttpService:GenerateGUID(false):sub(1, 8)
end

local function MakeDebugName(producerType, uid)
    return producerType .. "-" .. uid:sub(1, 3)
end

local function CalcEffectiveRate(producer)
    if not producer.active then
        return 0
    end
    local baseWithAdd = math.max(0, producer.baseRate + (producer.addBonus or 0))
    local multFactor = math.max(0, producer.multBonus or 1)
    return baseWithAdd * multFactor
end

function Aether.Settle(player, now)
    now = now or time()
    local aether = player.aether
    local dt = now - aether.lastSettleTs
    if dt < 0 then
        aether.lastSettleTs = now
        return
    end

    if dt <= 1e-4 then
        return
    end
    
    local current = aether.current
    local eff = Aether.GetEffectiveStats(player)
    local target = eff.target
    local rate = eff.totalRate

    if current >= target then
        local excess = current - target
        local decayed = excess * math.exp(-aether.decayRate * dt)
        current = target + decayed
    else
        current = math.min(target, current + rate * dt)
    end

    if aether.current < target and current == target then
        aether.hitCapacity = true
    end

    aether.current = current
    aether.lastSettleTs = now

    print("Settled aether for player", player.id, "- Current:", current, "Rate:", rate, "dt:", dt)
end

function Aether.RebuildTotalRate(player)
    local total = 0
    for _, producer in pairs(player.producers or {}) do
        total = total + CalcEffectiveRate(producer)
    end
    player.aether.totalRate = total
    return total
end

function Aether.GetBaseStats(player)
    local a = player.aether
    return {
        target = a.target,
        purityBase = a.purityBase,
        totalRate = a.totalRate,
    }
end

function Aether.GetEffectiveStats(player)
    local base = Aether.GetBaseStats(player)
    local mods = InventoryBridge.GetDerivedAetherModifiers(player)
    return {
        target = base.target + (mods.target_add or 0),
        purity = base.purityBase + (mods.purity_add or 0),
        totalRate = base.totalRate * (mods.rate_mult or 1),
    }
end

function Aether.Init(player)
    if not player.aether then
        player.aether = {
            current = 0,
            target = 20,
            decayRate = 0.08,
            purityBase = 0.55,
            totalRate = 0,
            lastSettleTs = time(),
        }
    end
    if not player.producers then
        player.producers = {}
    end
    
    Aether.RebuildTotalRate(player)
    Aether.Settle(player)
    
    return Aether.Snapshot(player)
end

function Aether.AddProducer(player, producerType, baseRate, patchId)
    Aether.Settle(player)
    
    baseRate = baseRate or (math.random() * 0.4 + 0.4)
    local uid = MakeUid()
    
    local producer = {
        uid = uid,
        type = producerType,
        debugName = MakeDebugName(producerType, uid),
        patch = patchId,
        baseRate = baseRate,
        addBonus = 0,
        multBonus = 1,
        active = true,
        tags = "",
    }
    
    player.producers[uid] = producer
    player.aether.totalRate = player.aether.totalRate + CalcEffectiveRate(producer)
    
    return uid, producer.debugName
end

function Aether.RemoveProducer(player, uid)
    Aether.Settle(player)
    
    local producer = player.producers[uid]
    if not producer then
        return false
    end
    
    player.aether.totalRate = player.aether.totalRate - CalcEffectiveRate(producer)
    player.producers[uid] = nil
    
    return true
end

function Aether.SetProducerActive(player, uid, active)
    Aether.Settle(player)
    
    local producer = player.producers[uid]
    if not producer then
        return false
    end
    
    local oldRate = CalcEffectiveRate(producer)
    producer.active = active
    local newRate = CalcEffectiveRate(producer)
    
    player.aether.totalRate = player.aether.totalRate + (newRate - oldRate)
    
    return true
end

function Aether.SetProducerRate(player, uid, baseRate, addBonus, multBonus)
    Aether.Settle(player)
    
    local producer = player.producers[uid]
    if not producer then
        return false
    end
    
    local oldRate = CalcEffectiveRate(producer)
    producer.baseRate = baseRate or producer.baseRate
    producer.addBonus = addBonus or producer.addBonus
    producer.multBonus = multBonus or producer.multBonus
    local newRate = CalcEffectiveRate(producer)
    
    player.aether.totalRate = player.aether.totalRate + (newRate - oldRate)
    
    return true
end

function Aether.ApplyBurst(player, value)
    Aether.Settle(player)
    player.aether.current = player.aether.current + value
end

function Aether.TryApplyInventoryBurst(player)
    local ok, burstValue = InventoryBridge.TryConsumeBurst(player, {})
    if ok and burstValue > 0 then
        Aether.ApplyBurst(player, burstValue)
        return true, burstValue
    end
    return false, 0
end

function Aether.RequestSell(player)
    Aether.Settle(player)
    local Economy
    if script and script.Parent then
        Economy = require(script.Parent:WaitForChild("Economy"))
    else
        Economy = require("Economy")
    end
    local gain = Economy.SellAether(player)
    return gain
end

function Aether.ApplyUpgrade(player, upgradeId)
    Aether.Settle(player)
    local Config
    if ReplicatedStorage then
        Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
    else
        Config = require("Config")
    end
    local upgrade = Config.UpgradeById[upgradeId]
    
    if not upgrade then
        return false
    end
    
    local aether = player.aether
    if upgrade.affects == "target" then
        aether.target = aether.target + upgrade.value
    elseif upgrade.affects == "purityBase" then
        aether.purityBase = aether.purityBase + upgrade.value
    elseif upgrade.affects == "decayRate" then
        aether.decayRate = aether.decayRate + upgrade.value
    end
    
    return true
end

function Aether.Snapshot(player)
    local eff = Aether.GetEffectiveStats(player)
    local snap = {
        current = player.aether.current,
        target = eff.target,
        totalRate = eff.totalRate,
        decayRate = player.aether.decayRate,
        purityBase = eff.purity,
        serverNow = time(),
        v = 1,
    }
    if player.aether.hitCapacity then
        snap.atCap = true
        player.aether.hitCapacity = nil
    end
    return snap
end

function Aether.ListProducers(player, filter)
    local producers = {}
    for uid, producer in pairs(player.producers or {}) do
        if not filter or producer.type:find(filter) or producer.debugName:find(filter) then
            table.insert(producers, {
                uid = uid,
                debugName = producer.debugName,
                type = producer.type,
                rate = CalcEffectiveRate(producer),
                active = producer.active,
            })
        end
    end
    
    table.sort(producers, function(a, b) return a.rate > b.rate end)
    
    return producers, player.aether.totalRate
end

return Aether
