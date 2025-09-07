--!strict

-- Run-time FX (stepped), low-perf toggle, no per-frame UI mutation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local LanternShared = require(ReplicatedStorage:WaitForChild("systems"):WaitForChild("Lantern"):WaitForChild("LanternShared"))
local Events = require(ReplicatedStorage.systems.Lantern.LanternEvents)

local RunLanternClient = {}

local player = Players.LocalPlayer

local state = {
    visCharge = 1.0,
    draining = false,
    lowPerf = true,
    stepHz = LanternShared.PERF.fxStepHzDefault,
    dirty = true,
}

-- Placeholder FX objects (create lazily/no-op safe)
local fx = {
    Vignette = nil,
    ColorCorrection = nil,
    SmallPointLight = nil,
    Halo = nil,
}

local function ensureFX()
    -- Intentionally minimal: create lightweight instances on-demand
    if not fx.ColorCorrection then
        local cc = Instance.new("ColorCorrectionEffect")
        cc.Name = "LanternCC"
        cc.Parent = game:GetService("Lighting")
        fx.ColorCorrection = cc
    end
    if not fx.Vignette then
        -- A ScreenGui + ImageLabel could be created if desired; keep noop for now
        fx.Vignette = true
    end
    if not fx.Halo then
        fx.Halo = true
    end
end

local function ComputeVignetteSize(charge: number)
    -- Placeholder mapping
    return 1 - math.clamp(charge, 0, 1)
end

local function ComputeSaturation(charge: number)
    return 0.0 + (1 - charge) * -0.2
end

local function ComputeRange(charge: number)
    -- If VIS.radiusMax is configured, scale toward it.
    local maxR = LanternShared.VIS.radiusMax or 12
    return math.clamp(2 + charge * (maxR - 2), 2, maxR)
end

local function ApplyFX()
    if not state.dirty then
        return
    end
    state.dirty = false
    ensureFX()

    if fx.ColorCorrection then
        fx.ColorCorrection.Saturation = ComputeSaturation(state.visCharge)
    end
    -- Vignette/Halo would be updated here if present
    if not state.lowPerf and fx.SmallPointLight then
        fx.SmallPointLight.Range = ComputeRange(state.visCharge)
    end
end

local function StepLoop()
    local step = 1 / (state.stepHz > 0 and state.stepHz or LanternShared.PERF.fxStepHzDefault)
    task.spawn(function()
        while true do
            if state.draining then
                state.visCharge = math.max(0.05, state.visCharge - step * 0.1)
                state.dirty = true
            else
                state.visCharge = math.min(1.0, state.visCharge + step * 0.05)
                state.dirty = true
            end
            ApplyFX()
            task.wait(step)
        end
    end)
end

local function onRunTension(level)
    -- Server-provided low-rate tension signal (0..1). Map to draining flag.
    state.draining = (level or 0) > 0.5
    state.dirty = true
end

function RunLanternClient.Init()
    -- Pull player settings if stored by server; fall back to defaults.
    state.lowPerf = true
    state.stepHz = LanternShared.PERF.fxStepHzDefault

    Net:GetEvent(Events.Events.RE_OnRunTension).OnClientEvent:Connect(onRunTension)

    StepLoop()
end

return RunLanternClient
