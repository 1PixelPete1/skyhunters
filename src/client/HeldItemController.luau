local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local StartHolding = ReplicatedStorage:WaitForChild("StartHoldingItem")
local RequestPlace = ReplicatedStorage:WaitForChild("RequestPlaceItem")
local ConfirmPlacement = ReplicatedStorage:WaitForChild("ConfirmPlacement")
local PlacementRejected = ReplicatedStorage:WaitForChild("PlacementRejected")

local ModelUtils = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ModelUtils"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()

type ItemDef = {
    id: string,
    model: string,
    type: "Build" | "Equip",
    weldTo: "Head" | "HumanoidRootPart" | "RightHand",
    carryOffset: CFrame?,
    count: number?,
}

local HeldItemController = {}

local placingItemId: string? = nil
local placingCount = 0
local heldModel: Instance? = nil
local ghostModel: Instance? = nil
local currentTemplate: Instance? = nil
local lastMouseHit: CFrame? = nil
local lastMouseOnPlatform = false
local currentItemDef: ItemDef? = nil
local currentMode: ("build" | "equip")? = nil

local GRID = 1
local snapEnabled = false
local currentYaw = 0
local lastPlace = 0

local exitButton
do
    local gui = Instance.new("ScreenGui")
    gui.Name = "PlacementGui"
    gui.ResetOnSpawn = false
    gui.Parent = player:WaitForChild("PlayerGui")

    exitButton = Instance.new("TextButton")
    exitButton.Text = "×"
    exitButton.Size = UDim2.new(0, 24, 0, 24)
    exitButton.Position = UDim2.new(1, -28, 0, 4)
    exitButton.AnchorPoint = Vector2.new(1, 0)
    exitButton.Visible = false
    exitButton.Parent = gui
end

local function getModel(modelName: string): Instance
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

local plotPlatform: Instance? = nil

-- Optional: rename to your real platform object (Part or Model)
local PLOT_PLATFORM_NAME = "Baseplate"

local function updatePlotBounds()
    local platform = workspace:FindFirstChild(PLOT_PLATFORM_NAME)
    plotPlatform = platform
    if platform and platform:IsA("Model") then
        local cf, size = platform:GetBoundingBox()
        plotBounds.min = cf.Position - size / 2
        plotBounds.max = cf.Position + size / 2
        return
    end
    if platform and platform:IsA("BasePart") then
        local cf = platform.CFrame
        local size = platform.Size
        plotBounds.min = cf.Position - size / 2
        plotBounds.max = cf.Position + size / 2
        return
    end
    -- Fallback if platform is missing
    plotBounds.min = Vector3.new(-50, 0, -50)
    plotBounds.max = Vector3.new(50, 0, 50)
    plotPlatform = nil
end

updatePlotBounds()

-- positioning helper
local function pivotTo(cf: CFrame, modelOrPart: Instance)
    if modelOrPart:IsA("BasePart") then
        (modelOrPart :: BasePart).CFrame = cf
        return
    end
    if modelOrPart:IsA("Model") then
        local m = modelOrPart :: Model
        if not m.PrimaryPart then
            local candidate = m:FindFirstChild("Primary") or m:FindFirstChild("Base") or m:FindFirstChildWhichIsA("BasePart")
            if candidate and candidate:IsA("BasePart") then
                m.PrimaryPart = candidate
            end
        end
        m:PivotTo(cf)
    end
end

local function spawnGhost(asset: Instance): Instance
    if ghostModel then
        ghostModel:Destroy()
    end
    local g = asset:Clone()
    g.Name = ("Ghost_%s"):format(asset.Name)
    g.Parent = workspace
    local function ghostify(i: Instance)
        if i:IsA("BasePart") then
            i.Transparency = 0.5
            i.CanCollide = false
            i.CanQuery = false
            i.CanTouch = false
            i.Anchored = true
        elseif i:IsA("Weld") or i:IsA("WeldConstraint") or i:IsA("Motor6D")
            or i:IsA("BallSocketConstraint") or i:IsA("HingeConstraint")
            or i:IsA("RodConstraint") then
            i:Destroy()
        end
    end
    ghostify(g)
    if g:IsA("Model") then
        g:ScaleTo(1)
        for _, d in ipairs(g:GetDescendants()) do
            ghostify(d)
        end
    end
    ghostModel = g
    return g
end

local function snap(v: number, step: number): number
    return math.floor((v + step / 2) / step) * step
end

local function updateGhostAt(mouseHit: CFrame)
    if not ghostModel then
        return
    end
    local pos = mouseHit.Position
    local yTop = plotBounds.max.Y
    local useSnap = snapEnabled and GRID > 0 and not (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift))
    local basePos
    if useSnap then
        basePos = Vector3.new(snap(pos.X, GRID), yTop, snap(pos.Z, GRID))
    else
        basePos = Vector3.new(pos.X, yTop, pos.Z)
    end
    local cf = CFrame.new(basePos) * CFrame.Angles(0, currentYaw, 0)
    pivotTo(cf, ghostModel)
end

