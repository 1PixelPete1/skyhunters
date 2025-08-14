local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RF_Place = ReplicatedStorage:WaitForChild("RF_PlaceItem")

local PlacementClient = {}

function PlacementClient.Place(typeId, plotId, worldCFrame)
    return RF_Place:InvokeServer(typeId, plotId, worldCFrame)
end

return PlacementClient

