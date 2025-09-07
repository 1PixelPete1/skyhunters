--!strict

-- Pond linking and lantern slot calculation.

local PondNetworkService = {}

function PondNetworkService.Init(services)
    PondNetworkService._services = services
end

function PondNetworkService.ComputeLanternSlots(ponds)
    local connected = ponds and ponds.connected or {}
    return 1 + #connected
end

return PondNetworkService

