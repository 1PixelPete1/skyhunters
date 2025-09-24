-- Central world constants used by transforms & validators.

return {
  EPSILON = 1e-03,                 -- numeric tolerance for comparisons
  HUB = {
    Center = Vector3.new(0, 0, 0),   -- y is ignored for radial checks
    Radius = 150,                    -- hub exclusion radius (studs)
  },
    WORLDGEN = {
      SkyIslands = {
      MinRadius = 300,           -- Regular islands start at 300 studs
      POIMinRadius = 800,       -- INCREASED: POIs must be at least 800 studs from spawn
      MaxRadius = 2500,          -- INCREASED: Extended for far exploration paths
      -- Height behavior (relative to hub Y)
      UseRelativeHeights = true, -- Heights are offsets from hub Y
      HeightOffsetMin = -12,     -- Slightly below spawn near hub
      HeightOffsetMax = 6,       -- Slightly above at far range
      HeightJitter   = 3,        -- Reduce variation (small jitter)
      -- Legacy absolute heights kept for fallback if UseRelativeHeights=false
      MinHeight = 80,            -- (fallback) absolute Y
      MaxHeight = 250,           -- (fallback) absolute Y
      -- NEW: Mixed paths + islands distribution (reduced for better spacing)
      TinyIslandCount = 80,      -- REDUCED: Less cluttered parkour islands
      SmallIslandCount = 25,     -- Fewer small resting spots
      MediumIslandCount = 10,    -- Strategic outposts
      LargeIslandCount = 6,      -- Key waypoints
      POICount = 3,              -- Major objectives (well-separated)
      PathSegmentCount = 8,      -- NEW: Floating bridge segments per tentacle
      MaxGapDistance = 40,       -- Ensure traversability with jump packs
      
      -- NEW: Improved layout patterns
      LayoutMode = "tentacles",  -- "organic" | "tentacles" | "banded"
      
      -- Organic pattern settings
      OrganicClumping = 0.3,     -- Tendency to form clusters (0-1, 0=uniform, 1=highly clustered)
      
      -- Tentacle pattern settings  
      TentacleCount = 4,         -- Cardinal directions (N, E, S, W)
      TentacleWidth = 200,       -- INCREASED: Base width for paths + islands (studs)
      TentacleTaper = 0.7,       -- How much density reduces with distance
      
      -- NEW: Floating path configuration
      PathWidth = 8,             -- Width of floating bridge segments
      PathLength = 60,           -- Length of each bridge segment
      PathHeightVariation = 15,  -- Height variation for bridge paths
      PathLateralVariation = 80, -- Side-to-side wobble strength
      BridgeLengthMult = 8,      -- Bridge plank length multiplier
      
      -- NEW: Enhanced island configuration
      IslandHeightVariation = 25, -- More dramatic height differences for obby feel
      IslandSpacing = 50,        -- Better spacing between islands to prevent overlap
      
      -- Enhanced spacing control (prevents overlaps)
      SpacingBase = 25,          -- INCREASED: Minimum spacing between islands (studs)
      SpacingGrowth = 60,        -- INCREASED: Additional spacing at max radius
      SpacingPower = 1.5,        -- Power curve for spacing growth (1=linear, 2=quadratic)
      
      -- Legacy banded layout settings (kept for compatibility)
      Rings = 10,                -- ring count for banded layout
      AngularJitter = 0.15,      -- fraction of step angle for jitter
      SparsityBase = 10,         -- (legacy) base extra spacing buffer
      SparsityRange = 30,        -- (legacy) additional spacing at max radius
      
      UsePartIslands = true,     -- NEW: Use part-based islands for floating bridges
      -- Cycling/skulk pacing
      RespawnPeriodSec = 450,    -- 7.5 minutes
      SpawnWindowSec  = 15,      -- add islands over ~15s
      Seed = 54321,              -- Deterministic generation
      Lights = { OnPitstops = true, OnSegments = true, OnTiny = false },

      -- Diamond path/pitstop tuning (exposed knobs)
      -- Small sky islands (tiny)
      FillerSpawnDistance = 180,   -- Horizontal radius around elements for tiny islands
      FillerDensity = 0.45,        -- Chance to spawn each candidate tiny island
      TinyIslandRadius = 8,        -- Radius used to build tiny diamond islands
      TinyBottomFactor = 1.8,      -- Bottom elongation factor for diamond
      TinyTopFlatScaleXZ = 0.9,    -- Plateau width scale (relative to R)
      TinyTopFlatThickness = 0.18, -- Plateau thickness scale (relative to R)
      TinyFillerCountMin = 3,      -- Min tiny islands per element
      TinyFillerCountMax = 6,      -- Max tiny islands per element
      TinyHeightVariation = 80,    -- Vertical jitter range for tiny islands

      -- Pitstops (terrain diamonds used along edges and tails)
      PitstopRadius = 22,            -- Size to host small buildings
      PitstopBottomFactor = 2.0,     -- Bottom elongation
      PitstopTopFlatScaleXZ = 1.2,   -- Plateau width scale
      PitstopTopFlatThickness = 0.22,-- Plateau thickness scale
      PitstopMinGap = 18,            -- Minimum gap between pitstops along an edge
      PitstopEndClearBuffer = 12,    -- Extra clearance from POI endpoints
      PitstopMaxPerEdge = 3,         -- Cap per edge
      PitstopJitterXZMax = 28,       -- Max lateral jitter off the edge (studs)
      PitstopJitterAlongMax = 14,    -- Max along-edge jitter (studs)
      PitstopJitterYMax = 12,        -- Max vertical jitter (studs)

      -- Tail configuration
      TailPathSegments = 5,          -- Visual pathing along tail (segments)
      TailMaxLength = 600,           -- Max tail reach
      TailPitstopMin = 1,            -- Randomized tail pitstop count (min)
      TailPitstopMax = 4,            -- Randomized tail pitstop count (max)
      TailStartOffset = 120,         -- Distance from first POI before first tail pitstop
      PseudoTailSpacing = 140,       -- Spacing between tail pitstops
      PseudoHeightVariation = 10,    -- Vertical jitter for pseudo/pitstop nodes
      PseudoEdgeChance = 0.75,       -- Chance to spawn pitstop-along-edge decorations
      PseudoPerEdgeMin = 1,
      PseudoPerEdgeMax = 2,

      -- Sky terrain cleanup band (used on regenerate)
      SkyClearEnabled = false,
      SkyClearYMin = -512,
      SkyClearYMax = 1024,
    },
  },
  PLOTS = {
    Slots = 24,                      -- ring slots around hub
    SlotOffsetYaw = 0,               -- radians; 0 = +X as slot 0 center
    RadialOffset = 150,              -- radial distance from HUB center to slot center (studs)
    MaxQueryRadius = nil,            -- optional: cap validation query radius; nil disables
  },
  ISLANDS = {
    -- preset half-size in local units (studs)
    Presets = {
      plane_64m = { HalfSize = 96, Revision = 1 }, -- Updated to match SizeStuds=192 (half of 192 = 96)
      -- Object/piece presets may live here for HalfSize canonicalization via PresetUtil
      lantern_basic = {
        HalfSize = Vector3.new(0.5, 1.0, 0.5), -- canonicalized by PresetUtil anyway
        Mount = "ground",                      -- informative for later
        FootprintRadius = 0.75,                -- optional hint; not used yet
        LanternType = "Default",               -- NEW: specify which lantern model to use
        Revision = 1,
      },
      lantern_default2 = {
        HalfSize = Vector3.new(0.6, 1.2, 0.6), -- slightly larger footprint
        Mount = "ground",
        FootprintRadius = 0.85,
        LanternType = "Default2",              -- NEW: spherical stacked lantern
        Revision = 1,
      },
      -- Additional lantern presets (tool-driven)
      lantern_advanced = {
        HalfSize = Vector3.new(0.6, 1.2, 0.6),
        Mount = "ground",
        FootprintRadius = 0.85,
        LanternType = "Default2",              -- map advanced to Default2 builder for now
        Revision = 1,
      },
      lantern_crystal = {
        HalfSize = Vector3.new(0.6, 1.2, 0.6),
        Mount = "ground",
        FootprintRadius = 0.85,
        LanternType = "Default2",              -- reuse Default2 visuals until a Crystal type exists
        Revision = 1,
      },
      -- Oil Reservoir presets
      oil_reservoir_small = {
        HalfSize = Vector3.new(1.0, 1.5, 1.0),
        Mount = "ground",
        FootprintRadius = 1.2,
        PlaceableType = "OilReservoir",
        ReservoirSize = "small",
        OilCapacity = 25,
        Revision = 1,
      },
      oil_reservoir_medium = {
        HalfSize = Vector3.new(1.5, 2.0, 1.5),
        Mount = "ground",
        FootprintRadius = 1.8,
        PlaceableType = "OilReservoir",
        ReservoirSize = "medium",
        OilCapacity = 50,
        Revision = 1,
      },
      oil_reservoir_large = {
        HalfSize = Vector3.new(2.0, 2.5, 2.0),
        Mount = "ground",
        FootprintRadius = 2.5,
        PlaceableType = "OilReservoir",
        ReservoirSize = "large",
        OilCapacity = 100,
        Revision = 1,
      },
    },
    MainPresetKey = "plane_64m",
    DefaultHeightY = 1,            -- global Y for Phase-1 main islands
    AllowScale = false,              -- Phase-1: fixed scale=1.0 (left here for future)
    
    -- M0.2 toggles and dimensions for SmoothTerrain island
    UseTerrain = true,               -- switch Part â†’ SmoothTerrain
    SizeStuds = 192,                 -- width/depth of island footprint (larger for testing)
    HeightStuds = 48,                -- terrain slab thickness
    -- M0.3 surface configuration (safe defaults & server maps to Enum.Material)
    TopMaterial = "Ground",          -- acceptable: "Ground","Grass","Mud","Sand" (fallbacks to Ground)
    CoreMaterial = "Rock",           -- interior/edges of slab (fallbacks to Rock)
    TopSkinThickness = 2,            -- thickness of top cap in studs
    EnableDecorations = false,       -- drives workspace.Terrain.Decoration
    Pond = {
      Radius = 15,                   -- inner water radius (studs)
      Depth = 2,                     -- water depth from island top (studs)
      Offset = Vector3.new(0, 0, 0), -- local offset of pond center
    },
  },
  POI = {
    DUNGEON_ISLAND_RADIUS = 150,        -- Larger for bigger rooms
    DUNGEON_GRID_SIZE = 5,              -- 5x5 grid max
    ROOM_SIZE = 60,                     -- 40 studs per room (bigger for mobility)
    ROOM_HEIGHT = 30,                   -- Taller ceilings
    DUNGEON_SPAWN_CHANCE = 0.3,         -- 30% of POIs are dungeons
    MAX_ROOMS_SMALL = 3,                -- Small dungeon size
    MAX_ROOMS_MEDIUM = 5,               -- Medium dungeon size
    MAX_ROOMS_LARGE = 7,                -- Large dungeon size
    DOORWAY_WIDTH = 8,                  -- Width of doorway openings
    DOORWAY_HEIGHT = 10,                -- Height of doorway openings
    WALL_THICKNESS = 2,                 -- Wall thickness
  },
}

