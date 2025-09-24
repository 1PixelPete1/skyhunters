-- SkyIslandGenerator.luau
-- Complete overhaul of the sky island generation system with organic network topology

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local SkyIslandGenerator = {}
SkyIslandGenerator.__index = SkyIslandGenerator

-- Universal tag for all sky island content
local SKY_ISLAND_TAG = "SkyIslandContent"

-- Utility function to tag any constellation-generated content
function SkyIslandGenerator:_tagConstellationContent(item, contentType)
    if not item then return end
    
    -- Add universal tag
    CollectionService:AddTag(item, SKY_ISLAND_TAG)
    
    -- Add constellation attribute for additional identification
    item:SetAttribute("IsConstellation", true)
    
    -- Add content type for debugging
    if contentType then
        item:SetAttribute("ConstellationType", contentType)
    end
    
    -- Log tagging for debugging
    print(string.format("[SkyIslandGenerator] Tagged %s as %s", item.Name, contentType or "constellation content"))
end

-- Ensure root folders for constellation content and terrain markers
function SkyIslandGenerator:_ensureRoots()
    if not self._roots then self._roots = {} end
    if not self._roots.root then
        local f = workspace:FindFirstChild("SkyConstellations") or Instance.new("Folder")
        f.Name = "SkyConstellations"
        f.Parent = workspace
        self:_tagConstellationContent(f, "RootFolder")
        self._roots.root = f
    end
    if not self._roots.markers then
        local m = workspace:FindFirstChild("SkyConstellationMarkers") or Instance.new("Folder")
        m.Name = "SkyConstellationMarkers"
        m.Parent = workspace
        self:_tagConstellationContent(m, "MarkersFolder")
        self._roots.markers = m
    end
    return self._roots.root, self._roots.markers
end

-- Record a terrain island so we can cleanly remove it later
function SkyIslandGenerator:_recordTerrainIsland(kind: string, id: string, position: Vector3, radius: number)
    local _, markers = self:_ensureRoots()
    local marker = Instance.new("Part")
    marker.Name = string.format("Marker_%s_%s", kind, id or "")
    marker.Anchored = true
    marker.CanCollide = false
    marker.Transparency = 1
    marker.Size = Vector3.new(1, 1, 1)
    marker.Position = position
    marker.Parent = markers
    marker:SetAttribute("IsConstellation", true)
    marker:SetAttribute("Kind", kind)
    marker:SetAttribute("Radius", radius)
    -- Tag the marker
    self:_tagConstellationContent(marker, "TerrainMarker")
    return marker
end

