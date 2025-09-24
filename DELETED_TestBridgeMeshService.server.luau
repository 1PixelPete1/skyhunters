--!strict
-- TestBridgeMeshService.server.luau (v2)
-- Test script for BridgeMeshService with Studio-uploaded mesh support

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for services to load
wait(2)

print("\n[TestBridgeMesh] ========================================")
print("[TestBridgeMesh] Bridge Mesh Service Test v2")
print("[TestBridgeMesh] ========================================\n")

local ServerScriptService = game:GetService("ServerScriptService")
local BridgeMeshService = require(ServerScriptService.Server.Worldgen.BridgeMeshService)

-- IMPORTANT: For Studio-uploaded meshes, you have two options:
-- 
-- Option 1: Place your mesh in ReplicatedStorage/Shared/Catalog/Models/
--           and reference it by name
--
-- Option 2: Place your mesh anywhere in workspace and add it directly
--           using AddMeshFromWorkspace (shown below)

-- Check for existing bridge models in Catalog
local function checkCatalogModels()
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    local catalog = shared and shared:FindFirstChild("Catalog")
    local models = catalog and catalog:FindFirstChild("Models")
    
    if models then
        print("[TestBridgeMesh] Found Catalog/Models folder")
        print("[TestBridgeMesh] Available models:")
        for _, model in ipairs(models:GetChildren()) do
            print(string.format("  - %s (%s)", model.Name, model.ClassName))
        end
    else
        warn("[TestBridgeMesh] Catalog/Models folder not found!")
        warn("[TestBridgeMesh] Create: ReplicatedStorage/Shared/Catalog/Models/")
    end
end

checkCatalogModels()

-- Test configuration using Catalog models and fallback parts
local testConfigs = {
    {
        meshId = "bridge_pone_1",  -- Will look for this in Catalog/Models
        baseScale = Vector3.new(0.04, 0.04, 0.04),
        maxStretch = 1.5,
        weight = 50,
        name = "CatalogBridge",
        material = Enum.Material.Wood,
        color = Color3.fromRGB(139, 90, 43),
        useCatalogModel = true,
    },
    {
        meshId = nil,  -- Will use fallback Part
        baseScale = Vector3.new(1, 1, 1),
        maxStretch = 2.0,
        weight = 50,
        name = "FallbackPlank",
        material = Enum.Material.WoodPlanks,
        color = Color3.fromRGB(160, 100, 50),
        useCatalogModel = false,
    },
}

-- Create service instance
local bridgeService = BridgeMeshService.new(testConfigs)

-- OPTION 2: If you have Studio-uploaded meshes in workspace, add them like this:
-- Look for any MeshParts in workspace that might be bridge meshes
local meshFolder = Workspace:FindFirstChild("BridgeMeshes")
if meshFolder then
    print("\n[TestBridgeMesh] Found BridgeMeshes folder, adding meshes...")
    for _, child in ipairs(meshFolder:GetChildren()) do
        if child:IsA("MeshPart") or child:IsA("Part") then
            bridgeService:AddMeshFromWorkspace(child, "Custom_" .. child.Name, 30)
            print(string.format("  Added: %s", child.Name))
        end
    end
else
    print("\n[TestBridgeMesh] TIP: Create a 'BridgeMeshes' folder in Workspace")
    print("[TestBridgeMesh]      and put your imported meshes there for testing")
end

-- Create test folder
local testFolder = Workspace:FindFirstChild("BridgeTests") or Instance.new("Folder")
testFolder.Name = "BridgeTests"
testFolder.Parent = Workspace

-- Clean up old tests
testFolder:ClearAllChildren()

print("\n[TestBridgeMesh] Starting bridge tests...\n")

-- Function to create test bridge with error handling
local function createTestBridge(name: string, startPos: Vector3, endPos: Vector3, description: string)
    print(string.format("[TestBridgeMesh] Test: %s", description))
    
    local success, bridge = pcall(function()
        return bridgeService:CreateBridge({
            startPos = startPos,
            endPos = endPos,
        })
    end)
    
    if success and bridge then
        bridge.Name = name
        bridge.Parent = testFolder
        print(string.format("  ✓ Success: %s created", name))
        return bridge
    else
        warn(string.format("  ✗ Failed: %s - %s", name, tostring(bridge)))
        return nil
    end
end

-- Test 1: Short bridge
createTestBridge(
    "Test1_ShortBridge",
    Vector3.new(0, 100, 0),
    Vector3.new(30, 100, 0),
    "Short bridge (30 studs)"
)

