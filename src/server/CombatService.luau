local CombatService = {}

function CombatService.FirePrimary(player, payload)
    -- TODO: validate fire rate and apply damage
    local weaponId = payload and payload.weaponId or "unknown"
    print("[COMBAT] FIRE", player.UserId, weaponId, "hits=0")
end

return CombatService
