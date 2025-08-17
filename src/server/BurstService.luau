local PlayerManager = require(script.Parent:WaitForChild("PlayerManager"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local Aether = require(script.Parent:WaitForChild("Aether"))

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

local BurstService = {}

function BurstService.Use(player, typeId)
    local cfg = ItemsConfig.Types[typeId]
    if not cfg or cfg.category ~= "burst" then
        return { ok = false, err = "invalid_type" }
    end
    if not InventoryService.Consume(player, typeId, 1) then
        return { ok = false, err = "no_item" }
    end
    local data = PlayerManager.GetPlayerData(player)
    Aether.ApplyBurst(data, cfg.burstValue or 0)
    return { ok = true }
end

function BurstService.Interact(player, uid)
    -- TODO: convert growth into aether; allow overflow that decays
    return { ok = false, code = "NOT_IMPLEMENTED" }
end

return BurstService

