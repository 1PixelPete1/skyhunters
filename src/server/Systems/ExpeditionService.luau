local ExpeditionService = {}

function ExpeditionService.Init(services)
    ExpeditionService._services = services
end

function ExpeditionService.StartExpedition(playerOrParty, req)
    -- Placeholder ticketing
    return { ok = false, err = "EXPEDITION_WIP" }
end

function ExpeditionService.EndExpedition(expeditionId: string, outcome: any)
    return true
end

return ExpeditionService
