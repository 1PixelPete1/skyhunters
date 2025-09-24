-- BridgeSetupHelper.server.luau
-- Helps set up the bridge model structure if it's missing

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ensureFolder(parent, name)
    local folder = parent:FindFirstChild(name)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = name
        folder.Parent = parent
        print(string.format("✅ Created folder: %s", folder:GetFullName()))
    else
        print(string.format("✅ Found existing folder: %s", folder:GetFullName()))
    end
    return folder
end

print("\n🔧 BRIDGE SETUP HELPER")
print("="*40)

-- Ensure the directory structure exists
print("\n📁 Setting up directory structure...")
local shared = ensureFolder(ReplicatedStorage, "Shared")
local catalog = ensureFolder(shared, "Catalog")
local models = ensureFolder(catalog, "Models")

-- Check if bridge model exists
print("\n🌉 Checking for bridge model...")
local bridgeModel = models:FindFirstChild("bridge_pone_1")

if bridgeModel then
    print("✅ Bridge model 'bridge_pone_1' found!")
    print(string.format("   Type: %s", bridgeModel.ClassName))
    print(string.format("   Location: %s", bridgeModel:GetFullName()))
    
    -- Test the bridge configuration
    print("\n🧪 Testing bridge configuration...")
    local UpdatedBridgeConfig = script.Parent:FindFirstChild("src") and 
        script.Parent.src.server.Worldgen:FindFirstChild("UpdatedBridgeConfig")
    
    if UpdatedBridgeConfig then
        local ok, result = pcall(function()
            local config = require(UpdatedBridgeConfig)
            return config.CheckSetup()
        end)
        
        if ok and result then
            print("✅ Bridge configuration test PASSED")
        else
            print("❌ Bridge configuration test FAILED")
        end
    end
else
    print("❌ Bridge model 'bridge_pone_1' NOT FOUND")
    print("\n📋 MANUAL IMPORT REQUIRED:")
    print("1. In Roblox Studio, right-click on the Models folder:")
    print("   " .. models:GetFullName())
    print("2. Select 'Insert from File...'")
    print("3. Navigate to your QuietWinds folder:")
    print("   src/replicated/Shared/Catalog/Models/bridge_pone_1.rbxm")
    print("4. Import the file")
    print("5. Make sure the imported model is named exactly 'bridge_pone_1'")
    print("\nThen run this script again to verify the setup.")
    
    print("\n📋 AVAILABLE ITEMS IN MODELS FOLDER:")
    local children = models:GetChildren()
    if #children == 0 then
        print("   (No items found)")
    else
        for _, child in ipairs(children) do
            print(string.format("   - %s (%s)", child.Name, child.ClassName))
        end
    end
end

print("\n" .. "="*40)
print("🏁 SETUP COMPLETE")

-- Self-destruct after 30 seconds
wait(30)
script:Destroy()
