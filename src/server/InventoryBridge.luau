
local okRS, ReplicatedStorage = pcall(function()
    return game:GetService("ReplicatedStorage")
end)

local function loadConfig()
    if okRS then
        local ok, cfg = pcall(function()
            return require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("InventoryConfig"))
        end)
        if ok then
            return cfg
        end
    end
    return require("InventoryConfig")
end

local InventoryConfig = loadConfig()

local PAGE_SIZE = InventoryConfig.UI.PageSize or 40

local SAMPLE_ITEMS = {}

local PLAYER_ITEMS = {}

for _, category in ipairs(InventoryConfig.Categories) do
    SAMPLE_ITEMS[category.id] = {}
    for i = 1, PAGE_SIZE * 2 do
        local uid = category.id .. "_" .. i
        table.insert(SAMPLE_ITEMS[category.id], {
            uid = uid,
            id = category.id .. "_item" .. i,
            name = category.label .. " Item " .. i,
            icon = InventoryConfig.Icons.fruit_apple,
            category = category.id,
            rings = {},
            summary = "Sample item",
        })
    end
end

local InventoryBridge = {}

local function getPlayerInventory(player)
    local inv = PLAYER_ITEMS[player]
    if not inv then
        inv = {}
        PLAYER_ITEMS[player] = inv
    end
    return inv
end

function InventoryBridge.GetDerivedAetherModifiers(player)
    return {
        target_add = 0,
        purity_add = 0,
        rate_mult = 1,
    }
end

function InventoryBridge.TryConsumeBurst(player, opts)
    return false, 0
end

function InventoryBridge.OnSnapshotComposed(player, snapshot)
end

-- Inventory façade -----------------------------------------------------

local function findPlayerItem(player, uidOrId)
    local inventory = getPlayerInventory(player)
    for _, items in pairs(inventory) do
        for _, item in ipairs(items) do
            if item.uid == uidOrId or item.id == uidOrId then
                return item
            end
        end
    end
end

function InventoryBridge.GetPage(player, category, search, cursor)
    local inventory = getPlayerInventory(player)
    local items = inventory[category] or {}
    local filtered = {}
    local query = search and string.lower(search) or nil
    for _, item in ipairs(items) do
        if not query or string.find(string.lower(item.name), query, 1, true) then
            table.insert(filtered, item)
        end
    end

    local startIndex = tonumber(cursor) or 1
    local page = {}
    for i = startIndex, math.min(startIndex + PAGE_SIZE - 1, #filtered) do
        table.insert(page, filtered[i])
    end

    local nextCursor
    if startIndex + PAGE_SIZE <= #filtered then
        nextCursor = tostring(startIndex + PAGE_SIZE)
    end

    return page, nextCursor, #filtered
end

function InventoryBridge.Equip(player, uidOrId)
    return findPlayerItem(player, uidOrId) ~= nil
end

function InventoryBridge._giveSampleItem(player, category, index)
    local catItems = SAMPLE_ITEMS[category]
    if not catItems then
        return nil
    end
    local item = catItems[index]
    if not item then
        return nil
    end
    local inventory = getPlayerInventory(player)
    inventory[category] = inventory[category] or {}
    table.insert(inventory[category], item)
    return item
end

function InventoryBridge.Use(player, uidOrId)
    return false
end

function InventoryBridge.GetDeltaSince(player, token)
    return {}, nil
end


return InventoryBridge

