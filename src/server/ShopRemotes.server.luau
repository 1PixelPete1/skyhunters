-- ServerScriptService/ShopRemotes.server.luau
-- Thin remote wrapper around ShopService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local folder = Instance.new("Folder")
folder.Name = "ShopRemotes"
folder.Parent = ReplicatedStorage

local RF_FetchCatalog = Instance.new("RemoteFunction")
RF_FetchCatalog.Name = "RF_FetchCatalog"
RF_FetchCatalog.Parent = folder

local RF_Purchase = Instance.new("RemoteFunction")
RF_Purchase.Name = "RF_Purchase"
RF_Purchase.Parent = folder

local RF_FetchShopSnapshot = Instance.new("RemoteFunction")
RF_FetchShopSnapshot.Name = "RF_FetchShopSnapshot"
RF_FetchShopSnapshot.Parent = folder

local ShopService = require(ServerStorage.ShopService)

RF_FetchCatalog.OnServerInvoke = function(player)
    return ShopService.FetchCatalog(player)
end

RF_Purchase.OnServerInvoke = function(player, payload)
    return ShopService.Purchase(player, payload)
end

RF_FetchShopSnapshot.OnServerInvoke = function(player)
    return ShopService.FetchShopSnapshot(player)
end
