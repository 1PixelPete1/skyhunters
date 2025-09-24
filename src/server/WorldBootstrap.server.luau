-- WorldBootstrap.server.luau
-- Spawns an island model with an invisible pivot and sculpts SmoothTerrain when enabled.

local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local CS  = game:GetService("CollectionService")
local Players = game:GetService("Players")

-- Config
local ConfigFolder = RS:WaitForChild("Config")
local WorldConfig = require(ConfigFolder:WaitForChild("WorldConfig"))

-- Robust resolver for the builder, trying both likely homes.
local function resolveWorldgenFolder()
    -- Most repos put it here:
    local underServer = script.Parent:FindFirstChild("Worldgen")
    if underServer then return underServer end

    -- Some Rojo maps as a sibling of 'Server' directly under SSS:
    local topLevel = SSS:FindFirstChild("Worldgen")
    if topLevel then return topLevel end

    return nil
end

local function requireTerrainIslandBuilder()
    local folder = resolveWorldgenFolder()
    if not folder then
        error("Worldgen folder not found. Tried: "
            .. tostring(script.Parent:GetFullName() .. ".Worldgen")
            .. " and " .. tostring(SSS:GetFullName() .. ".Worldgen"))
    end

    -- Handle possible name quirks (e.g., TerrainIslandBuilder.module)
    local mod = folder:FindFirstChild("TerrainIslandBuilder")
        or folder:FindFirstChild("TerrainIslandBuilder.module")

    if not (mod and mod:IsA("ModuleScript")) then
        local names = {}
        for _, child in ipairs(folder:GetChildren()) do
            table.insert(names, child.Name .. ":" .. child.ClassName)
        end
        error(("TerrainIslandBuilder ModuleScript not found under %s. Children: [%s]")
            :format(folder:GetFullName(), table.concat(names, ", ")))
    end

    return require(mod)
end

local TerrainIslandBuilder = requireTerrainIslandBuilder()

local SafeRequire = require(Shared:WaitForChild("SafeRequire"))
local function load(inst: Instance?)
    local r = SafeRequire.load(inst)
    if r.ok then return r.mod end
    warn("[WorldBootstrap] require failed for", r.path or "[nil]", r.reason or "unknown")
    return nil
end

local PondFieldService = load(SSS:WaitForChild("Server"):WaitForChild("PondFieldService"))
local OilService = load(SSS:WaitForChild("Server"):WaitForChild("OilService"))
local RimBuilder = load(SSS:WaitForChild("Server"):WaitForChild("RimBuilder"))
-- Optional UnifiedRimSystem (rim creation is centralized in PondNetworkService)
local UnifiedRimSystem = nil
local hasUnifiedRimSystem = pcall(function()
    UnifiedRimSystem = require(SSS:WaitForChild("Server"):WaitForChild("UnifiedRimSystem"))
end)
local LanternService = load(SSS:WaitForChild("Server"):WaitForChild("LanternService"))
local OilReservoirService = load(SSS:WaitForChild("Server"):WaitForChild("OilReservoirService"))
local PondNetworkService = load(SSS:WaitForChild("Systems"):WaitForChild("PondNetworkService")) -- FIXED: Missing require
local AsyncPondLoader = load(SSS:WaitForChild("Systems"):WaitForChild("AsyncPondLoader")) -- NEW: Async loading
-- Initialize boundary system and async pond loading
local BoundaryPublisher = require(SSS:WaitForChild("Server"):WaitForChild("Boundary"):WaitForChild("BoundaryPublisher"))
print("[WorldBootstrap] boundary system and async pond loader initialized")

-- Ensure root container
local root = workspace:FindFirstChild("Islands") or Instance.new("Folder")
root.Name = "Islands"
root.Parent = workspace

local island = root:FindFirstChild("Island_01")
if not island then
    island = Instance.new("Model")
    island.Name = "Island_01"
    island.Parent = root
end

-- Ensure invisible pivot to carry CFrame + attributes
local pivot = island:FindFirstChild("Pivot")
if not pivot then
    pivot = Instance.new("Part")
    pivot.Name = "Pivot"
    pivot.Transparency = 1
    pivot.Anchored = true
    pivot.CanCollide = false
    pivot.Size = Vector3.new(1, 1, 1)
    pivot.Position = Vector3.new(0, 0, 0)
    pivot.Parent = island
end

island.PrimaryPart = pivot
if island:GetAttribute("PresetKey") == nil then
    island:SetAttribute("PresetKey", "plane_64m")
end
CS:AddTag(island, "Island")

-- Build the island geometry
if WorldConfig.ISLANDS.UseTerrain then
    TerrainIslandBuilder.buildIslandAt(island.PrimaryPart.CFrame)
else
    -- Fallback flat Part (old behavior)
    if not island:FindFirstChild("Ground") then
        local ground = Instance.new("Part")
        ground.Name = "Ground"
        ground.Size = Vector3.new(WorldConfig.ISLANDS.SizeStuds, 2, WorldConfig.ISLANDS.SizeStuds)
        ground.Anchored = true
        ground.Position = island.PrimaryPart.Position
        ground.Material = Enum.Material.Rock
        ground.Parent = island
    end
end
-- NEW: Use the improved SkyIslandGenerator with proper collision prevention
local SkyIslandGenerator = nil
local GenerationQueue = nil

