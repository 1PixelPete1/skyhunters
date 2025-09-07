local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)

local UIRouter = {}

local player = Players.LocalPlayer

Net:GetEvent("RE_BaseAssigned").OnClientEvent:Connect(function(assignment)
    print("Plot assigned:", assignment.plotId)
end)

Net:GetEvent("RE_Balances").OnClientEvent:Connect(function(bal)
    print("Balances:", bal.aether, bal.crumbs)
end)

return UIRouter
