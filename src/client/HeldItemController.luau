local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local StartHolding = ReplicatedStorage:WaitForChild("StartHoldingItem")
local RequestPlace = ReplicatedStorage:WaitForChild("RequestPlaceItem")
local ConfirmPlacement = ReplicatedStorage:WaitForChild("ConfirmPlacement")
local PlacementRejected = ReplicatedStorage:WaitForChild("PlacementRejected")

local ModelUtils = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ModelUtils"))
local EquippedUI = require(script.Parent:WaitForChild("EquippedUI"))
local ItemsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemsConfig"))
local InventoryState = require(script.Parent:WaitForChild("InventoryState"))

local player = Players.LocalPlayer

type ItemDef = {
    id: string,
    model: string,
    type: "Build" | "Equip",
    weldTo: "Head" | "HumanoidRootPart" | "RightHand",
    carryOffset: CFrame?,
    count: number?,
    icon: string?,
    name: string?,
    cameraBehavior: string?,
}

local HeldItemController = {}

local placingItemId: string? = nil
local heldModel: Instance? = nil
local ghostModel: Instance? = nil
local currentTemplate: Instance? = nil
local currentItemDef: ItemDef? = nil
local currentMode: ("build" | "equip")? = nil

local savedCameraMode: Enum.CameraMode? = nil
local savedMinZoom: number? = nil
local savedMaxZoom: number? = nil
local updateConn: RBXScriptConnection? = nil
local countConn: RBXScriptConnection? = nil
local canPlace = false

local GRID = 1
local snapEnabled = false
local currentYaw = 0
local exitButton
local hintLabel
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

    hintLabel = Instance.new("TextLabel")
    hintLabel.Size = UDim2.new(1, 0, 0, 24)
    hintLabel.Position = UDim2.new(0, 0, 1, -28)
    hintLabel.BackgroundTransparency = 1
    hintLabel.TextColor3 = Color3.new(1, 1, 1)
    hintLabel.Text = ""
    hintLabel.Parent = gui
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

local plotCenterX = 0
local plotCenterZ = 0
local halfSizeX = 50
local halfSizeZ = 50

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
        plotCenterX = (plotBounds.min.X + plotBounds.max.X) / 2
        plotCenterZ = (plotBounds.min.Z + plotBounds.max.Z) / 2
        halfSizeX = (plotBounds.max.X - plotBounds.min.X) / 2
        halfSizeZ = (plotBounds.max.Z - plotBounds.min.Z) / 2
        return
    end
    if platform and platform:IsA("BasePart") then
        local cf = platform.CFrame
        local size = platform.Size
        plotBounds.min = cf.Position - size / 2
        plotBounds.max = cf.Position + size / 2
        plotCenterX = (plotBounds.min.X + plotBounds.max.X) / 2
        plotCenterZ = (plotBounds.min.Z + plotBounds.max.Z) / 2
        halfSizeX = (plotBounds.max.X - plotBounds.min.X) / 2
        halfSizeZ = (plotBounds.max.Z - plotBounds.min.Z) / 2
        return
    end
    -- Fallback if platform is missing
    plotBounds.min = Vector3.new(-50, 0, -50)
    plotBounds.max = Vector3.new(50, 0, 50)
    plotCenterX = 0
    plotCenterZ = 0
    halfSizeX = 50
    halfSizeZ = 50
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
            i.Anchored = true
            i.CanCollide = false
            i.Transparency = 0.5
            i.Massless = true
        end
    end
    ghostify(g)
    for _, d in ipairs(g:GetDescendants()) do
        ghostify(d)
    end
    if g:IsA("Model") then
        g:ScaleTo(1)
    end
    ghostModel = g
    return g
end

local function showToast(msg: string)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", { Title = "Skyhunters", Text = msg, Duration = 2 })
    end)
end

local function isPlayerInPlotXZ(): boolean
    local character = player.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return false
    end
    local p = hrp.Position
    local dx = math.abs(p.X - plotCenterX)
    local dz = math.abs(p.Z - plotCenterZ)
    return dx <= halfSizeX and dz <= halfSizeZ
end

local function snap(v: number, step: number): number
    return math.floor((v + step / 2) / step) * step
end


local function attachCarry(character: Model, asset: Instance, socketName: string, offset: CFrame?)
    if heldModel then heldModel:Destroy() end

    local carry = asset:Clone()
    ModelUtils.ensurePrimaryPart(carry)

    carry.Name = ("Carry_%s"):format(asset.Name)

    local function prep(part: Instance)
        if part:IsA("BasePart") then
            part.Anchored = false
            part.CanCollide = false
            part.Massless = true
        end
    end
    prep(carry)
    for _, d in ipairs(carry:GetDescendants()) do
        prep(d)
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
    currentTemplate = nil
    currentItemDef = nil
    currentMode = nil
    if updateConn then
        updateConn:Disconnect()
        updateConn = nil
    end
    if countConn then
        countConn:Disconnect()
        countConn = nil
    end
    if heldModel then
        heldModel:Destroy()
        heldModel = nil
    end
    if ghostModel then
        ghostModel:Destroy()
        ghostModel = nil
    end
    hintLabel.Text = ""
    exitButton.Visible = false
    if savedCameraMode then
        player.CameraMode = savedCameraMode
        if savedMinZoom then
            player.CameraMinZoomDistance = savedMinZoom
        end
        if savedMaxZoom then
            player.CameraMaxZoomDistance = savedMaxZoom
        end
    end
    savedCameraMode = nil
    savedMinZoom = nil
    savedMaxZoom = nil
    EquippedUI.Hide()
