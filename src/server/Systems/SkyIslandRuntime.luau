-- SkyIslandRuntime.luau
-- Small façade to manage the active SkyIslandGenerator for dev UI regeneration

local SkyIslandRuntime = {}

local state = {
    gen = nil :: any?,
}

function SkyIslandRuntime.register(generator)
    state.gen = generator
end

local function reseed()
    -- Re-seed Lua RNG for next generation; dev-only
    local t = tick()
    local n = math.floor((t % 1) * 1e9) + os.time()
    math.randomseed(n)
    return n
end

function SkyIslandRuntime.regenerate(opts: { newSeed: boolean }?)
    if not state.gen then
        warn("[SkyIslandRuntime] No generator registered")
        return false
    end
    if opts and opts.newSeed then
        local seed = reseed()
        print(string.format("[SkyIslandRuntime] New seed=%d", seed))
        if state.gen.setSeed then
            state.gen:setSeed(seed)
        end
    end
    if state.gen.Cleanup then state.gen:Cleanup() end
    if state.gen.Generate then state.gen:Generate() end
    return true
end

return SkyIslandRuntime

