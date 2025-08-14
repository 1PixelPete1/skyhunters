local PlayerManager = require(script.Parent:WaitForChild("PlayerManager"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local Aether = require(script.Parent:WaitForChild("Aether"))

local function loadItemsConfig()
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

local ItemsConfig = loadItemsConfig()

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

return BurstService

