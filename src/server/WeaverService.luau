--!strict
-- Server-side tracker for loom nodes. This module owns the open and occupied
-- node lists and provides simple harvest validation. This is a prototype level
-- implementation and lacks persistence and security features.

local WeaverService = {}

local looms = {}

function WeaverService.OnNodesEligible(loomUid, eligible)
    local state = looms[loomUid]
    if not state then
        state = { open = {}, occupied = {} }
        looms[loomUid] = state
    end
    for _, id in ipairs(eligible) do
        table.insert(state.open, id)
    end
end

-- Activation policy: move all open nodes to occupied when called.
function WeaverService.ActivateSome(loomUid)
    local state = looms[loomUid]
    if not state then return end
    for _, id in ipairs(state.open) do
        table.insert(state.occupied, id)
    end
    state.open = {}
end

function WeaverService.TryHarvest(player, loomUid, nodeId)
    local state = looms[loomUid]
    if not state then return false, "unknown_loom" end
    for i, id in ipairs(state.occupied) do
        if id == nodeId then
            table.remove(state.occupied, i)
            return true, nil
        end
    end
    return false, "node_not_occupied"
end

function WeaverService.GetNodeState(loomUid)
    local state = looms[loomUid]
    if not state then
        return {open = {}, occupied = {}}
    end
    return {open = state.open, occupied = state.occupied}
end

return WeaverService
