package.path = "src/server/?.luau;src/server/?/init.luau;src/shared/?.luau;src/shared/?/init.luau;" .. package.path

if not time then
    function time()
        return os.clock()
    end
end

if not Color3 then
    Color3 = { fromRGB = function() return {} end }
end

local Economy = require("Economy")
local Config = require("Config")

local function newPlayer()
    return {
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
        },
        timestamps = {},
    }
end

-- Selling Aether acceptance test
local player = newPlayer()
player.aether.current = 40
local gain = Economy.SellAether(player)
assert(gain == 176, "expected 176 gain")
assert(player.aether.current == 0, "aether not reset")
assert(player.crumbs == 176, "crumbs not updated")

-- Selling item polished_crystal
local player2 = newPlayer()
player2.inventory.polished_crystal = 2
local gain2 = Economy.SellItem(player2, "polished_crystal", 2)
assert(gain2 == 300, "expected gain 300")
assert(player2.inventory.polished_crystal == 0, "inventory not reduced")
assert(player2.crumbs == 300, "crumbs not updated")

-- Attempt to sell with zero aether
local player3 = newPlayer()
local gain3 = Economy.SellAether(player3)
assert(gain3 == 0, "gain should be 0")
assert(player3.crumbs == 0, "crumbs should remain 0")

-- Attempt with bad reason
local player4 = newPlayer()
local ok = Economy.ApplyCrumbsDelta(player4, 10, "hack")
assert(ok == false, "bad reason should be rejected")
assert(player4.crumbs == 0, "crumbs should not change")

-- Rate limit exceed
local player5 = newPlayer()
for i=1,10 do
    assert(Economy.ApplyCrumbsDelta(player5, 1, "grant"))
end
assert(Economy.ApplyCrumbsDelta(player5, 1, "grant") == false, "11th update should fail")

-- Purchase upgrade
local player6 = newPlayer()
player6.crumbs = 200
local success = Economy.PurchaseUpgrade(player6, "purity_plus005")
assert(success, "purchase should succeed")
assert(player6.crumbs == 0, "cost should be deducted")
assert(player6.aether.purityBase > 0.55, "purityBase should increase")
assert(player6.upgrades.purity_plus005 == true, "upgrade recorded")

print("All tests passed!")
