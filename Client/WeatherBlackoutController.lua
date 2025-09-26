-- WeatherBlackoutController.lua
-- Black-out lighting modification for weather system

local WeatherBlackoutController = {}
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

-- Settings
local BLACKOUT_ENABLED = false -- Guarded toggle for M0
local TRANSITION_TIME = 3

-- Store original lighting
local originalLighting = {}
local isBlackedOut = false

function WeatherBlackoutController:Initialize()
    -- Store original values
    originalLighting = {
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        Brightness = Lighting.Brightness,
        GlobalShadows = Lighting.GlobalShadows,
        FogEnd = Lighting.FogEnd,
        FogStart = Lighting.FogStart,
        FogColor = Lighting.FogColor
    }
end

function WeatherBlackoutController:SetBlackoutEnabled(enabled)
    BLACKOUT_ENABLED = enabled
    
    if enabled and not isBlackedOut then
        self:EnableBlackout()
    elseif not enabled and isBlackedOut then
        self:DisableBlackout()
    end
end

function WeatherBlackoutController:EnableBlackout(intensity)
    if not BLACKOUT_ENABLED then return end
    
    intensity = intensity or 1 -- 0 to 1 scale
    isBlackedOut = true
    
    -- Tween to black-out state
    local blackoutSettings = {
        OutdoorAmbient = Color3.new(0, 0, 0),
        Ambient = Color3.new(0.02, 0.02, 0.03) * (1 - intensity), -- Tiny bit of ambient
        Brightness = 0,
        GlobalShadows = false, -- Disable for performance in darkness
        
        -- Atmosphere/fog for distance obscurity
        FogEnd = 500 - (300 * intensity), -- Closer fog with intensity
        FogStart = 10,
        FogColor = Color3.new(0.05, 0.05, 0.08)
    }
    
    for property, value in pairs(blackoutSettings) do
        TweenService:Create(Lighting, TweenInfo.new(TRANSITION_TIME), {
            [property] = value
        }):Play()
    end
end

function WeatherBlackoutController:DisableBlackout()
    isBlackedOut = false
    
    -- Restore original
    for property, value in pairs(originalLighting) do
        TweenService:Create(Lighting, TweenInfo.new(TRANSITION_TIME), {
            [property] = value
        }):Play()
    end
end

function WeatherBlackoutController:SetStormIntensity(intensity)
    -- Scale blackout with storm intensity
    if BLACKOUT_ENABLED and intensity > 0 then
        self:EnableBlackout(intensity)
    elseif intensity == 0 then
        self:DisableBlackout()
    end
end

return WeatherBlackoutController