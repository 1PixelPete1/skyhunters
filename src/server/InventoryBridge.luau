local InventoryBridge = {}

function InventoryBridge.GetDerivedAetherModifiers(player)
    return {
        target_add = 0,
        purity_add = 0,
        rate_mult = 1,
    }
end

function InventoryBridge.TryConsumeBurst(player, opts)
    return false, 0
end

function InventoryBridge.OnSnapshotComposed(player, snapshot)
end

return InventoryBridge

