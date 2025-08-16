-- ServerStorage/TxnLock.luau
-- Lightweight per-player lock to avoid double-spend. Replace with MemoryStore if you like.

local TxnLock = {}
local locks = {} :: {[number]: {[string]: boolean}}

function TxnLock.withLock(player, key, fn)
    local uid = player.UserId
    locks[uid] = locks[uid] or {}
    if locks[uid][key] then
        return { ok = false, code = "BUSY" }
    end
    locks[uid][key] = true
    local ok, res = pcall(fn)
    locks[uid][key] = nil
    if not ok then
        warn("[TxnLock] error:", res)
        return { ok = false, code = "ERROR" }
    end
    return res
end

return TxnLock
