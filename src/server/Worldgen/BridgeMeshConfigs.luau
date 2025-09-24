--!strict
-- BridgeMeshConfigs.luau
-- Centralized configuration for bridge meshes
-- Modify this file to add/remove bridge types or adjust spawn weights

local BridgeMeshConfigs = {}

-- Replace these IDs with your actual mesh asset IDs
-- To get mesh IDs:
-- 1. Upload your mesh to Roblox as a MeshPart
-- 2. Copy the ID from the URL or properties
-- 3. Replace the placeholder IDs below

BridgeMeshConfigs.MESH_IDS = {
    -- Basic bridges
    WOODEN_PLANK = "17843185925",      -- Simple wooden plank bridge
    STONE_BRIDGE = "17843185926",      -- Stone/brick bridge
    ROPE_BRIDGE = "17843185927",       -- Rope/suspension bridge
    
    -- Advanced bridges (add your custom ones)
    METAL_BEAM = "17843185928",        -- Industrial metal bridge
    CRYSTAL_BRIDGE = "17843185929",    -- Fantasy crystal bridge
    VINE_BRIDGE = "17843185930",       -- Natural vine bridge
    ICE_BRIDGE = "17843185931",        -- Frozen ice bridge
    BONE_BRIDGE = "17843185932",       -- Spooky bone bridge
}

-- Bridge configurations for different game modes/areas
BridgeMeshConfigs.PRESETS = {
    -- Default configuration for normal gameplay
    DEFAULT = {
        {
            meshId = BridgeMeshConfigs.MESH_IDS.WOODEN_PLANK,
            baseScale = Vector3.new(0.04, 0.04, 0.04),
            maxStretch = 1.5,
            weight = 60, -- 60% chance
            name = "WoodenBridge",
            material = Enum.Material.Wood,
            color = Color3.fromRGB(139, 90, 43),
        },
        {
            meshId = BridgeMeshConfigs.MESH_IDS.STONE_BRIDGE,
            baseScale = Vector3.new(0.035, 0.035, 0.035),
            maxStretch = 1.3,
            weight = 30, -- 30% chance
            name = "StoneBridge",
            material = Enum.Material.Concrete,
            color = Color3.fromRGB(163, 162, 165),
        },
        {
            meshId = BridgeMeshConfigs.MESH_IDS.ROPE_BRIDGE,
            baseScale = Vector3.new(0.045, 0.045, 0.045),
            maxStretch = 1.8, -- Rope can stretch more
            weight = 10, -- 10% chance
            name = "RopeBridge",
            material = Enum.Material.Fabric,
            color = Color3.fromRGB(188, 155, 93),
        },
    },
    
    -- Fantasy/magical area configuration
    FANTASY = {
        {
            meshId = BridgeMeshConfigs.MESH_IDS.CRYSTAL_BRIDGE,
            baseScale = Vector3.new(0.04, 0.04, 0.04),
            maxStretch = 1.2,
            weight = 50,
            name = "CrystalBridge",
            material = Enum.Material.ForceField,
            color = Color3.fromRGB(150, 200, 255),
        },
        {
            meshId = BridgeMeshConfigs.MESH_IDS.VINE_BRIDGE,
            baseScale = Vector3.new(0.05, 0.05, 0.05),
            maxStretch = 2.0,
            weight = 35,
            name = "VineBridge",
            material = Enum.Material.LeafyGrass,
            color = Color3.fromRGB(65, 115, 45),
        },
        {
            meshId = BridgeMeshConfigs.MESH_IDS.WOODEN_PLANK,
            baseScale = Vector3.new(0.04, 0.04, 0.04),
            maxStretch = 1.5,
            weight = 15,
            name = "MagicWood",
            material = Enum.Material.Neon,
            color = Color3.fromRGB(200, 150, 255),
        },
    },
    
    -- Industrial/modern area configuration
    INDUSTRIAL = {
        {
            meshId = BridgeMeshConfigs.MESH_IDS.METAL_BEAM,
            baseScale = Vector3.new(0.038, 0.038, 0.038),
            maxStretch = 1.4,
            weight = 70,
            name = "MetalBeam",
            material = Enum.Material.Metal,
            color = Color3.fromRGB(150, 150, 150),
        },
        {
            meshId = BridgeMeshConfigs.MESH_IDS.STONE_BRIDGE,
            baseScale = Vector3.new(0.035, 0.035, 0.035),
            maxStretch = 1.3,
            weight = 30,
            name = "ConcreteBridge",
            material = Enum.Material.Concrete,
            color = Color3.fromRGB(180, 180, 180),
        },
    },
    
    -- Winter/ice area configuration
    FROZEN = {
        {
            meshId = BridgeMeshConfigs.MESH_IDS.ICE_BRIDGE,
            baseScale = Vector3.new(0.042, 0.042, 0.042),
            maxStretch = 1.2, -- Ice doesn't stretch much
            weight = 60,
            name = "IceBridge",
            material = Enum.Material.Glacier,
            color = Color3.fromRGB(200, 230, 255),
        },
        {
            meshId = BridgeMeshConfigs.MESH_IDS.STONE_BRIDGE,
            baseScale = Vector3.new(0.035, 0.035, 0.035),
            maxStretch = 1.3,
            weight = 40,
            name = "FrozenStone",
            material = Enum.Material.Limestone,
            color = Color3.fromRGB(220, 220, 230),
        },
    },
    
    -- Spooky/halloween configuration
    SPOOKY = {
        {
            meshId = BridgeMeshConfigs.MESH_IDS.BONE_BRIDGE,
            baseScale = Vector3.new(0.04, 0.04, 0.04),
            maxStretch = 1.6,
            weight = 60,
            name = "BoneBridge",
            material = Enum.Material.Sand,
            color = Color3.fromRGB(230, 220, 200),
        },
        {
            meshId = BridgeMeshConfigs.MESH_IDS.ROPE_BRIDGE,
            baseScale = Vector3.new(0.045, 0.045, 0.045),
            maxStretch = 1.8,
            weight = 30,
            name = "DecayedRope",
            material = Enum.Material.Fabric,
            color = Color3.fromRGB(80, 70, 60),
        },
        {
            meshId = BridgeMeshConfigs.MESH_IDS.WOODEN_PLANK,
            baseScale = Vector3.new(0.04, 0.04, 0.04),
            maxStretch = 1.5,
            weight = 10,
            name = "RottenWood",
            material = Enum.Material.Wood,
            color = Color3.fromRGB(60, 40, 30),
        },
    },
}

