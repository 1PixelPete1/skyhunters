--!strict
-- SurroundingAirEffectEnhanced.luau
-- Enhanced cylindrical storm sprites that physically rotate around the camera

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local sharedRoot = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local StormTypes = require(sharedRoot:WaitForChild("StormTypes"))
local StormDebugConfig = require(script.Parent.Parent:WaitForChild("StormDebugConfig"))

type StormState = StormTypes.StormState
type ConePose = StormTypes.ConePose
type ForbiddenAzimuth = StormTypes.ForbiddenAzimuth
export type PerfConfig = StormTypes.PerfConfig

type RingSprite = {
    part: BasePart,
    textureFront: Decal,
    textureBack: Decal,
    angle: number,
    baseAngle: number,
    trackId: number,
    fadeWeight: number,
    scrollOffset: number,
    windLerp: number,
    targetAngle: number,
    wobblePhase: number,
    orbitSpeed: number,
}

local VECTOR_UP = Vector3.new(0, 1, 0)
local DEBUG_COLOR_TRACK1 = Color3.fromRGB(200, 220, 240) -- Light blue
local DEBUG_COLOR_TRACK2 = Color3.fromRGB(180, 200, 220) -- Slightly darker blue

local SurroundingAirEffectEnhanced = {}
SurroundingAirEffectEnhanced.__index = SurroundingAirEffectEnhanced

function SurroundingAirEffectEnhanced.new(perfConfig: PerfConfig, perfTier: StormTypes.PerfTier?)
    local self = setmetatable({}, SurroundingAirEffectEnhanced)
    
    self.Container = Instance.new("Folder")
    self.Container.Name = "EnhancedStormRingSprites"
    self.Container.Parent = Workspace
    
    self.RingSprites = {} :: {RingSprite}
    self.Time = 0
    self.LastWindDirection = Vector3.new(0, 0, -1)
    
    -- Debug visualization parts
    self.DebugParts = {}
    
    self:BuildRingSprites()
    
    print("[EnhancedRingSprites] Initialized ROTATING sprites - adjust Storm_Ring* attributes on LocalPlayer")
    
    return self
end

function SurroundingAirEffectEnhanced:BuildRingSprites()
    local config = StormDebugConfig:GetRingConfig()
    if not config or not config.enabled then return end
    
    local segmentCount = math.max(config.segments, 6)
    
    -- Two half-rings that rotate around the camera
    local tracks = {
        { startAngle = -math.pi / 2, endAngle = math.pi / 2, id = 1, orbitDirection = 1 },   -- Front half, clockwise
        { startAngle = math.pi / 2, endAngle = 3 * math.pi / 2, id = 2, orbitDirection = -1 }, -- Back half, counter-clockwise
    }
    
    for _, track in ipairs(tracks) do
        for i = 0, segmentCount - 1 do
            local t = i / segmentCount
            local angle = track.startAngle + (track.endAngle - track.startAngle) * t
            
            -- Create the sprite part - NOT a billboard, a real 3D sprite
            local part = Instance.new("Part")
            part.Name = string.format("RingSprite_%d_%02d", track.id, i + 1)
            part.Anchored = true
            part.CanCollide = false
            part.CanQuery = false
            part.CanTouch = false
            part.Transparency = 0.5 -- Base transparency for the part itself
            part.Size = Vector3.new(config.spriteSize.X, config.spriteSize.Y, 0.2) -- Thin but visible
            part.Material = Enum.Material.SmoothPlastic
            part.Color = track.id == 1 and DEBUG_COLOR_TRACK1 or DEBUG_COLOR_TRACK2
            part.Parent = self.Container
            
            -- Add decals for the sprite texture (not billboards!)
            local textureFront = Instance.new("Decal")
            textureFront.Name = "SpriteFront"
            textureFront.Face = Enum.NormalId.Front
            textureFront.Texture = "rbxasset://textures/particles/smoke_main.dds"
            textureFront.Color3 = track.id == 1 and DEBUG_COLOR_TRACK1 or DEBUG_COLOR_TRACK2
            textureFront.Transparency = 1
            textureFront.Parent = part
            
            local textureBack = Instance.new("Decal")
            textureBack.Name = "SpriteBack"
            textureBack.Face = Enum.NormalId.Back
            textureBack.Texture = "rbxasset://textures/particles/smoke_main.dds"
            textureBack.Color3 = track.id == 1 and DEBUG_COLOR_TRACK1 or DEBUG_COLOR_TRACK2
            textureBack.Transparency = 1
            textureBack.Parent = part
            
            -- Calculate fade weight (stronger in middle, fade at edges)
            local edgeDistance = math.min(t, 1 - t)
            local fadeWeight = math.pow(edgeDistance * 2, 1.5)
            
            local sprite: RingSprite = {
                part = part,
                textureFront = textureFront,
                textureBack = textureBack,
                angle = angle,
                baseAngle = angle,
                trackId = track.id,
                fadeWeight = fadeWeight,
                scrollOffset = 0,
                windLerp = 0,
                targetAngle = angle,
                wobblePhase = math.random() * math.pi * 2,
                orbitSpeed = track.orbitDirection * (config.orbitSpeed or 0.5), -- Orbit speed with direction
            }
            
            table.insert(self.RingSprites, sprite)
        end
    end
