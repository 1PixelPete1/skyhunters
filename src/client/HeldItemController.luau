local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local StartHolding = ReplicatedStorage:WaitForChild("StartHoldingItem")
local RequestPlace = ReplicatedStorage:WaitForChild("RequestPlaceItem")
local ConfirmPlacement = ReplicatedStorage:WaitForChild("ConfirmPlacement")
local PlacementRejected = ReplicatedStorage:WaitForChild("PlacementRejected")

local ItemsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemsConfig"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local HeldItemController = {}

local currentHeld
local heldModel
local ghostModel
local handsUpAnim

local function getModel(modelName)
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    if not assets then
        warn("[HeldItemController] Assets folder missing")
        local p = Instance.new("Part")
        p.Name = modelName
        p.Size = Vector3.new(1, 1, 1)
        p.Anchored = true
        return p
    end
    local models = assets:FindFirstChild("Models")
    if not models then
        warn("[HeldItemController] Models folder missing in Assets")
        local p = Instance.new("Part")
        p.Name = modelName
        p.Size = Vector3.new(1, 1, 1)
        p.Anchored = true
        return p
    end
    local model = models:FindFirstChild(modelName)
    if not model then
        warn("[HeldItemController] Model " .. modelName .. " missing")
        local p = Instance.new("Part")
        p.Name = modelName
        p.Size = Vector3.new(1, 1, 1)
        p.Anchored = true
        return p
    end
    return model:Clone()
end

local plotBounds = {
    min = Vector3.new(-50, 0, -50),
    max = Vector3.new(50, 0, 50),
}

local function insideBounds(pos)
    return pos.X >= plotBounds.min.X and pos.X <= plotBounds.max.X and pos.Z >= plotBounds.min.Z and pos.Z <= plotBounds.max.Z
end

local function stopHolding()
    if heldModel then
        heldModel:Destroy()
        heldModel = nil
    end
    if handsUpAnim then
        handsUpAnim:Stop()
        handsUpAnim = nil
    end
    currentHeld = nil
end

function HeldItemController.startHold(item)
    if currentHeld then
        return
    end
    currentHeld = item
    StartHolding:FireServer(item.uid)

    local cfg = ItemsConfig.Types[item.typeId]
    if not cfg then
        return
    end

    local model = getModel(cfg.model)
    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart")
    local attach = hrp:FindFirstChild("HeldItemAttachment")
    if not attach then
        attach = Instance.new("Attachment")
        attach.Name = "HeldItemAttachment"
        attach.Position = Vector3.new(0, 5, 0)
        attach.Parent = hrp
    end
    model.Parent = attach
    heldModel = model

    local humanoid = character:WaitForChild("Humanoid")
    -- Reference the animation instance from ReplicatedStorage.Animations
    local animationsFolder = ReplicatedStorage:FindFirstChild("Animations")
    local handsUpAnimObj = animationsFolder and animationsFolder:FindFirstChild("HandsUp")
    if handsUpAnimObj and handsUpAnimObj:IsA("Animation") then
        handsUpAnim = humanoid:LoadAnimation(handsUpAnimObj)
        handsUpAnim:Play()
    else
        warn("[HeldItemController] HandsUp animation not found in ReplicatedStorage.Animations")
    end
end

local function spawnGhost(position, cfg)
    if ghostModel then
        ghostModel:Destroy()
    end
    ghostModel = getModel(cfg.model)
    if ghostModel:IsA("BasePart") then
        ghostModel.Transparency = 0.5
        ghostModel.CanCollide = false
        ghostModel.CFrame = CFrame.new(position)
    else
        for _, part in ipairs(ghostModel:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Transparency = 0.5
                part.CanCollide = false
            end
        end
        if ghostModel.PrimaryPart then
            ghostModel:SetPrimaryPartCFrame(CFrame.new(position))
        else
            ghostModel:PivotTo(CFrame.new(position))
        end
    end
    ghostModel.Parent = workspace
end

function HeldItemController.tryPlace(position)
    if not currentHeld then
        return
    end
    if not insideBounds(position) then
        return
    end
    local cfg = ItemsConfig.Types[currentHeld.typeId]
    if not cfg then
        return
    end
    spawnGhost(position, cfg)
    RequestPlace:FireServer(currentHeld.uid, position)
end

ConfirmPlacement.OnClientEvent:Connect(function()
    if ghostModel then
        ghostModel:Destroy()
        ghostModel = nil
    end
    stopHolding()
end)

PlacementRejected.OnClientEvent:Connect(function()
    if ghostModel then
        ghostModel:Destroy()
        ghostModel = nil
    end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then
        return
    end
    if input.UserInputType == Enum.UserInputType.MouseButton1 and currentHeld then
        HeldItemController.tryPlace(mouse.Hit.Position)
    end
end)

function HeldItemController.isHolding()
    return currentHeld ~= nil
end

return HeldItemController

