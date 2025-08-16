package.path = "src/shared/?.luau;src/shared/?/init.luau;" .. package.path

local ModelUtils = require("ModelUtils")

local bounds = {
    min = {X = 0, Y = 0, Z = 0},
    max = {X = 10, Y = 5, Z = 10},
}

assert(ModelUtils.insideHorizontalBounds({X = 5, Y = 100, Z = 5}, bounds), "jumping should still be inside")
assert(not ModelUtils.insideHorizontalBounds({X = -1, Y = 0, Z = 5}, bounds), "outside X should fail")

print("bounds_xy_spec passed!")
