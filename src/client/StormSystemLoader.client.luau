--!strict
-- StormSystemLoader.client.luau
-- Centralizes which storm controllers run on the client.

local RunService = game:GetService("RunService")

-- Toggle which implementations are active.
local ENABLE_LEGACY_STORM = true
local ENABLE_ENHANCED_CONTROLLER = true -- runs in fog-only mode by config
local ENABLE_WEATHER_SYSTEM = false

local function requireModule(module: ModuleScript, label: string)
    local ok, result = pcall(require, module)
    if not ok then
        warn("[StormLoader] Failed to require", label, result)
        return nil
    end

    if RunService:IsStudio() then
        print("[StormLoader] Required", label)
    end

    return result
end

local function enableIfModuleOrScript(container: Instance, name: string, label: string)
    local inst = container:FindFirstChild(name)
    if not inst then
        warn("[StormLoader]", label, "missing")
        return
    end

    if inst:IsA("ModuleScript") then
        requireModule(inst, label)
    elseif inst:IsA("LocalScript") then
        inst.Enabled = true
        if RunService:IsStudio() then
            print("[StormLoader] Enabled", label)
        end
    end
end

local function disableLocalScript(container: Instance, name: string, label: string)
    local inst = container:FindFirstChild(name)
    if inst and inst:IsA("LocalScript") then
        inst.Enabled = false
        if RunService:IsStudio() then
            print("[StormLoader] Disabled", label)
        end
    end
end

local function loadStormSystems()
    local stormFolder = script.Parent:FindFirstChild("Storm")
    if not stormFolder then
        warn("[StormLoader] Storm folder not found")
        return
    end

    if ENABLE_LEGACY_STORM then
        enableIfModuleOrScript(stormFolder, "StormClientController", "StormClientController")
    else
        disableLocalScript(stormFolder, "StormClientController", "StormClientController")
    end

    if ENABLE_ENHANCED_CONTROLLER then
        enableIfModuleOrScript(stormFolder, "EnhancedStormController", "EnhancedStormController")
    else
        disableLocalScript(stormFolder, "EnhancedStormController", "EnhancedStormController")
    end

    if ENABLE_WEATHER_SYSTEM then
        enableIfModuleOrScript(stormFolder, "WeatherSystem", "WeatherSystem")
    else
        disableLocalScript(stormFolder, "WeatherSystem", "WeatherSystem")
    end
end

loadStormSystems()

if RunService:IsStudio() then
    print("[StormLoader] Storm system initialization complete")
end
