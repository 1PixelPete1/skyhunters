package.path = "plugin/?.lua;plugin/?/init.lua;src/shared/?.luau;src/shared/?/init.luau;" .. package.path

if not Random then
    Random = {}
    local mt = {}
    mt.__index = mt
    function Random.new(seed)
        return setmetatable({seed = seed or 0}, mt)
    end
    function mt:NextInteger(min, max)
        self.seed = (1103515245 * self.seed + 12345) % 2^31
        local range = (max - min + 1)
        return min + (self.seed % range)
    end
    function mt:NextNumber(min, max)
        self.seed = (1103515245 * self.seed + 12345) % 2^31
        local value = self.seed / 2^31
        if min and max then
            return min + (max - min) * value
        else
            return value
        end
    end
end

if not game then
    game = {GetService = function() return nil end}
end

if not script then
    script = {FindFirstAncestor = function() return nil end}
end

local GrowthVisualizer = require("growth/GrowthVisualizer")

local function render(uid, overrides)
    local state = {
        loomUid = uid,
        configId = "tree_basic",
        baseSeed = 123,
        g = 100,
        overrides = overrides or {},
    }
    GrowthVisualizer.Render(nil, state)
    return GrowthVisualizer._getVisualState(uid).segments
end

-- Segment count override
local segsA = render(1, {segmentCount = 3})
assert(#segsA == 3, "segment override failed")

-- Min/max segment count
local segsB = render(2, {segmentCountMin = 2, segmentCountMax = 2})
assert(#segsB == 2, "segment min/max failed")

-- Zigzag cadence
local segsC = render(3, {segmentCount = 5, path = {style = "zigzag", amplitudeDeg = 10, zigzagEvery = 2}})
assert(segsC[1].yaw * segsC[2].yaw > 0 and segsC[2].yaw * segsC[3].yaw < 0, "zigzag cadence failed")

-- Size profile linear_down
local segsD = render(4, {segmentCount = 5, scaleProfile = {mode = "linear_down", start = 1, finish = 0.5, enableJitter = false}})
assert(segsD[1].lengthScale > segsD[5].lengthScale, "size profile failed")

print("growth_visualizer_spec.lua ok")
