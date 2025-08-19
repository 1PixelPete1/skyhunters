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
    if not LoomConfigs then
        local okL, mod = pcall(require, "looms/LoomConfigs")
        if okL then LoomConfigs = mod end
    end
    if not GrowthProfiles then
        local okG, mod = pcall(require, "looms/GrowthProfiles")
        if okG then GrowthProfiles = mod end
    end
    if not LoomConfigs then error("[GrowthVisualizer] Could not resolve LoomConfigs") end
    if not GrowthProfiles then error("[GrowthVisualizer] Could not resolve GrowthProfiles") end
end

local SeedUtil
do
    local root = script:FindFirstAncestor("LoomDesigner")
    if not root and script.Parent and script.Parent.Parent then
        root = script.Parent.Parent:FindFirstChild("LoomDesigner")
    end
    if root and root:FindFirstChild("SeedUtil") then
        SeedUtil = require(root.SeedUtil)
    else
        local ok2, RS = pcall(game.GetService, game, "ReplicatedStorage")
        if ok2 and RS and RS:FindFirstChild("looms") and RS.looms:FindFirstChild("SeedUtil") then
            SeedUtil = require(RS.looms.SeedUtil)
        end
    end

end
if not SeedUtil then
    local okS, mod = pcall(require, "LoomDesigner/SeedUtil")
    if okS then SeedUtil = mod end
end
if not SeedUtil then
    SeedUtil = {
        rng = function(seed)
            return Random.new(seed)
        end,
        noiseOffsets = function()
            return 0,0,0
        end,
    }
end

local _PLUGIN_VERSION = "scene-spawn-2025-08-18"

local function clamp(v, mn, mx)
    if v < mn then return mn end
    if v > mx then return mx end
    return v
end

local function evalScaleProfile(i, N, prof)
    prof = prof or {mode = "constant", value = 1.0}
    local t = (i - 1) / math.max(1, N - 1)

    local function lerp(a, b, x)
        return a + (b - a) * x
    end

    if prof.mode == "constant" then
        return prof.value or 1.0
    elseif prof.mode == "linear_down" then
        return lerp(prof.start or 1.0, prof.finish or 0.6, t)
    elseif prof.mode == "linear_up" then
        return lerp(prof.start or 0.6, prof.finish or 1.0, t)
    elseif prof.mode == "bell" then
        local p = prof.power or 2.0
        return (1 - (2 * t - 1) ^ 2) ^ p * (prof.amp or 0.5) + (prof.base or 0.5)
    elseif prof.mode == "inverse_bell" then
        local p = prof.power or 2.0
        local ends = (1 - ((t - 0.5) ^ 2 / 0.25)) ^ p
        return (prof.base or 0.7) + (prof.amp or 0.3) * ends
    end
    return 1.0
