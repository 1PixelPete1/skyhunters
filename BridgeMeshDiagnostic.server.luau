-- BridgeMeshDiagnostic.server.luau
-- Deep diagnostic to find why bridge_pone_1 isn't actually spawning

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BridgeMeshService = require(script.Parent.src.server.Worldgen.BridgeMeshService)
local UpdatedBridgeConfig = require(script.Parent.src.server.Worldgen.UpdatedBridgeConfig)

print("\n🔍 DEEP BRIDGE MESH DIAGNOSTIC")
print("="*50)

-- Get the model
local shared = ReplicatedStorage:FindFirstChild("Shared")
local catalog = shared and shared:FindFirstChild("Catalog")
local models = catalog and catalog:FindFirstChild("Models")
local bridgeModel = models and models:FindFirstChild("bridge_pone_1")

if bridgeModel then
    print("✅ Found bridge_pone_1 model")
    print(string.format("   Type: %s", bridgeModel.ClassName))
    print(string.format("   Name: %s", bridgeModel.Name))
    
    -- Examine the model structure in detail
    print("\n📊 MODEL STRUCTURE ANALYSIS:")
    print(string.format("   Children count: %d", #bridgeModel:GetChildren()))
    
    if bridgeModel:IsA("Model") then
        print(string.format("   PrimaryPart: %s", tostring(bridgeModel.PrimaryPart)))
        
        -- List all children
        print("\n   📋 ALL CHILDREN:")
        for i, child in ipairs(bridgeModel:GetChildren()) do
            print(string.format("     %d. %s (%s)", i, child.Name, child.ClassName))
            if child:IsA("BasePart") then
                print(string.format("        Size: %s", tostring(child.Size)))
                if child:IsA("MeshPart") then
                    print(string.format("        MeshId: %s", child.MeshId))
                    print(string.format("        MeshSize: %s", tostring(child.MeshSize)))
                end
            end
        end
        
        -- Test the extraction logic manually
        print("\n🧪 TESTING EXTRACTION LOGIC:")
        local primaryPart = bridgeModel.PrimaryPart
        if not primaryPart then
            print("   No PrimaryPart set, searching for first BasePart...")
            for _, child in ipairs(bridgeModel:GetChildren()) do
                if child:IsA("BasePart") then
                    primaryPart = child
                    print(string.format("   Found suitable part: %s", child.Name))
                    break
                end
            end
        else
            print(string.format("   Using PrimaryPart: %s", primaryPart.Name))
        end
        
        if primaryPart then
            print("✅ Extraction would succeed")
            
            -- Test cloning
            local success, cloneResult = pcall(function()
                return primaryPart:Clone()
            end)
            
            if success then
                print("✅ Cloning test passed")
                cloneResult:Destroy() -- Clean up
            else
                print(string.format("❌ Cloning test failed: %s", tostring(cloneResult)))
            end
        else
            print("❌ No suitable part found for extraction!")
        end
        
    elseif bridgeModel:IsA("BasePart") then
        print("   Model is a single BasePart")
        if bridgeModel:IsA("MeshPart") then
            print(string.format("   MeshId: %s", bridgeModel.MeshId))
            print(string.format("   Size: %s", tostring(bridgeModel.Size)))
        end
    end
    
    -- Test the actual BridgeMeshService logic
    print("\n🔧 TESTING BRIDGEMESHSERVICE:")
    local configs = UpdatedBridgeConfig.GetConfigs()
    local bridgeService = BridgeMeshService.new(configs)
    
    -- Find the CatalogBridge config
    local catalogConfig = nil
    for _, config in ipairs(configs) do
        if config.useCatalogModel and config.meshId == "bridge_pone_1" then
            catalogConfig = config
            break
        end
    end
    
    if catalogConfig then
        print(string.format("   Found catalog config: %s", catalogConfig.name))
        
        -- Test _getMeshPart directly
        local success, meshPart = pcall(function()
            return bridgeService:_getMeshPart(catalogConfig)
        end)
        
        if success and meshPart then
            print(string.format("✅ _getMeshPart succeeded: %s", meshPart.ClassName))
            print(string.format("   Size: %s", tostring(meshPart.Size)))
            if meshPart:IsA("MeshPart") then
                print(string.format("   MeshId: %s", meshPart.MeshId))
            end
            meshPart:Destroy() -- Clean up
        else
            print(string.format("❌ _getMeshPart failed: %s", tostring(meshPart)))
        end
    end
    
else
    print("❌ bridge_pone_1 model not found!")
    if models then
        print("\n📋 Available models:")
        for _, child in ipairs(models:GetChildren()) do
            print(string.format("   - %s (%s)", child.Name, child.ClassName))
        end
    end
end

-- Test weight distribution
print("\n⚖️  TESTING WEIGHT DISTRIBUTION:")
local configs = UpdatedBridgeConfig.GetConfigs()
local totalWeight = 0
for _, config in ipairs(configs) do
    totalWeight = totalWeight + config.weight
    print(string.format("   %s: %d weight (%.1f%%)", config.name, config.weight, (config.weight/90)*100))
end
print(string.format("   Total weight: %d", totalWeight))

-- Create a few test bridges
print("\n🔨 CREATING TEST BRIDGES:")
local bridgeService = BridgeMeshService.new(configs)
local testFolder = workspace:FindFirstChild("BridgeMeshDiagnostic") or Instance.new("Folder")
testFolder.Name = "BridgeMeshDiagnostic"
testFolder.Parent = workspace
testFolder:ClearAllChildren()

local results = {}
for i = 1, 10 do
    local bridge = bridgeService:CreateBridge({
        startPos = Vector3.new(i * 30, 100, 0),
        endPos = Vector3.new(i * 30, 100, 50),
        parent = testFolder
    })
    
    if bridge then
        local bridgeType = bridge:GetAttribute("BridgeType") or "Unknown"
        results[bridgeType] = (results[bridgeType] or 0) + 1
        print(string.format("   Bridge %d: %s", i, bridgeType))
    else
        print(string.format("   Bridge %d: FAILED", i))
    end
end

print("\n📊 TEST RESULTS:")
for bridgeType, count in pairs(results) do
    print(string.format("   %s: %d/10", bridgeType, count))
end

print("\n" .. "="*50)
print("🏁 DIAGNOSTIC COMPLETE")

-- Clean up after 60 seconds
wait(60)
if testFolder.Parent then
    testFolder:Destroy()
end
script:Destroy()
