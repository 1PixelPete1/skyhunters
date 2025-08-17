local FameService = {}

--[[
TODO: implement fame progression.
Aims: convert actions into fame and expose current totals.
Acceptance: selling value awards fame and queries return persisted sums.
]]

function FameService.AddFameFromValue(player, value)
    -- TODO: map sell value to fame using sigmoid
    return 0
end

function FameService.GetFame(player)
    -- TODO: return current fame from player data
    return 0
end

return FameService
