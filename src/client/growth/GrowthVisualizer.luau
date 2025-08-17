--!strict
-- Client-side visualiser for Loom growth. This implementation focuses on
-- deterministic traversal and keeps numeric data structures instead of real
-- Instances so that it can run inside the unit tests.

local LoomConfigs = require(game.ReplicatedStorage.looms.LoomConfigs)
local GrowthProfiles = require(game.ReplicatedStorage.looms.GrowthProfiles)
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

    -- clear old children
    for _, child in ipairs(container:GetChildren()) do
        child:Destroy()
    end

    -- build segment data
    local yaw, pitch, roll = 0,0,0
    local prevCFrame = CFrame.new(0,0,0)
    for i = 1, segCount do
        local seg = segments[i]
        if not seg then
            seg = { yaw = 0, pitch = 0, roll = 0, lengthScale = 1, thicknessScale = 1, fill = 0 }
            segments[i] = seg
        end
        local delta = GrowthProfiles.rotDelta(profile, rng, {})
        if profile.continuity == "accumulate" then
            yaw = yaw + delta.yaw
            pitch = pitch + delta.pitch
            roll = roll + delta.roll
        else
            yaw, pitch, roll = delta.yaw, delta.pitch, delta.roll
        end
        seg.yaw, seg.pitch, seg.roll = yaw, pitch, roll

        seg.lengthScale = 1 + rng:NextNumber(-jitter.length, jitter.length)
        seg.thicknessScale = 1 + rng:NextNumber(-jitter.thickness, jitter.thickness)

        -- actually spawn a Part
        if (loomState.g or 0) >= (i/segCount)*100 then
            local part = Instance.new("Part")
            part.Anchored = true
            part.Size = Vector3.new(0.3*seg.thicknessScale, 2*seg.lengthScale, 0.3*seg.thicknessScale)
            local rot = CFrame.Angles(pitch, yaw, roll)
            part.CFrame = prevCFrame * rot * CFrame.new(0, part.Size.Y/2, 0)
            part.Color = Color3.fromRGB(0, 200, 0)
            part.Parent = container
            prevCFrame = part.CFrame * CFrame.new(0, part.Size.Y/2, 0)
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
