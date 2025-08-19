--!strict
-- Helpers for applying rotation deltas based on a profile kind.
-- Server and client share this logic to keep traversal deterministic.

local GrowthProfiles = {}

local function clamp(num, min, max)
    if num < min then return min end
    if num > max then return max end
    return num
end

local function rotStraight(_prof, _rng, _state)
    return {yaw = 0, pitch = 0, roll = 0}
end

local function rotCurved(prof, _rng, state)
    state.t = (state.t or 0) + 1
    local i, N = state.t, prof.maxSegments or 24
    local t = (i-1) / math.max(1, N-1)
    local sweep = math.sin((t * math.pi) * (prof.frequency or 1)) * (prof.amplitudeDeg or 10)
    local env = (1 - (2*t-1)^2) ^ (prof.curvature or 0.35)
    return {
        yaw = sweep * env,
        pitch = (prof.amplitudeDeg or 10) * 0.35 * env,
        roll = (prof.rollBias or 0),
    }
end

local function rotZigzag(prof, _rng, state)
    state.zCount = (state.zCount or 0) + 1
    local runLen = prof.zigzagEvery or 1
    if state.zCount > runLen then
        state.zCount = 1
        state.zSign = -(state.zSign or 1)
    end
    local sign = state.zSign or 1
    return {
        yaw = sign * (prof.zigzagStep or prof.amplitudeDeg or 10),
        pitch = prof.pitchBias or 0,
        roll = prof.rollBias or 0,
    }
end

local function rotNoise(prof, rng, _state)
    local amp = prof.noiseAmp or (prof.amplitudeDeg or 10)
    local yaw = rng:NextNumber(-amp, amp)
    local pitch = rng:NextNumber(-0.6 * amp, 0.6 * amp)
    return {
        yaw = yaw,
        pitch = pitch,
        roll = prof.rollBias or 0,
    }
end

local function rotSigmoid(prof, _rng, state)
    state.sCount = (state.sCount or 0) + 1
    local i, N = state.sCount, prof.maxSegments or 24
    local t = (i-1) / math.max(1, N-1)
    local k = prof.sigmoidK or 6
    local mid = prof.sigmoidMid or 0.5
    local s = 1 / (1 + math.exp(-k * (t - mid)))
    local amp = prof.amplitudeDeg or 10
    return {
        yaw = (s - 0.5) * 2 * amp,
        pitch = (0.5 - math.abs(s - 0.5)) * 2 * (amp * 0.4),
        roll = prof.rollBias or 0,
    }
end

local function rotChaotic(prof, rng, state)
    state.x = state.x or rng:NextNumber(0.2, 0.8)
    local r = prof.chaoticR or 3.9
    state.x = r * state.x * (1 - state.x)
    local x = state.x
    local amp = prof.amplitudeDeg or 10
    return {
        yaw = (x - 0.5) * 2 * amp,
        pitch = (0.5 - math.abs(x - 0.5)) * 2 * (amp * 0.4),
        roll = prof.rollBias or 0,
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
        spiral = function(prof, rng, _st)
            return {
                yaw = (prof.yawStep or 0) + rng:NextNumber(-(prof.yawVar or 0), prof.yawVar or 0),
                pitch = (prof.pitchBias or 0) + rng:NextNumber(-(prof.pitchVar or 0), prof.pitchVar or 0),
                roll = (prof.rollBias or 0) + rng:NextNumber(-(prof.rollVar or 0), prof.rollVar or 0),
            }
        end,
        random = function(prof, rng, _st)
            local chaos = prof.randomChaos or 0
            return {
                yaw = rng:NextNumber(-chaos, chaos),
                pitch = (prof.pitchBias or 0) + rng:NextNumber(-(prof.pitchVar or 0), prof.pitchVar or 0),
                roll = (prof.rollBias or 0) + rng:NextNumber(-(prof.rollVar or 0), prof.rollVar or 0),
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
