local CombatService = {}

--[[
TODO: implement combat validation and damage.
Aims: enforce fire rates and apply weapon damage on hits.
Acceptance: primary fire respects rate limits and logs hits with damage.
]]

function CombatService.FirePrimary(player, payload)
    -- TODO: validate fire rate and apply damage
    local weaponId = payload and payload.weaponId or "unknown"
    print("[COMBAT] FIRE", player.UserId, weaponId, "hits=0")
end

return CombatService
