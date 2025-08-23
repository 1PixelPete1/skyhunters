--!strict
-- Client-side visualiser for Loom growth. This implementation focuses on
-- deterministic traversal and keeps numeric data structures instead of real
-- Instances so that it can run inside the unit tests.

local LoomConfigs
local GrowthProfiles
do
    local ok, RS = false, nil
    if game and game.GetService then
        ok, RS = pcall(game.GetService, game, "ReplicatedStorage")
    end
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
    local root
    if script and script.FindFirstAncestor then
        root = script:FindFirstAncestor("LoomDesigner")
        if not root and script.Parent and script.Parent.Parent then
            root = script.Parent.Parent:FindFirstChild("LoomDesigner")
        end
    end
    if root and root:FindFirstChild("SeedUtil") then
        SeedUtil = require(root.SeedUtil)
    else
        local ok2, RS = false, nil
        if game and game.GetService then
            ok2, RS = pcall(game.GetService, game, "ReplicatedStorage")
        end
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

local function isfinite(x)
    return x == x and x > -math.huge and x < math.huge
end

local function safeRad(x)
    if not isfinite(x) then return 0 end
    if x ~= x then return 0 end
    return math.rad(x)
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

local debugInfo = {}
GrowthVisualizer._debug = debugInfo

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

local function triangular(rng, a, b, mode)
    local u = rng:unit()
    local c = (mode - a) / (b - a)
    if u < c then
        return a + math.sqrt(u * (b - a) * (mode - a))
    else
        return b - math.sqrt((1 - u) * (b - a) * (b - mode))
    end
end

local function sampleSegCountTri(rng, minN, maxN, modeN)
    local x = triangular(rng, minN - 0.49, maxN + 0.49, modeN)
    x = math.floor(x + 0.5)
    if x < minN then x = minN end
    if x > maxN then x = maxN end
    return x
end

-- Box-Muller transform producing a standard normal deviate
local function gaussian(rng)
    if rng._spare then
        local z = rng._spare
        rng._spare = nil
        return z
    end
    local u1 = math.max(rng:unit(), 1e-12)
    local u2 = rng:unit()
    local r = math.sqrt(-2 * math.log(u1))
    local th = 2 * math.pi * u2
    rng._spare = r * math.sin(th)
    return r * math.cos(th)
end

local function normalClamped(rng, a, b, mu, sigma)
    local x = mu + sigma * gaussian(rng)
    if x < a then x = a end
    if x > b then x = b end
    return x
end

local function sampleSegCountNormal(rng, minN, maxN, meanN, sd)
    local x = normalClamped(rng, minN - 0.49, maxN + 0.49, meanN, sd)
    x = math.floor(x + 0.5)
    if x < minN then x = minN end
    if x > maxN then x = maxN end
    return x
end

local function biasedRange(rng, a, b, bias)
    local u = rng:unit()
    local t
    if bias > 0 then
        t = u ^ (1 / bias)
    else
        t = u
    end
    return a + (b - a) * t
end

local function sampleSegCountBiased(rng, minN, maxN, bias)
    local x = biasedRange(rng, minN - 0.49, maxN + 0.49, bias)
    x = math.floor(x + 0.5)
    if x < minN then x = minN end
    if x > maxN then x = maxN end
    return x
end

local function chooseSegCount(profile, overrides, rng)
    overrides = overrides or {}
    if overrides.segmentCount then
        local mn = overrides.segmentCountMin or profile.segmentCountMin or overrides.segmentCount
        local mx = overrides.segmentCountMax or profile.segmentCountMax or overrides.segmentCount
        local val = clamp(overrides.segmentCount, mn, mx)
        return math.max(1, math.floor(val))
    end
    if profile.segmentCount then
        local mn = profile.segmentCountMin or profile.segmentCount
        local mx = profile.segmentCountMax or profile.segmentCount
        local val = clamp(profile.segmentCount, mn, mx)
        return math.max(1, math.floor(val))
    end
    local mn = overrides.segmentCountMin or profile.segmentCountMin or (profile.segmentCount or 12)
    local mx = overrides.segmentCountMax or profile.segmentCountMax or (profile.segmentCount or 12)
    if mx < mn then mn, mx = mx, mn end
    local mode = overrides.segmentCountMode or profile.segmentCountMode or "uniform"
    local val
    if mode == "triangular" then
        local modeN = overrides.segmentCountModeN or profile.segmentCountModeN or math.floor((mn + mx) / 2)
        val = sampleSegCountTri(rng, mn, mx, modeN)
    elseif mode == "normal" then
        local meanN = overrides.segmentCountMean or profile.segmentCountMean or math.floor((mn + mx) / 2)
        local sd = overrides.segmentCountSd or profile.segmentCountSd or ((mx - mn) / 6)
        val = sampleSegCountNormal(rng, mn, mx, meanN, sd)
    elseif mode == "biased" then
        local bias = overrides.segmentCountBias or profile.segmentCountBias or 1
        val = sampleSegCountBiased(rng, mn, mx, bias)
    else
        val = rng:NextInteger(mn, mx)
    end
    return math.max(1, math.floor(val))