-- Constants for generation
local CONSTANTS = {
    -- Distance thresholds (INCREASED for better spacing)
    MIN_POI_SPACING = 400,          -- Increased: More spread out POIs
    BRIDGE_MIN_DISTANCE = 200,      -- Minimum distance for bridge path
    BRIDGE_MAX_DISTANCE = nil,      -- No hard max; allow long links
    FILLER_SPAWN_DISTANCE = 180,    -- Increased horizontal area for tiny islands
    
    -- POI settings (REDUCED size, INCREASED distance)
    MIN_POI_DISTANCE_FROM_SPAWN = 1600,  -- Minimum distance from spawn
    POI_TERRAIN_RADIUS = 40,        -- Smaller terrain islands
    POI_NO_BUILD_RADIUS = 80,       -- Reduced accordingly
    
    -- Bridge/Path settings (FRAGMENTED PARKOUR STYLE)
    PATH_SEGMENT_COUNT = 8,         -- Number of individual segments per path (fragmented mode)
    PATH_SEGMENT_SIZE_MIN = 8,      -- Minimum size of path segment
    PATH_SEGMENT_SIZE_MAX = 16,     -- Maximum size of path segment
    PATH_SEGMENT_GAP_MIN = 4,       -- Minimum gap between segments
    PATH_SEGMENT_GAP_MAX = 12,      -- Maximum gap between segments
    PATH_HEIGHT_VARIATION = 60,     -- Increased height variation between segments
    PATH_ROTATION_VARIATION = 45,   -- Increased yaw variance per segment
    PATH_LATERAL_VARIATION = 80,    -- New: stronger side-to-side wobble
    BRIDGE_LENGTH_MULT = 8,         -- New: much longer bridge planks
    
    -- Pseudo-POIs (treated as pitstops)
    PSEUDO_POI_ENABLED = true,
    PSEUDO_POI_EDGE_CHANCE = 0.75,  -- Chance to add pseudo-POIs along an edge
    PSEUDO_POI_PER_EDGE_MIN = 1,
    PSEUDO_POI_PER_EDGE_MAX = 2,
    PSEUDO_POI_TAIL_COUNT = 3,      -- Tail pitstops from first node toward hub
    PSEUDO_POI_TAIL_SPACING = 140,  -- Spacing between tail pitstops
    PSEUDO_POI_HEIGHT_VARIATION = 10, -- Vertical jitter band for tail
    USE_LONG_BRIDGES = false,       -- Prefer fragmented bridges (models + islands)
    BRIDGE_WIDTH = 16,              -- Visual width for long bridges
    BRIDGE_THICKNESS = 2,           -- Visual thickness for long bridges
    
    -- Filler island settings (small sky islands)
    TINY_ISLAND_RADIUS = 8,         -- Increased; still smaller than pitstops
    TINY_BOTTOM_FACTOR = 1.8,       -- Elongate bottom for diamond shape
    TINY_TOP_FLAT_SCALE_XZ = 0.9,   -- Plateau width relative to R
    TINY_TOP_FLAT_THICKNESS = 0.18, -- Plateau thickness relative to R
    TINY_FILLER_COUNT_MIN = 3,      -- Fewer per element to cut density
    TINY_FILLER_COUNT_MAX = 6,
    TINY_HEIGHT_VARIATION = 80,     -- Increased vertical volume
    FILLER_DENSITY = 0.45,          -- Sparser overall

    -- Pitstop settings (terrain diamond islands placed by path subdivision and pseudo-POIs)
    PITSTOP_RADIUS = 22,            -- Supports a small building + enemies
    PITSTOP_BOTTOM_FACTOR = 2.0,    -- Bottom extends ~2x further than width
    PITSTOP_TOP_FLAT_SCALE_XZ = 1.2,-- Plateau width relative to R
    PITSTOP_TOP_FLAT_THICKNESS = 0.22, -- Plateau thickness relative to R
    PITSTOP_MIN_GAP = 18,           -- Min gap between pitstops along an edge
    PITSTOP_END_CLEAR_BUFFER = 12,  -- Extra clearance beyond POI radii
    PITSTOP_MAX_PER_EDGE = 3,       -- Hard cap for performance
    PITSTOP_JITTER_XZ_MAX = 28,     -- Max horizontal jitter off the edge (studs)
    PITSTOP_JITTER_ALONG_MAX = 14,  -- Max along-edge jitter (studs)
    PITSTOP_JITTER_Y_MAX = 12,      -- Max vertical jitter (studs)
    
    -- Generation settings
    POIS_PER_QUADRANT = 4,          -- Reduced for better spacing
    USE_CONSTELLATION_POIS = true,  -- Generate POIs along outward chains per quadrant
    CONSTELLATION_STEP_MIN = 600,   -- Min radial step between POIs in a chain (more space for pseudo-POIs)
    CONSTELLATION_STEP_MAX = 1200,  -- Max radial step between POIs in a chain
    CONSTELLATION_ANGLE_JITTER = math.rad(20), -- Max angle change per step
    VERTICAL_VARIANCE = 200,        -- More dramatic height differences
    
    -- Tail/path settings
    TAIL_PATH_SEGMENTS = 5,         -- Create short bridge-like tail toward hub
    TAIL_MAX_LENGTH = 600,          -- Limit tail reach toward hub
    TAIL_PITSTOP_MIN = 1,           -- Tail pitstops random count
    TAIL_PITSTOP_MAX = 4,
    TAIL_START_OFFSET = 120,        -- Start farther from POI

    -- Queue settings
    OPERATIONS_PER_FRAME = 5,       -- How many operations before yielding
    MAX_OUTWARD_CONNECTIONS = 2,    -- Limit edges per POI; outward nearest
}

-- Quadrant definitions
local QUADRANTS = {
    North = {angle = 0, color = Color3.fromRGB(100, 200, 100)},
    East = {angle = math.pi/2, color = Color3.fromRGB(200, 100, 100)},
    South = {angle = math.pi, color = Color3.fromRGB(100, 100, 200)},
    West = {angle = 3*math.pi/2, color = Color3.fromRGB(200, 200, 100)},
}

