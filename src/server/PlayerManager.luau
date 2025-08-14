local Players = game:GetService("Players")

local PlayerManager = {}
local playerData = {}

local function createNewPlayerData(player)
    return {
        v = 1,
        id = player.UserId,
        crumbs = 0,
        inventory = {},
        upgrades = {},
        aether = {
            current = 0,
            target = 20,
            decayRate = 0.08,
            purityBase = 0.55,
            totalRate = 0,
            lastSettleTs = time(),
        },
        producers = {},
        timestamps = {},
    }
end

function PlayerManager.GetPlayerData(player)
    if not playerData[player] then
        playerData[player] = createNewPlayerData(player)
        local Aether = require(script.Parent:WaitForChild("Aether"))
        Aether.Init(playerData[player])
    end
    return playerData[player]
end

function PlayerManager.SavePlayerData(player, data)
    playerData[player] = data
    print("Saved data for player", player.Name, "- Crumbs:", data.crumbs)
end

Players.PlayerRemoving:Connect(function(player)
    playerData[player] = nil
end)

return PlayerManager
