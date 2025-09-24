--!strict
-- LanternFlashlight.luau
-- Simple SpotLight attachment for lantern flashlight effect

local RunService = game:GetService("RunService")

local LanternFlashlight = {}
LanternFlashlight.__index = LanternFlashlight

export type LanternFlashlight = {
    Attach: (self: LanternFlashlight, lanternPart: BasePart) -> (),
    Update: (self: LanternFlashlight, dt: number) -> (),
    SetIntensity: (self: LanternFlashlight, intensity: number) -> (),
    Cleanup: (self: LanternFlashlight) -> (),
}

function LanternFlashlight.new(): LanternFlashlight
    local self = setmetatable({}, LanternFlashlight)
    
    self._spotLight = nil :: SpotLight?
    self._attachment = nil :: Attachment?
    self._lanternPart = nil :: BasePart?
    self._baseIntensity = 1
    self._flickerTime = 0
    
    return self
end

function LanternFlashlight:Attach(lanternPart: BasePart)
    self:Cleanup()
    
    if not lanternPart then
        warn("[LanternFlashlight] No lantern part provided")
        return
    end
    
    self._lanternPart = lanternPart
    
    -- Create attachment for the spotlight
    local attachment = Instance.new("Attachment")
    attachment.Name = "FlashlightAttachment"
    -- Position the attachment to point forward from the lantern
    attachment.CFrame = CFrame.new(0, 0, -0.5) * CFrame.Angles(0, 0, 0)
    attachment.Parent = lanternPart
    self._attachment = attachment
    
    -- Create SpotLight for the flashlight effect
    local spotLight = Instance.new("SpotLight")
    spotLight.Name = "LanternFlashlight"
    spotLight.Brightness = 3.5
    spotLight.Range = 90 -- Extended range for better visibility
    spotLight.Angle = 65 -- Wide cone for better visibility
    spotLight.Color = Color3.fromRGB(255, 226, 163) -- Match lantern glow color exactly
    spotLight.Shadows = true
    spotLight.Face = Enum.NormalId.Front
    spotLight.Parent = attachment
    self._spotLight = spotLight
end

function LanternFlashlight:Update(dt: number)
    if not self._spotLight then
        return
    end
    
    -- Add subtle flickering effect
    self._flickerTime = self._flickerTime + dt
    local flicker = 1 + math.sin(self._flickerTime * 12) * 0.02 + math.sin(self._flickerTime * 23) * 0.015
    
    -- Update brightness with flicker
    self._spotLight.Brightness = 3.5 * self._baseIntensity * flicker
end

function LanternFlashlight:SetIntensity(intensity: number)
    self._baseIntensity = math.clamp(intensity, 0, 1)
    
    if self._spotLight then
        self._spotLight.Enabled = intensity > 0.1
        self._spotLight.Brightness = 3.5 * intensity
    end
end

function LanternFlashlight:Cleanup()
    if self._spotLight then
        self._spotLight:Destroy()
        self._spotLight = nil
    end
    
    if self._attachment then
        self._attachment:Destroy()
        self._attachment = nil
    end
    
    self._lanternPart = nil
end

return LanternFlashlight