function SkyIslandGenerator.new(worldConfig, terrainBuilder, queueSystem)
    local self = setmetatable({}, SkyIslandGenerator)
    
    self.worldConfig = worldConfig or {}
    self.terrainBuilder = terrainBuilder  -- Reference to TerrainIslandBuilder
    self.queueSystem = queueSystem        -- Reference to generation queue
    
    -- Apply config overrides for constants
    local cfg = (self.worldConfig and self.worldConfig.WORLDGEN and self.worldConfig.WORLDGEN.SkyIslands) or {}
    local function setIf(name, key)
        if cfg[key] ~= nil then CONSTANTS[name] = cfg[key] end
    end
    
    -- Apply all config overrides...
    setIf("FILLER_SPAWN_DISTANCE", "FillerSpawnDistance")
    setIf("FILLER_DENSITY", "FillerDensity")
    setIf("TINY_ISLAND_RADIUS", "TinyIslandRadius")
    setIf("PATH_HEIGHT_VARIATION", "PathHeightVariation")
    setIf("PATH_ROTATION_VARIATION", "PathRotationVariation")
    setIf("PATH_LATERAL_VARIATION", "PathLateralVariation")
    setIf("BRIDGE_LENGTH_MULT", "BridgeLengthMult")

    if cfg.Lights ~= nil then
        CONSTANTS.LIGHTS_ON_PITSTOPS = (cfg.Lights.OnPitstops ~= false)
        CONSTANTS.LIGHTS_ON_SEGMENTS = (cfg.Lights.OnSegments ~= false)
        CONSTANTS.LIGHTS_ON_TINY = (cfg.Lights.OnTiny == true)
    else
        CONSTANTS.LIGHTS_ON_PITSTOPS = true
        CONSTANTS.LIGHTS_ON_SEGMENTS = true
        CONSTANTS.LIGHTS_ON_TINY = false
    end
    
    -- Spatial hashing for O(1) collision detection
    self.spatialHash = {}
    self.cellSize = 100  -- Size of spatial hash cells
    
    -- Storage for generated elements
    self.pois = {}
    self.pathSegments = {}       -- Individual path segments for parkour
    self.tinyIslands = {}        -- Small filler islands
    self.pitstops = {}           -- Large terrain diamond islands (subdivided along edges)
    self.pseudoPois = {}         -- NEW: Pseudo-POIs along edges and tails
    self.connections = {}        -- Graph of POI connections
    
    -- Generation state
    self.isGenerating = false
    self.generationPhase = 0
    
    -- Debug aggregates
    self._dbg = {
        poiPolar = {},               -- { {id, r, thetaDeg, quadrant} }
        quadrantCounts = { North = 0, East = 0, South = 0, West = 0 },
        pairChecks = 0,
        rejects = { tooShort = 0, tooLong = 0, quadrant = 0 },
        accepts = 0,
        connectRDeltaSum = 0,
        connectRDeltaCount = 0,
    }
    
    return self
end

function SkyIslandGenerator:setSeed(seed: number)
    self._seed = seed
end

-- Main generation orchestrator
function SkyIslandGenerator:Generate()
    if self.isGenerating then
        warn("[SkyIslandGenerator] Generation already in progress")
        return
    end
    
    self.isGenerating = true
    -- Seed randomness (dev only): honor setSeed if available; else leave RNG as-is
    if self._seed ~= nil then
        math.randomseed(self._seed)
        print(string.format("[SkyIslandGenerator] RNG seeded seed=%d", self._seed))
    end
    print("[SkyIslandGenerator] Starting sky island network generation")
    
    -- Execute generation phases
    coroutine.wrap(function()
        print("[SkyIslandGenerator] Starting generation phases...")
        
        -- Phase 1: Generate POIs
        print("[SkyIslandGenerator] Starting Phase 1: POI Generation")
        -- TODO: Implement _generatePOIs
        print("[SkyIslandGenerator] Phase 1 complete: POI Generation (stub)")
        wait(0.1)
        
        -- Phase 2: Generate fragmented parkour paths
        print("[SkyIslandGenerator] Starting Phase 2: Parkour Path Generation")
        -- TODO: Implement _generateParkourPaths
        print("[SkyIslandGenerator] Phase 2 complete: Path Generation (stub)")
        wait(0.1)
        
        self.isGenerating = false
        print("[SkyIslandGenerator] Sky island network generation complete!")
        
        -- Fire completion event if needed
        if self.onGenerationComplete then
            self.onGenerationComplete()
        end
    end)()