-- Get configuration based on area or game mode
function BridgeMeshConfigs.GetPreset(presetName: string)
    local preset = BridgeMeshConfigs.PRESETS[presetName:upper()]
    if not preset then
        warn(string.format("[BridgeMeshConfigs] Preset '%s' not found, using DEFAULT", presetName))
        return BridgeMeshConfigs.PRESETS.DEFAULT
    end
    return preset
end

-- Create a mixed configuration from multiple presets
function BridgeMeshConfigs.MixPresets(presetWeights: {[string]: number})
    local mixed = {}
    
    for presetName, weight in pairs(presetWeights) do
        local preset = BridgeMeshConfigs.PRESETS[presetName:upper()]
        if preset then
            for _, config in ipairs(preset) do
                local mixedConfig = table.clone(config)
                mixedConfig.weight = config.weight * weight
                mixedConfig.name = mixedConfig.name .. "_" .. presetName
                table.insert(mixed, mixedConfig)
            end
        end
    end
    
    return mixed
end

-- Validate mesh IDs (checks if they're proper format)
function BridgeMeshConfigs.ValidateMeshIDs(): boolean
    local allValid = true
    
    for name, id in pairs(BridgeMeshConfigs.MESH_IDS) do
        if not (tonumber(id) or string.match(id, "^rbxassetid://")) then
            warn(string.format("[BridgeMeshConfigs] Invalid mesh ID format for %s: %s", name, tostring(id)))
            allValid = false
        end
    end
    
    return allValid
end

-- Example usage function
function BridgeMeshConfigs.GetExampleUsage()
    return [[
    -- Example 1: Use default preset
    local BridgeMeshService = require(script.Parent.BridgeMeshService)
    local BridgeMeshConfigs = require(script.Parent.BridgeMeshConfigs)
    
    local bridgeService = BridgeMeshService.new(BridgeMeshConfigs.GetPreset("DEFAULT"))
    
    -- Example 2: Use fantasy preset for magical area
    local fantasyBridges = BridgeMeshService.new(BridgeMeshConfigs.GetPreset("FANTASY"))
    
    -- Example 3: Mix multiple presets (50% default, 30% fantasy, 20% spooky)
    local mixedConfig = BridgeMeshConfigs.MixPresets({
        DEFAULT = 0.5,
        FANTASY = 0.3,
        SPOOKY = 0.2
    })
    local mixedBridges = BridgeMeshService.new(mixedConfig)
    ]]
end

return BridgeMeshConfigs
