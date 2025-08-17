local GrowthService = {}

function GrowthService.RegisterProducer(player, uid, seed)
    -- TODO: track producer growth state
end

function GrowthService.UnregisterProducer(player, uid)
    -- TODO: remove tracked producer
end

function GrowthService.Tick(dt)
    -- TODO: advance growth values and branch generation
end

function GrowthService.GetSnapshot(player)
    -- TODO: return growth and branch snapshot for player
    return {}
end

return GrowthService
