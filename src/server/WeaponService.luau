local WeaponService = {}

--[[
TODO: handle weapon equipment and retrieval.
Aims: equip weapons per player and expose current loadout.
Acceptance: equipping returns success and queries reflect state.
]]

function WeaponService.EquipWeapon(player, weaponId)
    -- TODO: equip weapon for player
    return false, "NOT_IMPLEMENTED"
end

function WeaponService.GetEquippedWeapon(player)
    -- TODO: return equipped weapon id
    return nil
end

return WeaponService
