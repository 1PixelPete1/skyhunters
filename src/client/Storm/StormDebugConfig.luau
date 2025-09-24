--!strict
-- StormDebugConfig.luau
-- Runtime-configurable debug parameters for storm effects

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local StormDebugConfig = {}

-- Create debug attributes on the player for real-time tweaking
local function initializeDebugAttributes()
    local player = Players.LocalPlayer
    if not player then return end
    
    -- SurroundingAirEffect debug controls
    player:SetAttribute("Storm_RingRadius", 40) -- Reduced from 120
    player:SetAttribute("Storm_RingHeight", 8)  -- Reduced from 18
    player:SetAttribute("Storm_RingSegments", 14)
    player:SetAttribute("Storm_RingSpriteWidth", 12)  -- Reduced from 36
    player:SetAttribute("Storm_RingSpriteHeight", 16) -- Reduced from 48
    player:SetAttribute("Storm_RingAlphaMin", 0.1)
    player:SetAttribute("Storm_RingAlphaMax", 0.4)   -- Reduced from 0.65
    player:SetAttribute("Storm_RingScrollSpeed", 8)
    player:SetAttribute("Storm_RingWindScale", 0.6)
    player:SetAttribute("Storm_RingOrbitSpeed", 0.5) -- How fast sprites orbit around camera
    player:SetAttribute("Storm_RingEnabled", true)
    
    -- Vignette corner effects
    player:SetAttribute("Storm_VignetteMode", "corners") -- "corners" or "full"
    player:SetAttribute("Storm_VignetteSize", 0.3)      -- Size of corner vignettes
    player:SetAttribute("Storm_VignetteAlpha", 0.4)
    player:SetAttribute("Storm_VignetteJitterAmount", 5) -- Pixels of jitter
    player:SetAttribute("Storm_VignetteJitterSpeed", 2)  -- Jitter frequency
    
    -- Enhanced gust controls
    player:SetAttribute("Storm_GustStyle", "volumetric") -- "smudge", "volumetric", "sheets"
    player:SetAttribute("Storm_GustScale", 1.5)
    player:SetAttribute("Storm_GustVariation", true)
    player:SetAttribute("Storm_GustTurbulence", 0.7)
    player:SetAttribute("Storm_GustLayerCount", 4)
    
    -- Overall storm intensity
    player:SetAttribute("Storm_GlobalIntensity", 0.8)
    player:SetAttribute("Storm_DebugView", false)
    
    print("[StormDebug] Debug attributes initialized - adjust in Properties window")
end

-- Get current debug values
function StormDebugConfig:GetRingConfig()
    local player = Players.LocalPlayer
    if not player then return nil end
    
    return {
        radius = player:GetAttribute("Storm_RingRadius") or 40,
        height = player:GetAttribute("Storm_RingHeight") or 8,
        segments = player:GetAttribute("Storm_RingSegments") or 14,
        spriteSize = Vector2.new(
            player:GetAttribute("Storm_RingSpriteWidth") or 12,
            player:GetAttribute("Storm_RingSpriteHeight") or 16
        ),
        alphaMin = player:GetAttribute("Storm_RingAlphaMin") or 0.1,
        alphaMax = player:GetAttribute("Storm_RingAlphaMax") or 0.4,
        scrollSpeed = player:GetAttribute("Storm_RingScrollSpeed") or 8,
        windScale = player:GetAttribute("Storm_RingWindScale") or 0.6,
        orbitSpeed = player:GetAttribute("Storm_RingOrbitSpeed") or 0.5,
        enabled = player:GetAttribute("Storm_RingEnabled") ~= false,
    }
end

function StormDebugConfig:GetVignetteConfig()
    local player = Players.LocalPlayer
    if not player then return nil end
    
    return {
        mode = player:GetAttribute("Storm_VignetteMode") or "corners",
        size = player:GetAttribute("Storm_VignetteSize") or 0.3,
        alpha = player:GetAttribute("Storm_VignetteAlpha") or 0.4,
        jitterAmount = player:GetAttribute("Storm_VignetteJitterAmount") or 5,
        jitterSpeed = player:GetAttribute("Storm_VignetteJitterSpeed") or 2,
    }
end

function StormDebugConfig:GetGustConfig()
    local player = Players.LocalPlayer
    if not player then return nil end
    
    return {
        style = player:GetAttribute("Storm_GustStyle") or "volumetric",
        scale = player:GetAttribute("Storm_GustScale") or 1.5,
        variation = player:GetAttribute("Storm_GustVariation") ~= false,
        turbulence = player:GetAttribute("Storm_GustTurbulence") or 0.7,
        layerCount = player:GetAttribute("Storm_GustLayerCount") or 4,
    }
end

function StormDebugConfig:GetGlobalIntensity()
    local player = Players.LocalPlayer
    if not player then return 0.8 end
    return player:GetAttribute("Storm_GlobalIntensity") or 0.8
end

function StormDebugConfig:IsDebugViewEnabled()
    local player = Players.LocalPlayer
    if not player then return false end
    return player:GetAttribute("Storm_DebugView") == true
end

-- Auto-initialize when module is required
if RunService:IsClient() then
    task.spawn(function()
        local player = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
        task.wait(0.1) -- Brief delay to ensure player is ready
        initializeDebugAttributes()
    end)
end

return StormDebugConfig
