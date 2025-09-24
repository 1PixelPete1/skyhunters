--!strict
-- SkyIslandCycleService
-- Periodically clears and regenerates sky islands. Supports paced spawn over a window for performance.

local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local WorldConfig = require(RS:WaitForChild("Config"):WaitForChild("WorldConfig"))

local function resolveWorldgenFolder()
    local underServer = SSS:FindFirstChild("Server") and SSS.Server:FindFirstChild("Worldgen")
    if underServer then return underServer end
    local topLevel = SSS:FindFirstChild("Worldgen")
    if topLevel then return topLevel end
    return nil
end

local worldgenFolder = resolveWorldgenFolder()
if not worldgenFolder then
    warn("[SkyIslandCycle] Worldgen folder not found; cycle service limited")
end

local ScatteredSkyIslands = worldgenFolder and require(worldgenFolder:WaitForChild("ScatteredSkyIslands"))
local DiamondIslandBuilder = worldgenFolder and require(worldgenFolder:WaitForChild("DiamondIslandBuilder"))

local SkyIslandCycleService = {}

local state = {
    active = false,
    rootFolder = nil :: Folder?,
    hubPos = Vector3.new(0, 0, 0),
    current = nil :: any?,
    timerConn = nil :: RBXScriptConnection?,
    sculptConn = nil :: RBXScriptConnection?,
}

local function isPartMode()
    local cfg = WorldConfig.WORLDGEN and WorldConfig.WORLDGEN.SkyIslands
    return cfg and cfg.UsePartIslands == true or false
end

