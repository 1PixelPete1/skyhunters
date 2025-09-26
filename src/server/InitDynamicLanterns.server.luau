--!strict
-- InitDynamicLanterns.server.luau
-- Initialization script for the dynamic lantern system
-- Place in ServerScriptService to auto-run

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

print("🏮 [InitDynamicLanterns] Starting initialization...")
print("   Script location:", script:GetFullName())

-- Ensure shared modules are loaded
local success, err = pcall(function()
	print("   Loading shared modules...")
	-- Load core modules to verify they exist
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Types = require(Shared:WaitForChild("LanternTypes"))
	local Archetypes = require(Shared:WaitForChild("LanternArchetypes"))
	local FeatureFlags = require(Shared:WaitForChild("FeatureFlags"))
	local BitSlicer = require(Shared:WaitForChild("BitSlicer"))
	local CurveEval = require(Shared:WaitForChild("CurveEval"))
	local FrameTransport = require(Shared:WaitForChild("FrameTransport"))
	print("   ✅ Shared modules loaded successfully")
end)

if not success then
	warn("❌ [InitDynamicLanterns] Failed to load Dynamic Lantern modules:", err)
	return
end

-- Check for LanternKit
local kitExists = ReplicatedStorage:FindFirstChild("LanternKit") ~= nil

if not kitExists then
	warn("⚠️ [InitDynamicLanterns] LanternKit not found in ReplicatedStorage")
	warn("   Run SetupLanternKit.server.luau to create test assets")
	
	-- Optionally auto-setup in Studio
	if RunService:IsStudio() then
		print("🔧 LanternKit setup should be run manually")
		print("   Run SetupLanternKit.server.luau if it exists")
	end
else
	print("✅ [InitDynamicLanterns] LanternKit found")
end

-- Load feature flags
local Shared = ReplicatedStorage:WaitForChild("Shared")
local FeatureFlags = require(Shared:WaitForChild("FeatureFlags"))

-- Check if system should be enabled
local isDynamic = FeatureFlags.get("Lanterns.DynamicEnabled")
local isDesigner = FeatureFlags.get("Lanterns.DesignerEnabled")

print("📊 [InitDynamicLanterns] System Status:")
print("   Dynamic Rendering:", isDynamic and "✅ Enabled" or "❌ Disabled")
print("   Designer UI:", isDesigner and "✅ Enabled" or "❌ Disabled")
print("   Platform:", RunService:IsStudio() and "Studio" or "Game")

if isDynamic then
	print("   Loading server modules...")
	
	-- Look for server modules in the same directory as this script
	local serverModules = {
		"LanternFactory",
		"BranchBuilder", 
		"LanternSpawnService",
		-- "MainIntegration" -- This appears to be a server script, not a module, so we skip it
	}
	
	local loadedModules = {}
	
	for _, moduleName in ipairs(serverModules) do
		print("   Looking for", moduleName, "...")
		
		-- Try to find the module in the same parent directory
		local module = script.Parent:FindFirstChild(moduleName)
		
		if module then
			print("      Found at:", module:GetFullName())
			-- Only require if it's a ModuleScript
			if module:IsA("ModuleScript") then
				local success, result = pcall(require, module)
				if success then
					loadedModules[moduleName] = result
					print("      ✅ Loaded", moduleName)
				else
					warn("      ❌ Failed to require", moduleName, ":", result)
				end
			else
				print("      ℹ️", moduleName, "is a", module.ClassName, ", skipping require")
			end
		else
			warn("      ❌ Missing", moduleName, "in", script.Parent:GetFullName())
			warn("      Contents of parent:", script.Parent:GetChildren())
		end
	end
	
	print("🏮 [InitDynamicLanterns] Dynamic Lantern System Ready!")
	print("   Successfully loaded", table.getn(loadedModules), "modules")
	
	-- Store loaded modules for other scripts to use
	_G.DynamicLanternModules = loadedModules
	
	-- Show help in Studio
	if RunService:IsStudio() then
		print("\n💡 Quick Start:")
		print("1. Use /lantern commands in chat")
		print("2. Press Alt+D to open Designer UI")
		print("3. Run TestLanternSystem to spawn test grid")
		print("\nType '/lantern' in chat for command list")
	end
else
	print("🏮 [InitDynamicLanterns] Dynamic Lantern System on standby")
	print("   Enable with: FeatureFlags.set('Lanterns.DynamicEnabled', true)")
end

return {}
