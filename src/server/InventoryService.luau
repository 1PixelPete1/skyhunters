local PlayerManager = require(script.Parent:WaitForChild("PlayerManager"))

local function loadConfig()
    if script and script.Parent and script.Parent.Parent then
        local shared = script.Parent.Parent:FindFirstChild("shared")
        if shared then
            local ok, cfg = pcall(function()
                return require(shared:WaitForChild("ItemsConfig"))
            end)
            if ok then
                return cfg
            end
        end
    end
    return require("ItemsConfig")
end

local ItemsConfig = loadConfig()

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

function InventoryService.GetPage(player, category, search, cursor)
    local data = PlayerManager.GetPlayerData(player)
    local items = {}
    for typeId, count in pairs(data.inventory) do
        local cfg = ItemsConfig.Types[typeId]
        if cfg and cfg.category == category then
            table.insert(items, {
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

