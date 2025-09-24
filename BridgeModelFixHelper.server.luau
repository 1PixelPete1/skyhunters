-- BridgeModelFixHelper.server.luau
-- Diagnoses and helps fix the bridge model MeshId issue

local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("\n🔧 BRIDGE MODEL FIX HELPER")
print("="*50)

-- Get the bridge model
local shared = ReplicatedStorage:FindFirstChild("Shared")
local catalog = shared and shared:FindFirstChild("Catalog")
local models = catalog and catalog:FindFirstChild("Models")
local bridgeModel = models and models:FindFirstChild("bridge_pone_1")

if bridgeModel then
    print("✅ Found bridge_pone_1 model")
    
    -- Analyze the model structure
    print("\n📊 MODEL ANALYSIS:")
    print(string.format("   Type: %s", bridgeModel.ClassName))
    print(string.format("   Children: %d", #bridgeModel:GetChildren()))
    
    if bridgeModel:IsA("Model") then
        local primaryPart = bridgeModel.PrimaryPart
        local suitablePart = primaryPart
        
        if not suitablePart then
            for _, child in ipairs(bridgeModel:GetChildren()) do
                if child:IsA("BasePart") then
                    suitablePart = child
                    break
                end
            end
        end
        
        if suitablePart then
            print(string.format("   Using part: %s (%s)", suitablePart.Name, suitablePart.ClassName))
            print(string.format("   Size: %s", tostring(suitablePart.Size)))
            
            if suitablePart:IsA("MeshPart") then
                local meshId = suitablePart.MeshId
                print(string.format("   MeshId: '%s'", meshId))
                
                if meshId == "" or meshId == nil then
                    print("\n❌ PROBLEM FOUND: MeshId is EMPTY!")
                    print("   This is why your bridges appear as gray boxes instead of your custom mesh.")
                    print("\n🛠️ HOW TO FIX:")
                    print("   1. Your mesh needs to be uploaded to Roblox first")
                    print("   2. Upload your .fbx/.obj file to Roblox as a MeshPart")
                    print("   3. Get the asset ID from the uploaded mesh")
                    print("   4. In Studio, select the 'Cube' part in your bridge_pone_1 model")
                    print("   5. Set the MeshId property to 'rbxassetid://YOUR_MESH_ID'")
                    print("\n💡 ALTERNATIVE SOLUTION:")
                    print("   1. In Studio, delete the current 'Cube' part")
                    print("   2. Insert your uploaded MeshPart directly into the model")
                    print("   3. Make sure it's named 'Cube' or set it as PrimaryPart")
                else
                    print(string.format("   ✅ MeshId is set: %s", meshId))
                    
                    -- Test if the mesh loads
                    local testPart = Instance.new("MeshPart")
                    testPart.MeshId = meshId
                    testPart.Name = "MeshTest"
                    testPart.Size = Vector3.new(10, 10, 10)
                    testPart.Position = Vector3.new(0, 200, 0)
                    testPart.Anchored = true
                    testPart.Parent = workspace
                    
                    print("   🧪 Created test mesh at Y=200 to verify it loads")
                    
                    -- Clean up after 10 seconds
                    task.wait(10)
                    if testPart.Parent then
                        testPart:Destroy()
                        print("   🗑️ Cleaned up test mesh")
                    end
                end
                
                -- Check mesh properties
                if suitablePart.MeshSize then
                    print(string.format("   MeshSize: %s", tostring(suitablePart.MeshSize)))
                end
                
            else
                print("   ℹ️  Not a MeshPart - this will render as a basic part")
            end
        else
            print("   ❌ No suitable BasePart found in model!")
        end
    end
    
    print("\n⚖️ NEW WEIGHT SYSTEM:")
    print("   Bridge weights are now simple and relative:")
    print("   - bridge1: weight=2, bridge2: weight=2, bridge3: weight=4")
    print("   - Total: 8, so percentages are: 25%, 25%, 50%")
    print("   - Just add up all weights and each bridge gets weight/total chance")
    
else
    print("❌ bridge_pone_1 model not found!")
    print("   Make sure you've imported the .rbxm file into Studio")
end

print("\n🎯 SUMMARY:")
if bridgeModel then
    local part = bridgeModel.PrimaryPart or bridgeModel:FindFirstChildOfClass("BasePart")
    if part and part:IsA("MeshPart") and (part.MeshId == "" or part.MeshId == nil) then
        print("   ISSUE: Your bridge model exists but has no mesh assigned")
        print("   SOLUTION: Upload your mesh to Roblox and assign the asset ID to MeshId")
        print("   STATUS: Bridges will appear as gray boxes until fixed")
    else
        print("   Your bridge model looks properly configured!")
    end
else
    print("   ISSUE: Bridge model not imported")
    print("   SOLUTION: Import bridge_pone_1.rbxm file into ReplicatedStorage/Shared/Catalog/Models/")
end

print("\n" .. "="*50)

-- Self-destruct after 30 seconds
wait(30)
script:Destroy()
