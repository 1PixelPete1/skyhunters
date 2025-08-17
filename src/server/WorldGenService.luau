local WorldGenService = {}

--[[
TODO: procedural island generation.
Aims: spawn/despawn islands from prefabs and expose active listings.
Acceptance: generated islands track by id and can be queried or removed.
]]

function WorldGenService.SpawnIsland(spec)
    -- TODO: assemble island from prefabs
    return 0
end

function WorldGenService.DespawnIsland(islandId)
    -- TODO: remove spawned island
end

function WorldGenService.GetIslands()
    -- TODO: return current islands
    return {}
end

return WorldGenService
