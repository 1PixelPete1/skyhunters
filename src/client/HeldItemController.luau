local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local StartHolding = ReplicatedStorage:WaitForChild("StartHoldingItem")
local RequestPlace = ReplicatedStorage:WaitForChild("RequestPlaceItem")
local ConfirmPlacement = ReplicatedStorage:WaitForChild("ConfirmPlacement")
local PlacementRejected = ReplicatedStorage:WaitForChild("PlacementRejected")

local ItemsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemsConfig"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local HeldItemController = {}

local placingItemId: string? = nil
local placingCount = 0
local heldModel: Instance? = nil
local ghostModel: Instance? = nil
local currentTemplate: Instance? = nil
local lastMouseHit: CFrame? = nil
local lastMouseOnPlatform = false

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

local function insideBounds(pos: Vector3): boolean
    return pos.X >= plotBounds.min.X and pos.X <= plotBounds.max.X and pos.Z >= plotBounds.min.Z and pos.Z <= plotBounds.max.Z
end

-- positioning helper
local function pivotTo(cf: CFrame, modelOrPart: Instance)
    if modelOrPart:IsA("BasePart") then
        (modelOrPart :: BasePart).CFrame = cf
        return
    end
    if modelOrPart:IsA("Model") then
        local m = modelOrPart :: Model
        if m.PrimaryPart then
            m:SetPrimaryPartCFrame(cf)
        else
            local candidate = m:FindFirstChild("Primary") or m:FindFirstChild("Base") or m:FindFirstChildWhichIsA("BasePart")
            if candidate and candidate:IsA("BasePart") then
                m.PrimaryPart = candidate
                m:SetPrimaryPartCFrame(cf)
            else
                m:PivotTo(cf)
            end
        end
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
    local useSnap = snapEnabled and GRID > 0 and not (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift))
    local basePos
    if useSnap then
        basePos = Vector3.new(snap(pos.X, GRID), snap(pos.Y, GRID), snap(pos.Z, GRID))
    else
        basePos = pos
    end
    local cf = CFrame.new(basePos) * CFrame.Angles(0, currentYaw, 0)
    pivotTo(cf, ghostModel)
end

local function attachOverHead(character: Model, asset: Instance)
    if heldModel then heldModel:Destroy() end

    local carry = asset:Clone()
    carry.Name = ("Carry_%s"):format(asset.Name)
    carry.Parent = character

    for _, d in ipairs(carry:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Massless = true
            d.CanCollide = false
            d.Anchored = false
        elseif d:IsA("Weld") or d:IsA("WeldConstraint")
            or d:IsA("Motor6D") or d:IsA("BallSocketConstraint")
            or d:IsA("HingeConstraint") or d:IsA("RodConstraint") then
            d:Destroy()
        end
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    local base = (carry:IsA("Model") and (carry.PrimaryPart or carry:FindFirstChildWhichIsA("BasePart"))) or carry
    if hrp and base and base:IsA("BasePart") then
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = base
        weld.Part1 = hrp :: BasePart
        weld.Parent = base
        carry:PivotTo((hrp :: BasePart).CFrame * CFrame.new(0, 0, -2))
    end
    heldModel = carry
end

local function cancelPlacement()
    placingItemId = nil
    placingCount = 0
    currentTemplate = nil
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
    cancelPlacement()
end)

RunService.Heartbeat:Connect(function()
    if not placingItemId then
        return
    end
    local character = player.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return
    end
    local pos = hrp.Position
    local within = pos.X >= plotBounds.min.X and pos.X <= plotBounds.max.X
        and pos.Z >= plotBounds.min.Z and pos.Z <= plotBounds.max.Z
        and pos.Y >= plotBounds.min.Y - 5 and pos.Y <= plotBounds.max.Y + 5
    if not within then
        cancelPlacement()
    end
end)

function HeldItemController.startHold(item)
    if placingItemId then
        return
    end
    placingItemId = item.uid
    placingCount = item.count or 1
    StartHolding:FireServer(item.uid)
    local cfg = ItemsConfig.Types[item.typeId]
    if not cfg then
        cancelPlacement()
        return
    end
    currentTemplate = getModel(cfg.model)
    local character = player.Character or player.CharacterAdded:Wait()
    attachOverHead(character, currentTemplate)
    lastMouseHit = nil
    lastMouseOnPlatform = false
    exitButton.Visible = true
    -- Do not spawn the ghost yet; wait for mouse.Move + insideBounds
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
        cancelPlacement()
    end
end)

PlacementRejected.OnClientEvent:Connect(function()
    -- keep ghost so player can adjust
end)

mouse.Move:Connect(function()
    if not placingItemId or not currentTemplate then return end

    lastMouseHit = mouse.Hit
    local pos = lastMouseHit.Position
    local target = mouse.Target
    local targetIsPlot = false
    if plotPlatform then
        if plotPlatform:IsA("Model") then
            targetIsPlot = target ~= nil and target:IsDescendantOf(plotPlatform)
        else
            targetIsPlot = target == plotPlatform
        end
    end
    local onTopSurface = mouse.TargetSurface == Enum.NormalId.Top
    local onPlot = targetIsPlot and onTopSurface and insideBounds(pos)
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
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        tryPlace()
    elseif input.KeyCode == Enum.KeyCode.R then
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
            currentYaw += math.rad(90)
        else
            currentYaw += math.rad(15)
        end
        if lastMouseHit then
            updateGhostAt(lastMouseHit)
        end
    elseif input.KeyCode == Enum.KeyCode.G then
        snapEnabled = not snapEnabled
        if lastMouseHit then
            updateGhostAt(lastMouseHit)
        end
    elseif input.KeyCode == Enum.KeyCode.X then

        cancelPlacement()
    end
end)

function HeldItemController.isHolding(): boolean
    return placingItemId ~= nil
end

return HeldItemController

