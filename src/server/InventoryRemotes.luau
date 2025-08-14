local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InventoryBridge = require(script.Parent:WaitForChild("InventoryBridge"))

local fetchPage = Instance.new("RemoteFunction")
fetchPage.Name = "Inventory_FetchPage"
fetchPage.Parent = ReplicatedStorage
fetchPage.OnServerInvoke = function(player, category, search, cursor)
    return InventoryBridge.GetPage(player, category, search, cursor)
end

local equip = Instance.new("RemoteFunction")
equip.Name = "Inventory_Equip"
equip.Parent = ReplicatedStorage
equip.OnServerInvoke = function(player, uid)
    return { ok = InventoryBridge.Equip(player, uid) }
end

local use = Instance.new("RemoteFunction")
use.Name = "Inventory_Use"
use.Parent = ReplicatedStorage
use.OnServerInvoke = function(player, uid)
    return { ok = InventoryBridge.Use(player, uid) }
end

return {
    FetchPage = fetchPage,
    Equip = equip,
    Use = use,
}
