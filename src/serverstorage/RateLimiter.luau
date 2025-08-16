-- ServerStorage/RateLimiter.luau
-- Simple per-player, per-key windowed limiter. Good enough for remotes.

local RateLimiter = {}
local buckets = {} :: {[number]: {[string]: {t: number, n: number}}}

function RateLimiter.Allow(player, key, maxCalls, windowSec)
    local uid = player.UserId
    buckets[uid] = buckets[uid] or {}
    local b = buckets[uid][key]
    local now = os.clock()
    if not b or (now - b.t) > windowSec then
        buckets[uid][key] = { t = now, n = 1 }
        return true
    end
    if b.n < maxCalls then
        b.n += 1
        return true
    end
    return false
end

return RateLimiter
