--!strict

-- Object pools for lantern FX (halos, attachments, minion groups).
-- Stubbed for now; provide simple alloc/free interfaces.

local LanternPools = {}

local pools: { [string]: { any } } = {}

function LanternPools.Init(services)
    LanternPools._services = services
    pools.Halo = {}
end

function LanternPools.Acquire(kind: string)
    local p = pools[kind]
    if p and #p > 0 then
        local obj = p[#p]
        p[#p] = nil
        return obj
    end
    return nil
end

function LanternPools.Release(kind: string, obj: any)
    local p = pools[kind]
    if not p then
        pools[kind] = { obj }
    else
        table.insert(p, obj)
    end
end

return LanternPools

