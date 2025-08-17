local CurseService = {}

function CurseService.GrantCurse(player, curseId, stacks, ttl)
    -- TODO: add curse to player data
end

function CurseService.RemoveCurse(player, curseId, stacks)
    -- TODO: remove or decrement curse
end

function CurseService.GetCurses(player)
    -- TODO: return active curses for player
    return {}
end

function CurseService.ApplyToStats(base, curses)
    -- TODO: apply curse modifiers to stats
    return base
end

return CurseService
