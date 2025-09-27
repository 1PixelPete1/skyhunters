--!strict
-- RotatingWindSprites.luau (FIXED - simple camera following, no complex adjustments)
-- Proper rotating wind sprite system with wind-aligned semicircles

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local sharedRoot = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local StormTypes = require(sharedRoot:WaitForChild("StormTypes"))

type StormState = StormTypes.StormState
export type PerfConfig = StormTypes.PerfConfig

type WindSprite = {
    part: BasePart,
    billboard: BillboardGui,
    image: ImageLabel,
    angle: number,
    radius: number,
    heightOffset: number,  -- Fixed offset from camera
    speed: number,
    opacity: number,
    semicircle: number,
}

local RotatingWindSprites = {}
RotatingWindSprites.__index = RotatingWindSprites

function RotatingWindSprites.new(_perfConfig: PerfConfig?, _perfTier: StormTypes.PerfTier?)
    local self = setmetatable({}, RotatingWindSprites)
    
    self.Container = Instance.new("Folder")
    self.Container.Name = "RotatingWindSprites"
    self.Container.Parent = Workspace
    
    self.Sprites = {} :: {WindSprite}
    self.Enabled = true
    self.WindAngle = 0
    
    -- Configuration
    self.Config = {
        spritesPerSemicircle = 8,
        radius = 15,
        minHeightOffset = -3,  -- Offset from camera, not absolute height
        maxHeightOffset = 8,
        spriteSize = 80,
        baseSpeed = 0.5,
        baseAlpha = 0.4,
        fadeZoneAngle = 30,
    }
    
    self:CreateSprites()
    
    print("[RotatingWindSprites] Simplified camera-following wind system initialized")
    
    return self
end

function RotatingWindSprites:CreateSprites()
    -- Create two semicircles of sprites
    for semicircle = 1, 2 do
        for i = 1, self.Config.spritesPerSemicircle do
            -- Calculate base angle
            local angleInSemicircle = (i - 1) / self.Config.spritesPerSemicircle * math.pi
            local baseAngle = angleInSemicircle + (semicircle - 1) * math.pi
            
            -- Create sprite part
            local part = Instance.new("Part")
            part.Name = string.format("WindSprite_S%d_%d", semicircle, i)
            part.Anchored = true
            part.CanCollide = false
            part.CanQuery = false
            part.CanTouch = false
            part.Transparency = 1
            part.Size = Vector3.new(0.1, 0.1, 0.1)
            part.CastShadow = false
            part.Parent = self.Container
            
            -- Create billboard
            local billboard = Instance.new("BillboardGui")
            billboard.Name = "WindSpriteBillboard"
            billboard.Adornee = part
            billboard.Size = UDim2.fromOffset(self.Config.spriteSize * 10, self.Config.spriteSize * 10)
            billboard.LightInfluence = 0
            billboard.AlwaysOnTop = false
            billboard.Parent = part
            
            local imageLabel = Instance.new("ImageLabel")
            imageLabel.Name = "WindGust"
            imageLabel.BackgroundTransparency = 1
            imageLabel.Size = UDim2.fromScale(1, 1)
            imageLabel.Image = "rbxasset://textures/particles/smoke_main.dds"
            imageLabel.ImageColor3 = Color3.fromRGB(200, 210, 225)
            imageLabel.ImageTransparency = 1 - self.Config.baseAlpha
            imageLabel.ScaleType = Enum.ScaleType.Stretch
            imageLabel.Parent = billboard
            
            -- SIMPLE: Just a fixed offset from camera for each sprite
            local heightOffset = self.Config.minHeightOffset + 
                               (self.Config.maxHeightOffset - self.Config.minHeightOffset) * ((i - 1) / self.Config.spritesPerSemicircle)
            
            -- Add some variation
            heightOffset = heightOffset + math.sin(i * 1.7) * 1.5
            
            local sprite: WindSprite = {
                part = part,
                billboard = billboard,
                image = imageLabel,
                angle = baseAngle,
                radius = self.Config.radius + (i % 2) * 3 + math.sin(i * 2.3) * 2,
                heightOffset = heightOffset,  -- FIXED offset from camera
                speed = self.Config.baseSpeed * (0.9 + math.random() * 0.2),
                opacity = self.Config.baseAlpha,
                semicircle = semicircle,
            }
            
            table.insert(self.Sprites, sprite)
        end
    end
