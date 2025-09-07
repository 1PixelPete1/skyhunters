local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ContentService = {}

local registry = {}

function ContentService.Init(services)
    ContentService._services = services
    local folder = ReplicatedStorage:WaitForChild("ContentRegistry")
    registry.parts = require(folder:WaitForChild("Parts"))
    registry.upgrades = require(folder:WaitForChild("Upgrades"))
end

function ContentService.GetPartConfig(partId: string)
    return registry.parts[partId]
end

function ContentService.GetUpgradeConfig(upgradeId: string)
    return registry.upgrades[upgradeId]
end

return ContentService

