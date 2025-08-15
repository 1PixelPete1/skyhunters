local PlayerManager = require(script.Parent:WaitForChild("PlayerManager"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local Aether = require(script.Parent:WaitForChild("Aether"))

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

local Uid = loadShared("Uid")
local ItemsConfig = loadShared("ItemsConfig")

local PlacementService = {}

local rtypeof = typeof or function(obj)
    return type(obj)
end

local function toLocal(cf)
    if rtypeof(cf) == "CFrame" then
        local px, py, pz = cf.Position.X, cf.Position.Y, cf.Position.Z
        local _, ry, _ = cf:ToOrientation()
        return { px = px, py = py, pz = pz, ry = ry }
    elseif type(cf) == "table" then
        return cf
    else
        return { px = 0, py = 0, pz = 0, ry = 0 }
    end
end

function PlacementService.Place(player, typeId, plotId, worldCFrame)
    local cfg = ItemsConfig.Types[typeId]
    if not cfg or cfg.category ~= "producers" then
        return { ok = false, err = "invalid_type" }
    end
    if not InventoryService.Consume(player, typeId, 1) then
        return { ok = false, err = "no_item" }
    end
    local data = PlayerManager.GetPlayerData(player)
    data.placed = data.placed or {}
    local uid = Uid.next("p")
    local prodUid = Aether.AddProducer(data, typeId, cfg.rate)
    local record = {
        uid = uid,

        itemId = typeId,
        plotId = plotId,
        cf = toLocal(worldCFrame),
        kind = "producer",
        rate = cfg.rate,
        producerUid = prodUid,
    }
    data.placed[uid] = record
    return { ok = true, uid = uid, serverRecord = record }
end

function PlacementService.Remove(player, uid)
    local data = PlayerManager.GetPlayerData(player)
    local record = data.placed and data.placed[uid]
    if not record then
        return { ok = false, err = "not_found" }
    end
    if record.producerUid then
        Aether.RemoveProducer(data, record.producerUid)
    end
    data.placed[uid] = nil
    InventoryService.Add(player, record.itemId or record.typeId, 1)
    return { ok = true }
end

return PlacementService

