--!strict
-- LanternBackAttachment.luau
-- Builds a simple backpack lantern with a glowing box and light on the local character.
-- Now includes flashlight cone effect for better visibility

local RunService = game:GetService("RunService")

local clientRoot = script.Parent.Parent
local stormRoot = script.Parent
local LanternFlashlight = require(stormRoot:WaitForChild("LanternFlashlight"))

local LanternBackAttachment = {}
LanternBackAttachment.__index = LanternBackAttachment

export type LanternBackAttachment = {
    Attach: (self: LanternBackAttachment, character: Model) -> (),
    Cleanup: (self: LanternBackAttachment) -> (),
    GetForwardVector: (self: LanternBackAttachment) -> Vector3?,
    SetFlashlightIntensity: (self: LanternBackAttachment, intensity: number) -> (),
}

local function getTorso(character: Model): BasePart?
    local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    if torso and torso:IsA("BasePart") then
        return torso
    end

    local ok, result = pcall(function()
        return character:WaitForChild("UpperTorso", 2)
    end)
    if ok and result and result:IsA("BasePart") then
        return result
    end

    torso = character:FindFirstChild("Torso")
    if torso and torso:IsA("BasePart") then
        return torso
    end

    return nil
end

local function buildLanternParts(character: Model, torso: BasePart)
    local right = torso.CFrame.RightVector
    local up = torso.CFrame.UpVector
    local forward = torso.CFrame.LookVector

    local anchorPosition = torso.Position - forward * 0.6 - right * 0.35 + up * 0.8
    local anchor = Instance.new("Part")
    anchor.Name = "LanternAnchor"
    anchor.Anchored = false
    anchor.CanCollide = false
    anchor.CanTouch = false
    anchor.CanQuery = false
    anchor.Massless = true
    anchor.Transparency = 1
    anchor.Size = Vector3.new(0.2, 0.2, 0.2)
    anchor.CFrame = CFrame.lookAt(anchorPosition, anchorPosition + forward)

    local post = Instance.new("Part")
    post.Name = "LanternPost"
    post.Anchored = false
    post.CanCollide = false
    post.CanTouch = false
    post.CanQuery = false
    post.Material = Enum.Material.Wood
    post.Color = Color3.fromRGB(120, 88, 65)
    post.Massless = true
    post.Size = Vector3.new(0.18, 2.6, 0.18)
    post.CFrame = anchor.CFrame * CFrame.new(0, 1.3, -0.05)

    local lantern = Instance.new("Part")
    lantern.Name = "LanternBox"
    lantern.Anchored = false
    lantern.CanCollide = false
    lantern.CanTouch = false
    lantern.CanQuery = false
    lantern.Massless = true
    lantern.Material = Enum.Material.Neon
    lantern.Color = Color3.fromRGB(255, 226, 163)
    lantern.Size = Vector3.new(0.7, 0.9, 0.7)
    lantern.CFrame = anchor.CFrame * CFrame.new(0, 2.05, -0.35)

    local housing = Instance.new("Part")
    housing.Name = "LanternFrame"
    housing.Anchored = false
    housing.CanCollide = false
    housing.CanTouch = false
    housing.CanQuery = false
    housing.Massless = true
    housing.Material = Enum.Material.Metal
    housing.Color = Color3.fromRGB(58, 52, 43)
    housing.Size = Vector3.new(0.85, 1.05, 0.85)
    housing.CFrame = lantern.CFrame
    housing.Transparency = 0.5

    local pointLight = Instance.new("PointLight")
    pointLight.Name = "LanternGlow"
    pointLight.Color = lantern.Color
    pointLight.Brightness = 3
    pointLight.Range = 26
    pointLight.Shadows = true
    pointLight.Parent = lantern

    local surfaceLight = Instance.new("SurfaceLight")
    surfaceLight.Name = "LanternBeam"
    surfaceLight.Color = lantern.Color
    surfaceLight.Angle = 110
    surfaceLight.Brightness = 1.1
    surfaceLight.Range = 32
    surfaceLight.Face = Enum.NormalId.Front
    surfaceLight.Parent = lantern

    local container = Instance.new("Folder")
    container.Name = "LanternBackpack"
    container.Parent = character

    anchor.Parent = container
    post.Parent = container
    lantern.Parent = container
    housing.Parent = container

    local anchorWeld = Instance.new("WeldConstraint")
    anchorWeld.Name = "LanternAnchorWeld"
    anchorWeld.Part0 = anchor
    anchorWeld.Part1 = torso
    anchorWeld.Parent = anchor

    local postWeld = Instance.new("WeldConstraint")
    postWeld.Name = "LanternPostWeld"
    postWeld.Part0 = post
    postWeld.Part1 = anchor
    postWeld.Parent = post

    local lanternWeld = Instance.new("WeldConstraint")
    lanternWeld.Name = "LanternBoxWeld"
    lanternWeld.Part0 = lantern
    lanternWeld.Part1 = post
    lanternWeld.Parent = lantern

    local frameWeld = Instance.new("WeldConstraint")
    frameWeld.Name = "LanternFrameWeld"
    frameWeld.Part0 = housing
    frameWeld.Part1 = lantern
    frameWeld.Parent = housing

    return container, lantern
end

function LanternBackAttachment.new(): LanternBackAttachment
    local self = setmetatable({}, LanternBackAttachment)
    self._container = nil :: Folder?
    self._lanternPart = nil :: BasePart?
    self._flashlight = nil :: any?
    self._updateConnection = nil :: RBXScriptConnection?
    return self
end

function LanternBackAttachment:Cleanup()
    if self._updateConnection then
        self._updateConnection:Disconnect()
        self._updateConnection = nil
    end
    
    if self._flashlight then
        self._flashlight:Cleanup()
        self._flashlight = nil
    end
    
    if self._container then
        self._container:Destroy()
        self._container = nil
        self._lanternPart = nil
    end
end

function LanternBackAttachment:Attach(character: Model)
    self:Cleanup()

    local torso = getTorso(character)
    if not torso then
        return
    end

    local container, lantern = buildLanternParts(character, torso)
    self._container = container
    self._lanternPart = lantern
    
    -- Create and attach the flashlight effect
    self._flashlight = LanternFlashlight.new()
    self._flashlight:Attach(lantern)
    self._flashlight:SetIntensity(1) -- Start at full intensity
    
    -- Update the flashlight effect each frame for flickering
    self._updateConnection = RunService.Heartbeat:Connect(function(dt)
        if self._flashlight then
            self._flashlight:Update(dt)
        end
    end)
end

function LanternBackAttachment:GetForwardVector(): Vector3?
    if self._lanternPart then
        return self._lanternPart.CFrame.LookVector
    end
    return nil
end

function LanternBackAttachment:SetFlashlightIntensity(intensity: number)
    if self._flashlight then
        self._flashlight:SetIntensity(intensity)
    end
end

return LanternBackAttachment
