-- BridgeModelDiagnostic.server.luau
-- Diagnoses bridge model issues and provides import instructions

local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("\n" .. "="*60)
print("🔧 BRIDGE MODEL DIAGNOSTIC")
print("="*60)

-- Check directory structure
local function checkPath(path, name)
    local result = ReplicatedStorage
    local pathParts = string.split(path, ".")
    
    for i, part in ipairs(pathParts) do
        result = result:FindFirstChild(part)
        if not result then
            print(string.format("❌ Missing: %s (stopped at step %d)", name, i))
            print(string.format("   Expected path: ReplicatedStorage.%s", path))
            return false, nil
        end
    end
    print(string.format("✅ Found: %s", name))
    return true, result
end

-- Check each level of the required path
print("\n📁 CHECKING DIRECTORY STRUCTURE:")
local hasShared, shared = checkPath("Shared", "Shared folder")
local hasCatalog, catalog = checkPath("Shared.Catalog", "Catalog folder") 
local hasModels, models = checkPath("Shared.Catalog.Models", "Models folder")

-- Check for the specific bridge model
print("\n🌉 CHECKING BRIDGE MODEL:")
if hasModels then
    local bridgeModel = models:FindFirstChild("bridge_pone_1")
    if bridgeModel then
        print("✅ Found: bridge_pone_1 model")
        print(string.format("   Type: %s", bridgeModel.ClassName))
        
        if bridgeModel:IsA("Model") then
            print(string.format("   Children count: %d", #bridgeModel:GetChildren()))
            for _, child in ipairs(bridgeModel:GetChildren()) do
                print(string.format("     - %s (%s)", child.Name, child.ClassName))
            end
            
            -- Check for primary part
            if bridgeModel.PrimaryPart then
                print(string.format("   Primary part: %s", bridgeModel.PrimaryPart.Name))
            else
                print("   ⚠️  No PrimaryPart set (this is okay, we'll find a part automatically)")
            end
        elseif bridgeModel:IsA("BasePart") then
            print("   Type: Single part/mesh")
            if bridgeModel:IsA("MeshPart") then
                print(string.format("   MeshId: %s", bridgeModel.MeshId))
                print(string.format("   Size: %s", tostring(bridgeModel.Size)))
            end
        end
    else
        print("❌ Missing: bridge_pone_1 model")
        print("\n📋 AVAILABLE MODELS IN FOLDER:")
        if #models:GetChildren() == 0 then
            print("   (No models found)")
        else
            for _, child in ipairs(models:GetChildren()) do
                print(string.format("   - %s (%s)", child.Name, child.ClassName))
            end
        end
    end
else
    print("❌ Cannot check bridge model - Models folder missing")
end

-- Provide instructions
print("\n📖 INSTRUCTIONS TO FIX:")
print("="*40)

if not hasShared then
    print("1. Create folder 'Shared' in ReplicatedStorage")
end

if not hasCatalog then
    print("2. Create folder 'Catalog' in ReplicatedStorage.Shared")
end

if not hasModels then
    print("3. Create folder 'Models' in ReplicatedStorage.Shared.Catalog")
end

if hasModels then
    local bridgeModel = models:FindFirstChild("bridge_pone_1")
    if not bridgeModel then
        print("4. Import the bridge model:")
        print("   a. Right-click on ReplicatedStorage.Shared.Catalog.Models")
        print("   b. Choose 'Insert from File...'")
        print("   c. Navigate to: src/replicated/Shared/Catalog/Models/bridge_pone_1.rbxm")
        print("   d. Import the file")
        print("   e. Ensure the imported model is named exactly 'bridge_pone_1'")
    end
end

print("\n🎯 CURRENT BRIDGE CONFIG:")
print("="*30)

-- Check current bridge configuration
local UpdatedBridgeConfig = require(script.Parent:FindFirstChild("src") and 
    script.Parent.src.server.Worldgen:FindFirstChild("UpdatedBridgeConfig"))

if UpdatedBridgeConfig then
    local configs = UpdatedBridgeConfig.GetConfigs()
    for i, config in ipairs(configs) do
        print(string.format("Bridge %d: %s (weight: %d%%)", i, config.name, config.weight))
        if config.useCatalogModel then
            print(string.format("  Looking for model: %s", config.meshId))
        else
            print("  Using fallback part")
        end
    end
end

print("\n🔄 TESTING BRIDGE SETUP:")
if hasModels and models:FindFirstChild("bridge_pone_1") then
    local setupOk = pcall(function()
        UpdatedBridgeConfig.CheckSetup()
    end)
    if setupOk then
        print("✅ Bridge setup validation passed")
    else
        print("❌ Bridge setup validation failed")
    end
else
    print("⏭️  Skipping setup test - model not imported yet")
end

print("\n" .. "="*60)
print("🏁 DIAGNOSTIC COMPLETE")
print("="*60)

-- Self-destruct after 30 seconds to avoid clutter
wait(30)
script:Destroy()
