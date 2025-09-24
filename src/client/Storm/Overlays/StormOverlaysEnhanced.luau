--!strict
-- StormOverlaysEnhanced.luau
-- Enhanced corner vignette system with wind-based jittering

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local sharedRoot = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local StormTypes = require(sharedRoot:WaitForChild("StormTypes"))
local StormDebugConfig = require(script.Parent.Parent:WaitForChild("StormDebugConfig"))

type StormState = StormTypes.StormState
type ConePose = StormTypes.ConePose  
type ForbiddenAzimuth = StormTypes.ForbiddenAzimuth

type CornerVignette = {
    frame: Frame,
    image: ImageLabel,
    basePosition: UDim2,
    jitterOffset: Vector2,
    jitterPhase: number,
    corner: string, -- "TL", "TR", "BL", "BR"
}

local StormOverlaysEnhanced = {}
StormOverlaysEnhanced.__index = StormOverlaysEnhanced

function StormOverlaysEnhanced.new()
    local self = setmetatable({}, StormOverlaysEnhanced)
    
    self.Player = Players.LocalPlayer
    self.PlayerGui = self.Player:WaitForChild("PlayerGui")
    
    self.OverlayGui = nil
    self.CornerVignettes = {} :: {CornerVignette}
    self.Time = 0
    self.WindSpeed = 0
    
    self:InitializeOverlays()
    
    print("[EnhancedOverlays] Initialized corner vignette system - adjust Storm_Vignette* attributes")
    
    return self
end

function StormOverlaysEnhanced:InitializeOverlays()
    -- DISABLED: Corner vignettes were showing visible frames and fog everywhere
    -- These should only shimmer at screen edges, not paste fog decals across the screen
    return -- Early return to disable all corner overlays
    
    --[[
    -- Create screen overlay GUI
    self.OverlayGui = Instance.new("ScreenGui")
    self.OverlayGui.Name = "EnhancedStormOverlays"
    self.OverlayGui.DisplayOrder = 100
    self.OverlayGui.IgnoreGuiInset = true
    self.OverlayGui.Parent = self.PlayerGui
    
    local config = StormDebugConfig:GetVignetteConfig()
    if not config then return end
    
    if config.mode == "corners" then
        self:CreateCornerVignettes(config)
    else
        self:CreateFullVignette(config)
    end
    --]]
end

function StormOverlaysEnhanced:CreateCornerVignettes(config)
    local corners = {
        {id = "TL", anchor = Vector2.new(0, 0), position = UDim2.new(0, 0, 0, 0)},
        {id = "TR", anchor = Vector2.new(1, 0), position = UDim2.new(1, 0, 0, 0)},
        {id = "BL", anchor = Vector2.new(0, 1), position = UDim2.new(0, 0, 1, 0)},
        {id = "BR", anchor = Vector2.new(1, 1), position = UDim2.new(1, 0, 1, 0)},
    }
    
    for _, corner in ipairs(corners) do
        local container = Instance.new("Frame")
        container.Name = "Vignette_" .. corner.id
        container.Size = UDim2.fromScale(config.size, config.size)
        container.Position = corner.position
        container.AnchorPoint = corner.anchor
        container.BackgroundTransparency = 1
        container.BorderSizePixel = 0
        container.ClipsDescendants = false
        container.Parent = self.OverlayGui
        
        -- Create gradient image for corner fog
        local image = Instance.new("ImageLabel")
        image.Name = "FogGradient"
        image.Size = UDim2.fromScale(1, 1)
        image.Position = UDim2.fromScale(0, 0)
        image.BackgroundTransparency = 1
        
        -- Use radial gradient texture or create custom gradient
        if corner.id == "TL" then
            image.Image = "rbxasset://textures/ui/LuaChat/9-slice/gradient.png"
            image.Rotation = 0
        elseif corner.id == "TR" then
            image.Image = "rbxasset://textures/ui/LuaChat/9-slice/gradient.png"
            image.Rotation = -90
        elseif corner.id == "BL" then
            image.Image = "rbxasset://textures/ui/LuaChat/9-slice/gradient.png"
            image.Rotation = 90
        else -- BR
            image.Image = "rbxasset://textures/ui/LuaChat/9-slice/gradient.png"
            image.Rotation = 180
        end
        
        image.ImageColor3 = Color3.fromRGB(70, 80, 90)
        image.ImageTransparency = 1
        image.ScaleType = Enum.ScaleType.Stretch
        image.Parent = container
        
        -- Add layered fog texture for depth
        local fogTexture = Instance.new("ImageLabel")
        fogTexture.Name = "FogTexture"
        fogTexture.Size = UDim2.fromScale(1.2, 1.2) -- Slightly larger for jitter room
        fogTexture.Position = UDim2.fromScale(-0.1, -0.1)
        fogTexture.BackgroundTransparency = 1
        fogTexture.Image = "rbxasset://textures/particles/smoke_main.dds"
        fogTexture.ImageColor3 = Color3.fromRGB(90, 100, 110)
        fogTexture.ImageTransparency = 1
        fogTexture.ScaleType = Enum.ScaleType.Tile
        fogTexture.TileSize = UDim2.fromOffset(150, 150)
        fogTexture.Parent = container
        
        local vignette: CornerVignette = {
            frame = container,
            image = fogTexture,
            basePosition = corner.position,
            jitterOffset = Vector2.new(0, 0),
            jitterPhase = math.random() * math.pi * 2,
            corner = corner.id,
        }
        
        table.insert(self.CornerVignettes, vignette)
    end
end

