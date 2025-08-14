package.path = "src/server/?.luau;src/server/?/init.luau;src/shared/?.luau;src/shared/?/init.luau;" .. package.path

if not Color3 then
    Color3 = { fromRGB = function() return {} end }
end

local InventoryBridge = require("InventoryBridge")

local items, cursor, total = InventoryBridge.GetPage({}, "producers")
assert(type(items) == "table" and #items > 0, "GetPage returns items")

local filtered = InventoryBridge.GetPage({}, "producers", "Item 1")
for _, item in ipairs(filtered) do
    assert(string.find(item.name, "Item 1"), "search filters names")
end

local first = items[1]
assert(InventoryBridge.Equip({}, first.uid) == true, "Equip existing item")
assert(InventoryBridge.Equip({}, "nope") == false, "Equip returns false for missing")

print("inventory spec passed")