end

local function buildChain(segOut, chainId, depth, baseSeed, startCF, profile, cfg, overrides)
    local seedFlags = overrides.seedAffects or {}
    local macroSeed = seedFlags.segmentCount == false and 0 or baseSeed
    local profileSeed = (seedFlags.curvature == false and seedFlags.frequency == false) and 0 or baseSeed
    local microSeed = seedFlags.jitter == false and 0 or baseSeed

    local rngMacro = SeedUtil.rng(macroSeed, "macro", chainId)
    local rngProfile = SeedUtil.rng(profileSeed, "profile", chainId)
    local rngMicro = SeedUtil.rng(microSeed, "micro", chainId)

    local segCount = chooseSegCount(profile, overrides, rngMacro)
    profile.maxSegments = segCount
    local state = { seed = baseSeed }

    local rotRules = overrides.rotationRules or {}
    local autoContByKind = {
        zigzag = "absolute", noise = "absolute", chaotic = "absolute",
        straight = "accumulate", curved = "accumulate", sigmoid = "accumulate", spiral = "accumulate", random = "absolute",
    }
    local cont = rotRules.continuity or autoContByKind[profile.kind or "curved"] or "accumulate"
    local yClamp = rotRules.yawClampDeg
    local pClamp = rotRules.pitchClampDeg
    if not yClamp or not pClamp then
        local d = ({
            straight={y=4,p=3}, curved={y=22,p=10}, zigzag={y=28,p=6},
            noise={y=16,p=16}, random={y=16,p=16}, chaotic={y=34,p=18}, sigmoid={y=18,p=8},
        })[profile.kind or "curved"] or {}
        yClamp = yClamp or d.y; pClamp = pClamp or d.p
    end

    local enableMicroJitter = overrides.enableMicroJitter == true
    local microJitter = tonumber(overrides.microJitterDeg) or 0

    local twistStrength = tonumber(overrides.twistStrengthDegPerSeg) or 0
    local twistRngRange = tonumber(overrides.twistRngRangeDeg) or 0
    local twistRngOn = (overrides.seedAffects and overrides.seedAffects.twist) ~= false
    local enableTwist = overrides.enableTwist ~= false
    if not enableTwist then
        twistStrength = 0
        twistRngRange = 0
    end

    local jitter = cfg.segmentScaleJitter or {length = 0, thickness = 0}
    local profScale = overrides.scaleProfile

    local partCfg = (overrides.materialization and overrides.materialization.part)
        or (cfg.materialization and cfg.materialization.part) or {}
    local baseLength = partCfg.baseLength or 2
    local baseThickness = partCfg.baseThickness or 1

    local yaw, pitch, roll = 0, 0, 0
    local currentCF = startCF
    local segRefs = {}
    for i = 1, segCount do
        local delta = GrowthProfiles.rotDelta(profile, rngProfile, state)
        local dy, dp, dr = delta.yaw, delta.pitch, delta.roll
        if enableMicroJitter then
            local j = microJitter
            dy = dy + rngMicro:NextNumber(-j, j)
            dp = dp + rngMicro:NextNumber(-j, j)
        end
        if twistStrength ~= 0 or (twistRngOn and twistRngRange > 0) then
            local rnd = twistRngOn and rngMicro:NextNumber(-twistRngRange, twistRngRange) or 0
            dr = dr + twistStrength + rnd
        end
        if cont == "accumulate" then
            yaw = yaw + dy; pitch = pitch + dp; roll = roll + dr
        else
            yaw, pitch, roll = dy, dp, dr
        end
        if yClamp then yaw = clamp(yaw, -yClamp, yClamp) end
        if pClamp then pitch = clamp(pitch, -pClamp, pClamp) end

        local baseS = evalScaleProfile(i, segCount, profScale)
        local enableScaleJitter = (overrides.enableScaleJitter ~= false)
        if profScale then
            if profScale.enableJitter == false then
                enableScaleJitter = false
            elseif profScale.enableJitter == true then
                enableScaleJitter = true
            end
        end
        local jSample = enableScaleJitter and gaussian(rngMicro) or 0
        local lenJ = jSample * jitter.length
        local thJ  = jSample * jitter.thickness
        local length = baseLength * baseS * (1 + lenJ)
        local thickness = baseThickness * baseS * (1 + thJ)
        if not isfinite(length) or length <= 0 then length = baseLength end
        if not isfinite(thickness) or thickness <= 0 then thickness = baseThickness end

        local rot = CFrame.Angles(safeRad(pitch), safeRad(roll), safeRad(yaw))
        local stepCF = currentCF * rot * CFrame.new(0, length/2, 0)
        local seg = {
            cframe = stepCF,
            length = length,
            thickness = thickness,
            depth = depth,
            chainId = chainId,
            index = i,
            fill = 0,
        }
        segOut[#segOut + 1] = seg
        segRefs[i] = seg
        currentCF = stepCF * CFrame.new(0, length/2, 0)
    end

    return { segRefs = segRefs, segCount = segCount }
end

local function getVisual(loomUid)
    local v = visuals[loomUid]
    if not v then
        v = {segments = {}}
        visuals[loomUid] = v
    end
    return v
end

local function renderSegments(scene, cfg, segments, chainMap)
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
        local branchName = (chainMap and chainMap[seg.chainId] and chainMap[seg.chainId].profileName) or "trunk"
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
            attributes = {
                BranchName = branchName,
                ChainId = seg.chainId,
                Depth = seg.depth or 0,
                Index = seg.index or 1,
            },
        })
    end
