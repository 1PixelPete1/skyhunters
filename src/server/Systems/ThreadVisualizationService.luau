local ThreadVisualizationService = {}

function ThreadVisualizationService.Init(services)
    ThreadVisualizationService._services = services
end

function ThreadVisualizationService.BuildClientSnapshot(plotId: string, audience)
    return { threads = {} }
end

return ThreadVisualizationService

