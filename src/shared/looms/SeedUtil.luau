--!strict
local bit32 = bit32
local SeedUtil = {}

local function fnv1a32(str: string): number
    local h = 2166136261
    for i = 1, #str do
        h = bit32.bxor(h, string.byte(str, i))
        h = bit32.band(h * 16777619, 0xFFFFFFFF)
    end
    return h
end

function SeedUtil.toInt(seedAny): number
    if typeof(seedAny) == "number" then
        return math.floor(seedAny)
    end
    return fnv1a32(tostring(seedAny))
end

local function mixSeed(master: number, ...): number
    master = SeedUtil.toInt(master)
    local s = tostring(master)
    for i = 1, select("#", ...) do
        s ..= "|" .. tostring(select(i, ...))
    end
    return fnv1a32(s)
end

local RNG = {}
RNG.__index = RNG

function RNG.new(seed32: number)
    return setmetatable({ state = seed32 % 0x100000000 }, RNG)
end

function RNG:uint32(): number
    local x = self.state
    x = bit32.band(1103515245 * x + 12345, 0xFFFFFFFF)
    self.state = x
    return x
end

function RNG:unit(): number
    return self:uint32() / 0x100000000
end

function RNG:NextNumber(a: number?, b: number?): number
    a = a or 0
    b = b or 1
    return a + (b - a) * self:unit()
end

function RNG:NextInteger(a: number, b: number): number
    if a > b then a, b = b, a end
    local span = b - a + 1
    return a + (self:uint32() % span)
end

function RNG:sign(): number
    return (bit32.band(self:uint32(), 1) == 0) and 1 or -1
end

function SeedUtil.mixSeed(master: number, ...): number
    return mixSeed(master, ...)
end

function SeedUtil.rng(master: number, ...): any
    return RNG.new(mixSeed(master, ...))
end

function SeedUtil.seededSign(master: number, key: string): number
    return (bit32.band(mixSeed(master, "sign", key), 1) == 0) and 1 or -1
end

function SeedUtil.noiseOffsets(master: number, stream: string): (number, number, number)
    local r = SeedUtil.rng(master, "noise", stream)
    return r:NextNumber(0, 10_000), r:NextNumber(0, 10_000), r:NextNumber(0, 10_000)
end

return SeedUtil
