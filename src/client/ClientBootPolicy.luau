--!strict
local ClientBootPolicy = {}

function ClientBootPolicy.timeoutSeconds()
    return 5.0
end

function ClientBootPolicy.debugLoggingEnabled()
    return false
end

return ClientBootPolicy