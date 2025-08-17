--!strict
-- Client-side visualiser for Loom growth. This prototype exposes a simple API
-- that mirrors the design but does not implement full rendering. It focuses on
-- determinism and maps growth percentage to segment visibility for tests.

local GrowthVisualizer = {}

local LoomConfigs = require("looms/LoomConfigs")
local GrowthProfiles = require("looms/GrowthProfiles")

-- Simplified pool structure used for tests. Real implementation would reuse
-- Instances. Here we just keep numeric data. Pooling allows early perf
-- measurements without allocating every render.
local visuals = {}
local segmentPools = {}
local tipDecoPool = {}
local tipDecos = {}

local function acquireSegmentBuffer(n)
    local pool = segmentPools[n]
    if pool and #pool > 0 then
        local buf = pool[#pool]
        pool[#pool] = nil
        return buf
    end
    local buf = {}
    for i = 1, n do
        buf[i] = 0
    end
    return buf
end

local function releaseSegmentBuffer(n, buf)
    for i = 1, n do
        buf[i] = nil
    end
    local pool = segmentPools[n]
    if not pool then
        pool = {}
        segmentPools[n] = pool
    end
    pool[#pool + 1] = buf
end

local function acquireTipDeco()
    local deco = tipDecoPool[#tipDecoPool]
    if deco then
        tipDecoPool[#tipDecoPool] = nil
        return deco
    end
    return {}
end

local function releaseTipDeco(deco)
    for k in pairs(deco) do
        deco[k] = nil
    end
    tipDecoPool[#tipDecoPool + 1] = deco
end

local function computeSegmentFill(N, g)
    local totalProgress = (g/100) * N
    local full = math.floor(totalProgress)
    local partial = totalProgress - full
    local result = acquireSegmentBuffer(N)
    for i = 1, N do
        if i <= full then
            result[i] = 1
        elseif i == full + 1 then
            result[i] = partial
        else
            result[i] = 0
        end
    end
    return result
end

function GrowthVisualizer.Render(container, loomState)
    local config = LoomConfigs[loomState.configId]
    if not config then return end
    local segCount = loomState.overrides and loomState.overrides.segmentCount or config.growthDefaults.segmentCount

    local existing = visuals[loomState.loomUid]
    if existing then
        releaseSegmentBuffer(#existing, existing)
    end

    visuals[loomState.loomUid] = computeSegmentFill(segCount, loomState.g)

    if not tipDecos[loomState.loomUid] then
        tipDecos[loomState.loomUid] = acquireTipDeco()
    end
end

function GrowthVisualizer.Release(container, loomUid)
    local visual = visuals[loomUid]
    if visual then
        releaseSegmentBuffer(#visual, visual)
        visuals[loomUid] = nil
    end
    local deco = tipDecos[loomUid]
    if deco then
        releaseTipDeco(deco)
        tipDecos[loomUid] = nil
    end
end

function GrowthVisualizer._getVisualState(loomUid)
    return visuals[loomUid]
end

return GrowthVisualizer
