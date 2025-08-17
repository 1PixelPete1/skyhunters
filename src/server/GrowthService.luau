--!strict
-- Runtime growth manager. Tracks Loom instances and advances their growth
-- percentage deterministically on the server. This is a simplified skeleton of
-- the design document and is intended for unit tests and early prototyping.

local GrowthService = {}

local LoomConfigs = require("looms/LoomConfigs")
local Rarity = require("Economy/Rarity")
local WeaverService = require("WeaverService")
local Uid = require("Uid")
local GrowthProfiles = require("looms/GrowthProfiles")

local BASE_RATE = 1 -- percent per second before rarity/complexity adjustments
local looms = {}
local serverRng = Random.new(os.clock())

local function computeComplexity(config, overrides)
    overrides = overrides or {}
    local segCount = overrides.segmentCount or config.growthDefaults.segmentCount
    local depth = overrides.branchDepthMax or config.growthDefaults.branchDepthMax
    local complexityFactor = segCount * (1 + 0.15 * (depth - 1))
    return complexityFactor
end

-- Determine eligible node ids numerically. This simplified version only
-- exposes tip nodes for depth 0 chains.
local function computeEligibleNodeIds(state, config)
    local nodes = {}
    if not config.nodes or config.nodes.mode == "none" then
        return nodes
    end
    local segCount = state.overrides and state.overrides.segmentCount or config.growthDefaults.segmentCount
    if config.nodes.tipsOnly then
        table.insert(nodes, {chainPath = "0", segIndex = segCount, kind = "tip", depth = 0})
    end
    return nodes
end

function GrowthService.RegisterLoom(player, configId, rarity, overrides, baseSeed)
    local config = LoomConfigs[configId]
    if not config then return nil end
    local seed = baseSeed or serverRng:NextInteger(1, 2^31 - 1)
    local uid = Uid.next("loom")
    looms[uid] = {
        loomUid = uid,
        configId = configId,
        rarity = rarity,
        baseSeed = seed,
        g = 0,
        overrides = overrides,
        completed = false,
    }
    local complexity = computeComplexity(config, overrides)
    local rarityMul = Rarity.GetGrowthMultiplier(rarity)
    local rate = BASE_RATE * rarityMul / complexity
    local totalTime = 100 / rate
    print(string.format("GrowthService.RegisterLoom uid=%s complexity=%.2f rate=%.4f time=%.2f", uid, complexity, rate, totalTime))
    return uid
end

function GrowthService.ApplyOverrides(loomUid, overrides)
    local state = looms[loomUid]
    if not state then return end
    state.overrides = state.overrides or {}
    for k,v in pairs(overrides) do
        state.overrides[k] = v
    end
end

function GrowthService.GetSnapshot(player)
    local list = {}
    for _, state in pairs(looms) do
        table.insert(list, {
            loomUid = state.loomUid,
            configId = state.configId,
            baseSeed = state.baseSeed,
            g = state.g,
            overrides = state.overrides,
        })
    end
    return { looms = list }
end

function GrowthService.GetEligibleNodeIds(loomUid)
    local state = looms[loomUid]
    if not state then return {} end
    local config = LoomConfigs[state.configId]
    return computeEligibleNodeIds(state, config)
end

function GrowthService.Tick(dt)
    for uid, state in pairs(looms) do
        if not state.completed then
            local config = LoomConfigs[state.configId]
            local complexity = computeComplexity(config, state.overrides)
            local rarityMul = Rarity.GetGrowthMultiplier(state.rarity)
            local rate = BASE_RATE * rarityMul / complexity
            state.g = math.min(100, state.g + rate * dt)
            if state.g >= 100 then
                state.completed = true
                local eligible = computeEligibleNodeIds(state, config)
                WeaverService.OnNodesEligible(uid, eligible)
                WeaverService.ActivateSome(uid)
            end
        end
    end
end

return GrowthService
