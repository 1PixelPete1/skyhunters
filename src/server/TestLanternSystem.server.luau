--!strict
-- TestLanternSystem.server.luau
-- Test script for the dynamic lantern system
-- This script must be manually triggered and won't run automatically

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- IMPORTANT: This script is disabled by default to prevent automatic spawning
-- To run tests, either:
-- 1. Set script.Disabled = false in Studio
-- 2. Call the test functions from the command bar
-- 3. Use the /lantern test command in chat

-- Prevent automatic execution
if script:GetAttribute("AutoRun") ~= true then
	print("🚫 [TestLanternSystem] Auto-run disabled. Set AutoRun attribute to true or trigger manually.")
	return
end

-- Wait for modules to load
wait(2)

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local FeatureFlags = require(Shared:WaitForChild("FeatureFlags"))
local LanternSpawnService = require(script.Parent:WaitForChild("LanternSpawnService"))
local Archetypes = require(Shared:WaitForChild("LanternArchetypes"))

print("========================================")
print("Dynamic Lantern System Test Suite")
print("========================================")

-- Test 1: Enable feature flags
print("\n📌 Test 1: Enabling feature flags...")
FeatureFlags.set("Lanterns.DynamicEnabled", true)
FeatureFlags.set("Lanterns.UseLightSocket", true)
assert(FeatureFlags.get("Lanterns.DynamicEnabled") == true, "Failed to enable dynamic lanterns")
print("✅ Feature flags enabled")

-- Test 2: Check if LanternKit exists
print("\n📌 Test 2: Checking for LanternKit...")
local kit = ReplicatedStorage:FindFirstChild("LanternKit")
if not kit then
	warn("⚠️ LanternKit not found! Run SetupLanternKit.server.luau first")
	print("Creating temporary kit...")
	-- Could call setup here if needed
