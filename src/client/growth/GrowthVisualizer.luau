--!strict
-- Client-side visualiser for Loom growth. This implementation focuses on
-- deterministic traversal and keeps numeric data structures instead of real
-- Instances so that it can run inside the unit tests.

local LoomConfigs
local GrowthProfiles
do
    local ok, RS = pcall(game.GetService, game, "ReplicatedStorage")
    if ok and RS then
        LoomConfigs = LoomConfigs or (RS:FindFirstChild("looms") and RS.looms:FindFirstChild("LoomConfigs") and require(RS.looms.LoomConfigs))
        GrowthProfiles = GrowthProfiles or (RS:FindFirstChild("growth") and RS.growth:FindFirstChild("GrowthProfiles") and require(RS.growth.GrowthProfiles))
    end
    if not LoomConfigs then
        local root = script and script:FindFirstAncestor("LoomDesigner")
        if root then
            local lc = root:FindFirstChild("looms")
            if lc and lc:FindFirstChild("LoomConfigs") then LoomConfigs = require(lc.LoomConfigs) end
        end
    end
    if not GrowthProfiles then
        local root = script and script:FindFirstAncestor("LoomDesigner")
        if root then
            local gr = root:FindFirstChild("growth")
            if gr and gr:FindFirstChild("GrowthProfiles") then GrowthProfiles = require(gr.GrowthProfiles) end
        end
    end
    if not LoomConfigs then error("[GrowthVisualizer] Could not resolve LoomConfigs") end
    if not GrowthProfiles then error("[GrowthVisualizer] Could not resolve GrowthProfiles") end
end

local function clamp(v, mn, mx)
    if v < mn then return mn end
    if v > mx then return mx end
    return v
end
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

local function renderSegments(scene, cfg, segments)
    if not scene or not scene.Spawn then
        return
    end
    for _, seg in ipairs(segments) do
        local shape = cfg.partType or Enum.PartType.Ball
        local size
        if shape == Enum.PartType.Ball then
            size = Vector3.new(seg.thickness, seg.thickness, seg.thickness)
        else
            size = Vector3.new(seg.thickness, seg.length, seg.thickness)
        end
        scene.Spawn({
            class = "Part",
            shape = shape,
            size = size,
            cframe   = seg.cframe,
            material = cfg.material or Enum.Material.SmoothPlastic,
            color    = cfg.color,
            anchored = true,
            canCollide = false,
            name = "Segment",
        })
    end
end

function GrowthVisualizer.Render(container, loomState)
    local config = LoomConfigs[loomState.configId]
    if not config then return end

    local v = getVisual(loomState.loomUid)
    local segments = v.segments

    local overrides = loomState.overrides or {}
    local segCount = overrides.segmentCount or config.growthDefaults.segmentCount
    local rng = Random.new(loomState.baseSeed or 0)
    local profile = GrowthProfiles.clampProfile(overrides.profile or config.profileDefaults)
    local jitter = config.growthDefaults.segmentScaleJitter or { length = 0, thickness = 0 }
    local tie = config.growthDefaults.relativeScaleTie or 0
    local rotRules = overrides.rotationRules or {}
    local matOverrides = overrides.materialization or {mode = "Model"}

    -- Build segment numerics
    local yaw, pitch, roll = 0, 0, 0
    for i = 1, segCount do
        local seg = segments[i]
        if not seg then
            seg = { yaw = 0, pitch = 0, roll = 0, lengthScale = 1, thicknessScale = 1, fill = 0 }
            segments[i] = seg
        end
        local delta = GrowthProfiles.rotDelta(profile, rng, {})
        local cont = rotRules.continuity or profile.continuity or "accumulate"
        if cont == "accumulate" then
            yaw = yaw + delta.yaw
            pitch = pitch + delta.pitch
            roll = roll + delta.roll
        else
            yaw, pitch, roll = delta.yaw, delta.pitch, delta.roll
        end
        if rotRules.extraRollPerSegDeg then
            roll = roll + rotRules.extraRollPerSegDeg
        end
        if rotRules.randomRollRangeDeg then
            roll = roll + rng:NextNumber(-rotRules.randomRollRangeDeg, rotRules.randomRollRangeDeg)
        end
        if rotRules.yawClampDeg then
            yaw = clamp(yaw, -rotRules.yawClampDeg, rotRules.yawClampDeg)
        end
        if rotRules.pitchClampDeg then
            pitch = clamp(pitch, -rotRules.pitchClampDeg, rotRules.pitchClampDeg)
        end
        local bias = rotRules.faceForwardBias
        if bias and bias > 0 then
            yaw = yaw * (1 - bias)
            pitch = pitch * (1 - bias)
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
    local scene = loomState.scene
    if scene and scene.Clear then scene.Clear() end

    if scene and scene.Spawn then
        local cfg = matOverrides.part or {}
        local segOut = {}
        local currentCF = CFrame.new(0,0,0)
        local baseLength = cfg.baseLength or 2
        local baseThickness = cfg.baseThickness or 1
        for i, seg in ipairs(segments) do
            if seg.fill > 0 then
                local rot = CFrame.Angles(math.rad(seg.pitch), math.rad(seg.yaw), math.rad(seg.roll))
                local length = baseLength * seg.lengthScale
                local thickness = baseThickness * seg.thicknessScale
                local stepCF = currentCF * rot * CFrame.new(0, length/2, 0)
                segOut[#segOut+1] = {cframe = stepCF, length = length, thickness = thickness}
                currentCF = stepCF * CFrame.new(0, length/2, 0)
            end
        end
        renderSegments(scene, cfg, segOut)
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
