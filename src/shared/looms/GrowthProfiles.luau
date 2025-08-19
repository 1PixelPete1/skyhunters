--!strict
-- Helpers for applying rotation deltas based on a profile kind.
-- Server and client share this logic to keep traversal deterministic.

local GrowthProfiles = {}

local function clamp(num, min, max)
    if num < min then return min end
    if num > max then return max end
    return num
end

local function clampExpArg(x)
    -- Prevent math.exp overflow/underflow; 60 ~ e^60 ≈ 1.1e26 (safe double)
    if x > 60 then return 60 end
    if x < -60 then return -60 end
    return x
end

local function seededSign(rng)
    return (rng:NextInteger(0, 1) == 0) and -1 or 1
end

local function rotStraight(_prof, _rng, _state)
    return {yaw = 0, pitch = 0, roll = 0}
end

local function rotCurved(prof, rng, state)
    -- cache per-render macro params so all segments share them
    if not state._curved then
        state._curved = {
            phase = rng:NextNumber(0, 2*math.pi),
            dir   = seededSign(rng),
        }
    end
    state.t = (state.t or 0) + 1
    local i, N = state.t, prof.maxSegments or 24
    local t = (i-1)/math.max(1, N-1)

    local amp  = prof.amplitudeDeg or 12
    local freq = prof.frequency or 1
    local curv = prof.curvature or 0.35

    local sweep = math.sin(t*math.pi*freq + state._curved.phase) * amp
    local env   = (1 - (2*t - 1)^2) ^ curv
    return {
        yaw   = state._curved.dir * sweep * env,
        pitch = state._curved.dir * (amp * 0.35) * env,
        roll  = prof.rollBias or 0,
    }
end

local function rotZigzag(prof, rng, state)
    if not state._zz then
        state._zz = { sign = seededSign(rng), left = 0 }
    end
    local runLen = math.max(1, prof.zigzagEvery or 1)
    if state._zz.left <= 0 then
        state._zz.sign = -state._zz.sign
        state._zz.left = runLen
    end
    state._zz.left = state._zz.left - 1
    local amp = (prof.zigzagStep or prof.amplitudeDeg or 12)
    return { yaw = state._zz.sign * amp, pitch = prof.pitchBias or 0, roll = prof.rollBias or 0 }
end

local function rotNoise(prof, rng, _state)
    local amp = prof.noiseAmp or (prof.amplitudeDeg or 10)
    return {
        yaw   = rng:NextNumber(-amp, amp),
        pitch = rng:NextNumber(-0.6*amp, 0.6*amp),
        roll  = prof.rollBias or 0,
    }
end

local function rotSigmoid(prof, rng, state)
    if not state._sig then
        -- vary slope and midpoint per seed for visible differences
        local kBase  = prof.sigmoidK or 6
        local k      = kBase * rng:NextNumber(0.8, 1.25)     -- slope variance
        local mid    = (prof.sigmoidMid or 0.5) + rng:NextNumber(-0.1, 0.1)
        state._sig   = { k = k, mid = clamp(mid, 0.15, 0.85), dir = seededSign(rng) }
    end
    state.sCount = (state.sCount or 0) + 1
    local i, N = state.sCount, prof.maxSegments or 24
    local t = (i-1)/math.max(1, N-1)

    local amp = prof.amplitudeDeg or 10
    local x   = clampExpArg(-state._sig.k * (t - state._sig.mid))
    local s   = 1 / (1 + math.exp(x))  -- safe logistic
    -- Centered outputs: yaw spans [-amp, amp], pitch peaks near the middle
    return {
        yaw   = state._sig.dir * (s - 0.5) * 2 * amp,
        pitch = (0.5 - math.abs(s - 0.5)) * 2 * (amp * 0.4),
        roll  = prof.rollBias or 0,
    }
end

local function rotChaotic(prof, rng, state)
    if not state._ch then
        state._ch = { x = rng:NextNumber(0.2, 0.8) }
    end
    local r = prof.chaoticR or 3.9
    local x = state._ch.x
    x = r * x * (1 - x)
    state._ch.x = x
    local amp = prof.amplitudeDeg or 12
    return {
        yaw   = (x - 0.5) * 2 * amp,
        pitch = (0.5 - math.abs(x - 0.5)) * 2 * (amp * 0.4),
        roll  = prof.rollBias or 0,
    }
end

-- Returns yaw/pitch/roll deltas in degrees.
function GrowthProfiles.rotDelta(profile, rngProfile, state)
    local kind = profile.kind
    local dispatch = {
        straight = rotStraight,
        curved = rotCurved,
        zigzag = rotZigzag,
        noise = rotNoise,
        sigmoid = rotSigmoid,
        chaotic = rotChaotic,
        spiral = function(prof, rng, state)
            state.dir = state.dir or (rng:NextNumber() < 0.5 and -1 or 1)
            local dir = state.dir
            local step = prof.yawStep or prof.amplitudeDeg or 10
            local yawVar = prof.yawVar or 0
            return {
                yaw = dir * step + rng:NextNumber(-yawVar, yawVar),
                pitch = (prof.pitchBias or 0) + rng:NextNumber(-(prof.pitchVar or 0), prof.pitchVar or 0),
                roll = (prof.rollBias or 0) + rng:NextNumber(-(prof.rollVar or 0), prof.rollVar or 0),
            }
        end,
        random = function(prof, rng, _st)
            local amp = prof.amplitudeDeg or 180
            return {
                yaw = rng:NextNumber(-amp, amp),
                pitch = rng:NextNumber(-amp, amp),
                roll = 0,
            }
        end,
    }
    local fn = dispatch[kind] or dispatch.random
    return fn(profile, rngProfile, state)
end

-- Clamp profile fields into safe ranges.
function GrowthProfiles.clampProfile(profile)
    local cloned = {}
    for k, v in pairs(profile) do cloned[k] = v end
    cloned.childInherit = clamp((profile.childInherit or 1), 0, 1)
    return cloned
end

return GrowthProfiles
