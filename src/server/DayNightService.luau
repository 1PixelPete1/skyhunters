local DayNightService = {}

--[[
TODO: manage global day/night cycle.
Aims: control cycle length and broadcast time changes.
Acceptance: cycle progresses smoothly and clients can query normalized
            time of day.
]]

function DayNightService.SetCycleLength(seconds)
    -- TODO: set day/night cycle length
end

function DayNightService.GetTimeOfDay()
    -- TODO: return normalized time of day
    return 0
end

function DayNightService.Tick(dt)
    -- TODO: advance time and broadcast changes
end

return DayNightService
