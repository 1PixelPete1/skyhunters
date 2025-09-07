local MetricsService = {}

function MetricsService.Init(services)
    MetricsService._services = services
end

function MetricsService.Emit(eventName: string, fields)
    -- placeholder for analytics
end

return MetricsService

