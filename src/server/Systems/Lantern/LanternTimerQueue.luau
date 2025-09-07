--!strict

local MinHeap = require(script.Parent.MinHeap)

local LanternTimerQueue = {}

local Q = MinHeap.new()

function LanternTimerQueue.Init(services)
    LanternTimerQueue._services = services

    task.spawn(function()
        while true do
            local head = Q:peek()
            if not head then
                task.wait(0.5)
            else
                local now = os.clock()
                local dt = head.expiresAt - now
                if dt and dt > 0 then
                    task.wait(math.min(dt, 1))
                else
                    local popped = Q:pop()
                    if popped and LanternTimerQueue._services and LanternTimerQueue._services.LanternService then
                        LanternTimerQueue._services.LanternService._expireLantern(popped.key)
                    end
                end
            end
        end
    end)
end

function LanternTimerQueue.AddOrUpdate(lanternId: string, expiresAt: number)
    Q:insertOrDecreaseKey(lanternId, expiresAt)
end

return LanternTimerQueue

