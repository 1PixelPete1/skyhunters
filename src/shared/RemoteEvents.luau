local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = {}

RemoteEvents.GetPlayerData = Instance.new("RemoteFunction")
RemoteEvents.GetPlayerData.Name = "GetPlayerData"
RemoteEvents.GetPlayerData.Parent = ReplicatedStorage

RemoteEvents.SellAether = Instance.new("RemoteFunction")
RemoteEvents.SellAether.Name = "SellAether"
RemoteEvents.SellAether.Parent = ReplicatedStorage

RemoteEvents.SellItem = Instance.new("RemoteFunction")
RemoteEvents.SellItem.Name = "SellItem"
RemoteEvents.SellItem.Parent = ReplicatedStorage

RemoteEvents.PurchaseUpgrade = Instance.new("RemoteFunction")
RemoteEvents.PurchaseUpgrade.Name = "PurchaseUpgrade"
RemoteEvents.PurchaseUpgrade.Parent = ReplicatedStorage

RemoteEvents.DebugAddCrumbs = Instance.new("RemoteFunction")
RemoteEvents.DebugAddCrumbs.Name = "DebugAddCrumbs"
RemoteEvents.DebugAddCrumbs.Parent = ReplicatedStorage

return RemoteEvents
