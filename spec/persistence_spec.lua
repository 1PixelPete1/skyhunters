package.path = "src/server/?.luau;src/server/?/init.luau;src/shared/?.luau;src/shared/?/init.luau;" .. package.path

if not time then
    function time()
        return os.clock()
    end
end

if not Color3 then
    Color3 = { fromRGB = function() return {} end }
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

local PlayerManager = require("PlayerManager")

local p1 = {UserId = 101, Name = "Tester"}
local data = PlayerManager.GetPlayerData(p1)
data.crumbs = 12
PlayerManager.SavePlayerData(p1, data)

local p2 = {UserId = 101, Name = "Rejoin"}
local loaded = PlayerManager.GetPlayerData(p2)
assert(loaded.crumbs == 12, "crumbs should persist across sessions")

print("Persistence tests passed!")