local function clearCurrent()
    print("[SkyIslandCycle] Starting comprehensive cleanup...")
    local cfg = WorldConfig.WORLDGEN and WorldConfig.WORLDGEN.SkyIslands or {}
    
    -- Stop rendering service first
    local ok, svc = pcall(function()
        return require(SSS:WaitForChild("Systems"):WaitForChild("SkyIslandRenderingService"))
    end)
    if ok and svc.stopRendering then 
        svc.stopRendering() 
        print("[SkyIslandCycle] Rendering service stopped")
    end
    
    -- Clear all model-based content in workspace
    local foldersToClean = {
        "SkyIslands",
        "SkyElements",
        "FloatingPaths",
        "FloatingBridges",
        "SkyConstellations",
        "SkyConstellationMarkers"
    }
    
    -- First check in rootFolder
    if state.rootFolder then
        for _, folderName in ipairs(foldersToClean) do
            local folder = state.rootFolder:FindFirstChild(folderName)
            if folder then
                folder:Destroy()
                print("[SkyIslandCycle] Cleared folder:", folderName, "from rootFolder")
            end
        end
    end
    
    -- Also check workspace directly
    for _, folderName in ipairs(foldersToClean) do
        local folder = workspace:FindFirstChild(folderName)
        if folder then
            folder:Destroy()
            print("[SkyIslandCycle] Cleared folder:", folderName, "from workspace")
        end
    end
    
    -- Clear terrain if we have island data
    if state.current then
        local terrain = workspace.Terrain
        
        -- Clear all elements (paths and islands)
        if state.current.elements then
            for _, element in ipairs(state.current.elements) do
                if element.type ~= "Path" and element.position then
                    -- Clear terrain for islands
                    local radius = element.terrainRadius or element.radius or 50
                    terrain:FillBall(element.position, radius * 1.5, Enum.Material.Air)
                end
            end
            print("[SkyIslandCycle] Cleared terrain for", #state.current.elements, "elements")
        elseif state.current.islands then
            -- Fallback to old islands array
            for _, island in ipairs(state.current.islands) do
                if island.position then
                    local radius = island.terrainRadius or island.radius or 50
                    terrain:FillBall(island.position, radius * 1.5, Enum.Material.Air)
                end
            end
            print("[SkyIslandCycle] Cleared terrain for", #state.current.islands, "islands")
        end
        
        -- Alternative: Use DiamondIslandBuilder's clearRegion if available
        if DiamondIslandBuilder and DiamondIslandBuilder.clearRegion then
            for _, island in ipairs(state.current.islands or {}) do
                DiamondIslandBuilder.clearRegion(island.position, island.radius, island.height, {
                    topSkin = (WorldConfig.ISLANDS and WorldConfig.ISLANDS.TopSkinThickness) or 2,
                })
            end
        end
    end
    
    -- Clear any debug visualization
    local debugFolder = workspace:FindFirstChild("SkyIslandDebug")
    if debugFolder then
        debugFolder:Destroy()
    end
    
    print("[SkyIslandCycle] Cleanup complete")
end

local function sculptTerrainQueued(islands: {any})
    local cfg = WorldConfig.WORLDGEN and WorldConfig.WORLDGEN.SkyIslands or {}
    local window = math.max(5, cfg.SpawnWindowSec or 15)
    local queue = {}
    for i = 1, #islands do queue[i] = islands[i] end
    local total = #queue
    if total == 0 then return end

    local created = 0
    local started = tick()
    if state.sculptConn then state.sculptConn:Disconnect() end
    state.sculptConn = RunService.Heartbeat:Connect(function(dt)
        if #queue == 0 then
            state.sculptConn:Disconnect()
            state.sculptConn = nil
            return
        end
        -- Budget islands across the window using elapsed time fraction
        local elapsed = tick() - started
        local targetCreated = math.floor((elapsed / window) * total)
        local toCreate = math.max(1, targetCreated - created)
        for _ = 1, toCreate do
            local island = table.remove(queue, 1)
            if not island then break end
            DiamondIslandBuilder.buildAt(island.position, island.radius, math.max(4, island.height), {
                topSkin = (WorldConfig.ISLANDS and WorldConfig.ISLANDS.TopSkinThickness) or 2,
                topMaterial = Enum.Material[(WorldConfig.ISLANDS and WorldConfig.ISLANDS.TopMaterial) or "Ground"] or Enum.Material.Ground,
                coreMaterial = Enum.Material[(WorldConfig.ISLANDS and WorldConfig.ISLANDS.CoreMaterial) or "Rock"] or Enum.Material.Rock,
            })
            created += 1
        end
    end)
end

local function regenNowInternal(reason: string?)
    print(string.format("[SkyIslandCycle] Regenerating islands reason=%s", tostring(reason or "timer")))
    clearCurrent()
    local cfg = WorldConfig.WORLDGEN and WorldConfig.WORLDGEN.SkyIslands
    local result = ScatteredSkyIslands and ScatteredSkyIslands.generate(state.rootFolder :: any, state.hubPos, cfg)
    state.current = result
    if isPartMode() then
        local ok, svc = pcall(function()
            return require(SSS:WaitForChild("Systems"):WaitForChild("SkyIslandRenderingService"))
        end)
        if ok then svc.startRendering(result.islands) end
    else
        if result and result.islands then sculptTerrainQueued(result.islands) end
    end
end

function SkyIslandCycleService.start(rootFolder: Folder, hubPos: Vector3, initialResult: any?)
    if state.active then return end
    state.active = true
    state.rootFolder = rootFolder
    state.hubPos = hubPos
    state.current = initialResult

    -- Start periodic timer
    local cfg = WorldConfig.WORLDGEN and WorldConfig.WORLDGEN.SkyIslands or {}
    local period = math.max(60, cfg.RespawnPeriodSec or 450)
    state.timerConn = RunService.Heartbeat:Connect(function()
        -- Poll a simple timer using tick()
        if not state._nextAt then
            state._nextAt = tick() + period
        elseif tick() >= state._nextAt then
            state._nextAt = tick() + period
            regenNowInternal("periodic")
        end
    end)
    print(string.format("[SkyIslandCycle] Started (period=%ds, partMode=%s)", period, tostring(isPartMode())))
end

function SkyIslandCycleService.stop()
    if state.timerConn then state.timerConn:Disconnect() end
    if state.sculptConn then state.sculptConn:Disconnect() end
    state.timerConn = nil
    state.sculptConn = nil
    state.active = false
end

function SkyIslandCycleService.regenNow(reason: string?)
    regenNowInternal(reason or "manual")
end

return SkyIslandCycleService
