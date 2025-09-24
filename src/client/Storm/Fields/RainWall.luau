--!strict
-- RainWall.luau
-- Thick rain animation using flickering textured quads
-- Positioned in front of camera to create depth

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local sharedRoot = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local StormTypes = require(sharedRoot:WaitForChild("StormTypes"))

type StormState = StormTypes.StormState
export type PerfConfig = StormTypes.PerfConfig

type RainPlane = {
    part: Part,
    surfaceGui: SurfaceGui,
    frame1: Frame,
    frame2: Frame,
    currentFrame: number,
    flickerTime: number,
    flickerSpeed: number,
    distance: number,
    height: number,
    width: number,
}

local RainWall = {}
RainWall.__index = RainWall

function RainWall.new(perfConfig: PerfConfig?, perfTier: StormTypes.PerfTier?)
    local self = setmetatable({}, RainWall)
    
    self.Container = Instance.new("Folder")
    self.Container.Name = "RainWall"
    self.Container.Parent = Workspace
    
    self.Enabled = true
    self.Time = 0
    self.RainPlanes = {} :: {RainPlane}
    
    -- Configuration
    self.Config = {
        -- Distance from camera (2x far rain radius)
        distance = 120, -- Assuming far rain is ~60 studs
        
        -- Wall dimensions
        wallWidth = 200,
        wallHeight = 100,
        
        -- Number of layers for depth
        layerCount = 3,
        layerSpacing = 15,
        
        -- Flicker settings
        flickerSpeedMin = 8,  -- Hz
        flickerSpeedMax = 15, -- Hz
        
        -- Colors for the two frames (slightly different)
        color1 = Color3.fromRGB(180, 190, 200), -- Lighter blue-grey
        color2 = Color3.fromRGB(170, 180, 195), -- Darker blue-grey
        
        -- Transparency
        baseAlpha = 0.3,
    }
    
    self:CreateRainWalls()
    
    print("[RainWall] Initialized flickering rain wall system")
    
    return self
end

