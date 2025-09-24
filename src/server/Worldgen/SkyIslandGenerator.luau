-- SkyIslandGenerator.luau
-- Complete overhaul of the sky island generation system with organic network topology

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local SafeRequire = require(RS.Shared.SafeRequire)
local function load(inst: Instance?)
    local r = SafeRequire.load(inst)
    if r.ok then return r.mod end
    return nil
end
local DungeonService = load(SSS:FindFirstChild("Server") and SSS.Server:FindFirstChild("POI") and SSS.Server.POI:FindFirstChild("DungeonService"))
local BridgeMeshService = require(script.Parent.BridgeMeshService)
local UpdatedBridgeConfig = require(script.Parent.UpdatedBridgeConfig)

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

-- Forward-declare constants so helpers can capture the upvalue
local CONSTANTS

-- Helper: tile a MeshPart along the segment length to avoid extreme non-uniform scaling
local function _tileMeshPlanks(basePart: MeshPart, totalLength: number, orient: CFrame, parent: Instance, width: number, thickness: number)
    local baseLen = 0
    if basePart.MeshSize and typeof(basePart.MeshSize) == "Vector3" then
        baseLen = basePart.MeshSize.Z
    end
    if baseLen <= 0 then
        baseLen = CONSTANTS.BRIDGE_UNIT_LENGTH or 16
    end

    local maxPer = baseLen * (CONSTANTS.BRIDGE_MAX_STRETCH or 2.0)
    local minPer = baseLen * (CONSTANTS.BRIDGE_MIN_STRETCH or 0.5)
    local count = math.max(1, math.ceil(totalLength / math.max(1e-3, maxPer)))
    local perLen = math.clamp(totalLength / count, minPer, maxPer)
    local step = perLen + (CONSTANTS.BRIDGE_TILE_GAP or 0)
    local midIndex = math.ceil(count / 2)

    local midPiece: MeshPart? = nil
    for i = 1, count do
        local part = if i == 1 then basePart else basePart:Clone()
        part.Name = "BridgePlank"
        part.Anchored = true
        part.Size = Vector3.new(width, thickness, perLen)
        local offset = (i - (count + 1) / 2) * step
        part.CFrame = orient * CFrame.new(0, 0, offset)
        part.Parent = parent
        if i == midIndex then
            midPiece = part
        end
    end
    return count, midPiece
end

-- Helper: tile a simple BasePart (fallback plank)
local function _tileSimplePart(basePart: BasePart, totalLength: number, orient: CFrame, parent: Instance, width: number, thickness: number)
    local baseLen = basePart.Size.Z
    if baseLen <= 0 then
        baseLen = CONSTANTS.BRIDGE_UNIT_LENGTH or 16
    end

    local maxPer = baseLen * (CONSTANTS.BRIDGE_MAX_STRETCH or 2.0)
    local minPer = baseLen * (CONSTANTS.BRIDGE_MIN_STRETCH or 0.5)
    local count = math.max(1, math.ceil(totalLength / math.max(1e-3, maxPer)))
    local perLen = math.clamp(totalLength / count, minPer, maxPer)
    local step = perLen + (CONSTANTS.BRIDGE_TILE_GAP or 0)
    local midIndex = math.ceil(count / 2)
    local midPiece: BasePart? = nil

    for i = 1, count do
        local part = if i == 1 then basePart else basePart:Clone()
        part.Name = "BridgePlank"
        part.Anchored = true
        part.Size = Vector3.new(width, thickness, perLen)
        local offset = (i - (count + 1) / 2) * step
        part.CFrame = orient * CFrame.new(0, 0, offset)
        part.Parent = parent
        if i == midIndex then
            midPiece = part
        end
    end
    return count, midPiece
end

