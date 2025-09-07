--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = require(ReplicatedStorage.systems.Lantern.LanternShared)
local Events = require(ReplicatedStorage.systems.Lantern.LanternEvents)
local Net = require(ReplicatedStorage.Shared.Net)

local LanternHUD = {}

local state = {
    lastUiApply = 0,
    uiMinInterval = Shared.PERF.uiMinInterval,
}

local function applyUI()
    -- Minimal placeholder for vignette/indicators; rate-limited by uiMinInterval
    -- Integrate with your existing UI framework if desired.
end

local function stepped()
    local stepHz = Shared.PERF.fxStepHzDefault
    local step = 1 / (stepHz > 0 and stepHz or 10)
    task.spawn(function()
        while true do
            local now = os.clock()
            if now - state.lastUiApply >= state.uiMinInterval then
                state.lastUiApply = now
                applyUI()
            end
            task.wait(step)
        end
    end)
end

function LanternHUD.Init()
    -- Wire up minimal listeners if needed.
    Net:GetEvent(Events.Events.RE_OnLanternStatesBatch).OnClientEvent:Connect(function(_batch)
        -- Could set dirty flags to recompute indicators.
    end)
    stepped()
end

return LanternHUD

