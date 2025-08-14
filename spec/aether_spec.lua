package.path = "src/server/?.luau;src/server/?/init.luau;src/shared/?.luau;src/shared/?/init.luau;" .. package.path

local Aether = require("Aether")
local Config = require("Config")

local function newPlayer()
    return {
        v = 1,
        id = 1,
        crumbs = 0,
        inventory = {},
        upgrades = {},
        aether = {
            current = 0,
            target = 20,
            decayRate = 0.08,
            purityBase = 0.55,
            totalRate = 0,
            lastSettleTs = os.time(),
        },
        producers = {},
        timestamps = {},
    }
end

-- Test 1: Offline settle - growth to target
local player1 = newPlayer()
player1.aether.totalRate = 1
player1.aether.lastSettleTs = os.time() - 25
Aether.Settle(player1)
assert(math.abs(player1.aether.current - 20) < 0.01, "Should reach target after 25s")

-- Test 2: Overfill decay
local player2 = newPlayer()
player2.aether.current = 50
player2.aether.target = 20
player2.aether.decayRate = 0.08
player2.aether.lastSettleTs = os.time() - 5
Aether.Settle(player2)
local expected = 20 + 30 * math.exp(-0.08 * 5)
assert(math.abs(player2.aether.current - expected) < 0.01, "Overfill decay incorrect")

-- Test 3: Add producer delta
local player3 = newPlayer()
Aether.Init(player3)
local uid = Aether.AddProducer(player3, "Basic", 0.73)
assert(math.abs(player3.aether.totalRate - 0.73) < 0.01, "totalRate should increase by 0.73")
Aether.SetProducerActive(player3, uid, false)
assert(math.abs(player3.aether.totalRate) < 0.01, "totalRate should decrease when inactive")

-- Test 4: Burst above target
local player4 = newPlayer()
player4.aether.current = 20
player4.aether.target = 20
Aether.ApplyBurst(player4, 30)
assert(player4.aether.current == 50, "Burst should add 30 to current")

-- Test 5: Sell path integration
local player5 = newPlayer()
player5.aether.current = 40
player5.aether.purityBase = 0.55
local gain = Aether.RequestSell(player5)
assert(gain == math.floor(40 * 0.55 * 8), "Sell calculation incorrect")
assert(player5.aether.current == 0, "Aether should be zeroed after sell")

-- Test 6: Multiple producers management
local player6 = newPlayer()
Aether.Init(player6)
local uids = {}
for i = 1, 5 do
    local uid = Aether.AddProducer(player6, "Test", 0.2)
    table.insert(uids, uid)
end
assert(math.abs(player6.aether.totalRate - 1.0) < 0.01, "5 producers * 0.2 = 1.0")

for i = 1, 3 do
    Aether.RemoveProducer(player6, uids[i])
end
assert(math.abs(player6.aether.totalRate - 0.4) < 0.01, "2 remaining producers * 0.2 = 0.4")

print("All Aether tests passed!")
