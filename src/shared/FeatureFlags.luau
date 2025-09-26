--!strict
-- FeatureFlags.luau
-- Feature flag system for dynamic lanterns

local RunService = game:GetService("RunService")

local FeatureFlags = {}

-- Define feature flags with default values
local FLAGS = {
	-- Master toggle for dynamic lantern rendering at runtime
	["Lanterns.DynamicEnabled"] = {
		default = false,
		description = "Enable dynamic lantern renderer (master toggle)"
	},
	
	-- Enable designer UI in Studio
	["Lanterns.DesignerEnabled"] = {
		default = RunService:IsStudio(),
		description = "Enable lantern designer UI (Studio only)"
	},
	
	-- Expose light socket for LightMerger
	["Lanterns.UseLightSocket"] = {
		default = true,
		description = "Expose head LightSocket for LightMerger targeting"
	}
}

-- Store override values (for runtime changes)
local overrides = {}

function FeatureFlags.get(flagName: string): boolean
	-- Check for override first
	if overrides[flagName] ~= nil then
		return overrides[flagName]
	end
	
	-- Return default value
	local flag = FLAGS[flagName]
	if flag then
		return flag.default
	end
	
	warn("Unknown feature flag:", flagName)
	return false
end

function FeatureFlags.set(flagName: string, value: boolean)
	if not FLAGS[flagName] then
		warn("Attempting to set unknown feature flag:", flagName)
		return
	end
	overrides[flagName] = value
end

function FeatureFlags.reset(flagName: string)
	overrides[flagName] = nil
end

function FeatureFlags.resetAll()
	overrides = {}
end

function FeatureFlags.getAll(): {[string]: boolean}
	local result = {}
	for name, flag in pairs(FLAGS) do
		result[name] = FeatureFlags.get(name)
	end
	return result
end

function FeatureFlags.getDescription(flagName: string): string?
	local flag = FLAGS[flagName]
	return flag and flag.description or nil
end

return FeatureFlags