-- Test 2: Medium bridge
createTestBridge(
    "Test2_MediumBridge",
    Vector3.new(50, 100, 0),
    Vector3.new(150, 105, 0),
    "Medium bridge with height variation (100 studs)"
)

-- Test 3: Long bridge
createTestBridge(
    "Test3_LongBridge",
    Vector3.new(200, 100, 0),
    Vector3.new(400, 110, 50),
    "Long diagonal bridge (200+ studs)"
)

-- Test 4: Very long bridge
createTestBridge(
    "Test4_VeryLongBridge",
    Vector3.new(0, 100, 100),
    Vector3.new(500, 120, 100),
    "Very long bridge (500 studs)"
)

-- Test 5: Vertical bridge
createTestBridge(
    "Test5_VerticalBridge",
    Vector3.new(600, 100, 0),
    Vector3.new(600, 200, 0),
    "Vertical bridge (100 studs up)"
)

-- Test 6: Multiple random bridges
print("\n[TestBridgeMesh] Creating random bridges to test distribution...\n")

local randomTestFolder = Instance.new("Folder")
randomTestFolder.Name = "RandomBridges"
randomTestFolder.Parent = testFolder

local typeCount = {}

for i = 1, 10 do
    local angle = (i - 1) * (math.pi * 2 / 10)
    local radius = 150
    local startPos = Vector3.new(
        math.cos(angle) * radius,
        100,
        math.sin(angle) * radius
    )
    local endPos = Vector3.new(
        math.cos(angle) * (radius + 50),
        100 + math.random(-10, 10),
        math.sin(angle) * (radius + 50)
    )
    
    local success, bridge = pcall(function()
        return bridgeService:CreateBridge({
            startPos = startPos,
            endPos = endPos,
        })
    end)
    
    if success and bridge then
        bridge.Name = "RandomBridge_" .. i
        bridge.Parent = randomTestFolder
        
        local bridgeType = bridge:GetAttribute("BridgeType")
        if bridgeType then
            typeCount[bridgeType] = (typeCount[bridgeType] or 0) + 1
        end
    end
end

print("\n[TestBridgeMesh] Random bridge type distribution:")
for bridgeType, count in pairs(typeCount) do
    print(string.format("  %s: %d/10 (%.0f%%)", bridgeType, count, count * 10))
end

-- Add visual markers and info
print("\n[TestBridgeMesh] Adding visual markers...\n")

for _, child in pairs(testFolder:GetChildren()) do
    if child:IsA("Model") then
        local length = child:GetAttribute("BridgeLength")
        if length then
            -- Create info billboard
            local part = Instance.new("Part")
            part.Name = "InfoMarker"
            part.Size = Vector3.new(1, 1, 1)
            part.Transparency = 1
            part.Anchored = true
            part.CanCollide = false
            part.Position = child:GetBoundingBox().Position + Vector3.new(0, 10, 0)
            part.Parent = child
            
            local billboard = Instance.new("BillboardGui")
            billboard.Size = UDim2.new(0, 200, 0, 50)
            billboard.StudsOffset = Vector3.new(0, 5, 0)
            billboard.Parent = part
            
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 0.3
            label.BackgroundColor3 = Color3.new(0, 0, 0)
            label.TextColor3 = Color3.new(1, 1, 1)
            label.TextScaled = true
            
            local tileCount = 0
            for _, tile in ipairs(child:GetChildren()) do
                if tile.Name:match("BridgeTile") then
                    tileCount = tileCount + 1
                end
            end
            
            label.Text = string.format("%s\nLength: %.1f studs\nTiles: %d", 
                child.Name, 
                length,
                tileCount
            )
            label.Parent = billboard
        end
    end
end

print("\n[TestBridgeMesh] ========================================")
print("[TestBridgeMesh] All tests complete!")
print("[TestBridgeMesh] Check 'BridgeTests' folder in Workspace")
print("[TestBridgeMesh] ========================================\n")

-- Instructions for setting up custom meshes
print("SETUP INSTRUCTIONS FOR CUSTOM MESHES:")
print("=====================================")
print("1. Import your bridge mesh using Studio's Import 3D")
print("2. EITHER:")
print("   A) Place it in ReplicatedStorage/Shared/Catalog/Models/")
print("      Name it 'bridge_pone_1' or update the config")
print("   OR")
print("   B) Place it in Workspace in a folder called 'BridgeMeshes'")
print("      The script will automatically detect and use it")
print("")
print("3. Make sure your mesh is:")
print("   - Anchored")
print("   - Has CanCollide = true")
print("   - Is reasonably sized (10-30 studs long)")
print("")
print("4. If meshes fail to load, the system will use fallback Parts")
