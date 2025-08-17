local MinionService = {}

--[[
TODO: drive decorative minions.
Aims: synchronize minion spawns, reactions, and behaviors around the
      player's base.
Acceptance: minions appear, celebrate on sales, and tick autonomously.
]]

function MinionService.SyncForPlayer(player)
    -- TODO: spawn or update minions around base
end

function MinionService.OnSellAether(player, amount)
    -- TODO: react to aether sales for celebration
end

function MinionService.Tick(dt)
    -- TODO: update minion state machines
end

return MinionService