else
	print("✅ LanternKit found with", #kit:GetChildren(), "categories")
end

-- Test 3: Spawn test lanterns in a grid
print("\n📌 Test 3: Spawning test lanterns...")
local testPositions = {}
local gridSize = 3
local spacing = 15

-- Spawn away from world spawn point to avoid interference
local gridOffset = Vector3.new(100, 0, 100) -- Offset from spawn

for x = 1, gridSize do
	for z = 1, gridSize do
		local pos = Vector3.new(
			(x - gridSize/2 - 0.5) * spacing,
			0,
			(z - gridSize/2 - 0.5) * spacing
		) + gridOffset
		table.insert(testPositions, pos)
	end
end

-- Spawn different archetypes
local archetypeNames = {"CommonA", "OrnateB", "TestSpiral"}
local spawnedLanterns = {}

for i, pos in ipairs(testPositions) do
	local archetypeName = archetypeNames[((i - 1) % #archetypeNames) + 1]
	local lantern = LanternSpawnService.SpawnDynamicLantern(
		"test_plot_" .. i,
		pos,
		"test",
		archetypeName
	)
	
	if lantern then
		table.insert(spawnedLanterns, lantern)
		print("  Spawned", archetypeName, "at", pos)
		-- Add test marker
		lantern:SetAttribute("IsTestLantern", true)
	else
		warn("  Failed to spawn lantern at", pos)
	end
	
	wait(0.1) -- Small delay to see spawning
end

print("✅ Spawned", #spawnedLanterns, "lanterns")

-- Test 4: Verify lantern attributes
print("\n📌 Test 4: Verifying lantern attributes...")
if #spawnedLanterns > 0 then
	local lantern = spawnedLanterns[1]
	local seed = lantern:GetAttribute("Seed")
	local archetype = lantern:GetAttribute("Archetype")
	local style = lantern:GetAttribute("Style")
	
	assert(seed ~= nil, "Lantern missing seed attribute")
	assert(archetype ~= nil, "Lantern missing archetype attribute")
	assert(style ~= nil, "Lantern missing style attribute")
	
	print("  Sample lantern attributes:")
	print("    Seed:", seed)
	print("    Archetype:", archetype)
	print("    Style:", style)
	print("✅ Attributes verified")
end

-- Test 5: Check for light sockets
print("\n📌 Test 5: Checking light sockets...")
local lightsFound = 0
for _, lantern in ipairs(spawnedLanterns) do
	local lightSocket = lantern:FindFirstChild("LightSocket", true)
	if lightSocket then
		lightsFound = lightsFound + 1
	end
end
print("  Found", lightsFound, "light sockets out of", #spawnedLanterns, "lanterns")
if lightsFound > 0 then
	print("✅ Light sockets working")
else
	warn("⚠️ No light sockets found")
end

-- Test 6: Determinism test
print("\n📌 Test 6: Testing determinism...")
local testPos = Vector3.new(0, 0, 150) -- Far from spawn
local plotId = "determinism_test"
local archetype = "CommonA"

-- Spawn first lantern
local lantern1 = LanternSpawnService.SpawnDynamicLantern(plotId, testPos, "test", archetype)
local seed1 = lantern1 and lantern1:GetAttribute("Seed")
local style1 = lantern1 and lantern1:GetAttribute("Style")

wait(0.1)

-- Clean up first lantern
if lantern1 then lantern1:Destroy() end

-- Spawn second lantern with same parameters
local lantern2 = LanternSpawnService.SpawnDynamicLantern(plotId, testPos, "test", archetype)
local seed2 = lantern2 and lantern2:GetAttribute("Seed")
local style2 = lantern2 and lantern2:GetAttribute("Style")

if seed1 == seed2 and style1 == style2 then
	print("✅ Determinism verified - identical seeds and styles")
else
	warn("⚠️ Determinism failed - seeds or styles don't match")
	print("  Seed1:", seed1, "Seed2:", seed2)
	print("  Style1:", style1, "Style2:", style2)
end

if lantern2 then lantern2:Destroy() end

-- Test 7: Performance test
print("\n📌 Test 7: Performance test...")
local startTime = tick()
local perfTestCount = 20
local perfLanterns = {}

for i = 1, perfTestCount do
	local pos = Vector3.new(
		math.random(150, 200),  -- Spawn in test area
		0,
		math.random(150, 200)
	)
	local lantern = LanternSpawnService.SpawnDynamicLantern(
		"perf_test_" .. i,
		pos,
		"test",
		"CommonA"
	)
	if lantern then
		lantern:SetAttribute("IsTestLantern", true)
		table.insert(perfLanterns, lantern)
	end
end

local elapsed = tick() - startTime
print("  Spawned", perfTestCount, "lanterns in", string.format("%.3f", elapsed), "seconds")
print("  Average:", string.format("%.3f", elapsed / perfTestCount), "seconds per lantern")

if elapsed / perfTestCount < 0.1 then
	print("✅ Performance acceptable")
else
	warn("⚠️ Performance may need optimization")
end

-- Clean up performance test lanterns after a delay
wait(2)
for _, lantern in ipairs(perfLanterns) do
	lantern:Destroy()
end

-- Test 8: Get statistics
print("\n📌 Test 8: Getting statistics...")
local stats = LanternSpawnService.GetStats()
print("  Total lanterns:", stats.total)
print("  Average height:", string.format("%.2f", stats.averageHeight))
print("  By archetype:")
for archetype, count in pairs(stats.byArchetype) do
	print("    " .. archetype .. ":", count)
end
print("  By style:")
for style, count in pairs(stats.byStyle) do
	print("    " .. style .. ":", count)
end
print("✅ Statistics retrieved")

-- Final summary
print("\n========================================")
print("Test Suite Complete!")
print("Total lanterns in workspace:", stats.total)
print("========================================")

print("\n💡 Tips:")
print("- Use /lantern commands in chat (Studio only)")
print("- Press Alt+D to toggle Designer UI")
print("- Use /lantern clear to remove all test lanterns")
print("- To run tests again: script:SetAttribute('AutoRun', true)")

return {}