end

function RotatingWindSprites:Update(state: StormState, _conePose, _forbidden, lanternEnabled: boolean, dt: number?)
    if not self.Enabled then return end
    
    local camera = Workspace.CurrentCamera
    if not camera then return end
    
    local delta = dt or (1/60)
    local cameraPos = camera.CFrame.Position  -- SIMPLE: Just use camera position directly
    local intensity = state.intensity
    
    -- Calculate wind direction angle
    local windDir = state.vector.Magnitude > 0.01 and state.vector.Unit or Vector3.new(0.3, 0, -0.8).Unit
    self.WindAngle = math.atan2(windDir.Z, windDir.X)
    
    -- Meeting points perpendicular to wind
    local meetPoint1 = self.WindAngle + math.pi/2
    local meetPoint2 = self.WindAngle - math.pi/2
    
    -- SIMPLE: Update each sprite with minimal calculations
    for _, sprite in ipairs(self.Sprites) do
        -- Rotate sprite
        sprite.angle = sprite.angle + sprite.speed * delta * intensity
        
        -- Normalize angle (keep between 0 and 2π)
        while sprite.angle < 0 do sprite.angle = sprite.angle + math.pi * 2 end
        while sprite.angle >= math.pi * 2 do sprite.angle = sprite.angle - math.pi * 2 end
        
        -- SIMPLE: Calculate fade based on distance to meeting point
        local targetMeet = sprite.semicircle == 1 and meetPoint2 or meetPoint1
        
        -- Normalize target meet
        while targetMeet < 0 do targetMeet = targetMeet + math.pi * 2 end
        while targetMeet >= math.pi * 2 do targetMeet = targetMeet - math.pi * 2 end
        
        local angleDiff = math.abs(sprite.angle - targetMeet)
        if angleDiff > math.pi then angleDiff = math.pi * 2 - angleDiff end
        
        -- Simple fade zone
        local fadeZoneRad = math.rad(self.Config.fadeZoneAngle)
        local alpha = self.Config.baseAlpha
        if angleDiff < fadeZoneRad then
            alpha = self.Config.baseAlpha * (angleDiff / fadeZoneRad)
            
            -- Respawn at opposite meeting point when fully faded
            if angleDiff < fadeZoneRad * 0.1 then
                local startMeet = sprite.semicircle == 1 and meetPoint1 or meetPoint2
                while startMeet < 0 do startMeet = startMeet + math.pi * 2 end
                while startMeet >= math.pi * 2 do startMeet = startMeet - math.pi * 2 end
                sprite.angle = startMeet
                alpha = 0
            end
        end
        
        -- SIMPLE: Calculate position directly from camera position (no complex adjustments!)
        local x = math.cos(sprite.angle) * sprite.radius
        local z = math.sin(sprite.angle) * sprite.radius
        local position = cameraPos + Vector3.new(x, sprite.heightOffset, z)  -- Direct addition, no smoothing
        
        sprite.part.CFrame = CFrame.new(position)
        
        -- Apply transparency
        local finalAlpha = alpha * intensity
        if lanternEnabled then
            finalAlpha = finalAlpha * 0.3
        end
        
        sprite.image.ImageTransparency = 1 - finalAlpha
        
        -- Scale based on intensity
        local sizeMult = 0.8 + intensity * 0.4
        sprite.billboard.Size = UDim2.fromOffset(
            self.Config.spriteSize * 10 * sizeMult,
            self.Config.spriteSize * 10 * sizeMult
        )
    end
end

function RotatingWindSprites:SetEnabled(enabled: boolean)
    self.Enabled = enabled
    for _, sprite in ipairs(self.Sprites) do
        sprite.image.ImageTransparency = enabled and (1 - sprite.opacity) or 1
    end
end

function RotatingWindSprites:Cleanup()
    for _, sprite in ipairs(self.Sprites) do
        if sprite.part then
            sprite.part:Destroy()
        end
    end
    self.Sprites = {}
    
    if self.Container then
        self.Container:Destroy()
        self.Container = nil
    end
end

return RotatingWindSprites