end
local GrowthVisualizer = {}
GrowthVisualizer._PLUGIN_VERSION = _PLUGIN_VERSION

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
    local cfg = config.growthDefaults or {}

    -- resolve profile and clamp
    local profile = overrides.profile or config.profileDefaults or {kind = "curved"}
    profile = GrowthProfiles.clampProfile(profile)
    local state = v._profileState or {}
    v._profileState = state

    -- RNG streams
    local rngMicro = SeedUtil.rng(loomState.baseSeed or 0, "micro")
    local rngProfile = SeedUtil.rng(loomState.baseSeed or 0, "profile")

    -- segment count
    local uiMin = tonumber(overrides.segmentCountMin)
    local uiMax = tonumber(overrides.segmentCountMax)
    local mn = uiMin or cfg.segmentCountMin or (cfg.segmentCount or 12)
    local mx = uiMax or cfg.segmentCountMax or ((cfg.segmentCount or 12) + 8)
    if mx < mn then mn, mx = mx, mn end
    local segCount = tonumber(overrides.segmentCount)
    if not segCount then
        local rngMacro = SeedUtil.rng(loomState.baseSeed or 0, "macro")
        segCount = rngMacro:NextInteger(mn, mx)
    end
    segCount = math.max(1, math.floor(segCount))

    -- TRIM cached segments if shrinking
    while #segments > segCount do segments[#segments] = nil end

    -- continuity and clamps
    local rotRules = overrides.rotationRules or {}
    local defaultCont =
        (profile.kind == "zigzag" or profile.kind == "random" or profile.kind == "noise" or profile.kind == "chaotic") and "absolute"
        or (profile.continuity or "accumulate")
    local cont = rotRules.continuity or defaultCont
    local yClamp = rotRules.yawClampDeg
    local pClamp = rotRules.pitchClampDeg
    if not yClamp or not pClamp then
        local d = {
            straight={y=4,p=3}, curved={y=22,p=10}, zigzag={y=28,p=6},
            noise={y=16,p=16}, random={y=16,p=16}, chaotic={y=34,p=18}, sigmoid={y=18,p=8},
        }[profile.kind or "curved"] or {}
        yClamp = yClamp or d.y; pClamp = pClamp or d.p
    end

    -- heading jitter
    local enableMicroJitter = overrides.enableMicroJitter == true
    local microJitter = tonumber(overrides.microJitterDeg) or 0

    -- twist controls
    local twistStrength = tonumber(overrides.twistStrengthDegPerSeg) or 0
    local twistRngRange = tonumber(overrides.twistRngRangeDeg) or 0
    local twistRngOn = (overrides.seedAffects and overrides.seedAffects.twist) ~= false

    -- size jitter config
    local jitter = cfg.segmentScaleJitter or {length = 0, thickness = 0}

    local yaw, pitch, roll = 0, 0, 0
    for i = 1, segCount do
        local seg = segments[i]
        if not seg then
            seg = {yaw = 0, pitch = 0, roll = 0, lengthScale = 1, thicknessScale = 1, fill = 0}
            segments[i] = seg
        end

        -- per-segment deltas (degrees)
        local delta = GrowthProfiles.rotDelta(profile, rngProfile, state)
        local dy, dp, dr = delta.yaw, delta.pitch, delta.roll

        if enableMicroJitter then
            local j = microJitter
            local jy = rngMicro:NextNumber(-j, j)
            local jp = rngMicro:NextNumber(-j, j)
            dy += jy; dp += jp
        end

        if twistStrength ~= 0 or (twistRngOn and twistRngRange > 0) then
            local rnd = twistRngOn and rngMicro:NextNumber(-twistRngRange, twistRngRange) or 0
            dr += twistStrength + rnd
        end

        if cont == "accumulate" then
            yaw += dy; pitch += dp; roll += dr
        else
            yaw, pitch, roll = dy, dp, dr
        end
        if yClamp then yaw = clamp(yaw, -yClamp, yClamp) end
        if pClamp then pitch = clamp(pitch, -pClamp, pClamp) end

        seg.yaw, seg.pitch, seg.roll = yaw, pitch, roll

        local prof = overrides.scaleProfile
        local baseS = evalScaleProfile(i, segCount, prof)
        local enableScaleJitter = prof and prof.enableJitter == true
        local lenJ = enableScaleJitter and rngMicro:NextNumber(-jitter.length, jitter.length) or 0
        local thJ  = enableScaleJitter and rngMicro:NextNumber(-jitter.thickness, jitter.thickness) or 0
        seg.lengthScale    = baseS * (1 + lenJ)
        seg.thicknessScale = baseS * (1 + thJ)
    end

    -- fills
    local designFull = (GrowthVisualizer._editorMode == true) or (overrides.designFull == true)
    local fills
    if designFull then
        fills = {}
        for i=1, segCount do fills[i] = 1 end
    else
        fills = computeSegmentFill(segCount, loomState.g or 0)
    end
    for i = 1, segCount do
        segments[i].fill = fills[i]
    end

    local matOverrides = overrides.materialization or cfg.materialization or {mode = "Model"}
    local scene = loomState.scene
    if scene and scene.Clear then scene.Clear() end

    local segOut = {}
    if scene and scene.Spawn then
        local cfg = matOverrides.part or {}
        local currentCF = CFrame.new(0,0,0)
        local baseLength = cfg.baseLength or 2
        local baseThickness = cfg.baseThickness or 1
        for i, seg in ipairs(segments) do
            if seg.fill > 0 then
                local rot = CFrame.Angles(math.rad(seg.pitch), math.rad(seg.roll), math.rad(seg.yaw))
                local length = baseLength * seg.lengthScale
                local thickness = baseThickness * seg.thicknessScale
                local stepCF = currentCF * rot * CFrame.new(0, length/2, 0)
                segOut[#segOut+1] = {cframe = stepCF, length = length, thickness = thickness}
                currentCF = stepCF * CFrame.new(0, length/2, 0)
            end
        end
        renderSegments(scene, cfg, segOut)

        local decorations = overrides.decorations or {}
        if decorations.enabled then
            local attach = decorations.attach or "along"
            local offset = decorations.offset or Vector3.new()
            for _, seg in ipairs(segOut) do
                for _, typ in ipairs(decorations.types or {}) do
                    local density = typ.densityPerSeg or 0
                    local count = math.floor(density)
                    local extra = density - count
                    local function placeOne()
                        local decoCF = seg.cframe
                        if attach == "tip" then
                            decoCF = seg.cframe * CFrame.new(0, seg.length/2, 0)
                        elseif attach == "junction" then
                            decoCF = seg.cframe * CFrame.new(0, -seg.length/2, 0)
                        end
                        decoCF = decoCF * CFrame.new(offset)
                        local yawR = rngMicro:NextNumber(-(typ.yaw or 0), typ.yaw or 0)
                        local pitchR = rngMicro:NextNumber(-(typ.pitch or 0), typ.pitch or 0)
                        local rollR = rngMicro:NextNumber(-(typ.roll or 0), typ.roll or 0)
                        decoCF = decoCF * CFrame.Angles(math.rad(pitchR), math.rad(rollR), math.rad(yawR))
                        local scale = rngMicro:NextNumber(typ.scaleMin or 1, typ.scaleMax or 1)
                        local spec
                        if typ.kind == "asset" and typ.assetId then
                            spec = {assetId = typ.assetId, cframe = decoCF}
                        else
                            spec = {
                                class = "Part",
                                size = Vector3.new(scale, scale, scale),
                                cframe = decoCF,
                                color = typ.color == "auto" and cfg.color or typ.color,
                                anchored = true,
                                canCollide = false,
                                name = "Deco",
                            }
                        end
                        scene.Spawn(spec)
                    end
                    for _ = 1, count do placeOne() end
                    if rngMicro:NextNumber() < extra then placeOne() end
                end
            end
        end
    end

    GrowthVisualizer._debug = {
        kind = profile.kind,
        segCount = segCount,
        cont = cont,
        yawClamp = yClamp,
        pitchClamp = pClamp,
        twistStrength = twistStrength,
        twistRngRange = twistRngRange,
        sizeProfile = overrides.scaleProfile,
    }
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
