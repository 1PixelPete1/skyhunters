local MemoryPoolService = {}

function MemoryPoolService.Init(services)
    MemoryPoolService._services = services
end

function MemoryPoolService.Acquire(kind: string)
    return Instance.new("Folder")
end

function MemoryPoolService.Release(kind: string, obj: Instance)
    obj:Destroy()
end

return MemoryPoolService

