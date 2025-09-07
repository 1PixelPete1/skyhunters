local SpatialIndexService = {}

function SpatialIndexService.Init(services)
    SpatialIndexService._services = services
end

function SpatialIndexService.BuildForPlot(plotId: string, placements)
    return true
end

function SpatialIndexService.QueryNavigators(plotId: string, region)
    return {}
end

function SpatialIndexService.QueryEnhancers(plotId: string, region)
    return {}
end

function SpatialIndexService.QueryCollectors(plotId: string, region)
    return {}
end

return SpatialIndexService

