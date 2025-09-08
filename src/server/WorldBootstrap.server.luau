-- WorldBootstrap.server.luau
-- Spawns an island model with an invisible pivot and sculpts SmoothTerrain when enabled.

local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local CS  = game:GetService("CollectionService")

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
local PondFieldService = require(SSS:WaitForChild("Server"):WaitForChild("PondFieldService"))
local OilService = require(SSS:WaitForChild("Server"):WaitForChild("OilService"))
local RimBuilder = require(SSS:WaitForChild("Server"):WaitForChild("RimBuilder"))
local LanternService = require(SSS:WaitForChild("Server"):WaitForChild("LanternService"))
local PondNetworkService = require(SSS:WaitForChild("Systems"):WaitForChild("PondNetworkService"))
-- Boundary publisher will be initialized AFTER ponds are created in PlayerAdded

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

-- One-time seed per assigned plot
local Players = game:GetService("Players")
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
        RimBuilder.build(workspace, center, radius, 24, nil)
        print(string.format("[Terrain] ponds seeded pk=%s r=%.1f", pk, radius))
        
        -- Add default pond to PondNetworkService
        local pondAdded = PondNetworkService.addPond(Vector2.new(center.X, center.Z), radius)
        if pondAdded then
            print(string.format("[WorldBootstrap] default pond added id=%s", pondAdded.id))
        end
        
        -- CRITICAL FIX: Wait for PondNetworkService to fully register the pond
        task.wait(0.2)
        
        -- Initialize boundary system AFTER pond exists
        local BoundaryPublisher = require(SSS:WaitForChild("Server"):WaitForChild("Boundary"):WaitForChild("BoundaryPublisher"))
        local BoundaryGraph = require(SSS:WaitForChild("Server"):WaitForChild("Boundary"):WaitForChild("BoundaryGraph"))
        
        -- Sync existing ponds from PondNetworkService to BoundaryGraph
        local existingSnap = PondNetworkService.getSnapshot()
        local trackedCount = 0
        for pondId, pond in pairs(existingSnap.ponds or {}) do
            local added = BoundaryGraph.addNode({ id = pondId, posXZ = pond.pos, radius = pond.radius })
            if added then
                trackedCount = trackedCount + 1
                print(string.format("[Boundary/Init] tracked pond id=%s pos=(%.1f,%.1f) r=%.1f", pondId, pond.pos.X, pond.pos.Y, pond.radius))
            end
        end
        
        -- Track any existing lakes
        for lakeId, lake in pairs(existingSnap.lakes or {}) do
            BoundaryGraph.addEdge({ id = lakeId, a = lake.a, b = lake.b, path = lake.path, width = lake.width })
            print(string.format("[Boundary/Init] tracked lake id=%s", lakeId))
        end
        
        -- Force initial boundary publish after tracking
        if trackedCount > 0 then
            task.wait(0.1)  -- Give graph time to process
            BoundaryPublisher.forcePublish()
            print(string.format("[Boundary/Init] forced publish for %d ponds", trackedCount))
        else
            warn("[Boundary/Init] no ponds tracked, boundary markers may not appear")
        end
        
        -- Restore lanterns for this plot
        LanternService.RestoreForPlot(pk, island)
    end
end)