-- Try to load new generation system with better error reporting
local hasNewGenerator, loadError = pcall(function()
    local worldgenFolder = resolveWorldgenFolder()
    if not worldgenFolder then
        error("Worldgen folder not found")
    end
    
    local skyGenModule = worldgenFolder:FindFirstChild("SkyIslandGenerator")
    if not skyGenModule then
        error("SkyIslandGenerator module not found in Worldgen folder")
    end
    
    local systemsFolder = SSS:FindFirstChild("Systems")
    if not systemsFolder then
        error("Systems folder not found under ServerScriptService")
    end
    
    local queueModule = systemsFolder:FindFirstChild("GenerationQueue")
    if not queueModule then
        error("GenerationQueue module not found in Systems folder")
    end
    
    SkyIslandGenerator = require(skyGenModule)
    GenerationQueue = require(queueModule)
end)

if not hasNewGenerator then
    warn("[WorldBootstrap] Failed to load new generation system:", loadError)
end

if hasNewGenerator and SkyIslandGenerator and GenerationQueue then
    print("[WorldBootstrap] Using NEW SkyIslandGenerator with collision prevention")
    
    -- Create generation queue
    local genQueue = GenerationQueue.new({
        maxOperationsPerFrame = 3,
        maxTimePerFrame = 0.006,
        priorityLevels = 3
    })
    
    -- Create sky island generator
    local skyGen = SkyIslandGenerator.new(
        WorldConfig,
        TerrainIslandBuilder,
        genQueue
    )
    -- Register with runtime for DevUI regeneration
    local SkyIslandRuntime = require(SSS:WaitForChild("Systems"):WaitForChild("SkyIslandRuntime"))
    SkyIslandRuntime.register(skyGen)
    
    -- Start generation
    skyGen:Generate()
    
    -- Optional: Set up debug commands
    local Players = game:GetService("Players")
    Players.PlayerAdded:Connect(function(player)
        if player.UserId == game.CreatorId then
            player.Chatted:Connect(function(msg)
                if msg:lower() == "/debugislands" then
                    skyGen:DebugVisualize()
                elseif msg:lower() == "/clearislands" then
                    skyGen:Cleanup()
                elseif msg:lower() == "/regenerate" then
                    skyGen:Cleanup()
                    wait(1)
                    skyGen:Generate()
                end
            end)
        end
    end)
else
    -- Fallback to old system
    print("[WorldBootstrap] Using old ScatteredSkyIslands (may have overlap issues)")
    local ScatteredSkyIslands = require(resolveWorldgenFolder():WaitForChild("ScatteredSkyIslands"))
    local hubCenter = WorldConfig.HUB.Center :: Vector3
    local hubPos = Vector3.new(hubCenter.X, island.PrimaryPart.Position.Y, hubCenter.Z)
    local skyConfig = WorldConfig.WORLDGEN and WorldConfig.WORLDGEN.SkyIslands
    local skyResult = ScatteredSkyIslands.generate(root, hubPos, skyConfig)
    
    -- Set up dynamic rendering only if using Part-based islands
    if skyConfig == nil or skyConfig.UsePartIslands == true then
        local SkyIslandRenderingService = require(SSS:WaitForChild("Systems"):WaitForChild("SkyIslandRenderingService"))
        SkyIslandRenderingService.startRendering(skyResult.islands)
        print("[WorldBootstrap] Sky islands dynamic rendering enabled (Part-based)")
    else
        print("[WorldBootstrap] Sky islands sculpted as terrain; Part-based rendering disabled")
    end
    
    -- Start periodic regeneration/pacing service
    local SkyIslandCycleService = require(SSS:WaitForChild("Systems"):WaitForChild("SkyIslandCycleService"))
    SkyIslandCycleService.start(root, hubPos, skyResult)
end

-- Initialize boundary system BEFORE any pond creation
-- This ensures the publisher is listening for graph changes

-- One-time seed per assigned plot
Players.PlayerAdded:Connect(function(player)
    -- Assign default plot via PlotService; then seed pond/oil/rim and restore lanterns
    local PlotService = require(SSS:WaitForChild("Systems"):WaitForChild("PlotService"))
    local assignment = PlotService.ClaimPlot(player)
    if assignment and assignment.plotId then
        local pk = assignment.plotId
        local pond = WorldConfig.ISLANDS.Pond
        local center = island.PrimaryPart.Position + (pond.Offset or Vector3.new())
        local radius = pond.Radius or 10
        PondFieldService.ensureDefault(pk, center, radius)
        OilService.initForPlot(pk, center, radius)
        -- Rim creation is handled inside PondNetworkService.addPond()
        print(string.format("[Terrain] ponds seeded pk=%s r=%.1f", pk, radius))
        
        -- Add default pond to PondNetworkService
        -- This will automatically register with BoundaryGraph and trigger boundary publishing
        -- Pass skipValidation=true for system-created default pond
        local pondAdded = PondNetworkService.addPond(Vector2.new(center.X, center.Z), radius, nil, true)
        if pondAdded then
            print(string.format("[WorldBootstrap] default pond added id=%s", pondAdded.id))
        else
            warn("[WorldBootstrap] failed to add default pond")
        end
        
        -- Restore lanterns and oil reservoirs for this plot
        LanternService.RestoreForPlot(pk, island)
        OilReservoirService.RestoreForPlot(pk, island) -- NEW: restore oil reservoirs
        
        -- Dungeon spawning is handled by SkyIslandGenerator at constellation POIs.
    end
end)