end

-- Cleanup function (COMPLETELY REWRITTEN - Tag-based removal)
function SkyIslandGenerator:Cleanup()
    print("[SkyIslandGenerator] Starting tag-based cleanup...")
    
    local startTime = tick()
    local cleanupStats = {
        taggedItems = 0,
        terrainRegions = 0
    }
    
    -- Step 1: Remove ALL tagged constellation content (models, folders, parts)
    -- This is the proper way - remove the actual models, not carve terrain
    local taggedItems = CollectionService:GetTagged(SKY_ISLAND_TAG)
    cleanupStats.taggedItems = #taggedItems
    
    print(string.format("[SkyIslandGenerator] Found %d tagged items for removal", cleanupStats.taggedItems))
    
    for _, item in ipairs(taggedItems) do
        if item and item.Parent then
            -- Double-check this isn't part of the spawn area
            local isInSpawn = false
            if item:IsA("BasePart") then
                local distanceFromSpawn = (item.Position - Vector3.new(0, 0, 0)).Magnitude
                local spawnRadius = (self.worldConfig and self.worldConfig.HUB and self.worldConfig.HUB.Radius) or 200
                isInSpawn = distanceFromSpawn < spawnRadius
            end
            
            if not isInSpawn then
                print(string.format("[SkyIslandGenerator] Destroying tagged item: %s (%s)", item.Name, item.ClassName))
                item:Destroy()
            else
                print(string.format("[SkyIslandGenerator] Preserved spawn area item: %s", item.Name))
            end
        end
    end
    
    -- Step 2: Clear terrain using markers for precise removal
    local _, markers = self:_ensureRoots()
    if markers then
        local terrain = workspace.Terrain
        local spawnRadius = (self.worldConfig and self.worldConfig.HUB and self.worldConfig.HUB.Radius) or 200
        
        for _, marker in ipairs(markers:GetChildren()) do
            if marker:IsA("BasePart") and marker:GetAttribute("Radius") then
                local pos = marker.Position
                local radius = marker:GetAttribute("Radius")
                
                -- Only clear if outside spawn area
                local distanceFromSpawn = (Vector2.new(pos.X, pos.Z)).Magnitude
                if distanceFromSpawn > spawnRadius + 50 then -- 50 stud buffer
                    -- Use FillBall for precise terrain removal (but only at marked locations)
                    terrain:FillBall(pos, radius * 1.5, Enum.Material.Air)
                    cleanupStats.terrainRegions = cleanupStats.terrainRegions + 1
                    print(string.format("[SkyIslandGenerator] Cleared terrain at %s (radius: %.1f)", tostring(pos), radius))
                end
            end
        end
        
        -- Clear all markers
        markers:ClearAllChildren()
    end
    
    -- Step 3: Clear debug visualization
    local debugFolder = workspace:FindFirstChild("SkyIslandDebug")
    if debugFolder then
        debugFolder:Destroy()
    end
    
    -- Step 4: Reset internal state for clean regeneration
    self.spatialHash = {}
    self.pois = {}
    self.pathSegments = {}
    self.tinyIslands = {}
    self.pitstops = {}
    self.pseudoPois = {}
    self.connections = {}
    self._roots = nil -- Force recreation of root folders
    
    self._dbg = {
        poiPolar = {},
        quadrantCounts = { North = 0, East = 0, South = 0, West = 0 },
        pairChecks = 0,
        rejects = { tooShort = 0, tooLong = 0, quadrant = 0 },
        accepts = 0,
        connectRDeltaSum = 0,
        connectRDeltaCount = 0,
    }
    
    -- Print cleanup statistics
    local elapsed = tick() - startTime
    print(string.format("[SkyIslandGenerator] Tag-based cleanup complete in %.2fms", elapsed * 1000))
    print(string.format("  - Tagged items removed: %d", cleanupStats.taggedItems))
    print(string.format("  - Terrain regions cleared: %d", cleanupStats.terrainRegions))
    print("[SkyIslandGenerator] Spawn area preserved, ready for regeneration")
end

return SkyIslandGenerator
