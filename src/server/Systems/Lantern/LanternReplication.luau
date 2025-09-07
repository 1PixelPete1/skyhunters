--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = require(ReplicatedStorage.systems.Lantern.LanternShared)

local LanternReplication = {}

local accum = {
    t0 = os.clock(),
    interval = Shared.NET.batchInterval or 3,
}

function LanternReplication.Init(services)
    LanternReplication._services = services
    LanternReplication._lanternService = services.LanternService

    task.spawn(function()
        while true do
            local now = os.clock()
            if now - accum.t0 >= accum.interval then
                accum.t0 = now
                if LanternReplication._lanternService then
                    LanternReplication._lanternService.FlushReplication()
                end
            end
            task.wait(0.5)
        end
    end)
end

return LanternReplication

