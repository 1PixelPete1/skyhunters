local EventService = {}

--[[
TODO: orchestrate timed world events.
Aims: schedule, start, and end events with arbitrary payloads.
Acceptance: events can be queued and queried for active status.
]]

function EventService.Schedule(id, at, data)
    -- TODO: schedule an event
end

function EventService.StartNow(id, data)
    -- TODO: start event immediately
end

function EventService.End(id)
    -- TODO: end active event
end

function EventService.GetActive()
    -- TODO: return active events
    return {}
end

return EventService
