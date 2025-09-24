--!strict
-- StormConfigEditor.luau
-- Utility to dynamically adjust storm configuration
-- Usage: require this module and call setGustScale() to adjust storm size

local StormConfig = require(script.Parent:WaitForChild("StormConfig"))

local StormConfigEditor = {}

-- Set the gust scale multiplier (affects overall storm size and intensity)
-- multiplier: number - Scale factor (1.0 = normal, 3.0 = 3x bigger, etc.)
function StormConfigEditor.setGustScale(multiplier: number)
    if multiplier <= 0 then
        warn("[StormConfigEditor] Gust scale multiplier must be positive, got:", multiplier)
        return false
    end
    
    StormConfig.DenseStorm.scaleMultiplier = multiplier
    print(string.format("[StormConfigEditor] Gust scale set to %.1fx", multiplier))
    return true
end

-- Get current gust scale multiplier
function StormConfigEditor.getGustScale(): number
    return StormConfig.DenseStorm.scaleMultiplier or 3.0
end

-- Reset to default scale (3.0x as requested by user)
function StormConfigEditor.resetGustScale()
    StormConfig.DenseStorm.scaleMultiplier = 3.0
    print("[StormConfigEditor] Gust scale reset to default (3.0x)")
end

-- Set custom wind direction for testing
function StormConfigEditor.setTestWindDirection(direction: Vector3)
    -- This would need to be implemented in the storm service
    -- For now, just normalize the direction
    local normalized = direction.Unit
    print(string.format("[StormConfigEditor] Test wind direction set to (%.2f, %.2f, %.2f)", 
        normalized.X, normalized.Y, normalized.Z))
end

-- Preset configurations
StormConfigEditor.Presets = {
    -- User's original request: "overwhelming" gusts
    OVERWHELMING = {gustScale = 3.0, description = "3x scale for overwhelming storm"},
    
    -- Additional presets for flexibility
    SUBTLE = {gustScale = 1.5, description = "1.5x scale for subtle enhancement"},
    INTENSE = {gustScale = 2.0, description = "2x scale for intense weather"},
    EXTREME = {gustScale = 4.0, description = "4x scale for extreme conditions"},
    HURRICANE = {gustScale = 5.0, description = "5x scale for hurricane-level storm"},
}

-- Apply a preset configuration
function StormConfigEditor.applyPreset(presetName: string)
    local preset = StormConfigEditor.Presets[presetName]
    if not preset then
        warn("[StormConfigEditor] Unknown preset:", presetName)
        warn("[StormConfigEditor] Available presets:", table.concat(
            (function()
                local names = {}
                for name, _ in pairs(StormConfigEditor.Presets) do
                    table.insert(names, name)
                end
                return names
            end)(), ", "))
        return false
    end
    
    StormConfigEditor.setGustScale(preset.gustScale)
    print("[StormConfigEditor] Applied preset:", presetName, "-", preset.description)
    return true
end

return StormConfigEditor