function RainWall:CreateRainWalls()
    for layer = 1, self.Config.layerCount do
        -- Create the part that will hold our rain texture
        local part = Instance.new("Part")
        part.Name = "RainWallLayer" .. layer
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.Transparency = 1 -- Part itself is invisible
        part.Size = Vector3.new(self.Config.wallWidth, self.Config.wallHeight, 0.1)
        part.Material = Enum.Material.SmoothPlastic
        part.CastShadow = false -- No shadows from rain wall
        part.Parent = self.Container
        
        -- Create SurfaceGui for the rain texture (stays upright, doesn't billboard)
        local surfaceGui = Instance.new("SurfaceGui")
        surfaceGui.Name = "RainTexture"
        surfaceGui.Face = Enum.NormalId.Front
        surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
        surfaceGui.PixelsPerStud = 50
        surfaceGui.LightInfluence = 0
        surfaceGui.AlwaysOnTop = false
        surfaceGui.Parent = part
        
        -- Create two frames with slightly different colors for flickering
        local frame1 = Instance.new("Frame")
        frame1.Name = "RainFrame1"
        frame1.Size = UDim2.fromScale(1, 1)
        frame1.Position = UDim2.fromScale(0, 0)
        frame1.BackgroundColor3 = self.Config.color1
        frame1.BackgroundTransparency = 1 - self.Config.baseAlpha
        frame1.BorderSizePixel = 0
        frame1.Visible = true
        frame1.Parent = surfaceGui
        
        local frame2 = Instance.new("Frame")
        frame2.Name = "RainFrame2"
        frame2.Size = UDim2.fromScale(1, 1)
        frame2.Position = UDim2.fromScale(0, 0)
        frame2.BackgroundColor3 = self.Config.color2
        frame2.BackgroundTransparency = 1 - self.Config.baseAlpha
        frame2.BorderSizePixel = 0
        frame2.Visible = false
        frame2.Parent = surfaceGui
        
        -- Add simple rain texture pattern using gradients
        for i = 1, 20 do
            -- Create vertical streaks for rain effect on frame 1
            local streak1 = Instance.new("Frame")
            streak1.Size = UDim2.new(0.002, 0, 1, 0)
            streak1.Position = UDim2.fromScale(math.random() * 0.98, 0)
            streak1.BackgroundColor3 = Color3.fromRGB(200, 210, 220)
            streak1.BackgroundTransparency = 0.7 + math.random() * 0.3
            streak1.BorderSizePixel = 0
            streak1.Parent = frame1
            
            -- Create slightly different streaks for frame 2
            local streak2 = Instance.new("Frame")
            streak2.Size = UDim2.new(0.002, 0, 1, 0)
            streak2.Position = UDim2.fromScale(math.random() * 0.98, 0)
            streak2.BackgroundColor3 = Color3.fromRGB(190, 200, 215)
            streak2.BackgroundTransparency = 0.7 + math.random() * 0.3
            streak2.BorderSizePixel = 0
            streak2.Parent = frame2
        end
        
        -- Store the rain plane
        local rainPlane: RainPlane = {
            part = part,
            surfaceGui = surfaceGui,
            frame1 = frame1,
            frame2 = frame2,
            currentFrame = 1,
            flickerTime = 0,
            flickerSpeed = self.Config.flickerSpeedMin + 
                         math.random() * (self.Config.flickerSpeedMax - self.Config.flickerSpeedMin),
            distance = self.Config.distance + (layer - 1) * self.Config.layerSpacing,
            height = self.Config.wallHeight,
            width = self.Config.wallWidth,
        }
        
        table.insert(self.RainPlanes, rainPlane)
    end
end

function RainWall:Update(state: StormState, conePose, forbidden, lanternEnabled: boolean, dt: number?)
    local camera = Workspace.CurrentCamera
    if not camera or not self.Enabled then return end
    
    local delta = dt or (1/60)
    self.Time += delta
    
    local cameraCf = camera.CFrame
    local intensity = state.intensity
    local windDir = state.vector.Magnitude > 0.01 and state.vector.Unit or Vector3.new(0.3, 0, -0.8).Unit
    
    -- Update each rain plane
    for i, plane in ipairs(self.RainPlanes) do
        -- Position the plane in front of the camera
        local forward = cameraCf.LookVector
        local right = cameraCf.RightVector
        local up = Vector3.new(0, 1, 0) -- Keep upright, not aligned to camera
        
        -- Position with slight offset based on layer
        local position = cameraCf.Position + forward * plane.distance
        
        -- Add slight horizontal offset based on wind
        local windOffset = windDir * (i - 1) * 5
        position = position + Vector3.new(windOffset.X, 0, windOffset.Z)
        
        -- Face the camera but stay upright
        local lookDirection = (cameraCf.Position - position) * Vector3.new(1, 0, 1)
        if lookDirection.Magnitude > 0.01 then
            plane.part.CFrame = CFrame.lookAt(position, position + lookDirection, up)
        else
            plane.part.CFrame = CFrame.new(position)
        end
        
        -- Handle flickering between frames
        plane.flickerTime += delta
        if plane.flickerTime >= 1 / plane.flickerSpeed then
            plane.flickerTime = 0
            
            -- Toggle between frames
            if plane.currentFrame == 1 then
                plane.frame1.Visible = false
                plane.frame2.Visible = true
                plane.currentFrame = 2
            else
                plane.frame1.Visible = true
                plane.frame2.Visible = false
                plane.currentFrame = 1
            end
        end
        
        -- Update transparency based on intensity and lantern
        local alpha = self.Config.baseAlpha * intensity
        
        -- Reduce visibility if lantern is on
        if lanternEnabled then
            alpha *= 0.4
        end
        
        -- Layer-based transparency (farther = more transparent)
        alpha *= (1 - (i - 1) * 0.2 / self.Config.layerCount)
        
        plane.frame1.BackgroundTransparency = 1 - alpha
        plane.frame2.BackgroundTransparency = 1 - alpha
        
        -- Update streak transparencies too
        for _, child in ipairs(plane.frame1:GetChildren()) do
            if child:IsA("Frame") then
                child.BackgroundTransparency = 0.7 + (1 - alpha) * 0.3
            end
        end
        for _, child in ipairs(plane.frame2:GetChildren()) do
            if child:IsA("Frame") then
                child.BackgroundTransparency = 0.7 + (1 - alpha) * 0.3
            end
        end
        
        -- Subtle size variation for organic feel
        local sizePulse = 1 + math.sin(self.Time * 0.5 + i) * 0.02
        plane.part.Size = Vector3.new(
            plane.width * sizePulse,
            plane.height,
            0.1
        )
    end
end

function RainWall:SetEnabled(enabled: boolean)
    self.Enabled = enabled
    for _, plane in ipairs(self.RainPlanes) do
        plane.part.Parent = enabled and self.Container or nil
    end
end

function RainWall:Cleanup()
    for _, plane in ipairs(self.RainPlanes) do
        if plane.part then
            plane.part:Destroy()
        end
    end
    self.RainPlanes = {}
    
    if self.Container then
        self.Container:Destroy()
        self.Container = nil
    end
end

return RainWall
