--!strict

local Economy
if script and script.Parent then
    Economy = require(script.Parent:WaitForChild("Economy"))
else
    Economy = require("Economy")
end

local Aether = {}

Aether.callbacks = {
    onSettle = function() end,
    onProducerAdded = function() end,
    onProducerToggled = function() end,
}

local function now()
    if type(time) == "function" then
        return time()
    end
    return os.clock()
end

local function ensure(player)
    player.aether = player.aether or {}
    local a = player.aether
    a.current = a.current or 0
    a.target = a.target or 20
    a.decayRate = a.decayRate or 0.08
    a.purityBase = a.purityBase or 0.55
    a.totalRate = a.totalRate or 0
    a.lastSettleTs = a.lastSettleTs or now()
    player.producers = player.producers or {}
end

function Aether.Init(player)
    ensure(player)
    player.aether.lastSettleTs = now()
end

function Aether.Settle(player, tNow)
    ensure(player)
    local a = player.aether
    local t = tNow or now()
    local dt = t - (a.lastSettleTs or t)
    if dt <= 0 then
        a.lastSettleTs = t
        return
    end

    local current = a.current
    local target = a.target
    local rate = a.totalRate
    local k = a.decayRate
    local newCurrent = current

    if current < target then
        local inc = math.max(0, rate) * dt
        newCurrent = math.min(target, current + inc)
        if newCurrent >= target and current < target then
            a.hitCapacity = true
        end
    elseif current > target then
        local over = current - target
        local over2 = over * math.exp(-k * dt)
        newCurrent = target + over2
    end

    a.current = newCurrent
    a.lastSettleTs = t
    Aether.callbacks.onSettle(dt, (current < target and "fill" or current > target and "decay" or "idle"))
end

local uidCounter = 0
local function nextUid()
    uidCounter = uidCounter + 1
    return "prod_" .. tostring(uidCounter)
end

function Aether.AddProducer(player, kind, rate)
    ensure(player)
    local uid = nextUid()
    player.producers[uid] = { kind = kind, rate = rate, active = true }
    player.aether.totalRate = player.aether.totalRate + rate
    Aether.callbacks.onProducerAdded(kind, rate)
    return uid
end

function Aether.RemoveProducer(player, uid)
    ensure(player)
    local p = player.producers[uid]
    if not p then
        return false
    end
    if p.active then
        player.aether.totalRate = player.aether.totalRate - p.rate
    end
    player.producers[uid] = nil
    return true
end

function Aether.SetProducerActive(player, uid, active)
    ensure(player)
    local p = player.producers[uid]
    if not p then
        return false
    end
    if p.active == active then
        return true
    end
    p.active = active
    if active then
        player.aether.totalRate = player.aether.totalRate + p.rate
    else
        player.aether.totalRate = player.aether.totalRate - p.rate
    end
    Aether.callbacks.onProducerToggled(uid, active)
    return true
end

function Aether.ApplyBurst(player, amount)
    ensure(player)
    Aether.Settle(player)
    player.aether.current = player.aether.current + amount
end

function Aether.RequestSell(player)
    Aether.Settle(player)
    return Economy.SellAether(player)
end

function Aether.Snapshot(player)
    ensure(player)
    local a = player.aether
    local snap = {
        current = a.current,
        target = a.target,
        totalRate = a.totalRate,
        decayRate = a.decayRate,
        purityBase = a.purityBase,
        serverNow = now(),
        v = 1,
    }
    if a.hitCapacity then
        snap.atCap = true
        a.hitCapacity = nil
    end
    return snap
end

return Aether

