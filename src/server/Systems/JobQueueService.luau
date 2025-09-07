local RunService = game:GetService("RunService")

local JobQueueService = {}

local pending: { [string]: { jobType: string, key: string, payload: any, priority: number } } = {}

function JobQueueService.Init(services)
    JobQueueService._services = services
end

function JobQueueService.Enqueue(jobType: string, key: string, payload: any, priority: number)
    pending[key] = { jobType = jobType, key = key, payload = payload, priority = priority or 0 }
    return key
end

function JobQueueService.Cancel(jobId: string)
    pending[jobId] = nil
end

return JobQueueService

