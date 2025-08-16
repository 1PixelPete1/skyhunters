-- ServerStorage/LootService.luau
-- Generic RNG drop system (not tied to crates). Fully server-side.
-- Call Roll(player, { numDrops, chanceModifier?, includeTags?, excludeTags?, sourceId? })
-- Filters server-only items by tags; unobtainable/adminOnly are never granted.

local ServerStorage = game:GetService("ServerStorage")
local InventoryService = require(ServerStorage:WaitForChild("InventoryService"))
local Economy = require(ServerStorage:WaitForChild("Economy"))
local ServerItemConfig = require(ServerStorage:WaitForChild("ServerItemConfig"))

local LootService = {}

local function rng()
    return Random.new(math.floor((os.clock() % 1) * 1e7))
end

local function passesTags(def, includeTags, excludeTags)
    local tags = def.tags or {}
    if includeTags then
        local found = false
        for _, inc in ipairs(includeTags) do
            for _, t in ipairs(tags) do
                if t == inc then
                    found = true
                    break
                end
            end
            if found then
                break
            end
        end
        if not found then
            return false
        end
    end
    if excludeTags then
        for _, ex in ipairs(excludeTags) do
            for _, t in ipairs(tags) do
                if t == ex then
                    return false
                end
            end
        end
    end
    return true
end

local function eligible(def)
    return def and def.obtainable and not def.adminOnly
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

    local pool = {}
    for id, def in pairs(ServerItemConfig.items) do
        if def.class == "Producer" and eligible(def) and passesTags(def, includeTags, excludeTags) then
            table.insert(pool, { id = id, weight = 1 })
        end
    end

    -- Use RNG
    local R = rng()

    for _ = 1, count do
        if mod < 1 and R:NextNumber() > mod then
            continue
        end
        local picked = pick(pool, R)
        if picked then
            InventoryService.Add(player, picked.id, 1)
            table.insert(drops, { id = picked.id, qty = 1 })
        end
    end

    return { ok = true, grants = drops }
end

return LootService
