--!strict
-- RotatingWindSprites.luau  
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
    angle: number,       -- Current angle around the circle
    targetAngle: number, -- Target angle to rotate towards
    radius: number,
    height: number,
    speed: number,
    opacity: number,
    fadeState: "in" | "out" | "visible",
    semicircle: number, -- Which semicircle: 1 or 2
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
    self.WindAngle = 0 -- Current wind direction angle
    
    -- Configuration
    self.Config = {
        spritesPerSemicircle = 8,  -- Number of sprites per half circle
        radius = 15,                -- Closer to camera
        minHeight = -3,
        maxHeight = 8,
        spriteSize = 80,            -- Much larger sprites
        baseSpeed = 0.5,            -- Rotation speed
        baseAlpha = 0.4,
        fadeZoneAngle = 30,         -- Degrees from meeting point to start fading
    }
    
    self:CreateSprites()
    
    print("[RotatingWindSprites] Proper wind-aligned semicircle system initialized")
    
    return self
end

function RotatingWindSprites:CreateSprites()
    -- Create two semicircles of sprites
    for semicircle = 1, 2 do
        for i = 1, self.Config.spritesPerSemicircle do
            -- Calculate base angle for this sprite in its semicircle
            local angleInSemicircle = (i - 1) / self.Config.spritesPerSemicircle * math.pi
            local baseAngle = angleInSemicircle + (semicircle - 1) * math.pi
            
            -- Create the sprite part (just an anchor point)
            local part = Instance.new("Part")
            part.Name = string.format("WindSprite_S%d_%d", semicircle, i)
            part.Anchored = true
            part.CanCollide = false
            part.CanQuery = false
            part.CanTouch = false
            part.Transparency = 1
            part.Size = Vector3.new(0.1, 0.1, 0.1)
            part.CastShadow = false -- No shadows from wind sprites
            part.Parent = self.Container
            
            -- Create billboard with large gust sprite
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
            
            -- Vary height for each sprite
            local heightOffset = self.Config.minHeight + 
                               (self.Config.maxHeight - self.Config.minHeight) * ((i - 1) / self.Config.spritesPerSemicircle)
            
            local sprite: WindSprite = {
                part = part,
                billboard = billboard,
                image = imageLabel,
                angle = baseAngle,
                targetAngle = baseAngle,
                radius = self.Config.radius + (i % 2) * 3, -- Slight radius variation
                height = heightOffset,
                speed = self.Config.baseSpeed,
                opacity = self.Config.baseAlpha,
                fadeState = "visible",
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
    local cameraPos = camera.CFrame.Position
    local intensity = state.intensity
    
    -- Calculate wind direction angle
    local windDir = state.vector.Magnitude > 0.01 and state.vector.Unit or Vector3.new(0.3, 0, -0.8).Unit
    self.WindAngle = math.atan2(windDir.Z, windDir.X)
    
    -- The semicircles should meet at points perpendicular to wind direction
    -- Meeting points are at windAngle + π/2 and windAngle - π/2
    local meetPoint1 = self.WindAngle + math.pi/2
    local meetPoint2 = self.WindAngle - math.pi/2
    
    -- Update each sprite
    for _, sprite in ipairs(self.Sprites) do
        -- Determine the semicircle's rotation direction and meeting points
        local startMeet, endMeet
        if sprite.semicircle == 1 then
            startMeet = meetPoint1
            endMeet = meetPoint2
        else
            startMeet = meetPoint2
            endMeet = meetPoint1
        end
        
        -- Normalize angles to 0-2π
        local normalizeAngle = function(angle)
            while angle < 0 do angle = angle + math.pi * 2 end
            while angle >= math.pi * 2 do angle = angle - math.pi * 2 end
            return angle
        end
        
        sprite.angle = normalizeAngle(sprite.angle)
        startMeet = normalizeAngle(startMeet)
        endMeet = normalizeAngle(endMeet)
        
        -- Rotate the sprite
        sprite.angle = sprite.angle + sprite.speed * delta * intensity
        sprite.angle = normalizeAngle(sprite.angle)
        
        -- Check if sprite is near meeting points for fading
        local fadeZoneRad = math.rad(self.Config.fadeZoneAngle)
        local distToEnd = math.abs(sprite.angle - endMeet)
        if distToEnd > math.pi then distToEnd = math.pi * 2 - distToEnd end
        
        -- Handle fading and respawning
        if distToEnd < fadeZoneRad then
            -- Approaching end meeting point - fade out
            sprite.fadeState = "out"
            sprite.opacity = self.Config.baseAlpha * (distToEnd / fadeZoneRad)
        elseif sprite.fadeState == "out" and distToEnd > fadeZoneRad then
            -- Respawn at start meeting point
            sprite.angle = startMeet
            sprite.fadeState = "in"
            sprite.opacity = 0
        elseif sprite.fadeState == "in" then
            -- Fading in after respawn
            local distFromStart = math.abs(sprite.angle - startMeet)
            if distFromStart > math.pi then distFromStart = math.pi * 2 - distFromStart end
            
            if distFromStart < fadeZoneRad then
                sprite.opacity = self.Config.baseAlpha * (distFromStart / fadeZoneRad)
            else
                sprite.fadeState = "visible"
                sprite.opacity = self.Config.baseAlpha
            end
        else
            sprite.fadeState = "visible"
            sprite.opacity = self.Config.baseAlpha
        end
        
        -- Calculate world position
        local x = math.cos(sprite.angle) * sprite.radius
        local z = math.sin(sprite.angle) * sprite.radius
        local position = cameraPos + Vector3.new(x, sprite.height, z)
        
        sprite.part.CFrame = CFrame.new(position)
        
        -- Apply transparency with intensity and lantern modulation
        local alpha = sprite.opacity * intensity
        if lanternEnabled then
            alpha *= 0.3 -- Reduce visibility with lantern
        end
        
        sprite.image.ImageTransparency = 1 - alpha
        
        -- Scale sprites based on distance and intensity
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
