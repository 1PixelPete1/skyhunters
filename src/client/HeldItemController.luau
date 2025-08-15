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

local placingItemId: string? = nil
local placingCount = 0
local heldModel: Instance? = nil
local ghostModel: Instance? = nil
local currentTemplate: Instance? = nil
local lastMouseHit: CFrame? = nil

local GRID = 1
local currentYaw = 0

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
        end
    end
    if g:IsA("Model") then
        g:ScaleTo(1)
        for _, d in ipairs(g:GetDescendants()) do
            ghostify(d)
        end
    elseif g:IsA("BasePart") then
        ghostify(g)
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
    local snapped = Vector3.new(snap(pos.X, GRID), snap(pos.Y, GRID), snap(pos.Z, GRID))
    local cf = CFrame.new(snapped) * CFrame.Angles(0, currentYaw, 0)
    pivotTo(cf, ghostModel)
end

local equipAttachmentOffset = CFrame.new(0, 3.5, 0)

local function attachOverHead(character: Model, asset: Instance)
    if heldModel then
        heldModel:Destroy()
    end
    local carry = asset:Clone()
    carry.Name = ("Carry_%s"):format(asset.Name)
    carry.Parent = character
    for _, d in ipairs(carry:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Massless = true
            d.CanCollide = false
            d.Anchored = false
        end
    end
    local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    local base = (carry:IsA("Model") and ((carry :: Model).PrimaryPart or (carry :: Model):FindFirstChildWhichIsA("BasePart"))) or carry
    if head and base and base:IsA("BasePart") then
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = base
        weld.Part1 = head :: BasePart
        weld.Parent = base
        carry:PivotTo((head :: BasePart).CFrame * equipAttachmentOffset)
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
end

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
    spawnGhost(currentTemplate)
    updateGhostAt(mouse.Hit)
end

local function tryPlace()
    if not placingItemId or not ghostModel then
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

ConfirmPlacement.OnClientEvent:Connect(function(ok)
    if ok then
        placingCount -= 1
        if placingCount <= 0 then
            cancelPlacement()
        end
    end
    if ghostModel then
        ghostModel:Destroy()
        ghostModel = nil
    end
end)

PlacementRejected.OnClientEvent:Connect(function()
    -- keep ghost so player can adjust
end)

mouse.Move:Connect(function()
    if not placingItemId or not currentTemplate then
        return
    end
    lastMouseHit = mouse.Hit
    if insideBounds(lastMouseHit.Position) then
        if not ghostModel and currentTemplate then
            spawnGhost(currentTemplate)
        end
        updateGhostAt(lastMouseHit)
    else
        if ghostModel then
            ghostModel:Destroy()
            ghostModel = nil
        end
    end
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
    elseif input.KeyCode == Enum.KeyCode.Escape then
        cancelPlacement()
    end
end)

function HeldItemController.isHolding(): boolean
    return placingItemId ~= nil
end

return HeldItemController

