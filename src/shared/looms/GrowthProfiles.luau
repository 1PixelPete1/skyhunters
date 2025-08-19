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

local function rotCurved(prof, rng, state)
    state.t = (state.t or 0) + 1
    local i, N = state.t, prof.maxSegments or 24
    local t = (i-1) / math.max(1, N-1)
    state.phase = state.phase or rng:NextNumber(0, 2 * math.pi)
    state.dir = state.dir or (rng:NextNumber() < 0.5 and -1 or 1)
    local phase = state.phase
    local dir = state.dir
    local amp = prof.amplitudeDeg or 10
    local sweep = math.sin(t * math.pi * (prof.frequency or 1) + phase) * amp
    local env = (1 - (2*t-1)^2) ^ (prof.curvature or 0.35)
    return {
        yaw = dir * sweep * env,
        pitch = dir * (amp * 0.35) * env,
        roll = 0,
    }
end

local function rotZigzag(prof, rng, state)
    state.count = (state.count or 0) + 1
    local runLen = prof.zigzagEvery or 1
    state.sign = state.sign or (rng:NextNumber() < 0.5 and -1 or 1)
    if state.count > runLen then
        state.count = 1
        state.sign = -state.sign
    end
    local step = prof.zigzagStep or prof.amplitudeDeg or 10
    return {
        yaw = state.sign * step,
        pitch = prof.pitchBias or 0,
        roll = prof.rollBias or 0,
    }
end

local function rotNoise(prof, rng, _state)
    local amp = prof.noiseAmp or (prof.amplitudeDeg or 10)
    return {
        yaw = rng:NextNumber(-amp, amp),
        pitch = rng:NextNumber(-0.6 * amp, 0.6 * amp),
        roll = 0,
    }
end

local function rotSigmoid(prof, rng, state)
    state.count = (state.count or 0) + 1
    local i, N = state.count, prof.maxSegments or 24
    local t = (i-1) / math.max(1, N-1)
    state.k = state.k or (prof.sigmoidK or 6) + rng:NextNumber(-1, 1)
    state.mid = state.mid or (prof.sigmoidMid or 0.5) + rng:NextNumber(-0.1, 0.1)
    local s = 1 / (1 + math.exp(-state.k * (t - state.mid)))
    local amp = prof.amplitudeDeg or 10
    return {
        yaw = (s - 0.5) * 2 * amp,
        pitch = (0.5 - math.abs(s - 0.5)) * 2 * (amp * 0.4),
        roll = 0,
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
        pitch = 0,
        roll = 0,
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
