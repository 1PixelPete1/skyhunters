local okPlayers, Players = pcall(function()
    return game:GetService("Players")
end)
if not okPlayers then
    Players = { PlayerRemoving = { Connect = function() end } }
end

local okDS, DataStoreAdapter = pcall(function()
    return require(script.Parent:WaitForChild("DataStoreAdapter"))
end)
if not okDS then
    DataStoreAdapter = require("DataStoreAdapter")
end

local okSched, SaveScheduler = pcall(function()
    return require(script.Parent:WaitForChild("SaveScheduler"))
end)
if not okSched then
    SaveScheduler = require("SaveScheduler")
end

local PlayerManager = {}
local playerData = {}

local function loadShared(name)
    local ok, ReplicatedStorage = pcall(function()
        return game:GetService("ReplicatedStorage")
    end)
    if ok and ReplicatedStorage then
        local Shared = ReplicatedStorage:WaitForChild("Shared")
        return require(Shared:WaitForChild(name))
    end
    return require(name)
end

local ItemsConfig = loadShared("ItemsConfig")

local function createNewPlayerData(player)
    return {
        v = 1,
        id = player.UserId,
        crumbs = 0,
        inventory = {},
        upgrades = {},
        aether = {
            current = 0,
            target = 20,
            decayRate = 0.08,
            purityBase = 0.55,
            totalRate = 0,
            lastSettleTs = time(),
        },
        producers = {},
        placed = {},
        timestamps = {},
    }
end

local function migrate(data)
    data.v = data.v or 1
    data.crumbs = math.max(0, data.crumbs or 0)
    data.inventory = data.inventory or {}
    data.upgrades = data.upgrades or {}
    data.aether = data.aether or {}
    local a = data.aether
    a.current = math.max(0, a.current or 0)
    a.target = a.target or 20
    a.decayRate = a.decayRate or 0.08
    a.purityBase = a.purityBase or 0.55
    a.totalRate = a.totalRate or 0
        local now = time()
    a.lastSettleTs = a.lastSettleTs or now
    if a.lastSettleTs > now then
        a.lastSettleTs = now
    end
    data.producers = data.producers or {}
    data.placed = data.placed or {}
    data.timestamps = data.timestamps or {}
    return data
end

function PlayerManager.GetPlayerData(player)
    if not playerData[player] then
        local data = DataStoreAdapter.Load(player)
        if data then
            data = migrate(data)
        else
            data = createNewPlayerData(player)
            SaveScheduler.enqueue(player.UserId, function()
                DataStoreAdapter.Save(player, data)
            end)
        end
        playerData[player] = data
        local Aether
        if script and script.Parent then
            Aether = require(script.Parent:WaitForChild("Aether"))
        else
            Aether = require("Aether")
        end
        Aether.Init(data)
        local total = 0
        for _, record in pairs(data.placed) do
            local cfg = ItemsConfig.Types[record.typeId]
            if cfg and (record.active ~= false) then
                total = total + (cfg.rate or 0)
            end
        end
        data.aether.totalRate = total
        SaveScheduler.start(player.UserId, function()
            DataStoreAdapter.Save(player, data)
        end)
    end
    return playerData[player]
end

function PlayerManager.SavePlayerData(player, data)
    playerData[player] = data
    SaveScheduler.enqueue(player.UserId, function()
        DataStoreAdapter.Save(player, data)
    end)
end

Players.PlayerRemoving:Connect(function(player)
    local data = playerData[player]
    if data then
        SaveScheduler.enqueue(player.UserId, function()
            DataStoreAdapter.Save(player, data)
        end)
    end
    playerData[player] = nil
    SaveScheduler.remove(player.UserId)
end)

return PlayerManager

