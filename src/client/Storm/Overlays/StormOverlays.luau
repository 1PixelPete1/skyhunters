--!strict
-- StormOverlays.luau  
-- Screen-space fog overlays for thick storm atmosphere

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local sharedRoot = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local StormTypes = require(sharedRoot:WaitForChild("StormTypes"))
local StormConfig = require(sharedRoot:WaitForChild("StormConfig"))

type StormState = StormTypes.StormState
type ConePose = StormTypes.ConePose
type ForbiddenAzimuth = StormTypes.ForbiddenAzimuth

local StormOverlays = {}
StormOverlays.__index = StormOverlays

function StormOverlays.new()
    local self = setmetatable({}, StormOverlays)
    
    self.Player = Players.LocalPlayer
    self.PlayerGui = self.Player:WaitForChild("PlayerGui")
    
    self.OverlayGui = nil
    self.FogFrames = {}
    self.Time = 0
    
    self:InitializeOverlays()
    
    return self
end

function StormOverlays:InitializeOverlays()
    -- DISABLED: Screen overlays were causing visibility issues
    -- Fog decals were appearing all over the screen instead of just at edges
    return -- Early return to disable all overlays
    
    --[[
    -- Create screen overlay GUI
    self.OverlayGui = Instance.new("ScreenGui")
    self.OverlayGui.Name = "StormOverlays"
    self.OverlayGui.DisplayOrder = 100 -- Above most UI
    self.OverlayGui.IgnoreGuiInset = true
    self.OverlayGui.Parent = self.PlayerGui
    
    -- Create multiple fog layers for depth
    local fogConfigs = {
        -- Dense near fog
        {
            name = "NearFog",
            color = Color3.fromRGB(120, 130, 140),
            transparency = 0.7,
            speed = Vector2.new(0.5, 0.2),
            scale = 1.2,
        },
        -- Medium fog
        {
            name = "MidFog", 
            color = Color3.fromRGB(100, 110, 125),
            transparency = 0.8,
            speed = Vector2.new(-0.3, 0.4),
            scale = 1.5,
        },
        -- Distant fog
        {
            name = "FarFog",
            color = Color3.fromRGB(90, 100, 115),
            transparency = 0.85,
            speed = Vector2.new(0.2, -0.3),
            scale = 2.0,
        },
    }
    
    for _, config in ipairs(fogConfigs) do
        local frame = Instance.new("Frame")
        frame.Name = config.name
        frame.Size = UDim2.fromScale(config.scale, config.scale)
        frame.Position = UDim2.fromScale((1 - config.scale) / 2, (1 - config.scale) / 2)
        frame.BackgroundColor3 = config.color
        frame.BackgroundTransparency = 1 -- Start hidden
        frame.BorderSizePixel = 0
        frame.Parent = self.OverlayGui
        
        -- Add texture for fog detail
        local texture = Instance.new("ImageLabel")
        texture.Size = UDim2.fromScale(1, 1)
        texture.Position = UDim2.fromScale(0, 0)
        texture.BackgroundTransparency = 1
        texture.Image = "rbxasset://textures/particles/smoke_main.dds"
        texture.ImageColor3 = config.color
        texture.ImageTransparency = config.transparency
        texture.ScaleType = Enum.ScaleType.Tile
        texture.TileSize = UDim2.fromOffset(200, 200)
        texture.Parent = frame
        
        table.insert(self.FogFrames, {
            frame = frame,
            texture = texture,
            config = config,
            offset = Vector2.new(0, 0),
        })
    end
    
    -- Vignette overlay for additional darkness
    local vignette = Instance.new("Frame")
    vignette.Name = "StormVignette"
    vignette.Size = UDim2.fromScale(1, 1)
    vignette.Position = UDim2.fromScale(0, 0)
    vignette.BackgroundTransparency = 1
    vignette.BorderSizePixel = 0
    vignette.Parent = self.OverlayGui
    
    local vignetteImage = Instance.new("ImageLabel")
    vignetteImage.Size = UDim2.fromScale(1, 1)
    vignetteImage.Position = UDim2.fromScale(0, 0)
    vignetteImage.BackgroundTransparency = 1
    vignetteImage.Image = "rbxasset://textures/ui/Vignette.png" -- Roblox default vignette
    vignetteImage.ImageColor3 = Color3.fromRGB(60, 70, 80)
    vignetteImage.ImageTransparency = 1
    vignetteImage.ScaleType = Enum.ScaleType.Stretch
    vignetteImage.Parent = vignette
    
    self.VignetteImage = vignetteImage
    --]]
end

function StormOverlays:Update(state: StormState, conePose: ConePose, forbidden: ForbiddenAzimuth, lanternEnabled: boolean, dt: number?)
    if not self.OverlayGui then return end
    
    local delta = dt or (1/60)
    self.Time += delta
    
    local intensity = math.clamp(state.intensity, 0, 1)
    
    -- Update fog layers
    for _, fogLayer in ipairs(self.FogFrames) do
        local config = fogLayer.config
        
        -- Animate fog movement
        fogLayer.offset += config.speed * delta * 10
        
        -- Wrap offset to prevent overflow
        if math.abs(fogLayer.offset.X) > 100 then
            fogLayer.offset = Vector2.new(fogLayer.offset.X % 100, fogLayer.offset.Y)
        end
        if math.abs(fogLayer.offset.Y) > 100 then
            fogLayer.offset = Vector2.new(fogLayer.offset.X, fogLayer.offset.Y % 100)
        end
        
        -- Apply scrolling
        fogLayer.texture.Position = UDim2.fromOffset(fogLayer.offset.X, fogLayer.offset.Y)
        
        -- Calculate fog opacity based on storm intensity - REDUCED for better 3D visibility
        local baseFogAlpha = intensity * (1 - config.transparency) * 0.5 -- Reduced by half
        
        -- Lantern effect - reduce fog opacity in center of screen
        local lanternReduction = 1
        if lanternEnabled then
            lanternReduction = 0.4 -- 60% fog reduction when lantern is on
        end
        
        local finalFogAlpha = baseFogAlpha * lanternReduction * 0.6 -- Further reduced
        fogLayer.texture.ImageTransparency = 1 - math.clamp(finalFogAlpha, 0, 0.4) -- Reduced max opacity
        
        -- Slight color pulsing for organic feel
        local pulse = 0.9 + 0.1 * math.sin(self.Time * 0.5 + config.speed.X * 3)
        local pulseColor = Color3.new(
            config.color.R * pulse,
            config.color.G * pulse, 
            config.color.B * pulse
        )
        fogLayer.texture.ImageColor3 = pulseColor
    end
    
    -- Update vignette - REDUCED for better 3D visibility
    local vignetteAlpha = intensity * 0.3 -- Reduced from 0.6
    if lanternEnabled then
        vignetteAlpha *= 0.5 -- Lantern reduces vignette effect
    end
    
    self.VignetteImage.ImageTransparency = 1 - math.clamp(vignetteAlpha, 0, 0.35) -- Reduced from 0.7
end

function StormOverlays:Cleanup()
    if self.OverlayGui then
        self.OverlayGui:Destroy()
        self.OverlayGui = nil
    end
    self.FogFrames = {}
end

return StormOverlays
