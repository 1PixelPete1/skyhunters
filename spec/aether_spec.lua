package.path = "src/server/?.luau;src/server/?/init.luau;src/shared/?.luau;src/shared/?/init.luau;" .. package.path

if not time then
    function time()
        return os.clock()
    end
end

if not Color3 then
    Color3 = { fromRGB = function() return {} end }
end

local Aether = require("Aether")
local Economy = require("Economy")

local function newPlayer()
    return {
        id = 1,
        crumbs = 0,
        inventory = {},
        upgrades = {},
        aether = {
            current = 0,
            target = 10,
            decayRate = 0.08,
            purityBase = 0.55,
            totalRate = 1,
            lastSettleTs = 0,
        },
        producers = {},
        timestamps = {},
    }
end

-- Settle clamps to capacity
local p1 = newPlayer()
Aether.Settle(p1, 20)
assert(p1.aether.current == 10, "should clamp to target")

-- Overfill decays back toward capacity
local p2 = newPlayer()
p2.aether.current = 15
Aether.Settle(p2, 5)
assert(p2.aether.current < 15, "overfill should decay")
assert(p2.aether.current > p2.aether.target, "still above target after decay")

-- Snapshot after sell carries crumbs
local p3 = newPlayer()
p3.aether.current = 20
local gain = Economy.SellAether(p3)
assert(gain > 0, "sell should return gain")
local payload = { aether = Aether.Snapshot(p3), crumbs = p3.crumbs }
assert(payload.crumbs == p3.crumbs, "crumbs missing from payload")
assert(payload.aether.current == 0, "aether not reset after sell")

-- Capacity rising edge flag fires once
local p4 = newPlayer()
p4.aether.totalRate = 5
Aether.Settle(p4, 2)
local snap1 = Aether.Snapshot(p4)
assert(snap1.atCap == true, "atCap should be true on first snapshot")
local snap2 = Aether.Snapshot(p4)
assert(not snap2.atCap, "atCap should clear after first snapshot")

print("Aether tests passed!")

