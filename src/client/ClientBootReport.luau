--!strict
-- ClientBootReport: tracks timeouts/missing modules; prints one summary line.

local ClientBootReport = {}
local missing: { string } = {}
local timeouts = 0
local degraded = false

function ClientBootReport.noteMissing(path: string)
    table.insert(missing, path)
    degraded = true
end

function ClientBootReport.noteTimeout()
    timeouts += 1
    degraded = true
end

function ClientBootReport.degraded()
    return degraded
end

function ClientBootReport.summary()
    print(("CLIENT_BOOT: degraded=%s timeouts=%d missing=[%s]")
        :format(tostring(degraded), timeouts, table.concat(missing, ", ")))
end

return ClientBootReport