local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local BurstService = require(script.Parent:WaitForChild("BurstService"))
local PlacementService = require(script.Parent:WaitForChild("PlacementService"))

local rfFetch = Instance.new("RemoteFunction")
rfFetch.Name = "RF_InventoryFetch"
rfFetch.Parent = ReplicatedStorage
rfFetch.OnServerInvoke = function(player, category, search, cursor)
    local result = InventoryService.GetPage(player, category, search, cursor)
    return result.items, result.nextCursor, result.total
end

local rfBurst = Instance.new("RemoteFunction")
rfBurst.Name = "RF_UseBurst"
rfBurst.Parent = ReplicatedStorage
rfBurst.OnServerInvoke = function(player, typeId)
    return BurstService.Use(player, typeId)
end

local rfPlace = Instance.new("RemoteFunction")
rfPlace.Name = "RF_PlaceItem"
rfPlace.Parent = ReplicatedStorage
rfPlace.OnServerInvoke = function(player, typeId, plotId, worldCFrame)
    return PlacementService.Place(player, typeId, plotId, worldCFrame)
end

local rfRemove = Instance.new("RemoteFunction")
rfRemove.Name = "RF_RemovePlaced"
rfRemove.Parent = ReplicatedStorage
rfRemove.OnServerInvoke = function(player, uid)
    return PlacementService.Remove(player, uid)
end

return {
    InventoryFetch = rfFetch,
    UseBurst = rfBurst,
    PlaceItem = rfPlace,
    RemovePlaced = rfRemove,
}

