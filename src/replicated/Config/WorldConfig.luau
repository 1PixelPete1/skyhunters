-- Central world constants used by transforms & validators.

return {
  EPSILON = 1e-03,                 -- numeric tolerance for comparisons
  HUB = {
    Center = Vector3.new(0, 0, 0),   -- y is ignored for radial checks
    Radius = 150,                    -- hub exclusion radius (studs)
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
      plane_64m = { HalfSize = 32, Revision = 1 }, -- include revision for dedupe keys
      -- Object/piece presets may live here for HalfSize canonicalization via PresetUtil
      lantern_basic = {
        HalfSize = Vector3.new(0.5, 1.0, 0.5), -- canonicalized by PresetUtil anyway
        Mount = "ground",                      -- informative for later
        FootprintRadius = 0.75,                -- optional hint; not used yet
        Revision = 1,
      },
    },
    MainPresetKey = "plane_64m",
    DefaultHeightY = 100,            -- global Y for Phase-1 main islands
    AllowScale = false,              -- Phase-1: fixed scale=1.0 (left here for future)
    
    -- M0.2 toggles and dimensions for SmoothTerrain island
    UseTerrain = true,               -- switch Part → SmoothTerrain
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
}
