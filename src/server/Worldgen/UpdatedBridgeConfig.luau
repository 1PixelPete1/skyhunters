-- UpdatedBridgeConfig.luau
-- Drop-in replacement config for SkyIslandGenerator to use with Studio-uploaded meshes

--[[
QUICK SETUP:
1. Place your imported bridge mesh in: ReplicatedStorage/Shared/Catalog/Models/
2. Name it "bridge_pone_1" (or change the name below to match)
3. This config will automatically find and use it
--]]

local UpdatedBridgeConfig = {}

-- Bridge configurations - SIMPLE RELATIVE WEIGHTS
UpdatedBridgeConfig.BRIDGE_CONFIGS = {
    {
        meshId = "bridge_pone_1",
        baseScale = Vector3.new(0.04, 0.04, 0.04),
        maxStretch = 1.5,
        weight = 4,  -- 4 out of 4 = 100% for now
        name = "WoodBridge",
        material = Enum.Material.Wood,
        color = Color3.fromRGB(139, 90, 43),
        useCatalogModel = true,
    },
    
    -- TODO: Add more bridges with simple relative weights:
    -- {
    --     meshId = "bridge_stone_1",
    --     baseScale = Vector3.new(0.04, 0.04, 0.04),
    --     maxStretch = 1.3,
    --     weight = 2,  -- 2 out of 8 total = 25%
    --     name = "StoneBridge",
    --     material = Enum.Material.Concrete,
    --     color = Color3.fromRGB(120, 120, 120),
    --     useCatalogModel = true,
    -- },
    -- {
    --     meshId = "bridge_rope_1",
    --     baseScale = Vector3.new(0.05, 0.05, 0.05),
    --     maxStretch = 1.8,
    --     weight = 2,  -- 2 out of 8 total = 25%
    --     name = "RopeBridge",
    --     material = Enum.Material.Fabric,
    --     color = Color3.fromRGB(160, 120, 80),
    --     useCatalogModel = true,
    -- },
    -- Total weights: 4 + 2 + 2 = 8
    -- Wood: 4/8 = 50%, Stone: 2/8 = 25%, Rope: 2/8 = 25%
}

-- Helper function to check if Catalog is set up correctly
function UpdatedBridgeConfig.CheckSetup()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    local catalog = shared and shared:FindFirstChild("Catalog")
    local models = catalog and catalog:FindFirstChild("Models")
    
    print("\n[BridgeConfig] Checking setup...")
    
    if not shared then
        warn("[BridgeConfig] ❌ Missing: ReplicatedStorage/Shared/")
        return false
    end
    
    if not catalog then
        warn("[BridgeConfig] ❌ Missing: ReplicatedStorage/Shared/Catalog/")
        return false
    end
    
    if not models then
        warn("[BridgeConfig] ❌ Missing: ReplicatedStorage/Shared/Catalog/Models/")
        return false
    end
    
    local bridgeModel = models:FindFirstChild("bridge_pone_1")
    if not bridgeModel then
        warn("[BridgeConfig] ❌ Missing: bridge_pone_1 in Catalog/Models/")
        print("[BridgeConfig] Available models in folder:")
        for _, child in ipairs(models:GetChildren()) do
            print("  -", child.Name)
        end
        return false
    end
    
    print("[BridgeConfig] ✅ Setup complete! Found bridge_pone_1")
    return true
end

-- Function to get configs for BridgeMeshService
function UpdatedBridgeConfig.GetConfigs()
    -- Check setup on first call
    if not UpdatedBridgeConfig._setupChecked then
        UpdatedBridgeConfig._setupChecked = true
        UpdatedBridgeConfig.CheckSetup()
    end
    
    return UpdatedBridgeConfig.BRIDGE_CONFIGS
end

-- Function to add a custom mesh from workspace
function UpdatedBridgeConfig.CreateConfigFromPart(part: BasePart, name: string, weight: number?): any
    if not part or not part:IsA("BasePart") then
        warn("[BridgeConfig] Invalid part provided")
        return nil
    end
    
    return {
        meshId = part,  -- Direct instance reference
        baseScale = Vector3.new(0.04, 0.04, 0.04),
        maxStretch = 1.5,
        weight = weight or 50,
        name = name,
        material = part.Material,
        color = part.Color,
        useCatalogModel = false,
    }
end

return UpdatedBridgeConfig
