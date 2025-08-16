-- ServerStorage/LootService.luau
-- Generic RNG drop system (not tied to crates). Fully server-side.
-- Call Roll(player, { numDrops, chanceModifier?, includeTags?, excludeTags?, sourceId? })
-- Filters server-only items by tags; unobtainable/adminOnly are never granted.

local ServerStorage = game:GetService("ServerStorage")
-- local InventoryService = require(ServerStorage.InventoryService)
-- local EconomyService = require(ServerStorage.EconomyService)
-- local ServerItemConfig = require(ServerStorage.ServerItemConfig)

local LootService = {}

local function rng()
    return Random.new(math.floor((os.clock() % 1) * 1e7))
end

local function passesTags(def, includeTags, excludeTags)
    -- TODO: implement according to your tag format (array or map)
    return true
end

local function eligible(def)
    -- Enforce obtainability/adminOnly server-side
    -- return def and def.obtainable and not def.adminOnly
    return true
end

-- Weighting strategy is a policy choice; basic uniform for now.
local function pick(items, R)
    if #items == 0 then return nil end
    local i = R:NextInteger(1, #items)
    return items[i]
end

-- options = { numDrops: number, chanceModifier?: number, includeTags?: {string}, excludeTags?: {string}, sourceId?: string }
function LootService.Roll(player, options)
    local opts = options or {}
    local drops = {}
    local count = math.clamp(tonumber(opts.numDrops) or 1, 1, 20)
    local mod = tonumber(opts.chanceModifier) or 1.0
    local includeTags = opts.includeTags
    local excludeTags = opts.excludeTags

    -- Build server-side candidate pool
    -- local pool = {}
    -- for id, def in pairs(ServerItemConfig.items) do
    --     if eligible(def) and passesTags(def, includeTags, excludeTags) then
    --         if def.class == "Producer" then
    --             table.insert(pool, { id = id, def = def })
    --         end
    --     end
    -- end

    -- Use RNG
    local R = rng()

    for _ = 1, count do
        -- Example: apply a flat fail roll with (1 - mod) chance if you want scarcity
        -- if mod < 1 and R:NextNumber() > mod then
        --     continue
        -- end

        -- local picked = pick(pool, R)
        local picked = nil -- replace with actual pick
        if picked then
            -- Grant here (server-side):
            -- InventoryService.AddItem(player, picked.id, 1)
            table.insert(drops, { id = picked.id, qty = 1 })
        end
    end

    -- Optionally award currency here, same pattern, server-side only.
    return { ok = true, grants = drops }
end

return LootService
