--!strict
-- Server-only Net fallback stub used when Shared.Net is invalid or throws.

local warnedOnce: { [string]: boolean } = {}

local function warnOnce(key: string, msg: string)
    if warnedOnce[key] then return end
    warnedOnce[key] = true
    warn(msg)
end

local Stub = {}

Stub.CONTRACT_VERSION = -1
Stub.Functions = setmetatable({}, { __index = function(_, k)
    return k
end })
Stub.Events = setmetatable({}, { __index = function(_, k)
    return k
end })

local function makeEventPlaceholder(name: string)
    local o = {}
    function o:FireClient(_player: Player, ...: any)
        warnOnce(
            "evt:" .. name,
            ("[NetStub] Event '%s' used; no-op (server degraded)"):format(name)
        )
        return nil
    end
    function o:FireAllClients(...: any)
        warnOnce(
            "evt_all:" .. name,
            ("[NetStub] Event '%s' broadcast; no-op (server degraded)"):format(name)
        )
        return nil
    end
    return o
end

local function makeFunctionPlaceholder(name: string)
    local o: any = { OnServerInvoke = nil }
    -- Assigning handlers on stub is allowed; invocations are logged by caller side normally.
    setmetatable(o, {
        __index = function(_, k)
            if k == "InvokeClient" then
                return function(_player: Player, ...: any)
                    warnOnce(
                        "fn_invoke:" .. name,
                        ("[NetStub] Function '%s' InvokeClient used; no-op (server degraded)"):format(name)
                    )
                    return nil
                end
            end
            return nil
        end,
    })
    return o
end

function Stub:GetEvent(name: string)
    return makeEventPlaceholder(name)
end

function Stub:GetFunction(name: string)
    return makeFunctionPlaceholder(name)
end

return Stub

