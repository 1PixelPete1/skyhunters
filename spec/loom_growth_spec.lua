package.path = "plugin/?.lua;plugin/?/init.lua;src/server/?.luau;src/server/?/init.luau;src/shared/?.luau;src/shared/?/init.luau;src/client/?.luau;src/client/?/init.luau;" .. package.path

-- Provide a simple Random stub for the plain Lua test environment.
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

local function tryRequire(name)
    local ok, mod = pcall(require, name)
    if not ok then
        print("loom_growth_spec.lua skipped: " .. tostring(mod))
    end
    return ok and mod or nil
end

local GrowthService = tryRequire("GrowthService")
local Rarity = tryRequire("Economy/Rarity")
local GrowthVisualizer = tryRequire("growth/GrowthVisualizer")
local GrowthProfiles = tryRequire("looms/GrowthProfiles")
local LoomDesigner = tryRequire("LoomDesigner")

if not (GrowthService and Rarity and GrowthVisualizer and GrowthProfiles and LoomDesigner) then
    return
end

if not CFrame then
    print("loom_growth_spec.lua skipped: missing Roblox globals")
    return
end

if LoomDesigner.Start then
    LoomDesigner.Start(nil)
end

-- Test rarity multipliers
assert(Rarity.GetGrowthMultiplier("Epic") == 0.85, "Epic multiplier incorrect")
assert(Rarity.GetGrowthMultiplier("Unknown") == 1.0, "default multiplier incorrect")

-- Register several looms then advance to completion
local uid1 = GrowthService.RegisterLoom({}, "tree_basic", "Common", nil, 123)
local uid2 = GrowthService.RegisterLoom({}, "tree_basic", "Common", nil, 123)
local uidA = GrowthService.RegisterLoom({}, "tree_basic", "Common", nil, 111)
local uidB = GrowthService.RegisterLoom({}, "tree_basic", "Common", nil, 222)

GrowthService.Tick(4000)

-- Determinism: two looms with same seed should produce identical eligible nodes
local nodes1 = GrowthService.GetEligibleNodeIds(uid1)
local nodes2 = GrowthService.GetEligibleNodeIds(uid2)
assert(#nodes1 == #nodes2, "node count mismatch")
for i = 1, #nodes1 do
    local n1, n2 = nodes1[i], nodes2[i]
    assert(n1.segIndex == n2.segIndex and n1.kind == n2.kind, "node mismatch")
end

-- Grab snapshots for later tests
local snapshot1, snapA, snapB
for _, s in ipairs(GrowthService.GetSnapshot({}).looms) do
    if s.loomUid == uid1 then snapshot1 = s end
    if s.loomUid == uidA then snapA = s end
    if s.loomUid == uidB then snapB = s end
end

-- GrowthVisualizer mapping test
GrowthVisualizer.Render(nil, snapshot1)
local visual = GrowthVisualizer._getVisualState(uid1)
assert(visual.segments[#visual.segments].fill == 1, "last segment should be filled after completion")

-- RNG isolation across multiple looms and determinism per loom
GrowthVisualizer.Render(nil, snapA)
GrowthVisualizer.Render(nil, snapB)
local vA1 = GrowthVisualizer._getVisualState(uidA)
local vB1 = GrowthVisualizer._getVisualState(uidB)
assert(vA1.segments[1].lengthScale ~= vB1.segments[1].lengthScale, "RNG isolation failed")
GrowthVisualizer.Render(nil, snapA)
local vA2 = GrowthVisualizer._getVisualState(uidA)
assert(vA1.segments[1].lengthScale == vA2.segments[1].lengthScale, "determinism failure")

-- Profile bounds respected
local profile = {kind = "spiral", yawStep = 0, yawVar = 5, pitchBias = 2, pitchVar = 3, rollBias = 1, rollVar = 2}
local rngProfile = Random.new(0)
for _ = 1, 20 do
    local d = GrowthProfiles.rotDelta(profile, rngProfile, {})
    assert(d.yaw >= -5 and d.yaw <= 5, "yaw bounds")
    assert(d.pitch >= -1 and d.pitch <= 5, "pitch bounds")
    assert(d.roll >= -1 and d.roll <= 3, "roll bounds")
end

-- Export -> reimport round trip of a config
local tmp = os.tmpname()
local newConfig = {
    id = "round_trip_test",
    uiName = "Round Trip",
    growthDefaults = {segmentCount = 5},
    profileDefaults = {kind = "spiral"},
    models = {byDepth = {}},
    nodes = {mode = "none"},
}
assert(LoomDesigner.ExportConfig(newConfig, tmp), "export failed")
local loaded = dofile(tmp)
assert(loaded.round_trip_test.growthDefaults.segmentCount == 5, "round trip failed")
os.remove(tmp)

print("loom_growth_spec.lua ok")
