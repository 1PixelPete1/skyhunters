package.path = "src/server/?.luau;src/server/?/init.luau;src/shared/?.luau;src/shared/?/init.luau;" .. package.path

if not Color3 then
    Color3 = { fromRGB = function() return {} end }
end

local InventoryBridge = require("InventoryBridge")

local player = {}

local items, cursor, total = InventoryBridge.GetPage(player, "producers")
assert(#items == 0 and total == 0, "Empty inventory returns no items")

local newItem = InventoryBridge._giveSampleItem(player, "producers", 1)
items, cursor, total = InventoryBridge.GetPage(player, "producers")
assert(#items == 1 and total == 1, "New items appear when added")

local first = items[1]
assert(InventoryBridge.Equip(player, first.uid) == true, "Equip existing item")
assert(InventoryBridge.Equip(player, "nope") == false, "Equip returns false for missing")

print("inventory spec passed")
