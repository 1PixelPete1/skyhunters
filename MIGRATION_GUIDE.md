# SkyIslandGenerator Bridge Mesh Migration Guide

## Quick Fix (Minimal Changes)

If you want the quickest fix without major refactoring, follow these steps:

### Step 1: Add BridgeMeshService
Copy `BridgeMeshService.luau` to `src/server/Worldgen/`

### Step 2: Update SkyIslandGenerator.luau

#### At the top, add this require:
```lua
local BridgeMeshService = require(script.Parent.BridgeMeshService)
```

#### In SkyIslandGenerator.new(), after line ~340 (after self initialization), add:
```lua
-- Initialize bridge service with ModelRegistry configs
if ModelRegistry and ModelRegistry.GetBridgeMeshConfigs then
    local bridgeConfigs = ModelRegistry:GetBridgeMeshConfigs()
    if #bridgeConfigs > 0 then
        self.bridgeService = BridgeMeshService.new(bridgeConfigs)
    else
        -- Use defaults if no configs in registry
        self.bridgeService = BridgeMeshService.new()
    end
else
    self.bridgeService = BridgeMeshService.new()
end
```

#### Replace the bridge_beam section in _generatePathSegmentModel (around line 1600-1700):

Find this code block:
```lua
elseif segment.segmentType == "bridge_beam" then
    -- Oriented bridge plank; prefer mesh assets if configured, else Catalog model, else fallback Part
    local length = segment.size * (segment.lengthMult or 8)
    -- [LOTS OF CODE HERE]
```

Replace the ENTIRE `elseif segment.segmentType == "bridge_beam" then` block with:
```lua
elseif segment.segmentType == "bridge_beam" then
    -- Bridge plank segment using BridgeMeshService
    local length = segment.size * (segment.lengthMult or 8)
    
    if self.bridgeService and CONSTANTS.USE_BRIDGE_ASSETS then
        -- Calculate positions for the bridge segment
        local forward = segment.rotation.LookVector
        local startPos = segment.position - forward * (length/2)
        local endPos = segment.position + forward * (length/2)
        
        local bridge = self.bridgeService:CreateBridge({
            startPos = startPos,
            endPos = endPos,
        })
        
        if bridge then
            bridge.Parent = segmentFolder
            print(string.format("[SkyIslandGenerator] Created bridge_beam using BridgeMeshService: %s", segment.id))
            
            -- Add optional lighting
            if CONSTANTS.LIGHTS_ON_SEGMENTS then
                local lightPos = segment.position + Vector3.new(
                    (CONSTANTS.BRIDGE_WIDTH or 16) * 0.4, 
                    3, 
                    0
                )
                self:_spawnStreetLight(lightPos, segmentFolder, segment.id)
            end
        else
            -- Fallback to simple wooden plank
            warn("[SkyIslandGenerator] BridgeMeshService failed for bridge_beam, using fallback")
            local plank = Instance.new("Part")
            plank.Name = "BridgePlank_Fallback"
            plank.Material = Enum.Material.Wood
            plank.BrickColor = BrickColor.new("Brown")
            plank.Anchored = true
            local width = CONSTANTS.BRIDGE_WIDTH or 16
            local thickness = CONSTANTS.BRIDGE_THICKNESS or 2
            plank.Size = Vector3.new(width, thickness, length)
            plank.CFrame = segment.rotation
            plank.Parent = segmentFolder
        end
    else
        -- Use simple wooden plank when assets are disabled
        local plank = Instance.new("Part")
        plank.Name = "BridgePlank"
        plank.Material = Enum.Material.Wood
        plank.BrickColor = BrickColor.new("Brown")
        plank.Anchored = true
        local width = CONSTANTS.BRIDGE_WIDTH or 16
        local thickness = CONSTANTS.BRIDGE_THICKNESS or 2
        plank.Size = Vector3.new(width, thickness, length)
        plank.CFrame = segment.rotation
        plank.Parent = segmentFolder
        
        if CONSTANTS.LIGHTS_ON_SEGMENTS then
            local lightPos = plank.Position + Vector3.new(width * 0.4, 3, 0)
            self:_spawnStreetLight(lightPos, segmentFolder, segment.id)
        end
    end
```

### Step 3: Update ModelRegistry.luau
Replace your existing ModelRegistry.luau with the updated version provided, or manually add the mesh configurations to your BRIDGE_MESHES table.

### Step 4: Configure Your Mesh IDs
In ModelRegistry.luau, update the mesh IDs with your actual asset IDs:
```lua
ModelRegistry.BRIDGE_MESHES = {
    wooden_plank = {
        meshId = YOUR_WOODEN_MESH_ID,  -- Replace with actual ID
        baseScale = Vector3.new(0.04, 0.04, 0.04),
        maxStretch = 1.5,
        weight = 60,
        material = Enum.Material.Wood,
        color = Color3.fromRGB(139, 90, 43),
    },
    -- Add more bridge types...
}
```

## Testing Your Changes

1. Start a test place
2. Run this in the command bar to test bridges directly:
```lua
local BridgeMeshService = require(game.ServerScriptService.Server.Worldgen.BridgeMeshService)
local service = BridgeMeshService.new()
local bridge = service:CreateBridge({
    startPos = Vector3.new(0, 100, 0),
    endPos = Vector3.new(100, 100, 0)
})
```

3. Or use the provided TestBridgeMeshService.server.luau for comprehensive testing

## What This Fixes

✅ **Proper Scaling**: Meshes are now scaled to 0.04 base scale as intended
✅ **No Distortion**: Maximum stretch of 1.5x prevents warping
✅ **Automatic Tiling**: Long bridges automatically tile to avoid over-stretching
✅ **Multiple Bridge Types**: Supports weighted random selection of different bridges
✅ **Robust Fallbacks**: Falls back to simple parts if meshes fail to load

## Common Issues & Solutions

### Issue: Meshes appear as gray boxes
**Solution**: Check that your mesh IDs are correct and the assets are public/uncopylocked

### Issue: Bridges still look stretched
**Solution**: Reduce maxStretch value in the config (try 1.2 or 1.3)

### Issue: Only one type of bridge spawns
**Solution**: Check the weight values in ModelRegistry - ensure different types have reasonable weights

### Issue: BridgeMeshService not found
**Solution**: Ensure BridgeMeshService.luau is in src/server/Worldgen/ folder

## Advanced Configuration

For area-specific bridge types, you can modify the bridge service initialization:
```lua
-- In specific generation areas, use different configs
if currentArea == "Fantasy" then
    self.bridgeService = BridgeMeshService.new({
        {
            meshId = "CRYSTAL_BRIDGE_ID",
            baseScale = Vector3.new(0.04, 0.04, 0.04),
            maxStretch = 1.2,
            weight = 100,
            name = "CrystalBridge",
            material = Enum.Material.ForceField,
            color = Color3.fromRGB(150, 200, 255),
        }
    })
end
```

## Performance Notes

- Meshes are cached after first load for better performance
- Tiling only creates necessary segments based on length
- CollisionFidelity is set to Box for optimal physics performance
- Consider calling `bridgeService:ClearCache()` during cleanup
