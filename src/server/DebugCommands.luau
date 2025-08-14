local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerManager = require(script.Parent:WaitForChild("PlayerManager"))
local Economy = require(script.Parent:WaitForChild("Economy"))
local Aether = require(script.Parent:WaitForChild("Aether"))
local aetherSnapshot = ReplicatedStorage:WaitForChild("Aether_Snapshot")

local DebugCommands = {}

function DebugCommands.GetPlayerMoney(playerName)
    local player = Players:FindFirstChild(playerName)
    if not player then
        print("Player not found:", playerName)
        return
    end
    local data = PlayerManager.GetPlayerData(player)
    print("Player", playerName, "has", data.crumbs, "crumbs")
    return data.crumbs
end

function DebugCommands.SetPlayerMoney(playerName, amount)
    local player = Players:FindFirstChild(playerName)
    if not player then
        print("Player not found:", playerName)
        return false
    end
    local data = PlayerManager.GetPlayerData(player)
    data.crumbs = amount
    PlayerManager.SavePlayerData(player, data)
    print("Set", playerName, "crumbs to", amount)
    return true
end

function DebugCommands.AddPlayerMoney(playerName, amount)
    local player = Players:FindFirstChild(playerName)
    if not player then
        print("Player not found:", playerName)
        return false
    end
    local data = PlayerManager.GetPlayerData(player)
    local success = Economy.ApplyCrumbsDelta(data, amount, "grant")
    if success then
        PlayerManager.SavePlayerData(player, data)
        print("Added", amount, "crumbs to", playerName, "- New total:", data.crumbs)
    else
        print("Failed to add crumbs to", playerName)
    end
    return success
end

function DebugCommands.ListPlayers()
    print("Active players:")
    for _, player in pairs(Players:GetPlayers()) do
        local data = PlayerManager.GetPlayerData(player)
        print(" -", player.Name, "- Crumbs:", data.crumbs, "- Aether:", data.aether.current)
    end
end

-- Producer management
function DebugCommands.AddProducer(playerName, producerType, baseRate, patchId)
    local player = Players:FindFirstChild(playerName)
    if not player then
        print("Player not found:", playerName)
        return false
    end
    local data = PlayerManager.GetPlayerData(player)
    local uid, debugName = Aether.AddProducer(data, producerType, baseRate, patchId)
    PlayerManager.SavePlayerData(player, data)
    aetherSnapshot:FireClient(player, Aether.Snapshot(data))
    print("Added producer", debugName, "(UID:", uid .. ") to", playerName)
    return uid, debugName
end

function DebugCommands.RemoveProducer(playerName, uid)
    local player = Players:FindFirstChild(playerName)
    if not player then
        print("Player not found:", playerName)
        return false
    end
    local data = PlayerManager.GetPlayerData(player)
    local success = Aether.RemoveProducer(data, uid)
    if success then
        PlayerManager.SavePlayerData(player, data)
        aetherSnapshot:FireClient(player, Aether.Snapshot(data))
        print("Removed producer", uid, "from", playerName)
    else
        print("Producer not found:", uid)
    end
    return success
end

function DebugCommands.SetProducerActive(playerName, uid, active)
    local player = Players:FindFirstChild(playerName)
    if not player then
        print("Player not found:", playerName)
        return false
    end
    local data = PlayerManager.GetPlayerData(player)
    local success = Aether.SetProducerActive(data, uid, active)
    if success then
        PlayerManager.SavePlayerData(player, data)
        aetherSnapshot:FireClient(player, Aether.Snapshot(data))
        print("Set producer", uid, "active to", active, "for", playerName)
    else
        print("Producer not found:", uid)
    end
    return success
end

function DebugCommands.SetProducerRate(playerName, uid, baseRate, addBonus, multBonus)
    local player = Players:FindFirstChild(playerName)
    if not player then
        print("Player not found:", playerName)
        return false
    end
    local data = PlayerManager.GetPlayerData(player)
    local success = Aether.SetProducerRate(data, uid, baseRate, addBonus, multBonus)
    if success then
        PlayerManager.SavePlayerData(player, data)
        aetherSnapshot:FireClient(player, Aether.Snapshot(data))
        print("Updated producer", uid, "rates for", playerName)
    else
        print("Producer not found:", uid)
    end
    return success
end

function DebugCommands.ListProducers(playerName, filter)
    local player = Players:FindFirstChild(playerName)
    if not player then
        print("Player not found:", playerName)
        return
    end
    local data = PlayerManager.GetPlayerData(player)
    local producers, totalRate = Aether.ListProducers(data, filter)
    print("Producers for", playerName, "(Total rate:", totalRate .. "):")
    for _, producer in pairs(producers) do
        local status = producer.active and "active" or "inactive"
        print(" -", producer.debugName, "(" .. producer.uid .. ")", "Type:", producer.type, "Rate:", producer.rate, "Status:", status)
    end
    return producers
end

function DebugCommands.GetProducer(playerName, uid)
    local player = Players:FindFirstChild(playerName)
    if not player then
        print("Player not found:", playerName)
        return
    end
    local data = PlayerManager.GetPlayerData(player)
    local producer = data.producers and data.producers[uid]
    if not producer then
        print("Producer not found:", uid)
        return
    end
    print("Producer details for", uid, "(" .. producer.debugName .. "):")
    print("  Type:", producer.type)
    print("  Base rate:", producer.baseRate)
    print("  Add bonus:", producer.addBonus or 0)
    print("  Mult bonus:", producer.multBonus or 1)
    print("  Active:", producer.active)
    print("  Patch:", producer.patch or "none")
    print("  Tags:", producer.tags or "none")
    return producer
end

-- Aether parameters
function DebugCommands.SetTarget(playerName, value)
    local player = Players:FindFirstChild(playerName)
    if not player then
        print("Player not found:", playerName)
        return false
    end
    local data = PlayerManager.GetPlayerData(player)
    Aether.Settle(data)
    data.aether.target = value
    PlayerManager.SavePlayerData(player, data)
    aetherSnapshot:FireClient(player, Aether.Snapshot(data))
    print("Set", playerName, "aether target to", value)
    return true
end

function DebugCommands.SetDecay(playerName, value)
    local player = Players:FindFirstChild(playerName)
    if not player then
        print("Player not found:", playerName)
        return false
    end
    local data = PlayerManager.GetPlayerData(player)
    Aether.Settle(data)
    data.aether.decayRate = value
    PlayerManager.SavePlayerData(player, data)
    aetherSnapshot:FireClient(player, Aether.Snapshot(data))
    print("Set", playerName, "aether decay rate to", value)
    return true
end

function DebugCommands.SetPurity(playerName, value)
    local player = Players:FindFirstChild(playerName)
    if not player then
        print("Player not found:", playerName)
        return false
    end
    local data = PlayerManager.GetPlayerData(player)
    Aether.Settle(data)
    data.aether.purityBase = value
    PlayerManager.SavePlayerData(player, data)
    aetherSnapshot:FireClient(player, Aether.Snapshot(data))
    print("Set", playerName, "aether purity base to", value)
    return true
end

function DebugCommands.Burst(playerName, value)
    local player = Players:FindFirstChild(playerName)
    if not player then
        print("Player not found:", playerName)
        return false
    end
    local data = PlayerManager.GetPlayerData(player)
    Aether.ApplyBurst(data, value)
    PlayerManager.SavePlayerData(player, data)
    aetherSnapshot:FireClient(player, Aether.Snapshot(data))
    print("Added", value, "aether burst to", playerName, "- New total:", data.aether.current)
    return true
end

return DebugCommands
