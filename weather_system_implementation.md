# Technical Implementation Guide - Weather System

## Light LOD System Implementation

### Core Architecture
The Light LOD system requires careful distance management to maintain performance while preserving visual quality.

```lua
-- LightLODService.lua (Server)
local LightLODService = {}
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Configuration
local LOD_DISTANCES = {
    REAL_LIGHT_MAX = 70,
    SPRITE_MAX = 150,
    HIDE_BEYOND = 200
}

local lightInstances = {} -- {light_id = {instance, position, brightness}}
local playerDistances = {} -- {player_id = {light_id = distance}}

-- Update cycle (every 0.5 seconds to reduce overhead)
local function updateLightLOD()
    for playerId, distances in pairs(playerDistances) do
        local player = game.Players:GetPlayerByUserId(playerId)
        if player and player.Character then
            local playerPos = player.Character.HumanoidRootPart.Position
            
            for lightId, lightData in pairs(lightInstances) do
                local distance = (playerPos - lightData.position).Magnitude
                playerDistances[playerId][lightId] = distance
                
                -- Send LOD update to client
                if distance <= LOD_DISTANCES.REAL_LIGHT_MAX then
                    -- Real light
                    ReplicatedStorage.LightLOD:FireClient(player, lightId, "real", lightData.brightness)
                elseif distance <= LOD_DISTANCES.SPRITE_MAX then
                    -- Sprite representation
                    ReplicatedStorage.LightLOD:FireClient(player, lightId, "sprite", lightData.brightness)
                else
                    -- Hidden
                    ReplicatedStorage.LightLOD:FireClient(player, lightId, "hidden", 0)
                end
            end
        end
    end
end

-- Start LOD system
RunService.Heartbeat:Connect(function()
    if tick() % 0.5 < 0.1 then -- Approximate 0.5s interval
        updateLightLOD()
    end
end)

return LightLODService
```

### Client Light Management
```lua
-- LightingController.lua (Client)
local LightingController = {}
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local activeLights = {} -- {light_id = {instance, currentState}}
local spritePool = {} -- Reusable sprite objects

-- Handle LOD updates from server
ReplicatedStorage.LightLOD.OnClientEvent:Connect(function(lightId, lodState, brightness)
    if lodState == "real" then
        showRealLight(lightId, brightness)
    elseif lodState == "sprite" then
        showSpriteLight(lightId, brightness)
    else
        hideLight(lightId)
    end
end)

local function showRealLight(lightId, brightness)
    -- Create or restore real PointLight
    if not activeLights[lightId] then
        local light = Instance.new("PointLight")
        light.Brightness = brightness
        light.Range = 20
        light.Color = Color3.new(1, 0.8, 0.6) -- Warm lantern color
        activeLights[lightId] = {instance = light, currentState = "real"}
    end
    
    -- Attach to lantern model
    local lanternModel = workspace.Lanterns:FindFirstChild("Lantern_" .. lightId)
    if lanternModel then
        activeLights[lightId].instance.Parent = lanternModel.Light
    end
end

local function showSpriteLight(lightId, brightness)
    -- Use sprite from pool or create new
    local sprite = table.remove(spritePool) or createLightSprite()
    
    -- Position sprite at lantern location
    local lanternModel = workspace.Lanterns:FindFirstChild("Lantern_" .. lightId)
    if lanternModel then
        sprite.Position = lanternModel.Position + Vector3.new(0, 5, 0)
        sprite.ImageTransparency = math.max(0.3, 1 - brightness)
        sprite.Parent = workspace.LightSprites
    end
    
    activeLights[lightId] = {instance = sprite, currentState = "sprite"}
end

-- Mobile optimization: Limit concurrent real lights
local MAX_REAL_LIGHTS_MOBILE = 8
local function enforceRealLightLimit()
    if game:GetService("UserInputService").TouchEnabled then
        local realLightCount = 0
        for _, data in pairs(activeLights) do
            if data.currentState == "real" then
                realLightCount = realLightCount + 1
            end
        end
        
        if realLightCount > MAX_REAL_LIGHTS_MOBILE then
            -- Convert furthest real lights to sprites
            -- Implementation here...
        end
    end
end

return LightingController
```

## Blackout Lighting Implementation

