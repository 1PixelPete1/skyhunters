--!strict
-- Client-side visualiser for Loom growth. This prototype exposes a simple API
-- that mirrors the design but does not implement full rendering. It focuses on
-- determinism and maps growth percentage to segment visibility for tests.

local GrowthVisualizer = {}

local LoomConfigs = require("looms/LoomConfigs")
local GrowthProfiles = require("looms/GrowthProfiles")

-- Simplified pool structure used for tests. Real implementation would reuse
-- Instances. Here we just keep numeric data.
local visuals = {}

local function computeSegmentFill(N, g)
    local totalProgress = (g/100) * N
    local full = math.floor(totalProgress)
    local partial = totalProgress - full
    local result = {}
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
    visuals[loomState.loomUid] = computeSegmentFill(segCount, loomState.g)
end

function GrowthVisualizer.Release(container, loomUid)
    visuals[loomUid] = nil
end

function GrowthVisualizer._getVisualState(loomUid)
    return visuals[loomUid]
end

return GrowthVisualizer