end

-- deterministic decoration placement
local function placeDecorations(scene, baseSeed, segOut, config, overrides, partCfg)
    local decoCfg = overrides.decorations
    if not (decoCfg and decoCfg.enabled and decoCfg.types and #decoCfg.types > 0) then
        if config and config.models and config.models.decorations then
            decoCfg = { enabled = true, types = config.models.decorations }
        else
            return
        end
    end
    for _, seg in ipairs(segOut) do
        if seg.fill == 1 then
        for _, typ in ipairs(decoCfg.types) do
            local depth = seg.depth or 0
            if depth >= (typ.minDepth or 0) and depth <= (typ.maxDepth or math.huge) then
                local rngD = SeedUtil.rng(baseSeed, "deco", seg.chainId or 0, seg.index or 0, depth)
                local density = tonumber(typ.density or typ.densityPerSeg or 0) or 0
                local count, extra
                if typ.perLength then
                    local k = density * (seg.length or 1)
                    count = math.floor(k)
                    extra = k - count
                else
                    count = math.floor(density)
                    extra = density - count
                end
                local function placeOne()
                    local cf = seg.cframe
                    if typ.placement == "tip" then
                        cf = cf * CFrame.new(0, (seg.length or 0)/2, 0)
                    elseif typ.placement == "junction" then
                        cf = cf * CFrame.new(0, -(seg.length or 0)/2, 0)
                    end
                    if typ.rotation == "upright" then
                        cf = CFrame.new(cf.Position)
                    end
                    local yaw = tonumber(typ.yaw or 0) or 0
                    local pitch = tonumber(typ.pitch or 0) or 0
                    local roll = tonumber(typ.roll or 0) or 0
                    local yawR = rngD:NextNumber(-yaw, yaw)
                    local pitchR = rngD:NextNumber(-pitch, pitch)
                    local rollR = rngD:NextNumber(-roll, roll)
                    cf = cf * CFrame.Angles(math.rad(pitchR), math.rad(rollR), math.rad(yawR))
                    local smin = tonumber(typ.scaleMin or 1) or 1
                    local smax = tonumber(typ.scaleMax or 1) or 1
                    local scale = rngD:NextNumber(smin, smax)
                    local spec
                    if typ.models and #typ.models > 0 and scene.ResolveModel then
                        local idx = rngD:NextInteger(1, #typ.models)
                        local inst = scene.ResolveModel(typ.models, { select = function(L) return L[idx] end })
                        if inst then
                            spec = { instance = inst, cframe = cf, scale = Vector3.new(scale, scale, scale) }
                        end
                    end
                    if not spec then
                        spec = {
                            class = "Part",
                            size = Vector3.new(scale, scale, scale),
                            cframe = cf,
                            material = partCfg and partCfg.material or Enum.Material.SmoothPlastic,
                            color = partCfg and partCfg.color or Color3.new(1,1,1),
                            anchored = true,
                            canCollide = false,
                            name = "Deco",
                        }
                    end
                    scene.Spawn(spec)
                end
                local placed = 0
                for _ = 1, count do
                    if typ.maxPerChain and placed >= typ.maxPerChain then break end
                    placeOne()
                    placed = placed + 1
                end
                if (not typ.maxPerChain or placed < typ.maxPerChain) and rngD:NextNumber() < extra then
                    placeOne()
                end
            end
        end
        end
    end
end

function GrowthVisualizer.Render(container, loomState)
    local config = LoomConfigs[loomState.configId]
    if not config then return end

    local v = getVisual(loomState.loomUid)
    v.segments = {}
    local segOut = v.segments

    local overrides = loomState.overrides or {}
    local cfg = config.growthDefaults or {}

    local profiles = config.profiles
    local branchAssignments = config.branchAssignments
    if not profiles or not branchAssignments then
        profiles = profiles or {}
        profiles.trunk = profiles.trunk or (config.profileDefaults or {kind = "curved"})
        branchAssignments = branchAssignments or {trunkProfile = "trunk"}
    end

    local trunkName = branchAssignments.trunkProfile or "trunk"
    if not profiles[trunkName] then
        warn(string.format(
            "[GrowthVisualizer] Missing profile '%s' in config '%s'; using 'trunk'",
            tostring(trunkName),
            tostring(loomState.configId)
        ))
        profiles.trunk = profiles.trunk or (config.profileDefaults or {kind="curved"})
        trunkName = "trunk"
    end

    local chainMap = {}
    local nextId = 1
    local baseSeed = loomState.baseSeed or 0

    local designFull = (GrowthVisualizer._editorMode == true) or (overrides.designFull == true)

    local profileOverride = overrides.profile

    local branchDepthMax = overrides.branchDepthMax
    if branchDepthMax == nil then
        branchDepthMax = cfg.branchDepthMax
    end
    branchDepthMax = branchDepthMax or 0

    local function resolveChildren(prof, profileName)
        local children = prof.children
        if type(children) == "table" and not (children[1] and children[1].name) then
            local flat = {}
            for _, list in pairs(children) do
                if type(list) == "table" then
                    for _, pick in ipairs(list) do
                        table.insert(flat, pick)
                    end
                end
            end
            if #flat > 0 then
                warn(string.format("[GrowthVisualizer] profile '%s' uses legacy depth rules; flattening", tostring(profileName)))
                children = flat
                prof.children = flat
            else
                children = nil
            end
        end
        if prof.depthRules then
            local flat = {}
            for _, list in pairs(prof.depthRules) do
                if type(list) == "table" then
                    for _, pick in ipairs(list) do
                        table.insert(flat, pick)
                    end
                end
            end
            if #flat > 0 then
                warn(string.format("[GrowthVisualizer] profile '%s' uses legacy depthRules; converting", tostring(profileName)))
                children = children or {}
                for _, pick in ipairs(flat) do table.insert(children, pick) end
                prof.children = children
            end
            prof.depthRules = nil
        end
        return children
    end

    local function spawnChildBranches(chainId, children, depth, startCF, segRefs, segCount)
        if not children or depth >= branchDepthMax then return end
        local lastSeg = segRefs[segCount]
        local parentRot = startCF.Rotation
        local basePos = startCF.Position

        for pIdx, pick in ipairs(children) do
            local place = pick.placement or "tip"

            local function placeCFForSeg(seg)
                local cf = seg.cframe
                if place == "junction" then
                    cf = cf * CFrame.new(0, -(seg.length or 0)/2, 0)
                else
                    cf = cf * CFrame.new(0, (seg.length or 0)/2, 0)
                end
                cf = CFrame.new(cf.Position) * parentRot
                local r = pick.rotation
                if r then
                    cf = cf * CFrame.Angles(math.rad(r.pitch or 0), math.rad(r.yaw or 0), math.rad(r.roll or 0))
                end
                return cf
            end

            local function spawnOneAt(cf)
                nextId = nextId + 1
                traverse(nextId, depth + 1, pick.name, cf)
            end

            if place == "per_segment" or place == "pattern" then
                local step = math.max(1, math.floor(pick.step or 1))
                local chancePct = tonumber(pick.chance or 0) or 0
                local yawStep = tonumber(pick.spiralDeg or 0) or 0
                local rngPick = SeedUtil.rng(baseSeed, "child-perseg", chainId, depth, pIdx)

                local yawAcc = 0
                for i = 1, segCount, step do
                    local seg = segRefs[i]
                    local fire = (chancePct <= 0) or (rngPick:NextNumber() < (chancePct / 100))
                    if fire then
                        local cf = placeCFForSeg(seg)
                        if yawStep ~= 0 then
                            yawAcc = yawAcc + yawStep
                            cf = cf * CFrame.Angles(0, math.rad(yawAcc), 0)
                        end
                        spawnOneAt(cf)
                    end
                end
            else
                local count = pick.count or 1
                local intCount = math.floor(count)
                local extra = count - intCount
                local posCF
                if place == "tip" and lastSeg then
                    local tipCF = lastSeg.cframe * CFrame.new(0, lastSeg.length/2, 0)
                    posCF = CFrame.new(tipCF.Position) * parentRot
                else
                    posCF = CFrame.new(basePos) * parentRot
                end
                for _ = 1, intCount do spawnOneAt(posCF) end
                if extra > 0 then
                    local rngPick = SeedUtil.rng(baseSeed, "child", chainId, depth, pIdx)
                    if rngPick:NextNumber() < extra then spawnOneAt(posCF) end
                end
            end
        end
    end

    local function traverse(chainId, depth, profileName, startCF)
        local prof = profileOverride or profiles[profileName] or profiles.trunk or (config.profileDefaults or {kind="curved"})
        prof = GrowthProfiles.clampProfile(prof)
        local res = buildChain(segOut, chainId, depth, baseSeed, startCF, prof, cfg, overrides)
        chainMap[chainId] = { id = chainId, depth = depth, profileName = profileName, startCF = startCF, segCount = res.segCount }
        local segRefs = res.segRefs
        local segCount = res.segCount

        local fills
        if designFull then
            fills = {}
            for i = 1, segCount do fills[i] = 1 end
        else
            fills = computeSegmentFill(segCount, loomState.g or 0)
        end
        for i = 1, segCount do
            segRefs[i].fill = fills[i]
        end

        local children = resolveChildren(prof, profileName)
        spawnChildBranches(chainId, children, depth, startCF, segRefs, segCount)
    end

    traverse(1, 0, trunkName, CFrame.new())

    local matOverrides = overrides.materialization or cfg.materialization or {mode = "Model"}
    local scene = loomState.scene
    if scene and scene.Clear then scene.Clear() end

    if scene and scene.Spawn then
        local partCfg = matOverrides.part or {}
        if matOverrides.mode == "Model" and scene.ResolveModel and config.models then
            local lists = config.models.byDepth or {}
            local function spawnPart(seg)
                local shape = partCfg.partType or Enum.PartType.Ball
                local size
                if shape == Enum.PartType.Ball then
                    size = Vector3.new(seg.thickness, seg.thickness, seg.thickness)
                else
                    size = Vector3.new(seg.thickness, seg.length, seg.thickness)
                end
                local branchName = (chainMap[seg.chainId] and chainMap[seg.chainId].profileName) or "trunk"
                scene.Spawn({
                    class = "Part",
                    shape = shape,
                    size = size,
                    cframe = seg.cframe,
                    material = partCfg.material or Enum.Material.SmoothPlastic,
                    color = partCfg.color,
                    anchored = true,
                    canCollide = false,
                    name = "Segment",
                    attributes = {
                        BranchName = branchName,
                        ChainId = seg.chainId,
                        Depth = seg.depth or 0,
                        Index = seg.index or 1,
                    },
                })
            end
            for _, seg in ipairs(segOut) do
                local list = lists[seg.depth]
                local chainInfo = chainMap[seg.chainId]
                if chainInfo and seg.index == chainInfo.segCount and lists.terminal then
                    list = lists.terminal
                end
                local inst
                if list and #list > 0 then
                    local r = SeedUtil.rng(baseSeed, "model", seg.chainId, seg.index)
                    local idx = r:NextInteger(1, #list)
                    inst = scene.ResolveModel(list, { select = function(L) return L[idx] end })
                end
                if inst then
                    local branchName = (chainMap[seg.chainId] and chainMap[seg.chainId].profileName) or "trunk"
                    scene.Spawn({
                        instance = inst,
                        cframe = seg.cframe,
                        attributes = {
                            BranchName = branchName,
                            ChainId = seg.chainId,
                            Depth = seg.depth or 0,
                            Index = seg.index or 1,
                        },
                    })
                else
                    spawnPart(seg)
                end
            end
        else
            renderSegments(scene, partCfg, segOut, chainMap)
        end

        placeDecorations(scene, baseSeed, segOut, config, overrides, partCfg)
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
