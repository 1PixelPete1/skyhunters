--!strict
-- InitBridgeSystem.server.luau
-- Quick initialization script to set up bridge system with Studio meshes
-- Place in ServerScriptService to run on game start

local RunService = game:GetService("RunService")

-- Only run in Studio
if not RunService:IsStudio() then
    return
end

print("\n========================================")
print("BRIDGE SYSTEM INITIALIZER")
print("========================================\n")

-- Create required folder structure
local function ensureFolderStructure()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    
    local shared = ReplicatedStorage:FindFirstChild("Shared") or Instance.new("Folder")
    shared.Name = "Shared"
    shared.Parent = ReplicatedStorage
    
    local catalog = shared:FindFirstChild("Catalog") or Instance.new("Folder")
    catalog.Name = "Catalog"
    catalog.Parent = shared
    
    local models = catalog:FindFirstChild("Models") or Instance.new("Folder")
    models.Name = "Models"
    models.Parent = catalog
    
    print("✅ Folder structure created/verified:")
    print("   ReplicatedStorage/Shared/Catalog/Models/")
    
    return models
end

-- Create a default bridge mesh if none exists
local function createDefaultBridge(parent: Instance)
    local existing = parent:FindFirstChild("bridge_pone_1")
    if existing then
        print("✅ Found existing bridge_pone_1")
        return existing
    end
    
    -- Create a simple plank as default
    local bridge = Instance.new("Part")
    bridge.Name = "bridge_pone_1"
    bridge.Size = Vector3.new(12, 1, 20)  -- Width, Height, Length
    bridge.Material = Enum.Material.Wood
    bridge.BrickColor = BrickColor.new("Brown")
    bridge.TopSurface = Enum.SurfaceType.Smooth
    bridge.BottomSurface = Enum.SurfaceType.Smooth
    bridge.Anchored = true
    bridge.Parent = parent
    
    print("✅ Created default bridge_pone_1 (simple Part)")
    print("   TIP: Replace with your imported mesh for better visuals")
    
    return bridge
end

-- Check for meshes in workspace that could be bridges
local function checkWorkspaceMeshes()
    local meshes = {}
    
    -- Look for common locations
    local locations = {
        workspace:FindFirstChild("BridgeMeshes"),
        workspace:FindFirstChild("Meshes"),
        workspace:FindFirstChild("ImportedMeshes"),
    }
    
    for _, folder in ipairs(locations) do
        if folder then
            print(string.format("\n📁 Found mesh folder: %s", folder.Name))
            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA("MeshPart") or (child:IsA("Model") and child.PrimaryPart) then
                    table.insert(meshes, child)
                    print(string.format("   - %s (%s)", child.Name, child.ClassName))
                end
            end
        end
    end
    
    return meshes
end

-- Main initialization
local function initialize()
    print("Starting initialization...\n")
    
    -- Step 1: Ensure folder structure
    local modelsFolder = ensureFolderStructure()
    
    -- Step 2: Create or find default bridge
    local defaultBridge = createDefaultBridge(modelsFolder)
    
    -- Step 3: Check for imported meshes
    local workspaceMeshes = checkWorkspaceMeshes()
    
    if #workspaceMeshes > 0 then
        print(string.format("\n💡 Found %d potential bridge meshes in workspace", #workspaceMeshes))
        print("   Would you like to use one of these instead?")
        print("   Copy it to ReplicatedStorage/Shared/Catalog/Models/")
        print("   and name it 'bridge_pone_1'")
        
        -- Optionally auto-copy the first one
        if workspaceMeshes[1] then
            print(string.format("\n   Suggested mesh: %s", workspaceMeshes[1].Name))
            
            -- Uncomment to auto-copy:
            -- local copy = workspaceMeshes[1]:Clone()
            -- copy.Name = "bridge_pone_1"
            -- defaultBridge:Destroy()
            -- copy.Parent = modelsFolder
            -- print("   ✅ Auto-copied to Catalog/Models/")
        end
    else
        print("\n💡 TIP: Import your bridge mesh using Import 3D")
        print("   Then place it in workspace/BridgeMeshes/")
        print("   This script will detect it next time")
    end
    
    -- Step 4: Test the system
    print("\n========================================")
    print("TESTING BRIDGE SYSTEM")
    print("========================================\n")
    
    local success, err = pcall(function()
        local BridgeMeshService = require(script.Parent.Worldgen.BridgeMeshService)
        local UpdatedBridgeConfig = require(script.Parent.Worldgen.UpdatedBridgeConfig)
        
        local service = BridgeMeshService.new(UpdatedBridgeConfig.GetConfigs())
        
        -- Create a test bridge
        local testBridge = service:CreateBridge({
            startPos = Vector3.new(0, 50, 0),
            endPos = Vector3.new(50, 50, 0)
        })
        
        if testBridge then
            testBridge.Name = "InitTest_Bridge"
            print("✅ Test bridge created successfully!")
            
            -- Clean up after 5 seconds
            task.wait(5)
            testBridge:Destroy()
            print("   Test bridge removed")
        else
            warn("❌ Failed to create test bridge")
        end
    end)
    
    if not success then
        warn("❌ Error testing bridge system:", err)
    end
    
    print("\n========================================")
    print("INITIALIZATION COMPLETE")
    print("========================================")
    print("\nNext steps:")
    print("1. Import your bridge mesh using Import 3D")
    print("2. Place it in ReplicatedStorage/Shared/Catalog/Models/")
    print("3. Name it 'bridge_pone_1'")
    print("4. Run your sky island generator")
    print("\nFor more options, see STUDIO_MESH_SETUP_GUIDE.md")
end

-- Run initialization
initialize()