### Weather State Manager
```lua
-- WeatherController.lua (Server)
local WeatherController = {}
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

-- Default lighting values for fallback
local DEFAULT_LIGHTING = {
    OutdoorAmbient = Color3.new(0.5, 0.5, 0.5),
    Brightness = 2,
    Ambient = Color3.new(0.5, 0.5, 0.5)
}

local BLACKOUT_LIGHTING = {
    OutdoorAmbient = Color3.new(0, 0, 0),
    Brightness = 0,
    Ambient = Color3.new(0.1, 0.1, 0.1) -- Slight ambient for UI visibility
}

local currentWeatherState = "normal"
local weatherTransitionTime = 3 -- seconds

function WeatherController.setBlackoutMode(enabled, intensity)
    intensity = intensity or 1
    
    local targetSettings = {}
    if enabled then
        targetSettings = {
            OutdoorAmbient = Color3.new(0, 0, 0),
            Brightness = math.max(0, 0.2 - (intensity * 0.2)), -- Slight brightness at low intensity
            Ambient = Color3.new(0.1 * (1 - intensity), 0.1 * (1 - intensity), 0.1 * (1 - intensity))
        }
        currentWeatherState = "blackout"
    else
        targetSettings = DEFAULT_LIGHTING
        currentWeatherState = "normal"
    end
    
    -- Smooth transition
    local tweenInfo = TweenInfo.new(weatherTransitionTime, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    
    for property, value in pairs(targetSettings) do
        local tween = TweenService:Create(Lighting, tweenInfo, {[property] = value})
        tween:Play()
    end
    
    -- Update atmosphere based on intensity
    if Lighting:FindFirstChild("Atmosphere") then
        local atmosphereTween = TweenService:Create(
            Lighting.Atmosphere, 
            tweenInfo, 
            {
                Density = 0.3 + (intensity * 0.4), -- More dense in intense blackout
                Haze = 0.2 + (intensity * 0.3)
            }
        )
        atmosphereTween:Play()
    end
end

-- Storm integration
function WeatherController.updateStormIntensity(stormLevel)
    -- stormLevel: 0-1, where 1 is full storm
    WeatherController.setBlackoutMode(stormLevel > 0.1, stormLevel)
    
    -- Update particle systems based on storm level
    local stormParticles = workspace:FindFirstChild("StormParticles")
    if stormParticles then
        for _, emitter in pairs(stormParticles:GetChildren()) do
            if emitter:IsA("ParticleEmitter") then
                emitter.Rate = emitter:GetAttribute("BaseRate") * stormLevel
            end
        end
    end
end

return WeatherController
```

## Performance Monitoring

### Mobile-Specific Optimizations
```lua
-- PerformanceMonitor.lua
local PerformanceMonitor = {}
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local targetFPS = isMobile and 45 or 60
local currentFPS = 60

-- FPS tracking
local frameCount = 0
local lastFPSCheck = tick()

RunService.RenderStepped:Connect(function()
    frameCount = frameCount + 1
    local now = tick()
    
    if now - lastFPSCheck >= 1 then
        currentFPS = frameCount / (now - lastFPSCheck)
        frameCount = 0
        lastFPSCheck = now
        
        -- Auto-adjust light quality if performance drops
        if currentFPS < targetFPS - 5 then
            PerformanceMonitor.reduceLightQuality()
        elseif currentFPS > targetFPS + 5 then
            PerformanceMonitor.increaseLightQuality()
        end
    end
end)

-- Dynamic quality adjustment
local lightQualityLevel = isMobile and 2 or 3 -- 1=lowest, 3=highest

function PerformanceMonitor.reduceLightQuality()
    if lightQualityLevel > 1 then
        lightQualityLevel = lightQualityLevel - 1
        applyLightQuality(lightQualityLevel)
        print("Reduced light quality to level", lightQualityLevel)
    end
end

function PerformanceMonitor.increaseLightQuality()
    local maxQuality = isMobile and 2 or 3
    if lightQualityLevel < maxQuality then
        lightQualityLevel = lightQualityLevel + 1
        applyLightQuality(lightQualityLevel)
        print("Increased light quality to level", lightQualityLevel)
    end
end

local function applyLightQuality(level)
    -- Adjust LOD distances based on quality level
    local LightLOD = require(game.ReplicatedStorage.Controllers.LightingController)
    
    if level == 1 then -- Low quality
        LightLOD.setLODDistances(40, 80, 120)
    elseif level == 2 then -- Medium quality  
        LightLOD.setLODDistances(60, 120, 180)
    else -- High quality
        LightLOD.setLODDistances(70, 150, 200)
    end
end

return PerformanceMonitor
```

## Integration Testing Framework

### Automated Testing for Weather System
```lua
-- WeatherSystemTests.lua
local WeatherSystemTests = {}
local WeatherController = require(script.Parent.WeatherController)

-- Test blackout transition
function WeatherSystemTests.testBlackoutTransition()
    print("Testing blackout transition...")
    
    local startTime = tick()
    WeatherController.setBlackoutMode(true, 1.0)
    
    -- Wait for transition
    wait(4)
    
    -- Verify lighting values
    local lighting = game:GetService("Lighting")
    assert(lighting.OutdoorAmbient.R < 0.1, "OutdoorAmbient not properly set to black")
    assert(lighting.Brightness < 0.1, "Brightness not properly reduced")
    
    print("✓ Blackout transition test passed")
end

-- Test performance under load
function WeatherSystemTests.testPerformanceUnderLoad()
    print("Testing performance with many lights...")
    
    -- Create 50 test lights
    local testLights = {}
    for i = 1, 50 do
        local part = Instance.new("Part")
        part.Position = Vector3.new(i * 10, 5, 0)
        local light = Instance.new("PointLight")
        light.Parent = part
        part.Parent = workspace
        table.insert(testLights, part)
    end
    
    -- Monitor FPS for 10 seconds
    local startFPS = getCurrentFPS()
    wait(10)
    local endFPS = getCurrentFPS()
    
    -- Cleanup
    for _, light in pairs(testLights) do
        light:Destroy()
    end
    
    -- Verify performance didn't degrade significantly
    assert(endFPS > startFPS * 0.8, "FPS dropped too much under light load")
    
    print("✓ Performance test passed")
end

return WeatherSystemTests
```

This technical implementation guide provides concrete code examples for the weather system component of your integration plan. The modular approach allows for easier testing and iteration during M0 development.
