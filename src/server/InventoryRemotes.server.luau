local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerManager = require(script.Parent:WaitForChild("PlayerManager"))

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
    remotesFolder = Instance.new("Folder")
    remotesFolder.Name = "Remotes"
    remotesFolder.Parent = ReplicatedStorage
end

local inventoryFolder = remotesFolder:FindFirstChild("Inventory")
if not inventoryFolder then
    inventoryFolder = Instance.new("Folder")
    inventoryFolder.Name = "Inventory"
    inventoryFolder.Parent = remotesFolder
end

local rfSnapshot = Instance.new("RemoteFunction")
rfSnapshot.Name = "RF_GetInventorySnapshot"
rfSnapshot.Parent = inventoryFolder
rfSnapshot.OnServerInvoke = function(player)
    local data = PlayerManager.GetPlayerData(player)
    local invCopy = {}
    for id, count in pairs(data.inventory or {}) do
        invCopy[id] = count
    end
    return { inventory = invCopy, crumbs = data.crumbs or 0 }
end

local rePush = Instance.new("RemoteEvent")
rePush.Name = "RE_InventoryPush"
rePush.Parent = inventoryFolder

return nil
