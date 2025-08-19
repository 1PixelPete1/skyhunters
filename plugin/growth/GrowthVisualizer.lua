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

local styleClampDefaults = {
    straight = {yaw = 4,  pitch = 3},
    curved   = {yaw = 22, pitch = 10},
    zigzag   = {yaw = 28, pitch = 6},
    noise    = {yaw = 16, pitch = 16},
    chaotic  = {yaw = 34, pitch = 18},
    sigmoid  = {yaw = 18, pitch = 8},
}

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
    local path = overrides.path or {}
    local style = path.style or "curved"
    local ampDeg = tonumber(path.amplitudeDeg) or 10
    local freq = tonumber(path.frequency) or 0.35
    local curvature = tonumber(path.curvature) or 0.35
    local zigzagSwap = tonumber(path.zigzagEvery) or 1
    local sigmoidK = tonumber(path.sigmoidK) or 6
    local sigmoidMid = tonumber(path.sigmoidMid) or 0.5
    local chaoticR = tonumber(path.chaoticR) or 3.9
    local microJitter = tonumber(path.microJitterDeg) or 2
    local seedAffects = overrides.seedAffects or {segmentCount=true, curvature=true, frequency=true, jitter=true, twist=true}

    local rngMacro = SeedUtil.rng(loomState.baseSeed or 0, "macro")

    local uiMin = tonumber(overrides.segmentCountMin)
    local uiMax = tonumber(overrides.segmentCountMax)
    local cfgMin = config.growthDefaults and config.growthDefaults.segmentCountMin
    local cfgMax = config.growthDefaults and config.growthDefaults.segmentCountMax
    local cfgDefault = config.growthDefaults.segmentCount or 12

    local mn = uiMin or cfgMin or cfgDefault
    local mx = uiMax or cfgMax or (cfgDefault + 8)
    if mx < mn then mn, mx = mx, mn end

    local segCount = tonumber(overrides.segmentCount)
    if segCount then
        segCount = math.max(1, math.floor(segCount))
    else
        if seedAffects.segmentCount then
            segCount = rngMacro:NextInteger(mn, mx)
        else
            segCount = cfgDefault
        end
    end
    if seedAffects.curvature and path.curvature == nil then
        curvature = curvature * rngMacro:NextNumber(0.8, 1.2)
    end
    if seedAffects.frequency and path.frequency == nil then
        freq = freq * rngMacro:NextNumber(0.7, 1.3)
    end
    if seedAffects.jitter and path.microJitterDeg == nil then
        microJitter = microJitter * rngMacro:NextNumber(0.7, 1.3)
    end

    local rngMicro = SeedUtil.rng(loomState.baseSeed or 0, "micro")
    local nx, ny, nz = SeedUtil.noiseOffsets(loomState.baseSeed or 0, "path")

    local rotRules = overrides.rotationRules or {}
    local matOverrides = overrides.materialization or {mode = "Model"}
    local jitter = config.growthDefaults.segmentScaleJitter or { length = 0, thickness = 0 }
    local tie = config.growthDefaults.relativeScaleTie or 0

    local function styleAngles(styleName, i, N)
        local t = (i - 1) / math.max(1, N - 1)
        local baseYaw, basePitch = 0, 0

        if styleName == "straight" then
            -- minimal base
        elseif styleName == "curved" then
            local sweep = math.sin((t * math.pi) * freq) * ampDeg
            local env = (1 - (2*t - 1)^2) ^ curvature
            baseYaw = sweep * env
            basePitch = (ampDeg * 0.35) * env
        elseif styleName == "zigzag" then
            local group = math.max(1, zigzagSwap)
            local sign = ((math.floor((i - 1) / group) % 2) == 0) and 1 or -1
            baseYaw = sign * ampDeg
            basePitch = 0
        elseif styleName == "noise" then
            local n1 = math.noise(nx + t * (10 * freq), ny, nz)
            local n2 = math.noise(nx, ny + t * (10 * freq), nz)
            baseYaw = n1 * ampDeg
            basePitch = n2 * ampDeg * 0.6
        elseif styleName == "sigmoid" then
            local s = 1 / (1 + math.exp(-sigmoidK * (t - sigmoidMid)))
            baseYaw = (s - 0.5) * 2 * ampDeg
            basePitch = (0.5 - math.abs(s - 0.5)) * 2 * (ampDeg * 0.4)
        elseif styleName == "chaotic" then
            GrowthVisualizer._chaos = GrowthVisualizer._chaos or {}
            if not GrowthVisualizer._chaos.start then GrowthVisualizer._chaos.start = rngMacro:NextNumber(0.2, 0.8) end
            local x = GrowthVisualizer._chaos.start
            for _=1,i do x = chaoticR * x * (1 - x) end
            baseYaw = (x - 0.5) * 2 * ampDeg
            basePitch = (0.5 - math.abs(x - 0.5)) * 2 * (ampDeg * 0.4)
        else
            local sweep = math.sin((t * math.pi) * freq) * ampDeg
            local env = (1 - (2*t - 1)^2) ^ curvature
            baseYaw = sweep * env
            basePitch = (ampDeg * 0.35) * env
        end

        local jy = rngMicro:NextNumber(-microJitter, microJitter)
        local jp = rngMicro:NextNumber(-microJitter, microJitter)
        local dy = baseYaw + jy
        local dp = basePitch + jp

        local tailDamp = 1.0
        if styleName == "straight" or styleName == "curved" then
            local u = math.max(0, (i / math.max(1, N)) - 0.7) / 0.3
            tailDamp = 1.0 - math.min(1, u * u)
        end
        dy = dy * tailDamp
        dp = dp * tailDamp

        return dy, dp, 0
    end

    local yaw, pitch, roll = 0, 0, 0
    while #segments > segCount do
        segments[#segments] = nil
    end
    for i = 1, segCount do
        local seg = segments[i]
        if not seg then
            seg = { yaw = 0, pitch = 0, roll = 0, lengthScale = 1, thicknessScale = 1, fill = 0 }
            segments[i] = seg
        end
        local dy, dp, dr = styleAngles(style, i, segCount)
        local extraRoll = tonumber(rotRules.extraRollPerSegDeg) or 0
        local rollRange = tonumber(rotRules.randomRollRangeDeg) or 0
        local twistEnabled = (overrides.seedAffects and overrides.seedAffects.twist) ~= false
        if twistEnabled then
            dr = (dr or 0) + extraRoll + rngMicro:NextNumber(-rollRange, rollRange)
        else
            dr = (dr or 0) + extraRoll
        end
        local defaultCont =
            (style == "zigzag" or style == "noise" or style == "chaotic") and "absolute" or "accumulate"
        local cont = rotRules.continuity or defaultCont
        if cont == "accumulate" then
            yaw = yaw + dy
            pitch = pitch + dp
            roll = roll + dr
        else
            yaw, pitch, roll = dy, dp, dr
        end
        local yClamp = rotRules.yawClampDeg
        local pClamp = rotRules.pitchClampDeg
        if not yClamp or not pClamp then
            local d = styleClampDefaults[style] or {}
            yClamp = yClamp or d.yaw
            pClamp = pClamp or d.pitch
        end
        if yClamp then yaw = clamp(yaw, -yClamp, yClamp) end
        if pClamp then pitch = clamp(pitch, -pClamp, pClamp) end
        if rotRules.faceForwardBias then
            yaw = yaw * (1 - rotRules.faceForwardBias)
            pitch = pitch * (1 - rotRules.faceForwardBias)
        end

        seg.yaw, seg.pitch, seg.roll = yaw, pitch, roll

        local prof = overrides.scaleProfile
        local baseS = evalScaleProfile(i, segCount, prof)
        local applyJitter = (prof == nil) or (prof.enableJitter ~= false)
        local lenJ = applyJitter and rngMicro:NextNumber(-jitter.length, jitter.length) or 0
        local thJ = applyJitter and rngMicro:NextNumber(-jitter.thickness, jitter.thickness) or 0
        seg.lengthScale = baseS * (1 + lenJ)
        seg.thicknessScale = baseS * (1 + lenJ * tie + thJ * (1 - tie))
    end

    local fills = computeSegmentFill(segCount, loomState.g or 0)
    for i = 1, segCount do
        segments[i].fill = fills[i]
    end

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