-- Helper: tile a Model along the segment length without scaling to preserve proportions
local function _tileModelPieces(baseModel: Model, totalLength: number, orient: CFrame, parent: Instance)
    baseModel.Name = "BridgePlank"
    baseModel.Parent = parent
    -- Ensure anchored
    for _, d in ipairs(baseModel:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored = true
        end
    end
    baseModel:PivotTo(orient)

    local ext = baseModel:GetExtentsSize()
    local baseLen = math.max(ext.Z, ext.X)
    if baseLen <= 0 then
        baseLen = CONSTANTS.BRIDGE_UNIT_LENGTH or 16
    end
    local count = math.max(1, math.ceil(totalLength / math.max(1e-3, baseLen)))
    local step = baseLen + (CONSTANTS.BRIDGE_TILE_GAP or 0)
    local midIndex = math.ceil(count / 2)
    local midModel: Model? = nil

    for i = 1, count do
        local mdl = if i == 1 then baseModel else baseModel:Clone()
        mdl.Name = "BridgePlank"
        local offset = (i - (count + 1) / 2) * step
        mdl:PivotTo(orient * CFrame.new(0, 0, offset))
        mdl.Parent = parent
        if i == midIndex then
            midModel = mdl
        end
    end
    return count, midModel
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
    end    return self._roots.root, self._roots.markers
end

-- Record a terrain island so we can cleanly remove it later with precise bounds
function SkyIslandGenerator:_recordTerrainIsland(kind: string, id: string, position: Vector3, radius: number, preciseRegion: Region3?)
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
    
    -- Store precise region bounds if provided
    if preciseRegion then
        local min, max = preciseRegion.CFrame.Position - preciseRegion.Size/2, preciseRegion.CFrame.Position + preciseRegion.Size/2
        marker:SetAttribute("RegionMinX", min.X)
        marker:SetAttribute("RegionMinY", min.Y)
        marker:SetAttribute("RegionMinZ", min.Z)
        marker:SetAttribute("RegionMaxX", max.X)
        marker:SetAttribute("RegionMaxY", max.Y)
        marker:SetAttribute("RegionMaxZ", max.Z)
        print(string.format("[SkyIslandGenerator] Stored precise region for %s: min=%s max=%s", kind, tostring(min), tostring(max)))
    end
    
    -- Tag the marker
    self:_tagConstellationContent(marker, "TerrainMarker")
    return marker
end
-- Constants for generation
  CONSTANTS = {
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
      BRIDGE_UNIT_LENGTH = 16,        -- Target per-piece length when tiling mesh/model
      BRIDGE_MAX_STRETCH = 2.0,       -- Max scale along length per piece before tiling
      BRIDGE_MIN_STRETCH = 0.5,       -- Min scale along length per piece before merging
      BRIDGE_TILE_GAP = 0.0,          -- Optional small gap/overlap between tiled pieces
      BRIDGE_MAX_WIDTH_TO_THICKNESS = 2.0, -- Clamp mesh X/Y scaling ratio to avoid warping
    
      -- Pseudo-POIs (treated as pitstops)
      PSEUDO_POI_ENABLED = true,
      PSEUDO_POI_EDGE_CHANCE = 0.75,  -- Chance to add pseudo-POIs along an edge
      PSEUDO_POI_PER_EDGE_MIN = 1,
      PSEUDO_POI_PER_EDGE_MAX = 2,
      PSEUDO_POI_TAIL_COUNT = 3,      -- Tail pitstops from first node toward hub
      PSEUDO_POI_TAIL_SPACING = 140,  -- Spacing between tail pitstops
      PSEUDO_POI_HEIGHT_VARIATION = 10, -- Vertical jitter band for tail
    USE_LONG_BRIDGES = false,       -- Prefer fragmented bridges (models + islands)
    USE_BRIDGE_ASSETS = true,       -- Use mesh/model assets for bridge planks by default
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
      setIf("FILLER_SPAWN_DISTANCE", "FillerSpawnDistance")
      setIf("FILLER_DENSITY", "FillerDensity")
      setIf("TINY_ISLAND_RADIUS", "TinyIslandRadius")
      setIf("TINY_BOTTOM_FACTOR", "TinyBottomFactor")
      setIf("TINY_TOP_FLAT_SCALE_XZ", "TinyTopFlatScaleXZ")
      setIf("TINY_TOP_FLAT_THICKNESS", "TinyTopFlatThickness")
      setIf("TINY_FILLER_COUNT_MIN", "TinyFillerCountMin")
      setIf("TINY_FILLER_COUNT_MAX", "TinyFillerCountMax")
      setIf("TINY_HEIGHT_VARIATION", "TinyHeightVariation")

      setIf("PITSTOP_RADIUS", "PitstopRadius")
      setIf("PITSTOP_BOTTOM_FACTOR", "PitstopBottomFactor")
      setIf("PITSTOP_TOP_FLAT_SCALE_XZ", "PitstopTopFlatScaleXZ")
      setIf("PITSTOP_TOP_FLAT_THICKNESS", "PitstopTopFlatThickness")
      setIf("PITSTOP_MIN_GAP", "PitstopMinGap")
      setIf("PITSTOP_END_CLEAR_BUFFER", "PitstopEndClearBuffer")
      setIf("PITSTOP_MAX_PER_EDGE", "PitstopMaxPerEdge")
      setIf("PITSTOP_JITTER_XZ_MAX", "PitstopJitterXZMax")
      setIf("PITSTOP_JITTER_ALONG_MAX", "PitstopJitterAlongMax")
      setIf("PITSTOP_JITTER_Y_MAX", "PitstopJitterYMax")

      setIf("TAIL_PATH_SEGMENTS", "TailPathSegments")
      setIf("TAIL_MAX_LENGTH", "TailMaxLength")
      setIf("TAIL_PITSTOP_MIN", "TailPitstopMin")
      setIf("TAIL_PITSTOP_MAX", "TailPitstopMax")
      setIf("TAIL_START_OFFSET", "TailStartOffset")

      setIf("PSEUDO_POI_TAIL_SPACING", "PseudoTailSpacing")
      setIf("PSEUDO_POI_HEIGHT_VARIATION", "PseudoHeightVariation")
      setIf("PSEUDO_POI_EDGE_CHANCE", "PseudoEdgeChance")
      setIf("PSEUDO_POI_PER_EDGE_MIN", "PseudoPerEdgeMin")
      setIf("PSEUDO_POI_PER_EDGE_MAX", "PseudoPerEdgeMax")

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
    
    
    local bridgeConfigs = nil
    local okBridgeConfig, configResult = pcall(function()
        return UpdatedBridgeConfig.GetConfigs()
    end)
    if okBridgeConfig and configResult then
        bridgeConfigs = configResult
    elseif not okBridgeConfig then
        warn("[SkyIslandGenerator] Bridge config load failed: " .. tostring(configResult))
    end
    
    local okBridgeService, bridgeServiceOrErr = pcall(function()
        return BridgeMeshService.new(bridgeConfigs)
    end)
    if okBridgeService then
        self.bridgeService = bridgeServiceOrErr
    else
        warn("[SkyIslandGenerator] BridgeMeshService init failed: " .. tostring(bridgeServiceOrErr))
        self.bridgeService = nil
    end
    return self
end

function SkyIslandGenerator:setSeed(seed: number)
    self._seed = seed
end

-- Debug summaries
function SkyIslandGenerator:_debugSummarizePOIs()
    local n = #self._dbg.poiPolar
    if n == 0 then return end
    local minR, maxR, sumR, sumR2 = math.huge, -math.huge, 0, 0
    for _, p in ipairs(self._dbg.poiPolar) do
        minR = math.min(minR, p.r)
        maxR = math.max(maxR, p.r)
        sumR += p.r
        sumR2 += p.r * p.r
    end
    local meanR = sumR / n
    local varR = math.max(0, (sumR2 / n) - (meanR * meanR))
    local stdR = math.sqrt(varR)
    print(string.format("[SkyIslandDebug] POI radial r_min=%.1f r_max=%.1f r_mean=%.1f r_std=%.1f count=%d", minR, maxR, meanR, stdR, n))
    print(string.format("[SkyIslandDebug] Quadrants N=%d E=%d S=%d W=%d", self._dbg.quadrantCounts.North or 0, self._dbg.quadrantCounts.East or 0, self._dbg.quadrantCounts.South or 0, self._dbg.quadrantCounts.West or 0))
end

function SkyIslandGenerator:_debugSummarizePaths()
    local avgRDelta = 0
    if self._dbg.connectRDeltaCount > 0 then
        avgRDelta = self._dbg.connectRDeltaSum / self._dbg.connectRDeltaCount
    end
    print(string.format("[SkyIslandDebug] Path checks total=%d accept=%d rej_short=%d rej_long=%d rej_quadrant=%d avg_r_delta=%.1f", self._dbg.pairChecks, self._dbg.accepts, self._dbg.rejects.tooShort, self._dbg.rejects.tooLong, self._dbg.rejects.quadrant, avgRDelta))
    local maxConnStr = (CONSTANTS.BRIDGE_MAX_DISTANCE ~= nil) and string.format("%.0f", CONSTANTS.BRIDGE_MAX_DISTANCE) or "inf"
    print(string.format("[SkyIslandDebug] Thresholds min_conn=%.0f max_conn=%s poi_min_r=%.0f", CONSTANTS.BRIDGE_MIN_DISTANCE, maxConnStr, CONSTANTS.MIN_POI_DISTANCE_FROM_SPAWN))
end

function SkyIslandGenerator:_debugFinalReport()
    -- Heuristic: ring tendency if std/mean small and avg_r_delta small relative to mean radius
    local n = #self._dbg.poiPolar
    if n == 0 then return end
    local minR, maxR, sumR, sumR2 = math.huge, -math.huge, 0, 0
    for _, p in ipairs(self._dbg.poiPolar) do
        minR = math.min(minR, p.r)
        maxR = math.max(maxR, p.r)
        sumR += p.r
        sumR2 += p.r * p.r
    end
    local meanR = sumR / n
    local varR = math.max(0, (sumR2 / n) - (meanR * meanR))
    local stdR = math.sqrt(varR)
    local avgRDelta = (self._dbg.connectRDeltaCount > 0) and (self._dbg.connectRDeltaSum / self._dbg.connectRDeltaCount) or 0

    local ringiness = (meanR > 0) and (stdR / meanR) or 0
    print(string.format("[SkyIslandDebug] Topology ringiness=%.3f avg_conn_r_delta=%.1f poi_r_band=[%.0f,%.0f]", ringiness, avgRDelta, minR, maxR))
end

-- Spatial hashing functions for collision detection
function SkyIslandGenerator:_getHashKey(position)
    local x = math.floor(position.X / self.cellSize)
    local y = math.floor(position.Y / self.cellSize)
    local z = math.floor(position.Z / self.cellSize)
    return string.format("%d,%d,%d", x, y, z)
end

function SkyIslandGenerator:_addToSpatialHash(position, radius, object)
    -- Add object to all cells it overlaps
    local minX = math.floor((position.X - radius) / self.cellSize)
    local maxX = math.floor((position.X + radius) / self.cellSize)
    local minY = math.floor((position.Y - radius) / self.cellSize)
    local maxY = math.floor((position.Y + radius) / self.cellSize)
    local minZ = math.floor((position.Z - radius) / self.cellSize)
    local maxZ = math.floor((position.Z + radius) / self.cellSize)
    
    for x = minX, maxX do
        for y = minY, maxY do
            for z = minZ, maxZ do
                local key = string.format("%d,%d,%d", x, y, z)
                if not self.spatialHash[key] then
                    self.spatialHash[key] = {}
                end
                table.insert(self.spatialHash[key], object)
            end
        end
    end
end

function SkyIslandGenerator:_checkCollision(position, radius)
    -- Check if position would collide with existing objects
    local minX = math.floor((position.X - radius) / self.cellSize)
    local maxX = math.floor((position.X + radius) / self.cellSize)
    local minY = math.floor((position.Y - radius) / self.cellSize)
    local maxY = math.floor((position.Y + radius) / self.cellSize)
    local minZ = math.floor((position.Z - radius) / self.cellSize)
    local maxZ = math.floor((position.Z + radius) / self.cellSize)
    
    for x = minX, maxX do
        for y = minY, maxY do
            for z = minZ, maxZ do
                local key = string.format("%d,%d,%d", x, y, z)
                local cell = self.spatialHash[key]
                if cell then
                    for _, object in ipairs(cell) do
                        -- Ensure object has position and radius fields
                        if object.position and object.radius then
                            local dist = (object.position - position).Magnitude
                            if dist < (object.radius + radius) then
                                return true  -- Collision detected
                            end
                        end
                    end
                end
            end
        end
    end
    
    return false
end

-- Poisson disk sampling for conflict-free POI placement
function SkyIslandGenerator:_generatePoissonDiskSamples(centerAngle, angleRange, minRadius, maxRadius, count, minSpacing)
    local samples = {}
    local activeList = {}
    local grid = {}
    local cellSize = minSpacing / math.sqrt(2)
    local maxAttempts = 30
    local hasMax = (maxRadius ~= nil)
    
    -- Helper function to get grid index
    local function getGridIndex(pos)
        local x = math.floor(pos.X / cellSize)
        local z = math.floor(pos.Z / cellSize)
        return x .. "," .. z
    end
    
    -- Generate first sample
    local angle = centerAngle + (math.random() - 0.5) * angleRange
    local radius
    if hasMax then
        radius = minRadius + math.random() * (maxRadius - minRadius)
    else
        -- When unbounded, start near the min radius with a small random band
        radius = minRadius + math.random() * (minSpacing * 2)
    end
    local height = 100 + (math.random() - 0.5) * CONSTANTS.VERTICAL_VARIANCE
    
    local firstSample = Vector3.new(
        math.cos(angle) * radius,
        height,
        math.sin(angle) * radius
    )
    
    table.insert(samples, firstSample)
    table.insert(activeList, firstSample)
    grid[getGridIndex(firstSample)] = firstSample
    
    -- Generate remaining samples
    while #activeList > 0 and #samples < count do
        local randomIndex = math.random(1, #activeList)
        local currentSample = activeList[randomIndex]
        local foundValid = false
        
        for attempt = 1, maxAttempts do
            -- Generate random point in annulus around current sample
            local newAngle = math.random() * 2 * math.pi
            local newRadius = minSpacing + math.random() * minSpacing
            local newHeight = currentSample.Y + (math.random() - 0.5) * CONSTANTS.VERTICAL_VARIANCE * 0.5
            
            local newSample = currentSample + Vector3.new(
                math.cos(newAngle) * newRadius,
                newHeight - currentSample.Y,
                math.sin(newAngle) * newRadius
            )
            
            -- Check if within quadrant bounds
            local sampleAngle = math.atan2(newSample.Z, newSample.X)
            local angleDiff = math.abs(sampleAngle - centerAngle)
            if angleDiff > math.pi then
                angleDiff = 2 * math.pi - angleDiff
            end
            
            if angleDiff <= angleRange / 2 then
                local sampleRadius = math.sqrt(newSample.X^2 + newSample.Z^2)
                if sampleRadius >= minRadius and (not hasMax or sampleRadius <= maxRadius) then
                    -- Check minimum distance to all other samples
                    local tooClose = false
                    for _, other in ipairs(samples) do
                        if (other - newSample).Magnitude < minSpacing then
                            tooClose = true
                            break
                        end
                    end
                    
                    if not tooClose and not self:_checkCollision(newSample, CONSTANTS.POI_NO_BUILD_RADIUS) then
                        table.insert(samples, newSample)
                        table.insert(activeList, newSample)
                        grid[getGridIndex(newSample)] = newSample
                        foundValid = true
                        break
                    end
                end
            end
        end
        
        if not foundValid then
            table.remove(activeList, randomIndex)
        end
    end
    
    return samples
end

-- Phase 1: Generate POIs with Poisson disk sampling
function SkyIslandGenerator:_generatePOIs()
    print("[SkyIslandGenerator] Phase 1: Generating POIs")

    for quadrantName, quadrantData in pairs(QUADRANTS) do
        local minR = CONSTANTS.MIN_POI_DISTANCE_FROM_SPAWN
        local maxR = nil -- No maximum cap
        local maxRStr = "inf"
        print(string.format("[SkyIslandGenerator] Processing quadrant %s (angle: %.2f, r=[%d,%s], spacing=%d)", quadrantName, quadrantData.angle, minR, maxRStr, CONSTANTS.MIN_POI_SPACING))

        local created = 0
        if CONSTANTS.USE_CONSTELLATION_POIS then
            -- Constellation-style: outward chain from minR with small angular drift
            local angle = quadrantData.angle
            local currentR = minR + math.random() * (CONSTANTS.CONSTELLATION_STEP_MIN)
            for i = 1, CONSTANTS.POIS_PER_QUADRANT do
                -- Advance radius
                currentR += math.random(CONSTANTS.CONSTELLATION_STEP_MIN, CONSTANTS.CONSTELLATION_STEP_MAX)
                -- Jitter angle a bit each step
                angle += (math.random() - 0.5) * 2 * CONSTANTS.CONSTELLATION_ANGLE_JITTER
                -- Compute position using hub at origin (XZ plane), random height around baseline
                local height = 100 + (math.random() - 0.5) * CONSTANTS.VERTICAL_VARIANCE
                local position = Vector3.new(math.cos(angle) * currentR, height, math.sin(angle) * currentR)

                -- Ensure spacing and no collision
                if (not self:_checkCollision(position, CONSTANTS.POI_NO_BUILD_RADIUS)) then
                    local poi = {
                        id = quadrantName .. "_POI_" .. (created + 1),
                        position = position,
                        radius = CONSTANTS.POI_NO_BUILD_RADIUS,
                        noBuildRadius = CONSTANTS.POI_NO_BUILD_RADIUS,
                        terrainRadius = CONSTANTS.POI_TERRAIN_RADIUS,
                        quadrant = quadrantName,
                        connections = {},
                        terrainGenerated = false,
                        buildingsGenerated = false
                    }
                    table.insert(self.pois, poi)
                    self:_addToSpatialHash(position, CONSTANTS.POI_NO_BUILD_RADIUS, poi)
                    created += 1

                    local r = (Vector2.new(position.X, position.Z)).Magnitude
                    local theta = math.deg(math.atan2(position.Z, position.X))
                    print(string.format("[SkyIslandGenerator] Created POI id=%s quadrant=%s pos=%s r=%.1f theta=%.1f", poi.id, poi.quadrant, tostring(position), r, theta))
                    table.insert(self._dbg.poiPolar, { id = poi.id, r = r, thetaDeg = theta, quadrant = quadrantName })
                    self._dbg.quadrantCounts[quadrantName] = (self._dbg.quadrantCounts[quadrantName] or 0) + 1

                    if self.queueSystem then
                        self.queueSystem:Add(function()
                            self:_generatePOITerrain(poi)
                        end, "POI_Terrain_" .. poi.id)
                    else
                        self:_generatePOITerrain(poi)
                    end
                end
            end
        else
            -- Poisson fallback
            local angle = quadrantData.angle
            local angleRange = math.pi / 2 - 0.2
            local poiPositions = self:_generatePoissonDiskSamples(
                angle,
                angleRange,
                minR,
                maxR,
                CONSTANTS.POIS_PER_QUADRANT,
                CONSTANTS.MIN_POI_SPACING
            )
            for i, position in ipairs(poiPositions) do
                local poi = {
                    id = quadrantName .. "_POI_" .. i,
                    position = position,
                    radius = CONSTANTS.POI_NO_BUILD_RADIUS,
                    noBuildRadius = CONSTANTS.POI_NO_BUILD_RADIUS,
                    terrainRadius = CONSTANTS.POI_TERRAIN_RADIUS,
                    quadrant = quadrantName,
                    connections = {},
                    terrainGenerated = false,
                    buildingsGenerated = false
                }
                table.insert(self.pois, poi)
                self:_addToSpatialHash(position, CONSTANTS.POI_NO_BUILD_RADIUS, poi)
                local r = (Vector2.new(position.X, position.Z)).Magnitude
                local theta = math.deg(math.atan2(position.Z, position.X))
                print(string.format("[SkyIslandGenerator] Created POI id=%s quadrant=%s pos=%s r=%.1f theta=%.1f", poi.id, poi.quadrant, tostring(position), r, theta))
                table.insert(self._dbg.poiPolar, { id = poi.id, r = r, thetaDeg = theta, quadrant = quadrantName })
                self._dbg.quadrantCounts[quadrantName] = (self._dbg.quadrantCounts[quadrantName] or 0) + 1
                if self.queueSystem then
                    self.queueSystem:Add(function()
                        self:_generatePOITerrain(poi)
                    end, "POI_Terrain_" .. poi.id)
                else
                    self:_generatePOITerrain(poi)
                end
            end
        end
    end

    print(string.format("[SkyIslandGenerator] Generated %d POIs", #self.pois))
    -- POI distribution summary
    self:_debugSummarizePOIs()
end

-- Generate terrain for a single POI
function SkyIslandGenerator:_generatePOITerrain(poi)
    if poi.terrainGenerated then return end
    
    -- Use the existing TerrainIslandBuilder if available
    if self.terrainBuilder and self.terrainBuilder.buildIslandAt then
        -- TerrainIslandBuilder expects just a CFrame, it handles size internally
        -- Pass POI type for proper terrain marking
        self.terrainBuilder.buildIslandAt(CFrame.new(poi.position), "POI")
        print(string.format("[SkyIslandGenerator] Generated terrain for POI %s at %s", poi.id, tostring(poi.position)))
    else
        -- Fallback: Create simple terrain sphere with precise region tracking
        local terrain = workspace.Terrain
        terrain:FillBall(poi.position, poi.radius, Enum.Material.Grass)
        
        -- Create precise bounding box for the sphere with generous padding
        local size = poi.radius * 3 -- INCREASED: More generous bounds (was 2)
        local preciseRegion = Region3.new(
            poi.position - Vector3.new(size/2, size/2, size/2),
            poi.position + Vector3.new(size/2, size/2, size/2)
        )
        
        print(string.format("[SkyIslandGenerator] Generated fallback terrain for POI %s", poi.id))
        
        -- Record with precise region
        local terrainRadius = poi.terrainRadius or poi.radius
        self:_recordTerrainIsland("POI", poi.id, poi.position, terrainRadius, preciseRegion)
    end
    
    poi.terrainGenerated = true
    
    -- Add simple building on top
    self:_generatePOIBuilding(poi)
end

-- Generate simple building on POI
function SkyIslandGenerator:_generatePOIBuilding(poi)
    if poi.buildingsGenerated then return end
    -- Replace POI building with a Dungeon spawn
    if DungeonService and DungeonService.SpawnDungeonPOI then
        local seed = (self._seed ~= nil) and self._seed or os.time()
        local yOffset = 1 -- slight lift above terrain top
        local ok, err = pcall(function()
            DungeonService:SpawnDungeonPOI(poi.id, poi.position + Vector3.new(0, yOffset, 0), seed)
        end)
        if not ok then
            warn("[SkyIslandGenerator] Dungeon spawn failed for", poi.id, err)
        end
    else
        warn("[SkyIslandGenerator] DungeonService unavailable; skipping dungeon for", poi.id)
    end
    poi.buildingsGenerated = true
end

-- Phase 2: Generate fragmented parkour paths
function SkyIslandGenerator:_generateParkourPaths()
    print("[SkyIslandGenerator] Phase 2: Generating fragmented parkour paths")
    
    local pathCount = 0
    
    -- For each quadrant, chain POIs by increasing radius (no cross-quadrant edges)
    local byQuadrant: { [string]: { any } } = { North = {}, East = {}, South = {}, West = {} }
    for _, poi in ipairs(self.pois) do
        table.insert(byQuadrant[poi.quadrant], poi)
    end
    for q, arr in pairs(byQuadrant) do
        table.sort(arr, function(a, b)
            local ra = (Vector2.new(a.position.X, a.position.Z)).Magnitude
            local rb = (Vector2.new(b.position.X, b.position.Z)).Magnitude
            return ra < rb
        end)
          -- Tail from first node toward hub: always generate tail edge (segments + pitstops)
          if #arr > 0 then
              self:_generatePseudoTail(arr[1], Vector3.new(0, arr[1].position.Y, 0))
          end
        for idx = 1, math.max(0, #arr - 1) do
            local a = arr[idx]
            local b = arr[idx + 1]
            local d = (a.position - b.position).Magnitude
            print(string.format("[SkyIslandGenerator] [Chain] q=%s a=%s b=%s d=%.1f", q, a.id, b.id, d))
            self._dbg.pairChecks += 1
            if d < CONSTANTS.BRIDGE_MIN_DISTANCE then
                self._dbg.rejects.tooShort += 1
                print(string.format("[SkyIslandGenerator] [Reject] reason=too_short a=%s b=%s d=%.1f min=%.1f", a.id, b.id, d, CONSTANTS.BRIDGE_MIN_DISTANCE))
            else
                -- Generate segments first; then place pitstops to avoid blocking paths
                local pathSegments = self:_createFragmentedPath(a, b)
                if pathSegments and #pathSegments > 0 then
                    for _, segment in ipairs(pathSegments) do
                        table.insert(self.pathSegments, segment)
                        if self.queueSystem then
                            self.queueSystem:Add(function() self:_generatePathSegmentModel(segment) end, "PathSegment_" .. segment.id, 2)
                        else
                            self:_generatePathSegmentModel(segment)
                        end
                    end
                    table.insert(a.connections, b)
                    table.insert(b.connections, a)
                    pathCount += 1
                    self._dbg.accepts += 1
                    local ra = (Vector2.new(a.position.X, a.position.Z)).Magnitude
                    local rb = (Vector2.new(b.position.X, b.position.Z)).Magnitude
                    self._dbg.connectRDeltaSum += math.abs(ra - rb)
                      self._dbg.connectRDeltaCount += 1
                      -- Place pitstops now; collision avoids segments
                      self:_addPitstopsAlongEdge(a, b)
                      -- Add pseudo-POIs (now pitstops) with jitter around the edge
                      -- Skip along-edge pseudo nodes if subdivision pitstops are active to avoid redundancy
                      local allowEdgePseudo = (CONSTANTS.PITSTOP_MAX_PER_EDGE or 0) <= 0
                      if CONSTANTS.PSEUDO_POI_ENABLED and allowEdgePseudo then
                          self:_generatePseudoAlongEdge(a, b)
                      end
                  end
              end
        end
    end
    
    print(string.format("[SkyIslandGenerator] Generated %d fragmented parkour paths with %d total segments", pathCount, #self.pathSegments))
    self:_debugSummarizePaths()
end

-- Check if two quadrants are adjacent
function SkyIslandGenerator:_areQuadrantsAdjacent(quadrantA, quadrantB)
    local adjacency = {
        North = {"East", "West"},
        East = {"North", "South"},
        South = {"East", "West"},
        West = {"North", "South"}
    }
    
    for _, adjacent in ipairs(adjacency[quadrantA] or {}) do
        if adjacent == quadrantB then
            return true
        end
    end
    
    return false
end

-- Create fragmented parkour path between two POIs
  function SkyIslandGenerator:_createFragmentedPath(poiA, poiB)
    local segments = {}
    local segmentId = 0
    
    local startPos = poiA.position
    local endPos = poiB.position
    local totalDistance = (endPos - startPos).Magnitude
    local direction = (endPos - startPos).Unit
    
    -- Calculate how many segments we need
    local segmentCount = CONSTANTS.PATH_SEGMENT_COUNT
    local segmentSpacing = totalDistance / (segmentCount + 1)
    
    -- Define different segment types
    local segmentTypes = {"organic", "platform", "lootable"}
    
    for i = 1, segmentCount do
        segmentId += 1
        local progress = i / (segmentCount + 1)
        
        -- Base position along the path
        local basePos = startPos + direction * (segmentSpacing * i)
        
        -- Add random offset for interesting pathing
          local perpendicular = Vector3.new(-direction.Z, 0, direction.X)
          local lateralOffset = (math.random() - 0.5) * (CONSTANTS.PATH_LATERAL_VARIATION or 60)
          local heightOffset = (math.random() - 0.5) * (CONSTANTS.PATH_HEIGHT_VARIATION or 40) * 3
        
        local segmentPos = basePos + perpendicular * lateralOffset + Vector3.new(0, heightOffset, 0)
        
        -- Random size and rotation
        local size = math.random(CONSTANTS.PATH_SEGMENT_SIZE_MIN, CONSTANTS.PATH_SEGMENT_SIZE_MAX)
        local rotationY = math.random(-CONSTANTS.PATH_ROTATION_VARIATION, CONSTANTS.PATH_ROTATION_VARIATION)
        
          -- Choose segment type: prefer simple bridge beams; avoid lootable platforms near pitstops
          local r = math.random()
          local segmentType = if r < 0.8 then "bridge_beam" else "organic"
        
        -- Check collision before placing
          local lengthMult = (segmentType == "bridge_beam") and (CONSTANTS.BRIDGE_LENGTH_MULT or 8) or 1
          -- Collision radius should reflect width, not visual length of the plank
          local collisionRadius = math.max((CONSTANTS.BRIDGE_WIDTH or 16) * 0.6, size * 1.4)
          if not self:_checkCollision(segmentPos, collisionRadius) then
              local orient = CFrame.lookAt(segmentPos, segmentPos + direction) * CFrame.Angles(0, math.rad(rotationY), 0)
              local segment = {
                  id = string.format("%s_to_%s_seg_%d", poiA.id, poiB.id, segmentId),
                  position = segmentPos,
                  size = size,
                  radius = collisionRadius,
                  rotation = orient,
                  segmentType = segmentType,
                  lengthMult = lengthMult,
                  generated = false
              }
            
            table.insert(segments, segment)
            
            -- Add to spatial hash with radius
            self:_addToSpatialHash(segmentPos, size * 2, segment)
            print(string.format("[SkyIslandGenerator] Created path segment %s at %s (type: %s)", segment.id, tostring(segmentPos), segmentType))
        else
            print(string.format("[SkyIslandGenerator] Skipped segment due to collision at %s", tostring(segmentPos)))
        end
    end
    
    return segments
end

-- Create a single long bridge segment between two POIs
function SkyIslandGenerator:_createLongBridge(poiA, poiB)
    local segments = {}
    local startPos = poiA.position
    local endPos = poiB.position
    local mid = (startPos + endPos) / 2
    local dir = (endPos - startPos)
    local length = dir.Magnitude
    if length <= 0 then return segments end
    local look = CFrame.lookAt(mid, mid + dir)

    local segment = {
        id = string.format("%s_to_%s_long", poiA.id, poiB.id),
        position = mid,
        size = length,
        radius = math.max(CONSTANTS.BRIDGE_WIDTH, length) * 0.5,
        rotation = look,
        segmentType = "long_bridge",
        generated = false,
    }
    table.insert(segments, segment)
    self:_addToSpatialHash(mid, segment.radius, segment)
    print(string.format("[SkyIslandGenerator] Created long bridge %s len=%.1f", segment.id, length))
    return segments
end

  -- Pseudo-POIs are pitstops: generate as terrain diamonds (delegated)
  function SkyIslandGenerator:_generatePseudoPOIModel(node)
      if node.generated then return end
      local fake = {
          id = node.id,
          position = node.position,
          terrainRadius = CONSTANTS.PITSTOP_RADIUS,
          bottomFactor = CONSTANTS.PITSTOP_BOTTOM_FACTOR,
          generated = false,
      }
      self:_generatePitstopModel(fake)
      node.generated = true
  end

  function SkyIslandGenerator:_createPseudoPOI(position)
      -- Unify pseudo-POIs with pitstops
      local ok = self:_createPitstop(position)
      return ok
  end

-- Pseudo-POIs along a->b edge
  function SkyIslandGenerator:_generatePseudoAlongEdge(a, b)
      if math.random() > CONSTANTS.PSEUDO_POI_EDGE_CHANCE then return end
      local count = math.random(CONSTANTS.PSEUDO_POI_PER_EDGE_MIN, CONSTANTS.PSEUDO_POI_PER_EDGE_MAX)
      local dir = (b.position - a.position)
      local dist = dir.Magnitude
      if dist <= 0 then return end
      local unit = dir.Unit
      local perp = Vector3.new(-unit.Z, 0, unit.X)
      for i = 1, count do
          local t = (i / (count + 1)) + (math.random() - 0.5) * 0.1 -- slight along-edge jitter
          t = math.clamp(t, 0.1, 0.9)
          local lateralMax = math.min(CONSTANTS.PITSTOP_JITTER_XZ_MAX or 0, dist * 0.25)
          local lateral = (math.random() * 2 - 1) * lateralMax
          local height = (math.random() * 2 - 1) * (CONSTANTS.PITSTOP_JITTER_Y_MAX or 0)
          local alongJ = (math.random() * 2 - 1) * (CONSTANTS.PITSTOP_JITTER_ALONG_MAX or 0)
          local base = a.position + unit * (t * dist + alongJ)
          local pos = base + perp * lateral + Vector3.new(0, height, 0)
          self:_createPseudoPOI(pos) -- now generates terrain pitstops
      end
  end

-- Tail of pseudo-POIs from first node toward hub
  function SkyIslandGenerator:_generatePseudoTail(firstNode, hubPos)
      local toHub = (hubPos - firstNode.position)
      local dist = toHub.Magnitude
      if dist <= 0 then return end
      local unit = toHub.Unit
      local perp = Vector3.new(-unit.Z, 0, unit.X)
    local tailMin = CONSTANTS.TAIL_PITSTOP_MIN or 1
    local tailMax = CONSTANTS.TAIL_PITSTOP_MAX or 4
    local count = math.clamp(math.floor(math.random(tailMin, tailMax)), 1, 8)
    local startOffset = CONSTANTS.TAIL_START_OFFSET or 0
    for i = 1, count do
        local d = startOffset + i * CONSTANTS.PSEUDO_POI_TAIL_SPACING
        local alongJ = (math.random() * 2 - 1) * (CONSTANTS.PITSTOP_JITTER_ALONG_MAX or 0)
        local lateral = (math.random() * 2 - 1) * (CONSTANTS.PITSTOP_JITTER_XZ_MAX or 0)
        local height = (math.random() * 2 - 1) * (CONSTANTS.PITSTOP_JITTER_Y_MAX or 0)
        -- Aim tail toward hub (not away)
        local base = firstNode.position + unit * (d + alongJ)
        local pos = base + perp * lateral + Vector3.new(0, height, 0)
        -- Avoid going inside hub by enforcing minimum radius
        local r = (Vector2.new(pos.X, pos.Z)).Magnitude
        local minR = (self.worldConfig and self.worldConfig.HUB and self.worldConfig.HUB.Radius) or 150
        local poiClear = (firstNode.terrainRadius or firstNode.radius or 0) + (CONSTANTS.PITSTOP_RADIUS or 20) + (CONSTANTS.PITSTOP_END_CLEAR_BUFFER or 0)
        local fromPoi = (Vector2.new(pos.X, pos.Z) - Vector2.new(firstNode.position.X, firstNode.position.Z)).Magnitude
        if r > minR + 30 and fromPoi > poiClear then
            self:_createPseudoPOI(pos) -- terrain pitstop
        end
    end

  -- Subdivide an edge (POI A -> POI B) into evenly spaced Pitstops.
  -- Ensures: not too close to POIs, no overlap with each other or existing geometry.
  function SkyIslandGenerator:_addPitstopsAlongEdge(poiA, poiB)
      local startPos = poiA.position
      local endPos = poiB.position
      local vec = endPos - startPos
      local length = vec.Magnitude
      if length <= 0 then return end
      local dir = vec.Unit
      local perp = Vector3.new(-dir.Z, 0, dir.X)
      local R = CONSTANTS.PITSTOP_RADIUS
      local clearA = (poiA.terrainRadius or poiA.radius or 0) + R + (CONSTANTS.PITSTOP_END_CLEAR_BUFFER or 0)
      local clearB = (poiB.terrainRadius or poiB.radius or 0) + R + (CONSTANTS.PITSTOP_END_CLEAR_BUFFER or 0)
      local usable = length - (clearA + clearB)
      local minGap = CONSTANTS.PITSTOP_MIN_GAP or 18
      local minStep = 2 * R + minGap
      local cap = CONSTANTS.PITSTOP_MAX_PER_EDGE or 3
      if cap <= 0 then return end -- per-edge pitstops disabled
      local maxBySpace = (usable > 0) and math.floor(usable / minStep) or 0
      local count
      local step
      if usable > 0 and maxBySpace > 0 then
          count = math.min(maxBySpace, cap)
          step = usable / (count + 1)
      else
          -- Guarantee at least one attempt per edge even in tight spans
          count = 1
          step = 0
      end
      -- Recheck: guarantee step >= minStep
      if step < minStep then
          count = math.max(0, math.floor(usable / minStep))
          if count <= 0 then return end
          step = usable / (count + 1)
      end
      local placed = 0
      for i = 1, count do
          local d = (step ~= 0) and (clearA + step * i) or (length * 0.5)
          local base = startPos + dir * d
          local pos = self:_findClearPitstopPosition(base, dir, perp, poiA, poiB, R, 1.0)
          if pos and self:_createPitstop(pos) then
              placed += 1
          end
      end
      -- Fallback: ensure minimum 1 per edge
      if placed == 0 then
          local mid = startPos + dir * (length * 0.5)
          local pos = self:_findClearPitstopPosition(mid, dir, perp, poiA, poiB, R, 2.5)
          if pos then
              self:_createPitstop(pos)
          end
      end
  end

  -- Clear a horizontal band of terrain by tiling FillBlock calls to avoid extents errors
  function SkyIslandGenerator:_clearSkyTerrainBand(yMin: number, yMax: number, radius: number)
      local terrain = workspace.Terrain
      local centerY = (yMin + yMax) * 0.5
      local height = (yMax - yMin)
      if height <= 0 then return end
      local pad = 200
      local half = radius + pad
      local CHUNK = 1024
      local size = Vector3.new(CHUNK, height + 60, CHUNK)
      local start = -half
      local stop = half
      local x = start
      while x <= stop do
          local z = start
          while z <= stop do
              local cx = math.clamp(x + CHUNK * 0.5, -half, half)
              local cz = math.clamp(z + CHUNK * 0.5, -half, half)
              terrain:FillBlock(CFrame.new(cx, centerY, cz), size, Enum.Material.Air)
              z += CHUNK
          end
          x += CHUNK
      end
  end

  -- Try multiple jittered positions to find a collision-free pitstop placement near the edge
  function SkyIslandGenerator:_findClearPitstopPosition(base: Vector3, dir: Vector3, perp: Vector3, poiA, poiB, R: number, ampFactor: number?)
      local alongJMax = (CONSTANTS.PITSTOP_JITTER_ALONG_MAX or 14)
      local latMax = (CONSTANTS.PITSTOP_JITTER_XZ_MAX or 28) * (ampFactor or 1.0)
      local yMax = (CONSTANTS.PITSTOP_JITTER_Y_MAX or 12) * (ampFactor or 1.0)
      local minA = (poiA.terrainRadius or poiA.radius or 0) + R + (CONSTANTS.PITSTOP_END_CLEAR_BUFFER or 0)
      local minB = (poiB.terrainRadius or poiB.radius or 0) + R + (CONSTANTS.PITSTOP_END_CLEAR_BUFFER or 0)
      local aXZ = Vector2.new(poiA.position.X, poiA.position.Z)
      local bXZ = Vector2.new(poiB.position.X, poiB.position.Z)
      -- Expand lateral attempts gradually and try both sides
      local attempts = 16
      for pass = 1, attempts do
          local amp = latMax * (0.25 + 0.12 * pass)
          for side = -1, 1, 2 do
              local alongJ = (math.random() * 2 - 1) * alongJMax
              local lateral = side * amp
              local height = (math.random() * 2 - 1) * yMax
              local candidate = base + dir * alongJ + perp * lateral + Vector3.new(0, height, 0)
              local pXZ = Vector2.new(candidate.X, candidate.Z)
              if (pXZ - aXZ).Magnitude > minA and (pXZ - bXZ).Magnitude > minB then
                  if not self:_checkCollision(candidate, R * 1.1) then
                      return candidate
                  end
              end
          end
      end
      return nil
  end
  
  -- Utility: spawn a simple street light (upside-down L)
    function SkyIslandGenerator:_spawnStreetLight(pos: Vector3, parent: Instance?, suffix: string?)
        local root = self:_ensureRoots()
        local folder = Instance.new("Folder")
        folder.Name = "StreetLight_" .. (suffix or "")
        folder.Parent = parent or root
        folder:SetAttribute("IsConstellation", true)
      self:_tagConstellationContent(folder, "StreetLight")
      local pole = Instance.new("Part")
      pole.Name = "Pole"
      pole.Size = Vector3.new(0.5, 10, 0.5)
      pole.Anchored = true
      pole.Material = Enum.Material.Metal
      pole.BrickColor = BrickColor.new("Black")
      pole.CFrame = CFrame.new(pos + Vector3.new(0, pole.Size.Y/2, 0))
      pole.Parent = folder
      local arm = Instance.new("Part")
      arm.Name = "Arm"
      arm.Size = Vector3.new(6, 0.4, 0.4)
      arm.Anchored = true
      arm.Material = Enum.Material.Metal
      arm.BrickColor = BrickColor.new("Black")
      arm.CFrame = CFrame.new(pole.Position + Vector3.new(arm.Size.X/2, pole.Size.Y/2 - 0.4, 0))
      arm.Parent = folder
      local lamp = Instance.new("Part")
      lamp.Name = "Lamp"
      lamp.Size = Vector3.new(1.2, 1.2, 1.2)
      lamp.Anchored = true
      lamp.Material = Enum.Material.Neon
      lamp.BrickColor = BrickColor.new("New Yeller")
      lamp.CFrame = CFrame.new(arm.Position + Vector3.new(arm.Size.X/2, -0.8, 0))
      lamp.Parent = folder
      local light = Instance.new("PointLight")
      light.Brightness = 2.2
      light.Range = 32
      light.Color = Color3.fromRGB(255, 230, 180)
      light.Parent = lamp
      return folder
  end

  -- Also add a short fragmented path from the first node toward the hub
  do
      local hubRadius = (self.worldConfig and self.worldConfig.HUB and self.worldConfig.HUB.Radius) or 150
      local firstXZ = Vector2.new(firstNode.position.X, firstNode.position.Z)
      local hubXZ = Vector2.new(hubPos.X, hubPos.Z)
      local distXZ = (hubXZ - firstXZ).Magnitude
      local maxReach = math.min(CONSTANTS.TAIL_MAX_LENGTH, math.max(0, distXZ - hubRadius - 60))
      if maxReach > 30 then
          local tailTarget = {
              id = firstNode.id .. "_Tail",
              position = firstNode.position + unit * maxReach,
          }
          -- Temporarily reduce path segments for tail
          local originalCount = CONSTANTS.PATH_SEGMENT_COUNT
          local desired = math.max(2, math.floor(CONSTANTS.TAIL_PATH_SEGMENTS))
          CONSTANTS.PATH_SEGMENT_COUNT = desired
          local segments = self:_createFragmentedPath(firstNode, tailTarget)
          CONSTANTS.PATH_SEGMENT_COUNT = originalCount
          if segments and #segments > 0 then
              for _, seg in ipairs(segments) do
                  table.insert(self.pathSegments, seg)
                  if self.queueSystem then
                      self.queueSystem:Add(function() self:_generatePathSegmentModel(seg) end, "TailSeg_" .. seg.id, 2)
                  else
                      self:_generatePathSegmentModel(seg)
                  end
              end
          end
      end
  end
end

-- Generate physical model for a path segment
    function SkyIslandGenerator:_generatePathSegmentModel(segment)
        if segment.generated then return end

        local root = self:_ensureRoots()
        local segmentFolder = Instance.new("Folder")
        segmentFolder.Name = "PathSegment_" .. segment.id
        segmentFolder.Parent = root
        segmentFolder:SetAttribute("IsConstellation", true)
        self:_tagConstellationContent(segmentFolder, "PathSegment")

        if segment.segmentType == "organic" then
            local rock = Instance.new("Part")
            rock.Name = "RockChunk"
            rock.Size = Vector3.new(
                math.max(3, math.floor(segment.size / 2)),
                math.max(2, math.floor(segment.size / 3)),
                math.max(6, segment.size)
            )
            rock.CFrame = segment.rotation
            rock.Material = Enum.Material.Rock
            rock.BrickColor = BrickColor.new("Dark stone grey")
            rock.Anchored = true
            rock.Parent = segmentFolder

        elseif segment.segmentType == "lootable" then
            local platform = Instance.new("Part")
            platform.Name = "LootPlatform"
            platform.Size = Vector3.new(segment.size, 2, segment.size)
            platform.CFrame = segment.rotation
            platform.Material = Enum.Material.Concrete
            platform.BrickColor = BrickColor.new("Medium stone grey")
            platform.Anchored = true
            platform.Parent = segmentFolder

            local barrel = Instance.new("Part")
            barrel.Name = "LootBarrel"
            barrel.Size = Vector3.new(3, 4, 3)
            barrel.Shape = Enum.PartType.Cylinder
            barrel.Position = platform.Position + Vector3.new(0, 3, 0)
            barrel.Material = Enum.Material.Metal
            barrel.BrickColor = BrickColor.new("Rust")
            barrel.Anchored = true
            barrel.Parent = segmentFolder

        elseif segment.segmentType == "long_bridge" then
            local assetsEnabled = (CONSTANTS.USE_BRIDGE_ASSETS ~= false)
            local bridgePlaced = false
            local center = segment.rotation.Position

            if self.bridgeService and assetsEnabled then
                local halfLength = segment.size * 0.5
                local lookVector = segment.rotation.LookVector
                local startPos = center - lookVector * halfLength
                local endPos = center + lookVector * halfLength

                local bridge = self.bridgeService:CreateBridge({
                    startPos = startPos,
                    endPos = endPos,
                    orientation = segment.rotation,
                    parent = segmentFolder,
                })

                if bridge then
                    bridge.Name = "LongBridge_" .. segment.id
                    bridge:SetAttribute("SegmentId", segment.id)
                    bridgePlaced = true

                    if CONSTANTS.LIGHTS_ON_SEGMENTS then
                        local offset = (CONSTANTS.BRIDGE_WIDTH or 16) * 0.4
                        local lightPos = center + segment.rotation.RightVector * offset + Vector3.new(0, 3, 0)
                        self:_spawnStreetLight(lightPos, segmentFolder, segment.id)
                    end
                else
                    warn(string.format(
                        "[SkyIslandGenerator] BridgeMeshService failed for long_bridge id=%s, using fallback",
                        segment.id
                    ))
                end
            end

            if not bridgePlaced then
                local bridgePart = Instance.new("Part")
                bridgePart.Name = "LongBridge"
                bridgePart.Size = Vector3.new(CONSTANTS.BRIDGE_WIDTH, CONSTANTS.BRIDGE_THICKNESS, segment.size)
                bridgePart.CFrame = segment.rotation
                bridgePart.Material = Enum.Material.Wood
                bridgePart.BrickColor = BrickColor.new("Brown")
                bridgePart.Anchored = true
                bridgePart.TopSurface = Enum.SurfaceType.Smooth
                bridgePart.BottomSurface = Enum.SurfaceType.Smooth
                bridgePart.Parent = segmentFolder
            end

        elseif segment.segmentType == "bridge_beam" then
            local length = segment.size * (segment.lengthMult or 8)
            local assetsEnabled = (CONSTANTS.USE_BRIDGE_ASSETS ~= false)
            local bridgePlaced = false
            local center = segment.position or segment.rotation.Position

            if self.bridgeService and assetsEnabled then
                local forward = segment.rotation.LookVector
                local halfLength = length * 0.5
                local startPos = center - forward * halfLength
                local endPos = center + forward * halfLength

                local bridge = self.bridgeService:CreateBridge({
                    startPos = startPos,
                    endPos = endPos,
                    orientation = segment.rotation,
                    parent = segmentFolder,
                })

                if bridge then
                    bridge.Name = "BridgeBeam_" .. segment.id
                    bridge:SetAttribute("SegmentId", segment.id)
                    bridgePlaced = true

                    if CONSTANTS.LIGHTS_ON_SEGMENTS then
                        local offset = (CONSTANTS.BRIDGE_WIDTH or 16) * 0.4
                        local lightPos = center + segment.rotation.RightVector * offset + Vector3.new(0, 3, 0)
                        self:_spawnStreetLight(lightPos, segmentFolder, segment.id)
                    end
                else
                    warn(string.format(
                        "[SkyIslandGenerator] BridgeMeshService failed for bridge_beam id=%s, using fallback",
                        segment.id
                    ))
                end
            end

            if not bridgePlaced then
                local plank = Instance.new("Part")
                plank.Name = "BridgePlank"
                plank.Material = Enum.Material.Wood
                plank.BrickColor = BrickColor.new("Brown")
                plank.Anchored = true
                local width = (CONSTANTS.BRIDGE_WIDTH or 16)
                local thickness = (CONSTANTS.BRIDGE_THICKNESS or 2)
                local maxRatio = (CONSTANTS.BRIDGE_MAX_WIDTH_TO_THICKNESS or 2.0)
                if (width / math.max(thickness, 1e-3)) > maxRatio then
                    thickness = width / maxRatio
                end
                plank.Size = Vector3.new(width, thickness, length)
                plank.CFrame = segment.rotation
                plank.Parent = segmentFolder

                if CONSTANTS.LIGHTS_ON_SEGMENTS then
                    local offset = width * 0.4
                    local lightPos = segment.rotation.Position + segment.rotation.RightVector * offset + Vector3.new(0, 3, 0)
                    self:_spawnStreetLight(lightPos, segmentFolder, segment.id)
                end
            end
        end

        segment.generated = true
        CollectionService:AddTag(segmentFolder, "PathSegment")
    end


  -- Phase 3: Generate filler islands (tiny only; pitstops are placed via path subdivision)
  function SkyIslandGenerator:_generateFillerIslands()
    print("[SkyIslandGenerator] Phase 3: Generating filler islands")
    
    local tinyCount = 0
    
    -- Generate filler islands near POIs
    for _, poi in ipairs(self.pois) do
      self:_generateFillerNearElement(poi, "POI", tinyCount, 0)
    end
    
    -- Generate filler islands near path segments
    for _, segment in ipairs(self.pathSegments) do
      self:_generateFillerNearElement(segment, "PathSegment", tinyCount, 0)
    end
    
    print(string.format("[SkyIslandGenerator] Generated %d tiny islands (pitstops handled via subdivision)", #self.tinyIslands))
  end

  -- Generate filler islands near a specific element (POI or path segment)
  function SkyIslandGenerator:_generateFillerNearElement(element, elementType, tinyCount, mediumCount)
    -- Only decorate around connected POIs or existing path segments
    if elementType == "POI" then
        local conn = element.connections
        if not conn or #conn == 0 then
            return
        end
    end

    local basePos = element.position
    local spawnRadius = CONSTANTS.FILLER_SPAWN_DISTANCE
    
      -- Generate tiny filler islands around each element (sparser, broader area)
      local fillerCount = math.random(CONSTANTS.TINY_FILLER_COUNT_MIN or 3, CONSTANTS.TINY_FILLER_COUNT_MAX or 6)
    
    for i = 1, fillerCount do
        -- Random chance to spawn filler
        if math.random() < CONSTANTS.FILLER_DENSITY then
            -- Random position around the element
            local angle = math.random() * math.pi * 2
              local distance = math.random(math.floor(spawnRadius * 0.4), spawnRadius)
              local heightVar = CONSTANTS.TINY_HEIGHT_VARIATION or 60
              local height = basePos.Y + math.random(-heightVar, heightVar)
            
            local fillerPos = basePos + Vector3.new(
                math.cos(angle) * distance,
                height - basePos.Y,
                math.sin(angle) * distance
            )
            
      -- Only tiny filler islands here; pitstops are created via path subdivision
      self:_createTinyIsland(fillerPos, tinyCount)
        end
    end
end

-- Create tiny filler island
function SkyIslandGenerator:_createTinyIsland(position, tinyCount)
    local radius = CONSTANTS.TINY_ISLAND_RADIUS
    
    -- Check collision
    if self:_checkCollision(position, radius * 2) then
        return false
    end
    
    local tinyIsland = {
        id = "TinyIsland_" .. (#self.tinyIslands + 1),
        position = position,
        radius = radius * 2,  -- Use expanded radius for collision detection
        terrainRadius = radius,  -- Actual terrain radius
        height = CONSTANTS.TINY_ISLAND_HEIGHT,
        generated = false
    }
    
    table.insert(self.tinyIslands, tinyIsland)
    self:_addToSpatialHash(position, radius * 2, tinyIsland)
    
    -- Queue generation
    if self.queueSystem then
        self.queueSystem:Add(function()
            self:_generateTinyIslandModel(tinyIsland)
        end, "TinyIsland_" .. tinyIsland.id, 3)
    else
        self:_generateTinyIslandModel(tinyIsland)
    end
    
    return true
end

  -- Create Pitstop (large terrain diamond island)
  function SkyIslandGenerator:_createPitstop(position)
      local radius = CONSTANTS.PITSTOP_RADIUS
      -- Check collision
      if self:_checkCollision(position, radius * 2) then
          return false
      end
      local pit = {
          id = "Pitstop_" .. (#self.pitstops + 1),
          position = position,
          radius = radius * 2,       -- Collision radius budget
          terrainRadius = radius,    -- Visual/platform width
          bottomFactor = CONSTANTS.PITSTOP_BOTTOM_FACTOR,
          generated = false,
      }
      table.insert(self.pitstops, pit)
      self:_addToSpatialHash(position, radius * 2, pit)
      if self.queueSystem then
          self.queueSystem:Add(function()
              self:_generatePitstopModel(pit)
          end, pit.id, 2)
      else
          self:_generatePitstopModel(pit)
      end
      return true
  end

-- Generate tiny island model (small diamond terrain)
  function SkyIslandGenerator:_generateTinyIslandModel(island)
      if island.generated then return end
      local terrain = workspace.Terrain
      local R = island.terrainRadius or island.radius / 2
      local p = island.position
      local bottomFactor = CONSTANTS.TINY_BOTTOM_FACTOR or 1.8
      -- Diamond body (stacked spheres)
      terrain:FillBall(p + Vector3.new(0, 0.30 * R, 0), 0.55 * R, Enum.Material.Rock)
      terrain:FillBall(p, R, Enum.Material.Rock)
      terrain:FillBall(p + Vector3.new(0, -0.80 * R, 0), 0.75 * R, Enum.Material.Rock)
      terrain:FillBall(p + Vector3.new(0, -1.50 * R * bottomFactor / 2.0, 0), 0.40 * R, Enum.Material.Rock)
      -- Flatten top via carve-first near the dome peak, then refill a thinner level slab
      local flatScale = CONSTANTS.TINY_TOP_FLAT_SCALE_XZ or 0.9
      local carveThick = (CONSTANTS.TINY_TOP_FLAT_THICKNESS or 0.18) * R * 2.8 -- deep carve to remove dome
      local fillThick = (CONSTANTS.TINY_TOP_FLAT_THICKNESS or 0.18) * R
      local carveCenterY = 0.95 * R  -- carve close to top
      local fillCenterY = 0.85 * R   -- refill slightly below to create a flat plateau
      local carveSize = Vector3.new(2 * R * flatScale, carveThick, 2 * R * flatScale)
      local fillSize = Vector3.new(2 * R * flatScale, fillThick, 2 * R * flatScale)
      terrain:FillBlock(CFrame.new(p + Vector3.new(0, carveCenterY, 0)), carveSize, Enum.Material.Air)
      terrain:FillBlock(CFrame.new(p + Vector3.new(0, fillCenterY, 0)), fillSize, Enum.Material.Ground)
      
      -- Optional street light
      if (CONSTANTS.LIGHTS_ON_TINY) then
          local topY = p.Y + (0.85 * R) + ((CONSTANTS.TINY_TOP_FLAT_THICKNESS or 0.18) * R * 0.5) + 2
          self:_spawnStreetLight(Vector3.new(p.X, topY, p.Z), workspace, island.id)
      end
      -- Record marker for precise cleanup later with generous bounding box
      local size = R * 6 -- INCREASED: More generous bounds for diamond shapes (was 4)
      local preciseRegion = Region3.new(
          p - Vector3.new(size/2, size/2, size/2),
          p + Vector3.new(size/2, size/2, size/2)
      )
      self:_recordTerrainIsland("Tiny", island.id or tostring(#self.tinyIslands), p, R, preciseRegion)
      island.generated = true
      print(string.format("[SkyIslandGenerator] Generated tiny diamond island %s at %s", island.id, tostring(island.position)))
  end

  -- Generate Pitstop model: terrain diamond (bottom elongated)
    function SkyIslandGenerator:_generatePitstopModel(pit)
        if pit.generated then return end
        local terrain = workspace.Terrain
        local R = pit.terrainRadius or (pit.radius / 2)
        local bottomFactor = pit.bottomFactor or 2.0
        local p = pit.position
      -- Build a diamond-like shape with stacked spheres, elongated downward
      -- Top cap
      terrain:FillBall(p + Vector3.new(0, 0.40 * R, 0), 0.60 * R, Enum.Material.Rock)
      -- Core
      terrain:FillBall(p, R, Enum.Material.Rock)
      -- Downward taper (3 steps)
      terrain:FillBall(p + Vector3.new(0, -0.70 * R, 0), 0.90 * R, Enum.Material.Rock)
      terrain:FillBall(p + Vector3.new(0, -1.45 * R, 0), 0.65 * R, Enum.Material.Rock)
      terrain:FillBall(p + Vector3.new(0, -2.10 * R * math.clamp(bottomFactor, 1.2, 2.5) / 2.0, 0), 0.35 * R, Enum.Material.Rock)
      -- Flatten top via carve-first to remove dome peak, then refill a thinner level slab
      local plateScale = CONSTANTS.PITSTOP_TOP_FLAT_SCALE_XZ or 1.2
      local carveThick = (CONSTANTS.PITSTOP_TOP_FLAT_THICKNESS or 0.22) * R * 3.2 -- deeper carve to guarantee flat top
      local fillThick = (CONSTANTS.PITSTOP_TOP_FLAT_THICKNESS or 0.22) * R
      local carveCenterY = 0.95 * R  -- carve near the topmost region
      local fillCenterY = 0.85 * R   -- refill slightly below to form plateau
      local carveSize = Vector3.new(2 * R * plateScale, carveThick, 2 * R * plateScale)
      local fillSize = Vector3.new(2 * R * plateScale, fillThick, 2 * R * plateScale)
      terrain:FillBlock(CFrame.new(p + Vector3.new(0, carveCenterY, 0)), carveSize, Enum.Material.Air)
      terrain:FillBlock(CFrame.new(p + Vector3.new(0, fillCenterY, 0)), fillSize, Enum.Material.Ground)
      -- Optional street light on plateau
      if (CONSTANTS.LIGHTS_ON_PITSTOPS) then
          local topY = p.Y + (0.85 * R) + ((CONSTANTS.PITSTOP_TOP_FLAT_THICKNESS or 0.22) * R * 0.5) + 2
          self:_spawnStreetLight(Vector3.new(p.X, topY, p.Z), nil, pit.id)
      end
      -- Record marker for precise cleanup later with generous bounding box
      local size = R * 6 -- INCREASED: More generous bounds for diamond shapes (was 4)
      local preciseRegion = Region3.new(
          p - Vector3.new(size/2, size/2, size/2),
          p + Vector3.new(size/2, size/2, size/2)
      )
      self:_recordTerrainIsland("Pitstop", pit.id or tostring(#self.pitstops), p, R, preciseRegion)
      pit.generated = true
      print(string.format("[SkyIslandGenerator] Generated pitstop %s at %s (R=%.1f)", pit.id, tostring(pit.position), R))
  end

-- Phase 4: Generate terrain for all remaining POIs
function SkyIslandGenerator:_generateAllTerrain()
    print("[SkyIslandGenerator] Phase 4: Generating terrain for all POIs")
    
    local terrainCount = 0
    for _, poi in ipairs(self.pois) do
        if not poi.terrainGenerated then
            if self.queueSystem then
                self.queueSystem:Add(function()
                    self:_generatePOITerrain(poi)
                end, "POI_Terrain_Final_" .. poi.id, 1) -- High priority
            else
                self:_generatePOITerrain(poi)
            end
            terrainCount = terrainCount + 1
        end
    end
    
    print(string.format("[SkyIslandGenerator] Queued terrain generation for %d POIs", terrainCount))
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
        self:_generatePOIs()
        print(string.format("[SkyIslandGenerator] Phase 1 complete: %d POIs generated", #self.pois))
        wait(0.1)
        
        -- Phase 2: Generate fragmented parkour paths
        print("[SkyIslandGenerator] Starting Phase 2: Parkour Path Generation")
        self:_generateParkourPaths()
        print(string.format("[SkyIslandGenerator] Phase 2 complete: %d path segments generated", #self.pathSegments))
        wait(0.1)
        
        -- Phase 3: Generate filler islands
        print("[SkyIslandGenerator] Starting Phase 3: Filler Island Generation")
        self:_generateFillerIslands()
      print(string.format("[SkyIslandGenerator] Phase 3 complete: %d tiny islands generated", #self.tinyIslands))
        wait(0.1)
        
        -- Phase 4: Generate terrain for all islands (not just POIs)
        print("[SkyIslandGenerator] Starting Phase 4: Terrain Generation")
        self:_generateAllTerrain()
        print("[SkyIslandGenerator] Phase 4 complete")
        
        self.isGenerating = false
        print("[SkyIslandGenerator] Sky island network generation complete!")
      print(string.format("[SkyIslandGenerator] Final stats: %d POIs, %d path segments, %d tiny islands, %d pitstops", #self.pois, #self.pathSegments, #self.tinyIslands, #self.pitstops))
        -- Final debug report to explain topology tendencies
        self:_debugFinalReport()
        
        -- Fire completion event if needed
        if self.onGenerationComplete then
            self.onGenerationComplete()
        end
    end)()
end

-- Debug visualization
  function SkyIslandGenerator:DebugVisualize()
    local debugFolder = workspace:FindFirstChild("SkyIslandDebug") or Instance.new("Folder")
    debugFolder.Name = "SkyIslandDebug"
    debugFolder.Parent = workspace
    
    -- Clear existing debug visuals
    debugFolder:ClearAllChildren()
    
    -- Visualize POI no-build zones
    for _, poi in ipairs(self.pois) do
        local sphere = Instance.new("Part")
        sphere.Name = poi.id .. "_NoBuildZone"
        sphere.Shape = Enum.PartType.Ball
        sphere.Size = Vector3.one * poi.noBuildRadius * 2
        sphere.Position = poi.position
        sphere.Material = Enum.Material.ForceField
        sphere.BrickColor = BrickColor.new("Really red")
        sphere.Transparency = 0.8
        sphere.CanCollide = false
        sphere.Anchored = true
        sphere.Parent = debugFolder
    end
    
    -- Visualize path segments
    for _, segment in ipairs(self.pathSegments) do
        local marker = Instance.new("Part")
        marker.Name = "PathSegment_" .. segment.id
        marker.Size = Vector3.new(4, 4, 4)
        marker.Position = segment.position + Vector3.new(0, 10, 0)
        marker.Material = Enum.Material.Neon
        marker.BrickColor = BrickColor.new("Bright blue")
        marker.Transparency = 0.3
        marker.CanCollide = false
        marker.Anchored = true
        marker.Parent = debugFolder
    end
    
    -- Visualize tiny islands
    for _, tiny in ipairs(self.tinyIslands) do
        local marker = Instance.new("Part")
        marker.Name = "TinyIsland_" .. tiny.id
        marker.Size = Vector3.new(2, 2, 2)
        marker.Position = tiny.position + Vector3.new(0, 5, 0)
        marker.Material = Enum.Material.Neon
        marker.BrickColor = BrickColor.new("Bright green")
        marker.Transparency = 0.5
        marker.CanCollide = false
        marker.Anchored = true
        marker.Parent = debugFolder
    end
    
      -- Visualize pitstops
      for _, pit in ipairs(self.pitstops) do
          local marker = Instance.new("Part")
          marker.Name = "Pitstop_" .. pit.id
          marker.Size = Vector3.new(8, 8, 8)
          marker.Position = pit.position + Vector3.new(0, 10, 0)
          marker.Material = Enum.Material.Neon
          marker.BrickColor = BrickColor.new("Bright yellow")
          marker.Transparency = 0.3
          marker.CanCollide = false
          marker.Anchored = true
          marker.Parent = debugFolder
      end
end

-- Cleanup function - Use enhanced cleanup system
function SkyIslandGenerator:Cleanup()
    print("[SkyIslandGenerator] ===== GENERATOR CLEANUP STARTING =====")
    
    -- Use the enhanced cleanup system for comprehensive removal
    print("[SkyIslandGenerator] Loading enhanced cleanup module...")
    local SkyIslandCleanupEnhanced = require(script.Parent.SkyIslandCleanupEnhanced)
    
    print("[SkyIslandGenerator] Calling enhanced cleanup with worldConfig...")
    local stats = SkyIslandCleanupEnhanced.cleanupAll(self.worldConfig)
    
    print("[SkyIslandGenerator] Enhanced cleanup returned, resetting internal state...")
    
    -- Reset internal state for clean regeneration
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
    
    print("[SkyIslandGenerator] Enhanced cleanup complete, ready for regeneration")
    return stats
end

return SkyIslandGenerator







