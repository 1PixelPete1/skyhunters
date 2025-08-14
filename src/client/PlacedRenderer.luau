local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemsConfig"))

local PlacedRenderer = {}

local function getFolder()
    local folder = workspace:FindFirstChild("ClientObjects")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "ClientObjects"
        folder.Parent = workspace
    end
    local playerFolder = folder:FindFirstChild(tostring(Players.LocalPlayer.UserId))
    if not playerFolder then
        playerFolder = Instance.new("Folder")
        playerFolder.Name = tostring(Players.LocalPlayer.UserId)
        playerFolder.Parent = folder
    end
    return playerFolder
end

function PlacedRenderer.Render(params)
    local cfg = ItemsConfig.Types[params.typeId]
    if not cfg then
        return
    end
    local model = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Models"):WaitForChild(cfg.model):Clone()
    model.CFrame = params.worldCFrame
    model.Parent = getFolder()
end

function PlacedRenderer.Remove(uid)
    local folder = getFolder()
    local model = folder:FindFirstChild(uid)
    if model then
        model:Destroy()
    end
end

return PlacedRenderer

