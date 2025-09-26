-- LightLODController.lua
-- Advanced LOD system for lights with distance-based quality

local LightLODController = {}
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- LOD settings
local LOD_RANGES = {
    NEAR = 70,      -- Full quality lights
    MID = 220,      -- Twinkle sprites
    FAR = 500       -- Culled
}

local MOBILE_PARTICLE_BUDGET = 50
local PC_PARTICLE_BUDGET = 200

-- Active LOD states
local lightLODs = {} -- {lightId = {model, currentLOD, lastUpdate}}
local particleCount = 0
local isMobile = false

function LightLODController:Initialize()
    -- Detect platform
    isMobile = game:GetService("UserInputService").TouchEnabled
    
    -- Start LOD update loop
    RunService.Heartbeat:Connect(function()
        self:UpdateLODs()
    end)
end

function LightLODController:RegisterLight(lightId, model, position)
    lightLODs[lightId] = {
        model = model,
        position = position,
        currentLOD = "FAR",
        lastUpdate = 0,
        baseLight = nil,
        sprite = nil
    }
end

function LightLODController:UpdateLODs()
    local camera = workspace.CurrentCamera
    if not camera then return end
    
    local cameraPos = camera.CFrame.Position
    local now = tick()
    
    -- Reset particle count
    particleCount = 0
    local maxParticles = isMobile and MOBILE_PARTICLE_BUDGET or PC_PARTICLE_BUDGET
    
    for lightId, data in pairs(lightLODs) do
        -- Throttle updates
        if now - data.lastUpdate < 0.1 then
            continue
        end
        data.lastUpdate = now
        
        local distance = (data.position - cameraPos).Magnitude
        local newLOD = self:CalculateLOD(distance)
        
        if newLOD ~= data.currentLOD then
            self:TransitionLOD(lightId, data, newLOD, maxParticles)
        end
    end
end

function LightLODController:CalculateLOD(distance)
    if distance <= LOD_RANGES.NEAR then
        return "NEAR"
    elseif distance <= LOD_RANGES.MID then
        return "MID"
    else
        return "FAR"
    end
end

function LightLODController:TransitionLOD(lightId, data, newLOD, maxParticles)
    local oldLOD = data.currentLOD
    data.currentLOD = newLOD
    
    -- Clean up old LOD
    if oldLOD == "NEAR" and data.baseLight then
        data.baseLight:Destroy()
        data.baseLight = nil
    elseif oldLOD == "MID" and data.sprite then
        data.sprite:Destroy()
        data.sprite = nil
        particleCount = particleCount - 1
    end
    
    -- Apply new LOD
    if newLOD == "NEAR" then
        self:CreateNearLight(data)
    elseif newLOD == "MID" and particleCount < maxParticles then
        self:CreateMidSprite(data)
        particleCount = particleCount + 1
    end
    -- FAR = no rendering
end

function LightLODController:CreateNearLight(data)
    -- Full quality PointLight
    local light = Instance.new("PointLight")
    light.Brightness = 2
    light.Range = 30
    light.Color = Color3.fromHSV(0.1, 0.4, 1)
    light.Shadows = not isMobile -- Disable shadows on mobile
    
    if data.model and data.model.PrimaryPart then
        light.Parent = data.model.PrimaryPart
    end
    
    data.baseLight = light
end

function LightLODController:CreateMidSprite(data)
    -- Twinkle sprite for mid-range
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(2, 0, 2, 0)
    billboard.AlwaysOnTop = false
    billboard.LightInfluence = 0
    
    local image = Instance.new("ImageLabel")
    image.Size = UDim2.new(1, 0, 1, 0)
    image.BackgroundTransparency = 1
    image.Image = "rbxasset://textures/particles/sparkles_main.dds"
    image.ImageColor3 = Color3.fromHSV(0.1, 0.4, 1)
    image.Parent = billboard
    
    -- Twinkle animation
    local connection
    connection = RunService.Heartbeat:Connect(function()
        if image.Parent then
            local time = tick()
            local alpha = math.sin(time * 3 + math.random() * math.pi) * 0.3 + 0.7
            image.ImageTransparency = 1 - alpha
        else
            connection:Disconnect()
        end
    end)
    
    if data.model and data.model.PrimaryPart then
        billboard.Adornee = data.model.PrimaryPart
        billboard.Parent = data.model.PrimaryPart
    end
    
    data.sprite = billboard
end

return LightLODController