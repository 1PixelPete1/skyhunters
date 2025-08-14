local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemsConfig"))

local PlacedRenderer = {}

local function getModel(modelName)
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    if not assets then
        warn("[PlacedRenderer] Assets folder missing")
        local p = Instance.new("Part")
        p.Name = modelName
        p.Size = Vector3.new(1, 1, 1)
        p.Anchored = true
        return p
    end
    local models = assets:FindFirstChild("Models")
    if not models then
        warn("[PlacedRenderer] Models folder missing in Assets")
        local p = Instance.new("Part")
        p.Name = modelName
        p.Size = Vector3.new(1, 1, 1)
        p.Anchored = true
        return p
    end
    local model = models:FindFirstChild(modelName)
    if not model then
        warn("[PlacedRenderer] Model " .. modelName .. " missing")
        local p = Instance.new("Part")
        p.Name = modelName
        p.Size = Vector3.new(1, 1, 1)
        p.Anchored = true
        return p
    end
    return model:Clone()
end

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
    local model = getModel(cfg.model)
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

