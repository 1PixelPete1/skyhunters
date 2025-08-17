--!strict
-- Client-side visualiser for Loom growth. This implementation focuses on
-- deterministic traversal and keeps numeric data structures instead of real
-- Instances so that it can run inside the unit tests.

local GrowthVisualizer = {}

local LoomConfigs = require("looms/LoomConfigs")
local GrowthProfiles = require("looms/GrowthProfiles")

-- visual state keyed by loomUid
-- each entry: {segments = { {yaw,pitch,roll,lengthScale,thicknessScale,fill}, ...}}
local visuals = {}

local function computeSegmentFill(N, g)
    local total = (g / 100) * N
    local full = math.floor(total)
    local partial = total - full
    local fills = {}
    for i = 1, N do
        if i <= full then
            fills[i] = 1
        elseif i == full + 1 then
            fills[i] = partial
        else
            fills[i] = 0
        end
    end
    return fills
end

local function getVisual(loomUid)
    local v = visuals[loomUid]
    if not v then
        v = {segments = {}}
        visuals[loomUid] = v
    end
    return v
end

function GrowthVisualizer.Render(container, loomState)
    local config = LoomConfigs[loomState.configId]
    if not config then return end

    local v = getVisual(loomState.loomUid)
    local segments = v.segments

    local segCount = (loomState.overrides and loomState.overrides.segmentCount) or config.growthDefaults.segmentCount
    local rng = Random.new(loomState.baseSeed or 0)
    local profile = GrowthProfiles.clampProfile((loomState.overrides and loomState.overrides.profile) or config.profileDefaults)
    local jitter = config.growthDefaults.segmentScaleJitter or { length = 0, thickness = 0 }
    local tie = config.growthDefaults.relativeScaleTie or 0

    local state = {}
    local yaw, pitch, roll = 0, 0, 0
    for i = 1, segCount do
        local seg = segments[i]
        if not seg then
            seg = { yaw = 0, pitch = 0, roll = 0, lengthScale = 1, thicknessScale = 1, fill = 0 }
            segments[i] = seg
        end
        local delta = GrowthProfiles.rotDelta(profile, rng, state)
        if profile.continuity == "accumulate" then
            yaw = yaw + delta.yaw
            pitch = pitch + delta.pitch
            roll = roll + delta.roll
        else
            yaw, pitch, roll = delta.yaw, delta.pitch, delta.roll
        end
        seg.yaw, seg.pitch, seg.roll = yaw, pitch, roll

        local lenJit = rng:NextNumber(-jitter.length, jitter.length)
        local thickJit = rng:NextNumber(-jitter.thickness, jitter.thickness)
        seg.lengthScale = 1 + lenJit
        seg.thicknessScale = 1 + lenJit * tie + thickJit * (1 - tie)
    end

    local fills = computeSegmentFill(segCount, loomState.g or 0)
    for i = 1, segCount do
        segments[i].fill = fills[i]
    end
end

function GrowthVisualizer.Release(container, loomUid)
    visuals[loomUid] = nil
end

function GrowthVisualizer._getVisualState(loomUid)
    return visuals[loomUid]
end

function GrowthVisualizer.SetEditorMode(isEditor)
    GrowthVisualizer._editorMode = isEditor and true or false
end

return GrowthVisualizer