end

exitButton.Activated:Connect(function()
    HeldItemController.Stop()
end)


function HeldItemController.Start(itemDef: ItemDef, mode: "build" | "equip")
    if currentItemDef then
        return
    end
    InventoryState.InitOnce()
    if InventoryState.GetCount(itemDef.id) <= 0 then
        showToast("Out of items")
        return
    end
    currentItemDef = itemDef
    currentMode = mode
    savedCameraMode = player.CameraMode
    savedMinZoom = player.CameraMinZoomDistance
    savedMaxZoom = player.CameraMaxZoomDistance
    local character = player.Character or player.CharacterAdded:Wait()
    if mode == "build" then
        placingItemId = itemDef.id
        StartHolding:FireServer(itemDef.id)
        currentTemplate = getModel(itemDef.model)
        attachCarry(character, currentTemplate, itemDef.weldTo or "Head", itemDef.carryOffset)
        spawnGhost(currentTemplate)
        exitButton.Visible = true
    elseif mode == "equip" then
        local asset = getModel(itemDef.model)
        attachCarry(character, asset, itemDef.weldTo or "RightHand", itemDef.carryOffset)
        exitButton.Visible = true
    end
    local behavior = itemDef.cameraBehavior or "free"
    if behavior == "firstPerson" then
        player.CameraMode = Enum.CameraMode.LockFirstPerson
        player.CameraMinZoomDistance = 0.5
        player.CameraMaxZoomDistance = 0.5
    elseif behavior == "restricted" then
        player.CameraMode = Enum.CameraMode.Classic
        player.CameraMinZoomDistance = 6
        player.CameraMaxZoomDistance = 12
    else
        player.CameraMode = Enum.CameraMode.Classic
    end
    local count = InventoryState.GetCount(itemDef.id)
    EquippedUI.Show(itemDef.icon or "", itemDef.name or "", count)
    countConn = InventoryState.OnItemCountChanged:Connect(function(id, newCount)
        if currentItemDef and id == currentItemDef.id then
            EquippedUI.Update(newCount)
            if newCount <= 0 then
                HeldItemController.Stop()
            end
        end
    end)
    updateConn = RunService:BindToRenderStep("Placement_Update", Enum.RenderPriority.First.Value + 1, function()
        if currentMode ~= "build" or not currentTemplate or not ghostModel then
            return
        end
        local camera = workspace.CurrentCamera
        local mousePos = UserInputService:GetMouseLocation()
        local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Blacklist
        params.FilterDescendantsInstances = { character }
        local result = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
        local hitPos
        if result then
            hitPos = result.Position
        else
            local planeY = plotBounds.max.Y
            local t = (planeY - ray.Origin.Y) / ray.Direction.Y
            hitPos = ray.Origin + ray.Direction * t
        end
        local basePos = Vector3.new(hitPos.X, plotBounds.max.Y, hitPos.Z)
        if snapEnabled and GRID > 0 and not (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)) then
            basePos = Vector3.new(snap(basePos.X, GRID), plotBounds.max.Y, snap(basePos.Z, GRID))
        end
        local cf = CFrame.new(basePos) * CFrame.Angles(0, currentYaw, 0)
        pivotTo(cf, ghostModel)
        canPlace = isPlayerInPlotXZ()
        hintLabel.Text = canPlace and "" or "Step onto your plot to place"
    end)
end

HeldItemController.Stop = cancelPlacement

local function buildItemDef(itemId: string, mode: "build" | "equip"): ItemDef?
    local cfg = ItemsConfig.Types[itemId]
    if not cfg then
        return nil
    end
    -- TODO: fetch actual inventory count
    local def: ItemDef = {
        id = itemId,
        model = cfg.model,
        weldTo = mode == "build" and "Head" or "RightHand",
        carryOffset = nil,
        count = 1,
        icon = cfg.icon,
        name = cfg.displayName,
        cameraBehavior = cfg.cameraBehavior,
    }
    return def
end

function HeldItemController.Switch(itemId: string, mode: "build" | "equip")
    local current, currentMode = HeldItemController.GetCurrent()
    if current and current.id == itemId and currentMode == mode then
        return
    end
    local itemDef = buildItemDef(itemId, mode)
    if not itemDef then
        return
    end
    HeldItemController.Stop()
    HeldItemController.Start(itemDef, mode)
end

function HeldItemController.GetCurrent()
    return currentItemDef, currentMode
end

local function tryPlace()
    if not placingItemId or not ghostModel or InventoryState.GetCount(placingItemId) <= 0 then
        return
    end
    if not canPlace then
        return
    end
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
    if currentTemplate then
        spawnGhost(currentTemplate)
    end
end)

PlacementRejected.OnClientEvent:Connect(function()
    -- keep ghost so player can adjust
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
    elseif currentMode == "build" and input.KeyCode == Enum.KeyCode.G then
        snapEnabled = not snapEnabled
    elseif input.KeyCode == Enum.KeyCode.X then

        HeldItemController.Stop()
    end
end)

function HeldItemController.isHolding(): boolean
    return currentItemDef ~= nil
end

return HeldItemController

