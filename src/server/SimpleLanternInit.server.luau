--!strict
-- SimpleLanternInit.server.luau
-- Simple initialization script for the Dynamic Lantern System

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("🏮 Starting Dynamic Lantern System...")

-- Step 1: Check for required folders
local shared = ReplicatedStorage:WaitForChild("Shared", 5)
if not shared then
	error("❌ Shared folder not found in ReplicatedStorage! Check your file structure.")
end

-- Step 2: Check for LanternKit
local kit = ReplicatedStorage:FindFirstChild("LanternKit")
if not kit then
	warn("⚠️ LanternKit not found. Please run SetupLanternKit.server.luau first!")
	-- Try to run setup automatically in Studio
	if RunService:IsStudio() then
		local setupScript = script.Parent:FindFirstChild("SetupLanternKit")
		if setupScript then
			print("🔧 Running LanternKit setup...")
			local success, err = pcall(function()
				loadstring(setupScript.Source)()
			end)
			if not success then
				warn("Failed to auto-run setup:", err)
				warn("Please run SetupLanternKit.server.luau manually")
			end
		end
	end
end

-- Step 3: Load and check modules
local modules = {
	FeatureFlags = shared:WaitForChild("FeatureFlags"),
	LanternTypes = shared:WaitForChild("LanternTypes"),
	LanternArchetypes = shared:WaitForChild("LanternArchetypes"),
	BitSlicer = shared:WaitForChild("BitSlicer"),
	CurveEval = shared:WaitForChild("CurveEval"),
	FrameTransport = shared:WaitForChild("FrameTransport")
}

local serverModules = {
	LanternFactory = script.Parent:WaitForChild("LanternFactory"),
	BranchBuilder = script.Parent:WaitForChild("BranchBuilder"),
	LanternSpawnService = script.Parent:WaitForChild("LanternSpawnService")
}

-- Test loading
for name, module in pairs(modules) do
	local success = pcall(require, module)
	if success then
		print("✅", name, "loaded")
	else
		warn("❌", name, "failed to load")
	end
end

for name, module in pairs(serverModules) do
	local success = pcall(require, module)
	if success then
		print("✅", name, "loaded")
	else
		warn("❌", name, "failed to load")
	end
end

-- Step 4: Enable the system
local FeatureFlags = require(modules.FeatureFlags)
local enabled = FeatureFlags.get("Lanterns.DynamicEnabled")

if enabled then
	print("🏮 Dynamic Lantern System is ENABLED")
else
	print("🏮 Dynamic Lantern System is DISABLED")
	print("   Enable with: /lantern flag Lanterns.DynamicEnabled true")
end

-- Step 5: Load main integration if enabled
if enabled then
	local mainIntegration = script.Parent:FindFirstChild("MainIntegration")
	if mainIntegration then
		print("🔌 Loading main integration...")
		-- MainIntegration is a server script, it will run automatically
	end
end

print("\n✨ Dynamic Lantern System initialization complete!")
print("Commands: /lantern help")

return {}
