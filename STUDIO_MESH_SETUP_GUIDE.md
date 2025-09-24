# Studio Mesh Setup Guide for Bridge System

## The Problem
When you upload meshes via Studio's "Import 3D" feature, they often:
- Are not public/accessible via InsertService
- Don't have proper asset IDs yet
- Can't be loaded using `CreateMeshPartAsync`

## Solution: Three Methods

### Method 1: Catalog Model (Recommended)
This is the most reliable method for Studio-uploaded meshes.

**Steps:**
1. Import your bridge mesh using Studio's Import 3D
2. Create this folder structure if it doesn't exist:
   ```
   ReplicatedStorage/
     Shared/
       Catalog/
         Models/
           bridge_pone_1  (your mesh here)
   ```
3. Name your mesh `bridge_pone_1` (or update the config to match your name)
4. The BridgeMeshService will automatically find and use it

**Config Example:**
```lua
{
    meshId = "bridge_pone_1",  -- Name in Catalog/Models
    baseScale = Vector3.new(0.04, 0.04, 0.04),
    maxStretch = 1.5,
    weight = 60,
    name = "WoodenBridge",
    material = Enum.Material.Wood,
    color = Color3.fromRGB(139, 90, 43),
    useCatalogModel = true,  -- Important!
}
```

### Method 2: Direct Workspace Reference
For quick testing without moving meshes around.

**Steps:**
1. Import your bridge mesh
2. Place it in a folder called `BridgeMeshes` in Workspace
3. Use the `AddMeshFromWorkspace` method:

```lua
local bridgeService = BridgeMeshService.new()
local meshFolder = workspace.BridgeMeshes

for _, mesh in ipairs(meshFolder:GetChildren()) do
    if mesh:IsA("MeshPart") then
        bridgeService:AddMeshFromWorkspace(mesh, "Custom_" .. mesh.Name, 50)
    end
end
```

### Method 3: Fallback Part System
If meshes fail to load, the system automatically uses simple Parts.

**Config Example:**
```lua
{
    meshId = nil,  -- No mesh, will use Part
    baseScale = Vector3.new(1, 1, 1),
    maxStretch = 2.0,
    weight = 40,
    name = "SimplePlank",
    material = Enum.Material.WoodPlanks,
    color = Color3.fromRGB(160, 100, 50),
}
```

## Mesh Requirements

### Size Guidelines
- **Length (Z axis)**: 10-30 studs
- **Width (X axis)**: 8-16 studs  
- **Height (Y axis)**: 1-3 studs
- **Pivot**: Center of the mesh

### Properties
- **Anchored**: true
- **CanCollide**: true
- **Material**: Any (will be overridden by config)
- **Color**: Any (will be overridden by config)

### Import Settings
When using Import 3D:
1. Keep "Import as single mesh" checked if it's one piece
2. Set appropriate scale during import
3. Center the pivot point

## Testing Your Setup

Run this in the command bar to test:
```lua
-- Quick test
local BridgeMeshService = require(game.ServerScriptService.Server.Worldgen.BridgeMeshService)
local service = BridgeMeshService.new()

-- Check if Catalog models are found
local shared = game.ReplicatedStorage:FindFirstChild("Shared")
local catalog = shared and shared:FindFirstChild("Catalog")
local models = catalog and catalog:FindFirstChild("Models")

if models then
    print("Found models:", #models:GetChildren())
    for _, m in ipairs(models:GetChildren()) do
        print(" -", m.Name, m.ClassName)
    end
else
    warn("Catalog/Models not found!")
end

-- Create a test bridge
local bridge = service:CreateBridge({
    startPos = Vector3.new(0, 100, 0),
    endPos = Vector3.new(50, 100, 0)
})

if bridge then
    print("Success! Bridge created:", bridge.Name)
else
    warn("Failed to create bridge")
end
```

## Common Issues & Solutions

### "could not fetch" Error
**Problem**: Mesh asset is not public or doesn't exist
**Solution**: Use Method 1 (Catalog Model) or Method 2 (Workspace Reference)

### "invalid mesh asset" Error  
**Problem**: Mesh ID is invalid or private
**Solution**: Don't use mesh IDs for Studio-uploaded meshes, use Catalog models instead

### Mesh appears stretched/distorted
**Problem**: Scaling issues
**Solution**: Adjust `baseScale` and `maxStretch` in config:
```lua
baseScale = Vector3.new(0.04, 0.04, 0.04),  -- Smaller = less stretched
maxStretch = 1.2,  -- Lower = less stretch allowed
```

### No meshes spawning
**Problem**: Configs not set up properly
**Solution**: Check that meshes are in the right location and configs match

## Integration with SkyIslandGenerator

The updated ModelRegistry.luau now properly supports both methods:

```lua
-- In ModelRegistry.luau
ModelRegistry.BRIDGE_MESHES = {
    -- Catalog model reference
    wooden_plank = {
        meshId = "bridge_pone_1",  -- Name in Catalog/Models
        baseScale = Vector3.new(0.04, 0.04, 0.04),
        maxStretch = 1.5,
        weight = 60,
        material = Enum.Material.Wood,
        color = Color3.fromRGB(139, 90, 43),
        useCatalogModel = true,  -- Use Catalog lookup
    },
    
    -- Fallback part (always works)
    simple_plank = {
        meshId = nil,
        baseScale = Vector3.new(1, 1, 1),
        maxStretch = 2.0,
        weight = 40,
        material = Enum.Material.WoodPlanks,
        color = Color3.fromRGB(160, 100, 50),
    },
}
```

## Best Practices

1. **Always test with fallback Parts enabled** - Ensures bridges work even if meshes fail
2. **Keep multiple bridge types** - Adds variety and handles failures gracefully
3. **Use reasonable weights** - 60/30/10 split works well for common/uncommon/rare
4. **Test at different lengths** - Make sure tiling works properly
5. **Monitor console for warnings** - Helps identify config issues quickly

## Example Full Setup

1. Create folder structure:
   ```
   ReplicatedStorage/Shared/Catalog/Models/
   ```

2. Import your bridge mesh and place it there as `bridge_pone_1`

3. Update ModelRegistry.luau with proper config

4. Run TestBridgeMeshService to verify everything works

5. Generate sky islands and check that bridges spawn correctly

## Performance Tips

- Keep mesh complexity reasonable (under 5000 triangles)
- Use Box collision fidelity for better performance
- Cache meshes using the built-in caching system
- Clear cache when done: `bridgeService:ClearCache()`