end

function SurroundingAirEffectEnhanced:CreateDebugVisualization(config, cameraPos: Vector3)
    -- Clean up old debug parts
    for _, part in ipairs(self.DebugParts) do
        part:Destroy()
    end
    self.DebugParts = {}
    
    if not StormDebugConfig:IsDebugViewEnabled() then return end
    
    -- Create debug ring to show the circle
    local segments = 32
    for i = 1, segments do
        local angle1 = (i - 1) / segments * math.pi * 2
        local angle2 = i / segments * math.pi * 2
        
        local part = Instance.new("Part")
        part.Name = "DebugRing_" .. i
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.Material = Enum.Material.Neon
        part.BrickColor = BrickColor.new("Lime green")
        part.Size = Vector3.new(2, 0.5, config.radius * 2 * math.sin(math.pi / segments))
        
        local x1 = math.cos(angle1) * config.radius
        local z1 = math.sin(angle1) * config.radius
        local x2 = math.cos(angle2) * config.radius
        local z2 = math.sin(angle2) * config.radius
        
        local midX = (x1 + x2) / 2
        local midZ = (z1 + z2) / 2
        
        part.CFrame = CFrame.lookAt(
            cameraPos + Vector3.new(midX, config.height, midZ),
            cameraPos + Vector3.new(x2, config.height, z2)
        )
        part.Parent = self.Container
        
        table.insert(self.DebugParts, part)
    end
end

