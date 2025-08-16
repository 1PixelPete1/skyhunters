local PlayerManager = require(script.Parent:WaitForChild("PlayerManager"))

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

local InventoryService = {}

function InventoryService.Add(player, typeId, qty)
    qty = qty or 1
    local data = PlayerManager.GetPlayerData(player)
    data.inventory[typeId] = (data.inventory[typeId] or 0) + qty
    return true
end

function InventoryService.Consume(player, typeId, qty)
    qty = qty or 1
    local data = PlayerManager.GetPlayerData(player)
    local current = data.inventory[typeId] or 0
    if current < qty then
        return false
    end
    data.inventory[typeId] = current - qty
    if data.inventory[typeId] <= 0 then
        data.inventory[typeId] = nil
    end
    return true
end

function InventoryService.GetCount(player, typeId)
    local data = PlayerManager.GetPlayerData(player)
    return data.inventory[typeId] or 0
end

function InventoryService.GetPage(player, category, search, cursor)
    local data = PlayerManager.GetPlayerData(player)
    local items = {}
    for typeId, count in pairs(data.inventory) do
        local cfg = ItemsConfig.Types[typeId]
        if cfg and cfg.category == category then
            table.insert(items, {
                uid = typeId,
                typeId = typeId,
                displayName = cfg.displayName,
                count = count,
                icon = cfg.icon,
            })
        end
    end
    return { items = items, nextCursor = nil, total = #items }
end

return InventoryService

