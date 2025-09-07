local StreamingService = {}

function StreamingService.Init(services)
    StreamingService._services = services
end

function StreamingService.RegisterPlot(plotId: string, bounds)
    return true
end

function StreamingService.SetPlayerFocus(player: Player, region)
    return true
end

return StreamingService

