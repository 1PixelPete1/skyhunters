local PlayerManager = require(script.Parent:WaitForChild("PlayerManager"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local Aether = require(script.Parent:WaitForChild("Aether"))

local function loadShared(name)
    if script and script.Parent and script.Parent.Parent then
        local shared = script.Parent.Parent:FindFirstChild("shared")
        if shared then
            local ok, mod = pcall(function()
                return require(shared:WaitForChild(name))
            end)
            if ok then
                return mod
            end
        end
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
    if not cfg or cfg.category ~= "producer" then
        return { ok = false, err = "invalid_type" }
    end
    if not InventoryService.Consume(player, typeId, 1) then
        return { ok = false, err = "no_item" }
    end
    local data = PlayerManager.GetPlayerData(player)
    data.placed = data.placed or {}
    local uid = Uid.next("p")
    local record = {
        typeId = typeId,
        plotId = plotId,
        local = toLocal(worldCFrame),
        active = true,
    }
    data.placed[uid] = record
    Aether.Settle(data)
    data.aether.totalRate = (data.aether.totalRate or 0) + (cfg.rate or 0)
    return { ok = true, uid = uid, serverRecord = record }
end

function PlacementService.Remove(player, uid)
    local data = PlayerManager.GetPlayerData(player)
    local record = data.placed and data.placed[uid]
    if not record then
        return { ok = false, err = "not_found" }
    end
    local cfg = ItemsConfig.Types[record.typeId]
    Aether.Settle(data)
    data.aether.totalRate = (data.aether.totalRate or 0) - (cfg and cfg.rate or 0)
    data.placed[uid] = nil
    InventoryService.Add(player, record.typeId, 1)
    return { ok = true }
end

return PlacementService

