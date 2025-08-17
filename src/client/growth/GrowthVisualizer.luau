--!strict
-- Client-side visualiser for Loom growth. This implementation focuses on
-- deterministic traversal and keeps numeric data structures instead of real
-- Instances so that it can run inside the unit tests.

local LoomConfigs = require(game.ReplicatedStorage.looms.LoomConfigs)
local GrowthProfiles = require(game.ReplicatedStorage.growth.GrowthProfiles)
local GrowthVisualizer = {}

-- visual state keyed by loomUid
-- each entry: {segments = { {yaw,pitch,roll,lengthScale,thicknessScale,fill}, ...}}

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

    -- Build segment numerics
    local yaw, pitch, roll = 0, 0, 0
    for i = 1, segCount do
        local seg = segments[i]
        if not seg then
            seg = { yaw = 0, pitch = 0, roll = 0, lengthScale = 1, thicknessScale = 1, fill = 0 }
            segments[i] = seg
        end
        local delta = GrowthProfiles.rotDelta(profile, rng, {}) -- your state if needed
        if profile.continuity == "accumulate" then
            yaw += delta.yaw; pitch += delta.pitch; roll += delta.roll
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

    -- === Rendering to Workspace via scene API ===
    -- loomState.scene must be a table with:
    --   scene.Clear()
    --   scene.Spawn(inst, cf)
    --   scene.ResolveModel(refListOrRef)  (we'll pass this from UI/Main using ModelResolver)
    if not loomState.scene then
        warn("GrowthVisualizer.Render: loomState.scene missing; nothing will spawn.")
        return
    end

    loomState.scene.Clear()

    local currentCF = CFrame.new(0,0,0)
    for i, seg in ipairs(segments) do
        if seg.fill > 0 then
            local isTerminal = (i == segCount)
            -- Pick model by depth vs terminal
            local refList
            if isTerminal and config.models and config.models.byDepth and config.models.byDepth.terminal then
                refList = config.models.byDepth.terminal
            elseif config.models and config.models.byDepth and config.models.byDepth[i-1] then
                refList = config.models.byDepth[i-1]
            end

            local model = loomState.scene.ResolveModel(refList)
            if model then
                local rot = CFrame.Angles(seg.pitch, seg.yaw, seg.roll)
                local length = 2 * seg.lengthScale
                local stepCF = currentCF * rot * CFrame.new(0, length/2, 0)
                loomState.scene.Spawn(model, stepCF)
                currentCF = stepCF * CFrame.new(0, length/2, 0)
            end
        end
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

function GrowthVisualizer.SetEditorMode(isEditor)
    GrowthVisualizer._editorMode = isEditor and true or false
end

return GrowthVisualizer