function StormOverlaysEnhanced:CreateFullVignette(config)
    -- Traditional full-screen vignette (fallback mode)
    local vignette = Instance.new("Frame")
    vignette.Name = "FullVignette"
    vignette.Size = UDim2.fromScale(1, 1)
    vignette.Position = UDim2.fromScale(0, 0)
    vignette.BackgroundTransparency = 1
    vignette.BorderSizePixel = 0
    vignette.Parent = self.OverlayGui
    
    local image = Instance.new("ImageLabel")
    image.Size = UDim2.fromScale(1, 1)
    image.Position = UDim2.fromScale(0, 0)
    image.BackgroundTransparency = 1
    image.Image = "rbxasset://textures/ui/Vignette.png"
    image.ImageColor3 = Color3.fromRGB(60, 70, 80)
    image.ImageTransparency = 1
    image.ScaleType = Enum.ScaleType.Stretch
    image.Parent = vignette
    
    -- Store as a single corner vignette for compatibility
    local fullVignette: CornerVignette = {
        frame = vignette,
        image = image,
        basePosition = UDim2.fromScale(0, 0),
        jitterOffset = Vector2.new(0, 0),
        jitterPhase = 0,
        corner = "FULL",
    }
    
    table.insert(self.CornerVignettes, fullVignette)
end

function StormOverlaysEnhanced:Update(state: StormState, conePose: ConePose?, forbidden: ForbiddenAzimuth?, lanternEnabled: boolean, dt: number?)
    if not self.OverlayGui then return end
    
    local delta = dt or (1/60)
    self.Time += delta
    
    local config = StormDebugConfig:GetVignetteConfig()
    if not config then return end
    
    local intensity = math.clamp(state.intensity * StormDebugConfig:GetGlobalIntensity(), 0, 1)
    
    -- Calculate wind speed for jitter
    self.WindSpeed = state.vector.Magnitude
    local jitterIntensity = math.clamp(self.WindSpeed / 30, 0, 1) * intensity
    
    -- Update each corner vignette
    for _, vignette in ipairs(self.CornerVignettes) do
        -- Calculate jitter based on wind speed
        if config.mode == "corners" and vignette.corner ~= "FULL" then
            -- Multi-frequency jitter for organic movement
            local jitterX = 0
            local jitterY = 0
            
            -- Low frequency sway
            jitterX += math.sin(self.Time * config.jitterSpeed * 0.5 + vignette.jitterPhase) * config.jitterAmount * 0.6
            jitterY += math.cos(self.Time * config.jitterSpeed * 0.5 + vignette.jitterPhase * 1.3) * config.jitterAmount * 0.6
            
            -- High frequency vibration
            jitterX += math.sin(self.Time * config.jitterSpeed * 3 + vignette.jitterPhase * 2) * config.jitterAmount * 0.3
            jitterY += math.cos(self.Time * config.jitterSpeed * 3 + vignette.jitterPhase * 2.5) * config.jitterAmount * 0.3
            
            -- Apply wind direction bias
            local windAngle = math.atan2(state.vector.Z, state.vector.X)
            jitterX += math.cos(windAngle) * config.jitterAmount * 0.5
            jitterY += math.sin(windAngle) * config.jitterAmount * 0.5
            
            -- Scale jitter by wind intensity
            jitterX *= jitterIntensity
            jitterY *= jitterIntensity
            
            -- Smooth the jitter transition
            vignette.jitterOffset = vignette.jitterOffset:Lerp(
                Vector2.new(jitterX, jitterY),
                delta * 5
            )
            
            -- Apply jitter to position
            vignette.frame.Position = UDim2.new(
                vignette.basePosition.X.Scale,
                vignette.basePosition.X.Offset + vignette.jitterOffset.X,
                vignette.basePosition.Y.Scale,
                vignette.basePosition.Y.Offset + vignette.jitterOffset.Y
            )
            
            -- Animate fog texture scrolling
            local scrollX = math.sin(self.Time * 0.3 + vignette.jitterPhase) * 20
            local scrollY = math.cos(self.Time * 0.4 + vignette.jitterPhase * 0.7) * 20
            vignette.image.Position = UDim2.fromOffset(-10 + scrollX, -10 + scrollY)
            
            -- Pulsing size effect based on wind gusts
            local sizePulse = 1 + math.sin(self.Time * 1.5 + vignette.jitterPhase) * 0.05 * jitterIntensity
            vignette.frame.Size = UDim2.fromScale(config.size * sizePulse, config.size * sizePulse)
        end
        
        -- Calculate opacity
        local baseAlpha = config.alpha * intensity
        
        -- Lantern effect - reduce corner fog when lantern is active
        if lanternEnabled then
            baseAlpha *= 0.3 -- 70% reduction with lantern
        end
        
        -- Add subtle flickering for atmosphere
        local flicker = 0.95 + 0.05 * math.sin(self.Time * 7 + vignette.jitterPhase * 3)
        local finalAlpha = baseAlpha * flicker
        
        -- Apply transparency
        vignette.image.ImageTransparency = 1 - math.clamp(finalAlpha, 0, 0.6)
        
        -- Color variation based on storm intensity
        local colorIntensity = 0.7 + 0.3 * intensity
        local stormColor = Color3.fromRGB(
            70 * colorIntensity,
            80 * colorIntensity,
            95 * colorIntensity
        )
        vignette.image.ImageColor3 = stormColor
        
        -- Extra gradient transparency for corner vignettes
        if vignette.corner ~= "FULL" then
            local gradient = vignette.frame:FindFirstChild("FogGradient")
            if gradient and gradient:IsA("ImageLabel") then
                gradient.ImageTransparency = 1 - math.clamp(finalAlpha * 0.7, 0, 0.5)
            end
        end
    end
end

function StormOverlaysEnhanced:Cleanup()
    if self.OverlayGui then
        self.OverlayGui:Destroy()
        self.OverlayGui = nil
    end
    self.CornerVignettes = {}
end

return StormOverlaysEnhanced
