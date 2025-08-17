local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local serverModules = ServerScriptService:WaitForChild("Server")
local InventoryService = require(serverModules:WaitForChild("InventoryService"))
local ServerItemConfig = require(ServerStorage:WaitForChild("ServerItemConfig"))

local DropsService = {}

function DropsService.Roll(player, opts)
    if typeof(opts) ~= "table" then
        print("[DROPS] ROLL", player.UserId, "drops=[]")
        return { ok = false, grants = {} }
    end
    local numDrops = math.clamp(opts.numDrops or 0, 1, 20)
    local chance = opts.chanceModifier or 1
    chance = math.clamp(chance, 0, 1)
    local includeTags = opts.includeTags
    local excludeTags = opts.excludeTags

    local pool = {}
    for id, def in pairs(ServerItemConfig.items) do
        if def.obtainable and not def.adminOnly then
            local tags = def.tags or {}
            local ok = true
            if includeTags then
                for _, tag in ipairs(includeTags) do
                    if not table.find(tags, tag) then
                        ok = false
                        break
                    end
                end
            end
            if ok and excludeTags then
                for _, tag in ipairs(excludeTags) do
                    if table.find(tags, tag) then
                        ok = false
                        break
                    end
                end
            end
            if ok then
                table.insert(pool, id)
            end
        end
    end

    local grants = {}
    if #pool > 0 then
        for _ = 1, numDrops do
            if math.random() <= chance then
                local itemId = pool[math.random(1, #pool)]
                InventoryService.Add(player, itemId, 1)
                table.insert(grants, { id = itemId, qty = 1 })
            end
        end
    end

    local dropsJson = "[]"
    local okEncode, encoded = pcall(function()
        return HttpService:JSONEncode(grants)
    end)
    if okEncode then
        dropsJson = encoded
    end
    print("[DROPS] ROLL", player.UserId, "drops=" .. dropsJson)

    return { ok = true, grants = grants }
end

return DropsService
