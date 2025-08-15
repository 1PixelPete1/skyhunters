local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local BurstService = require(script.Parent:WaitForChild("BurstService"))
local PlacementService = require(script.Parent:WaitForChild("PlacementService"))
local PlayerManager = require(script.Parent:WaitForChild("PlayerManager"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemsConfig = require(Shared:WaitForChild("ItemsConfig"))

local rfFetch = Instance.new("RemoteFunction")
rfFetch.Name = "Inventory_FetchPage"
rfFetch.Parent = ReplicatedStorage
rfFetch.OnServerInvoke = function(player, category, search, cursor)
    local result = InventoryService.GetPage(player, category, search, cursor)
    return result.items, result.nextCursor, result.total
end

local rfEquip = Instance.new("RemoteFunction")
rfEquip.Name = "Inventory_Equip"
rfEquip.Parent = ReplicatedStorage
rfEquip.OnServerInvoke = function(player, uid)
    return { ok = false }
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

local evStartHolding = Instance.new("RemoteEvent")
evStartHolding.Name = "StartHoldingItem"
evStartHolding.Parent = ReplicatedStorage
evStartHolding.OnServerEvent:Connect(function(player, uid)
    local data = PlayerManager.GetPlayerData(player)
    data.heldItem = uid
end)

local evRequestPlace = Instance.new("RemoteEvent")
evRequestPlace.Name = "RequestPlaceItem"
evRequestPlace.Parent = ReplicatedStorage

local evConfirm = Instance.new("RemoteEvent")
evConfirm.Name = "ConfirmPlacement"
evConfirm.Parent = ReplicatedStorage

local evReject = Instance.new("RemoteEvent")
evReject.Name = "PlacementRejected"
evReject.Parent = ReplicatedStorage

local function getModel(modelName)
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    if not assets then
        warn("[InventoryRemotes] Assets folder missing")
        local p = Instance.new("Part")
        p.Name = modelName
        p.Size = Vector3.new(1, 1, 1)
        p.Anchored = true
        return p
    end
    local models = assets:FindFirstChild("Models")
    if not models then
        warn("[InventoryRemotes] Models folder missing in Assets")
        local p = Instance.new("Part")
        p.Name = modelName
        p.Size = Vector3.new(1, 1, 1)
        p.Anchored = true
        return p
    end
    local model = models:FindFirstChild(modelName)
    if not model then
        warn("[InventoryRemotes] Model " .. modelName .. " missing")
        local p = Instance.new("Part")
        p.Name = modelName
        p.Size = Vector3.new(1, 1, 1)
        p.Anchored = true
        return p
    end
    return model:Clone()
end
evRequestPlace.OnServerEvent:Connect(function(player, uid, worldCFrame)
    local data = PlayerManager.GetPlayerData(player)
    if data.heldItem ~= uid then
        evReject:FireClient(player)
        return
    end
    local cfg = ItemsConfig.Types[uid]
    if not cfg then
        evReject:FireClient(player)
        return
    end
    if not InventoryService.Consume(player, uid, 1) then
        evReject:FireClient(player)
        return
    end
    local model = getModel(cfg.model)
    if model:IsA("BasePart") then
        model.CFrame = worldCFrame
    else
        if model.PrimaryPart then
            model:SetPrimaryPartCFrame(worldCFrame)
        else
            model:PivotTo(worldCFrame)
        end
    end
    model.Parent = workspace
    data.heldItem = nil
    evConfirm:FireClient(player, true, model)
end)

return {
    FetchPage = rfFetch,
    Equip = rfEquip,
    UseBurst = rfBurst,
    PlaceItem = rfPlace,
    RemovePlaced = rfRemove,
    StartHolding = evStartHolding,
    RequestPlace = evRequestPlace,
    ConfirmPlacement = evConfirm,
    PlacementRejected = evReject,
}