function SurroundingAirEffectEnhanced:Update(state: StormState, conePose: ConePose?, forbidden: ForbiddenAzimuth?, lanternEnabled: boolean, dt: number?)
    local camera = Workspace.CurrentCamera
    if not camera then return end
    
    local config = StormDebugConfig:GetRingConfig()
    if not config or not config.enabled then
        -- Hide all sprites if disabled
        for _, sprite in ipairs(self.RingSprites) do
            sprite.textureFront.Transparency = 1
            sprite.textureBack.Transparency = 1
        end
        return
    end
    
    local delta = dt or (1/60)
    self.Time += delta
    
    local intensity = math.clamp(state.intensity * StormDebugConfig:GetGlobalIntensity(), 0, 1)
    if intensity <= 0 then
        for _, sprite in ipairs(self.RingSprites) do
            sprite.textureFront.Transparency = 1
            sprite.textureBack.Transparency = 1
        end
        return
    end
    
    local cameraCf = camera.CFrame
    local cameraPos = cameraCf.Position
    
    -- Get horizontal wind direction
    local horizontalWind = Vector3.new(state.vector.X, 0, state.vector.Z)
    local windMagnitude = horizontalWind.Magnitude
    local windDirection = windMagnitude > 0.01 and horizontalWind.Unit or Vector3.new(0, 0, -1)
    
    -- Smooth wind direction changes
    self.LastWindDirection = self.LastWindDirection:Lerp(windDirection, delta * 2)
    
    -- Update debug visualization
    self:CreateDebugVisualization(config, cameraPos)
    
    -- Update each sprite
    for _, sprite in ipairs(self.RingSprites) do
        -- ORBIT THE SPRITES AROUND THE CAMERA
        local orbitMultiplier = config.orbitSpeed or 0.5
        sprite.angle += sprite.orbitSpeed * delta * intensity
        
        -- Keep angle in bounds
        if sprite.angle > math.pi * 2 then
            sprite.angle -= math.pi * 2
        elseif sprite.angle < -math.pi * 2 then
            sprite.angle += math.pi * 2
        end
        
        -- Calculate wind influence on angle (sprites lean toward wind direction)
        local windInfluence = 0.2 * intensity * windMagnitude / 10
        local windAngle = math.atan2(windDirection.Z, windDirection.X)
        
        -- Add some wobble based on wind
        local windWobble = math.sin(self.Time * 2 + sprite.wobblePhase) * windInfluence
        local finalAngle = sprite.angle + windWobble
        
        -- Add subtle vertical wobble for organic movement
        local verticalWobble = math.sin(self.Time * 0.5 + sprite.wobblePhase) * 2 * intensity
        
        -- Calculate position on ring AROUND THE CAMERA
        local radius = config.radius
        local height = config.height + verticalWobble
        
        local x = math.cos(finalAngle) * radius
        local z = math.sin(finalAngle) * radius
        local position = cameraPos + Vector3.new(x, height, z) -- Follow camera!
        
        -- ORIENT THE SPRITE TANGENTIALLY TO THE CIRCLE (not facing camera!)
        -- This is key - sprites should be perpendicular to the radius
        local tangentDirection = Vector3.new(-math.sin(finalAngle), 0, math.cos(finalAngle))
        
        -- Add slight tilt based on wind
        local tiltAngle = windInfluence * 0.3
        local upVector = VECTOR_UP
        
        -- Create the sprite orientation
        sprite.part.CFrame = CFrame.lookAt(position, position + tangentDirection, upVector) 
            * CFrame.Angles(0, 0, tiltAngle) -- Add tilt
            * CFrame.Angles(0, math.pi/2, 0) -- Rotate to face tangentially
        
        -- Animate texture properties (simulate scrolling if we had UV control)
        sprite.scrollOffset += config.scrollSpeed * delta * (sprite.trackId == 1 and 1 or -1)
        
        -- Calculate transparency based on various factors
        local baseAlpha = config.alphaMin + (config.alphaMax - config.alphaMin) * intensity
        local alpha = baseAlpha * sprite.fadeWeight
        
        -- Distance fade from camera
        local distanceToCamera = (position - cameraPos).Magnitude
        local distanceFade = math.clamp(1 - (distanceToCamera - config.radius * 0.8) / (config.radius * 0.4), 0, 1)
        alpha *= distanceFade
        
        -- Angle-based fade - sprites directly in front are more visible
        local toCameraForward = cameraCf.LookVector
        local toSprite = (position - cameraPos).Unit
        local viewDot = math.abs(toCameraForward:Dot(toSprite))
        local angleFade = 0.3 + viewDot * 0.7
        alpha *= angleFade
        
        -- Lantern cone reduction
        if lanternEnabled and conePose then
            local dot = toSprite:Dot(conePose.dir)
            local angleDeg = math.deg(math.acos(math.clamp(dot, -1, 1)))
            
            if angleDeg < conePose.halfAngleDeg then
                -- Inside cone - dramatically reduce visibility
                local coneFade = math.clamp((angleDeg / conePose.halfAngleDeg), 0, 1)
                alpha *= 0.05 + coneFade * 0.15
            end
        end
        
        -- Apply final transparency to decals
        local finalTransparency = 1 - math.clamp(alpha, 0, 0.9)
        sprite.textureFront.Transparency = finalTransparency
        sprite.textureBack.Transparency = finalTransparency
        
        -- Make the part itself semi-transparent
        sprite.part.Transparency = math.max(0.7, finalTransparency * 0.9)
        
        -- Add subtle color variation based on position in orbit
        local colorShift = 0.85 + 0.15 * math.sin(sprite.angle * 2 + self.Time * 0.3)
        local trackColor = sprite.trackId == 1 and DEBUG_COLOR_TRACK1 or DEBUG_COLOR_TRACK2
        local finalColor = Color3.new(
            trackColor.R * colorShift,
            trackColor.G * colorShift,
            trackColor.B * colorShift
        )
        sprite.textureFront.Color3 = finalColor
        sprite.textureBack.Color3 = finalColor
        sprite.part.Color = finalColor
    end
end

function SurroundingAirEffectEnhanced:Cleanup()
    for _, sprite in ipairs(self.RingSprites) do
        if sprite.part then
            sprite.part:Destroy()
        end
    end
    self.RingSprites = {}
    
    for _, part in ipairs(self.DebugParts) do
        part:Destroy()
    end
    self.DebugParts = {}
    
    if self.Container then
        self.Container:Destroy()
        self.Container = nil
    end
end

return SurroundingAirEffectEnhanced
