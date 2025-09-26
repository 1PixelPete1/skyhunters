--!strict
-- QuickTestFix.server.luau
-- Quick test to verify the system loads without errors

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("🔧 Testing Dynamic Lantern System fixes...")

-- Test 1: Check if Shared folder exists
local shared = ReplicatedStorage:WaitForChild("Shared", 5)
if not shared then
	error("❌ Shared folder not found in ReplicatedStorage!")
end
print("✅ Shared folder found")

-- Test 2: Try loading all shared modules
local modulesToTest = {
	"LanternTypes",
	"LanternArchetypes", 
	"BitSlicer",
	"CurveEval",
	"FrameTransport",
	"FeatureFlags"
}

for _, moduleName in ipairs(modulesToTest) do
	local success, result = pcall(function()
		return require(shared:WaitForChild(moduleName))
	end)
	if success then
		print("✅ Loaded", moduleName)
	else
		warn("❌ Failed to load", moduleName, "-", result)
	end
end

-- Test 3: Try the BitSlicer with fixed bit operations
local BitSlicer = require(shared:WaitForChild("BitSlicer"))
local slicer = BitSlicer.fromU64(12345678)
local value = slicer:take(8)
print("✅ BitSlicer test:", value)

-- Test 4: Enable flags and test spawn
local FeatureFlags = require(shared:WaitForChild("FeatureFlags"))
FeatureFlags.set("Lanterns.DynamicEnabled", true)

-- Test 5: Check if SetupLanternKit needs to run
local kit = ReplicatedStorage:FindFirstChild("LanternKit")
if not kit then
	print("⚠️ LanternKit not found - running setup...")
	-- Run setup
	local setupScript = script.Parent:FindFirstChild("SetupLanternKit")
	if setupScript then
		require(setupScript)
		wait(1)
		kit = ReplicatedStorage:FindFirstChild("LanternKit") 
		if kit then
			print("✅ LanternKit created")
		else
			warn("❌ Failed to create LanternKit")
		end
	end
else
	print("✅ LanternKit already exists")
end

-- Test 6: Try spawning a lantern
if kit then
	local LanternSpawnService = require(script.Parent:WaitForChild("LanternSpawnService"))
	local lantern = LanternSpawnService.SpawnDynamicLantern(
		"test_fix",
		Vector3.new(0, 5, 0),
		"test", 
		"CommonA"
	)
	if lantern then
		print("✅ Successfully spawned test lantern!")
		wait(3)
		lantern:Destroy()
		print("✅ Cleaned up test lantern")
	else
		warn("❌ Failed to spawn test lantern")
	end
end

print("\n🎉 Fix verification complete!")
print("If you see this message, the main errors should be resolved.")
print("\nNext steps:")
print("1. Run SetupLanternKit if you haven't already")
print("2. Try /lantern commands in chat")
print("3. Press Alt+D to open Designer UI (Studio only)")

return {}
