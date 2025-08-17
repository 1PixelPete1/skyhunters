package.path = "src/server/?.luau;src/server/?/init.luau;src/shared/?.luau;src/shared/?/init.luau;src/client/?.luau;src/client/?/init.luau;" .. package.path

-- Provide a simple Random stub for the Lua environment.
if not Random then
    Random = {}
    local mt = {}
    mt.__index = mt
    function Random.new(seed)
        local self = {seed = seed or 0}
        return setmetatable(self, mt)
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

local GrowthService = require("GrowthService")
local WeaverService = require("WeaverService")
local Rarity = require("Economy/Rarity")
local GrowthVisualizer = require("growth/GrowthVisualizer")

-- Test rarity multipliers
assert(Rarity.GetGrowthMultiplier("Epic") == 0.85, "Epic multiplier incorrect")
assert(Rarity.GetGrowthMultiplier("Unknown") == 1.0, "default multiplier incorrect")

-- Determinism: two looms with same seed should produce identical eligible nodes
local uid1 = GrowthService.RegisterLoom({}, "tree_basic", "Common", nil, 123)
local uid2 = GrowthService.RegisterLoom({}, "tree_basic", "Common", nil, 123)

GrowthService.Tick(4000) -- advance to completion

local nodes1 = GrowthService.GetEligibleNodeIds(uid1)
local nodes2 = GrowthService.GetEligibleNodeIds(uid2)
assert(#nodes1 == #nodes2, "node count mismatch")
for i = 1, #nodes1 do
    local n1, n2 = nodes1[i], nodes2[i]
    assert(n1.segIndex == n2.segIndex and n1.kind == n2.kind, "node mismatch")
end

-- GrowthVisualizer mapping test
local snapshot = GrowthService.GetSnapshot({}).looms[1]
GrowthVisualizer.Render(nil, snapshot)
local visual = GrowthVisualizer._getVisualState(snapshot.loomUid)
assert(visual[#visual] == 1, "last segment should be filled after completion")

print("loom_growth_spec.lua ok")
