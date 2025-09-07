local ProfilerService = {}

function ProfilerService.Init(services)
    ProfilerService._services = services
end

function ProfilerService.BeginSample(name: string) end
function ProfilerService.EndSample(name: string) end

return ProfilerService

