local InventoryState = {}

local counts = {}

function InventoryState.SetCount(uid: string, count: number)
    counts[uid] = count
end

function InventoryState.GetCount(uid: string): number
    return counts[uid] or 0
end

return InventoryState
