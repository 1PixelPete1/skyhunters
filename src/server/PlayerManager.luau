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

local okRep, ReplicatedStorage = pcall(function()
    return game:GetService("ReplicatedStorage")
end)
if not okRep then
    ReplicatedStorage = nil
end

local okWorkspace, Workspace = pcall(function()
    return game:GetService("Workspace")
end)
if not okWorkspace then
    Workspace = nil
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

local function getModel(modelName)
    if not ReplicatedStorage then
        return nil
    end
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    if not assets then
        return nil
    end
    local models = assets:FindFirstChild("Models")
    if not models then
        return nil
    end
    local model = models:FindFirstChild(modelName)
    if not model then
        return nil
    end
    return model:Clone()
end

local PLOT_PLATFORM_NAME = "Baseplate"

local function getPlotBounds()
    if not Workspace then
        return Vector3.new(-50, 0, -50), Vector3.new(100, 0, 100)
    end
    local platform = Workspace:FindFirstChild(PLOT_PLATFORM_NAME)
    if platform then
        if platform:IsA("Model") then
            local cf, size = platform:GetBoundingBox()
            return cf.Position - size / 2, size
        elseif platform:IsA("BasePart") then
            local cf = platform.CFrame
            return cf.Position - platform.Size / 2, platform.Size
        end
    end
    return Vector3.new(-50, 0, -50), Vector3.new(100, 0, 100)
end

local function toWorld(cf)
    if type(cf) == "table" then
        local py = cf.y or cf.py or 0
        local ry = cf.ry or 0
        if cf.rx ~= nil and cf.rz ~= nil then
            local min, size = getPlotBounds()
            local px = min.X + cf.rx * size.X
            local pz = min.Z + cf.rz * size.Z
            if CFrame and CFrame.new then
                local base = CFrame.new(px, py, pz)
                if CFrame.Angles then
                    return base * CFrame.Angles(0, ry, 0)
                else
                    return base
                end
            end
        else
            local px = cf.px or 0
            local pz = cf.pz or 0
            if CFrame and CFrame.new then
                local base = CFrame.new(px, py, pz)
                if CFrame.Angles then
                    return base * CFrame.Angles(0, ry, 0)
                else
                    return base
                end
            end
        end
    elseif typeof and typeof(cf) == "CFrame" then
        return cf
    end
    return CFrame.new(0, 0, 0)
end

local function spawnPlaced(uid, record)
    if not Workspace then
        return
    end
    local cfg = ItemsConfig.Types[record.itemId or record.typeId]
    if not cfg then
        return
    end
    local model = getModel(cfg.model)
    if not model then
        return
    end
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then
            p.Anchored = true
            p.CanCollide = true
        end
    end
    local cf = toWorld(record.cf)
    if model:IsA("BasePart") then
        model.CFrame = cf
    else
        if model.PrimaryPart then
            model:SetPrimaryPartCFrame(cf)
        else
            model:PivotTo(cf)
        end
    end
    model.Name = uid
    model.Parent = Workspace
end

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
        heldItem = nil,
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
    data.heldItem = data.heldItem
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
        for _, record in pairs(data.placed) do
            if record.kind == "producer" then
                if not record.producerUid or not data.producers[record.producerUid] then
                    local puid = Aether.AddProducer(data, record.itemId or record.typeId, record.rate)
                    record.producerUid = puid
                end
            end
        end
        Aether.RebuildTotalRate(data)

        for uid, record in pairs(data.placed) do
            spawnPlaced(uid, record)
        end

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

