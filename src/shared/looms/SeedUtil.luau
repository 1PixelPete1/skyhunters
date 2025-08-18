--!strict
local SeedUtil = {}

local function hash32(s: string): number
    local h = 2166136261
    for i = 1, #s do
        h = (bit32.bxor(h, string.byte(s, i)) * 16777619) % 2^32
    end
    return h % 2147483647 -- 31-bit positive
end

function SeedUtil.toInt(seedAny): number
    if typeof(seedAny) == "number" then return math.floor(seedAny) end
    return hash32(tostring(seedAny))
end

function SeedUtil.rng(seedAny, stream: string): Random
    local s = SeedUtil.toInt(seedAny)
    local t = hash32(stream)
    -- combine with xor & a golden-ratio-ish odd multiplier to decorrelate
    local combined = (bit32.bxor(s, t) * 2654435761) % 2147483647
    if combined <= 0 then combined = combined + 1 end
    return Random.new(combined)
end

function SeedUtil.noiseOffsets(seedAny, stream: string): (number, number, number)
    local r = SeedUtil.rng(seedAny, "noise:"..stream)
    return r:NextNumber(0, 10_000), r:NextNumber(0, 10_000), r:NextNumber(0, 10_000)
end

return SeedUtil
