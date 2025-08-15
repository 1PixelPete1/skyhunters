package.path = "src/server/?.luau;src/server/?/init.luau;src/shared/?.luau;src/shared/?/init.luau;" .. package.path

if not time then
    function time()
        return os.clock()
    end
end

if not Color3 then
    Color3 = { fromRGB = function() return {} end }
end

if not CFrame then
    CFrame = {}
    function CFrame.new(x, y, z)
        return {
            Position = { X = x, Y = y, Z = z },
            ToOrientation = function()
                return 0, 0, 0
            end,
        }
    end
end

game = {
    GetService = function(self, name)
        if name == "Players" then
            return { PlayerRemoving = { Connect = function() end } }
        else
            error("service not available")
        end
    end
}

script = {
    Parent = {
        WaitForChild = function(_, name)
            return name
        end,
    },
}

local PlayerManager = require("PlayerManager")
local InventoryService = require("InventoryService")
local PlacementService = require("PlacementService")

local player = { UserId = 1, Name = "Tester" }
local data = PlayerManager.GetPlayerData(player)
InventoryService.Add(player, "prod_cube_basic", 1)

local result = PlacementService.Place(player, "prod_cube_basic", nil, CFrame.new(0,0,0))
assert(result.ok, "placement should succeed")
assert(data.aether.totalRate > 0, "producer increases totalRate")

print("aether integration spec passed")