local function attachCarry(character: Model, asset: Instance, socketName: string, offset: CFrame?)
    if heldModel then heldModel:Destroy() end

    local carry = asset:Clone()
    ModelUtils.ensurePrimaryPart(carry)
    carry.Name = ("Carry_%s"):format(asset.Name)

    for _, d in ipairs(carry:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored = false
            d.CanCollide = false
            d.Massless = true
        end
    end
    ModelUtils.stripExternalConstraints(carry)
    ModelUtils.weldModelRigid(carry)

    local socket = character:FindFirstChild(socketName) or character:FindFirstChild("HumanoidRootPart")
    if not socket or not carry.PrimaryPart then
        carry:Destroy()
        return
    end

    carry.Parent = character

    if not offset then
        local _, size = carry:GetBoundingBox()
        local up = math.max(1.0, 0.5 * size.Y + 0.5)
        local fwd = math.max(0.6, 0.25 * size.Z)
        offset = CFrame.new(0, up, -fwd)
    end

    carry:PivotTo((socket :: BasePart).CFrame * offset)

    local base = carry.PrimaryPart :: BasePart
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = base
    weld.Part1 = socket :: BasePart
    weld.Parent = base

    heldModel = carry
end

local function cancelPlacement()
    placingItemId = nil
    placingCount = 0
    currentTemplate = nil
    currentItemDef = nil
    currentMode = nil
    if heldModel then
        heldModel:Destroy()
        heldModel = nil
    end
    if ghostModel then
        ghostModel:Destroy()
        ghostModel = nil
    end
    lastMouseHit = nil
    lastMouseOnPlatform = false
    exitButton.Visible = false
end

exitButton.Activated:Connect(function()
    HeldItemController.Stop()
end)

RunService.Heartbeat:Connect(function()
    if currentMode ~= "build" then
        return
    end
    local character = player.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return
    end
    local pos = hrp.Position
    local within = ModelUtils.insideHorizontalBounds(pos, plotBounds)
    if not within then
        HeldItemController.Stop()
    end
end)

function HeldItemController.Start(itemDef: ItemDef, mode: "build" | "equip")
    if currentItemDef then
        return
    end
    currentItemDef = itemDef
    currentMode = mode
    if mode == "build" then
        placingItemId = itemDef.id
        placingCount = itemDef.count or 1
        StartHolding:FireServer(itemDef.id)
        currentTemplate = getModel(itemDef.model)
        local character = player.Character or player.CharacterAdded:Wait()
        attachCarry(character, currentTemplate, itemDef.weldTo or "Head", itemDef.carryOffset)
        lastMouseHit = nil
        lastMouseOnPlatform = false
        exitButton.Visible = true
    elseif mode == "equip" then
        local character = player.Character or player.CharacterAdded:Wait()
        local asset = getModel(itemDef.model)
        attachCarry(character, asset, itemDef.weldTo or "RightHand", itemDef.carryOffset)
        exitButton.Visible = true
    end
end

HeldItemController.Stop = cancelPlacement

function HeldItemController.Switch(itemDef: ItemDef, mode: "build" | "equip")
    HeldItemController.Stop()
    HeldItemController.Start(itemDef, mode)
end

function HeldItemController.GetCurrent()
    return currentItemDef, currentMode
end

local function tryPlace()
    if not placingItemId or not ghostModel then
        return
    end
    local now = tick()
    if now - lastPlace < 0.2 then
        return
    end
    lastPlace = now
    local cf
    if ghostModel:IsA("Model") then
        cf = ghostModel:GetPivot()
    else
        cf = (ghostModel :: BasePart).CFrame
    end
    RequestPlace:FireServer(placingItemId, cf)
end

ConfirmPlacement.OnClientEvent:Connect(function(ok, payload)
    if not ok then
        return
    end
    if ghostModel then
        ghostModel:Destroy()
        ghostModel = nil
    end
    placingCount = payload and payload.remaining or 0
    if placingCount > 0 then
        if lastMouseHit and lastMouseOnPlatform and currentTemplate then
            spawnGhost(currentTemplate)
            updateGhostAt(lastMouseHit)
        end
        -- else: wait for next mouse.Move to re-enter bounds before recreating the ghost
    else
        HeldItemController.Stop()
    end
end)

PlacementRejected.OnClientEvent:Connect(function()
    -- keep ghost so player can adjust
end)

mouse.Move:Connect(function()
    if currentMode ~= "build" or not currentTemplate then return end

    lastMouseHit = mouse.Hit
    local pos = lastMouseHit.Position
    local onPlot = ModelUtils.insideHorizontalBounds(pos, plotBounds)
    if onPlot then
        if not ghostModel then
            spawnGhost(currentTemplate)
        end
        updateGhostAt(lastMouseHit)
    else
        if ghostModel then
            ghostModel:Destroy()
            ghostModel = nil
        end
    end
    lastMouseOnPlatform = onPlot
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then
        return
    end
    if currentMode == "build" and input.UserInputType == Enum.UserInputType.MouseButton1 then
        tryPlace()
    elseif currentMode == "build" and input.KeyCode == Enum.KeyCode.R then
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
            currentYaw += math.rad(90)
        else
            currentYaw += math.rad(15)
        end
        if lastMouseHit then
            updateGhostAt(lastMouseHit)
        end
    elseif currentMode == "build" and input.KeyCode == Enum.KeyCode.G then
        snapEnabled = not snapEnabled
        if lastMouseHit then
            updateGhostAt(lastMouseHit)
        end
    elseif input.KeyCode == Enum.KeyCode.X then

        HeldItemController.Stop()
    end
end)

function HeldItemController.isHolding(): boolean
    return currentItemDef ~= nil
end

return HeldItemController

