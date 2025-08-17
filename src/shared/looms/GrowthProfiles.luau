--!strict
-- Helpers for applying rotation deltas based on a profile kind.
-- Server and client share this logic to keep traversal deterministic.

local GrowthProfiles = {}

local function clamp(num, min, max)
    if num < min then return min end
    if num > max then return max end
    return num
end

-- Returns yaw/pitch/roll deltas in degrees.
function GrowthProfiles.rotDelta(profile, rngProfile, state)
    local kind = profile.kind
    if kind == "spiral" then
        return {
            yaw = (profile.yawStep or 0) + rngProfile:NextNumber(-(profile.yawVar or 0), profile.yawVar or 0),
            pitch = (profile.pitchBias or 0) + rngProfile:NextNumber(-(profile.pitchVar or 0), profile.pitchVar or 0),
            roll = (profile.rollBias or 0) + rngProfile:NextNumber(-(profile.rollVar or 0), profile.rollVar or 0),
        }
    elseif kind == "curved" then
        local sign = state.curveSign or 1
        return {
            yaw = sign * (profile.curveRate or 0),
            pitch = (profile.pitchBias or 0) + rngProfile:NextNumber(-(profile.pitchVar or 0), profile.pitchVar or 0),
            roll = (profile.rollBias or 0) + rngProfile:NextNumber(-(profile.rollVar or 0), profile.rollVar or 0),
        }
    elseif kind == "zigzag" then
        state.zig = -(state.zig or 1)
        return {
            yaw = (state.zig) * (profile.zigzagStep or 0),
            pitch = (profile.pitchBias or 0) + rngProfile:NextNumber(-(profile.pitchVar or 0), profile.pitchVar or 0),
            roll = (profile.rollBias or 0) + rngProfile:NextNumber(-(profile.rollVar or 0), profile.rollVar or 0),
        }
    else -- random/linear fallback
        local chaos = profile.randomChaos or 0
        return {
            yaw = rngProfile:NextNumber(-chaos, chaos),
            pitch = (profile.pitchBias or 0) + rngProfile:NextNumber(-(profile.pitchVar or 0), profile.pitchVar or 0),
            roll = (profile.rollBias or 0) + rngProfile:NextNumber(-(profile.rollVar or 0), profile.rollVar or 0),
        }
    end
end

-- Clamp profile fields into safe ranges.
function GrowthProfiles.clampProfile(profile)
    local cloned = {}
    for k, v in pairs(profile) do cloned[k] = v end
    cloned.childInherit = clamp((profile.childInherit or 1), 0, 1)
    return cloned
end

return GrowthProfiles
