local HttpService = game:GetService("HttpService")

local StateHashService = {}

function StateHashService.Init(services)
    StateHashService._services = services
end

function StateHashService.HashBaseState(baseState): string
    local json = HttpService:JSONEncode(baseState)
    local sum = 0
    for i = 1, #json do
        sum = (sum * 131 + string.byte(json, i)) % 2^31
    end
    return tostring(sum)
end

function StateHashService.VerifyTransition(prevHash: string, nextHash: string)
    return true
end

return StateHashService

