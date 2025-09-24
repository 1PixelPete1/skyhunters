--!strict
-- FogController.luau
-- Smoothly modulates atmosphere properties to reinforce storm intensity

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local sharedRoot = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local StormTypes = require(sharedRoot:WaitForChild("StormTypes"))
local StormConfig = require(sharedRoot:WaitForChild("StormConfig"))

type StormState = StormTypes.StormState
export type PerfConfig = StormTypes.PerfConfig

type AtmosphereSnapshot = {
    Density: number,
    Offset: number,
    Haze: number?,
}

local FogController = {}
FogController.__index = FogController

function FogController.new(perfConfig: PerfConfig, perfTier: StormTypes.PerfTier?)
    local self = setmetatable({}, FogController)
    self.PerfConfig = perfConfig
    self.PerfTier = perfTier or "HIGH"

    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    if not atmosphere then
        atmosphere = Instance.new("Atmosphere")
        atmosphere.Name = "StormAtmosphere"
        atmosphere.Parent = Lighting
        self.CreatedAtmosphere = true
    end

    self.Atmosphere = atmosphere
    self.Original = {
        Density = atmosphere.Density,
        Offset = atmosphere.Offset,
        Haze = atmosphere.Haze,
    } :: AtmosphereSnapshot

    self.CurrentDensity = atmosphere.Density
    self.CurrentOffset = atmosphere.Offset
    self.NextPulseAt = 0

    return self
end

local fogConfig = StormConfig.Fog

local function ease(current: number, target: number, smoothing: number, dt: number): number
    local factor = 1 - math.exp(-smoothing * dt)
    return current + (target - current) * factor
end

function FogController:Update(state: StormState, conePose, forbiddenAzimuth, lanternEnabled, dt: number?)
    if not self.Atmosphere then
        return
    end

    local delta = (dt and dt > 0) and dt or 1 / 60
    local intensity = math.clamp(state.intensity, 0, 1)

    -- Base target from intensity
    local targetDensity = self.Original.Density + intensity * fogConfig.densityScale
    local targetOffset = self.Original.Offset - intensity * fogConfig.offsetScale

    -- Occasional pulse to sell extra gust
    local now = tick()
    if intensity > 0.55 and now >= self.NextPulseAt then
        local pulseStrength = fogConfig.pulseStrength * intensity
        targetDensity += pulseStrength
        targetOffset -= pulseStrength * 0.4
        local interval = fogConfig.pulseInterval[1] + math.random() * (fogConfig.pulseInterval[2] - fogConfig.pulseInterval[1])
        self.NextPulseAt = now + interval
    end

    self.CurrentDensity = ease(self.CurrentDensity, targetDensity, fogConfig.smoothing, delta)
    self.CurrentOffset = ease(self.CurrentOffset, targetOffset, fogConfig.smoothing, delta)

    self.Atmosphere.Density = self.CurrentDensity
    self.Atmosphere.Offset = self.CurrentOffset
end

function FogController:Cleanup()
    if self.Atmosphere then
        self.Atmosphere.Density = self.Original.Density
        self.Atmosphere.Offset = self.Original.Offset
        if self.Original.Haze then
            self.Atmosphere.Haze = self.Original.Haze
        end
        if self.CreatedAtmosphere then
            self.Atmosphere:Destroy()
        end
    end
end

return FogController

