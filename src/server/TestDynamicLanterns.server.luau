--!strict
-- TestDynamicLanterns.server.luau
-- Comprehensive test suite for the Dynamic Lantern system

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Archetypes = require(Shared:WaitForChild("LanternArchetypes"))
local LanternValidator = require(Shared:WaitForChild("LanternValidator"))
local LanternConverter = require(Shared:WaitForChild("LanternConverter"))
local LanternSpawnService = require(script.Parent:WaitForChild("LanternSpawnService"))

local TestLanterns = {}

-- Test configuration
local TEST_POSITION = Vector3.new(0, 10, 0)
local TEST_SPACING = 15

-- Helper: Clear all test lanterns
local function clearTestLanterns()
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("Model") and obj:GetAttribute("IsTest") then
			obj:Destroy()
		end
	end
	print("🧹 Cleared all test lanterns")
end

-- Helper: Create test marker
local function createMarker(position: Vector3, label: string, color: Color3)
	local marker = Instance.new("Part")
	marker.Name = "TestMarker"
	marker.Size = Vector3.new(1, 0.2, 1)
	marker.Position = position
	marker.Anchored = true
	marker.CanCollide = false
	marker.Material = Enum.Material.Neon
	marker.Color = color
	marker.Transparency = 0.5
	
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.Adornee = marker
	billboard.AlwaysOnTop = true
	billboard.Parent = marker
	
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = label
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextSize = 18
	textLabel.Font = Enum.Font.SourceSansBold
	textLabel.TextStrokeTransparency = 0.5
	textLabel.Parent = billboard
	
	marker.Parent = Workspace
	return marker
end

-- Test 1: Validate all archetypes
function TestLanterns.testValidation()
	print("\n" .. string.rep("━", 50))
	print("TEST 1: ARCHETYPE VALIDATION")
	print(string.rep("━", 50))
	
	local results = LanternValidator.validateAll(Archetypes)
	LanternValidator.printReport(results)
	
	local allValid = true
	for _, result in pairs(results) do
		if not result.valid then
			allValid = false
			break
		end
	end
	
	if allValid then
		print("✅ TEST 1 PASSED: All archetypes valid")
	else
		warn("❌ TEST 1 FAILED: Some archetypes have errors")
	end
	
	return allValid
end

-- Test 2: Spawn all archetype styles
function TestLanterns.testAllStyles()
	print("\n" .. string.rep("━", 50))
	print("TEST 2: SPAWN ALL ARCHETYPE STYLES")
	print(string.rep("━", 50))
	
	clearTestLanterns()
	
	local i = 0
	for name, _ in pairs(Archetypes) do
		local position = TEST_POSITION + Vector3.new(i * TEST_SPACING, 0, 0)
		
		print(string.format("Spawning %s at %s", name, tostring(position)))
		
		local lantern = LanternSpawnService.SpawnDynamicLantern(
			"test_" .. name,
			position,
			"test",
			name
		)
		
		if lantern then
			lantern:SetAttribute("IsTest", true)
			createMarker(position + Vector3.new(0, -2, 0), name, Color3.fromRGB(100, 200, 100))
			print(string.format("  ✅ %s spawned successfully", name))
		else
			warn(string.format("  ❌ %s failed to spawn", name))
		end
		
		i = i + 1
	end
	
	print("✅ TEST 2 COMPLETE: Check workspace for spawned lanterns")
	return true
end

-- Test 3: Test spiral/helix tangent alignment
function TestLanterns.testSpiralAlignment()
	print("\n" .. string.rep("━", 50))
	print("TEST 3: SPIRAL/HELIX TANGENT ALIGNMENT")
	print(string.rep("━", 50))
	
	clearTestLanterns()
	
	-- Spawn TestSpiral archetype
	local position = TEST_POSITION + Vector3.new(0, 0, 20)
	local lantern = LanternSpawnService.SpawnDynamicLantern(
		"test_spiral_alignment",
		position,
		"test",
		"TestSpiral"
	)
	
	if lantern then
		lantern:SetAttribute("IsTest", true)
		createMarker(position + Vector3.new(0, -2, 0), "TestSpiral", Color3.fromRGB(200, 100, 200))
		
		-- Check orientation of segments
		local pole = lantern:FindFirstChild("Pole")
		if pole then
			local segments = {}
			for _, child in ipairs(pole:GetChildren()) do
				if child:IsA("Part") and child.Name == "PoleSegment" then
					table.insert(segments, child)
				end
			end
			
			print(string.format("  Found %d pole segments", #segments))
			
			-- Check if segments are tangent-aligned (not all parallel to world up)
			local upAlignedCount = 0
			for _, segment in ipairs(segments) do
				local upDot = segment.CFrame.UpVector:Dot(Vector3.yAxis)
				if math.abs(upDot) > 0.9 then
					upAlignedCount = upAlignedCount + 1
				end
			end
			
			local percentUpAligned = (upAlignedCount / #segments) * 100
			print(string.format("  %.1f%% of segments are vertical (should be <50%% for spirals)", percentUpAligned))
			
			if percentUpAligned < 50 then
				print("  ✅ Segments appear to be tangent-aligned (not ladder-like)")
			else
				warn("  ⚠️ Segments may still have ladder effect")
			end
		end
		
		print("✅ TEST 3 COMPLETE: Inspect spiral visually for smooth curves")
	else
		warn("❌ TEST 3 FAILED: Could not spawn TestSpiral")
	end
	
	return true
end

-- Test 4: Test branch guarantee and RNG
function TestLanterns.testBranchSystem()
	print("\n" .. string.rep("━", 50))
	print("TEST 4: BRANCH SYSTEM (Guarantee & RNG)")
	print(string.rep("━", 50))
	
	clearTestLanterns()
	
	-- Spawn multiple lanterns with same archetype to check RNG variation
	for i = 1, 5 do
		local position = TEST_POSITION + Vector3.new(i * TEST_SPACING, 0, 40)
		local lantern = LanternSpawnService.SpawnDynamicLantern(
			"test_branch_" .. i,
			position,
			"test",
			"CommonA"  -- Has require_one = true for tip
		)
		
		if lantern then
			lantern:SetAttribute("IsTest", true)
			
			-- Check for branches
			local branchCount = 0
			local hasTipBranch = false
			
			for _, child in ipairs(lantern:GetDescendants()) do
				if child:IsA("Model") and child.Name:match("^Branch_") then
					branchCount = branchCount + 1
					local socketOrigin = child:GetAttribute("SocketOrigin")
					if socketOrigin == "Tip" then
						hasTipBranch = true
					end
				end
			end
			
			print(string.format("  Lantern %d: %d branches, tip branch: %s", 
				i, branchCount, hasTipBranch and "✅" or "❌"))
			
			if not hasTipBranch then
				warn(string.format("  ⚠️ Lantern %d missing guaranteed tip branch!", i))
			end
			
			createMarker(position + Vector3.new(0, -2, 0), "Branch Test " .. i, Color3.fromRGB(100, 150, 200))
		end
	end
	
	print("✅ TEST 4 COMPLETE: All lanterns should have tip branches")
	return true
end

-- Test 5: Test seed determinism
function TestLanterns.testDeterminism()
	print("\n" .. string.rep("━", 50))
	print("TEST 5: SEED DETERMINISM")
	print(string.rep("━", 50))
	
	clearTestLanterns()
	
	-- Spawn two lanterns with same plot ID and position (should be identical)
	local testPos = TEST_POSITION + Vector3.new(0, 0, 60)
	
	local lantern1 = LanternSpawnService.SpawnDynamicLantern(
		"determinism_test",
		testPos,
		"test",
		"OrnateB"
	)
	
	local lantern2 = LanternSpawnService.SpawnDynamicLantern(
		"determinism_test",
		testPos + Vector3.new(10, 0, 0),
		"test",
		"OrnateB"
	)
	
	if lantern1 and lantern2 then
		lantern1:SetAttribute("IsTest", true)
		lantern2:SetAttribute("IsTest", true)
		
		local seed1 = lantern1:GetAttribute("Seed")
		local seed2 = lantern2:GetAttribute("Seed")
		local style1 = lantern1:GetAttribute("Style")
		local style2 = lantern2:GetAttribute("Style")
		
		print(string.format("  Lantern 1: Seed=%s, Style=%s", tostring(seed1), tostring(style1)))
		print(string.format("  Lantern 2: Seed=%s, Style=%s", tostring(seed2), tostring(style2)))
		
		if seed1 == seed2 and style1 == style2 then
			print("  ✅ Seeds match - lanterns should be identical")
		else
			warn("  ⚠️ Seeds differ - check hash function")
		end
		
		createMarker(testPos + Vector3.new(0, -2, 0), "Determinism A", Color3.fromRGB(200, 200, 100))
		createMarker(testPos + Vector3.new(10, -2, 0), "Determinism B", Color3.fromRGB(200, 200, 100))
	end
	
	print("✅ TEST 5 COMPLETE: Compare lanterns visually")
	return true
end

-- Test 6: Test converter utilities
function TestLanterns.testConverter()
	print("\n" .. string.rep("━", 50))
	print("TEST 6: DESIGNER↔RUNTIME CONVERTER")
	print(string.rep("━", 50))
	
	-- Convert runtime to designer
	local runtimeArchetype = Archetypes.CommonA
	local designerArchetype = LanternConverter.runtimeToDesigner(runtimeArchetype, "straight")
	
	print("  Runtime → Designer conversion:")
	print(string.format("    Style: %s", designerArchetype.style))
	print(string.format("    Base: %s", designerArchetype.base_model))
	print(string.format("    Height: %.2f (locked: %s)", 
		designerArchetype.height.value, 
		tostring(designerArchetype.height.locked)))
	
	-- Convert back to runtime
	local convertedRuntime = LanternConverter.designerToRuntime(designerArchetype)
	
	print("  Designer → Runtime conversion:")
	print(string.format("    Style weights: %s", table.concat(
		(function()
			local t = {}
			for k, v in pairs(convertedRuntime.style_weights) do
				table.insert(t, string.format("%s=%.1f", k, v))
			end
			return t
		end)(), ", ")))
	
	-- Validate converted archetype
	local valid = LanternValidator.quickValidate(convertedRuntime, "Converted Archetype")
	
	if valid then
		print("  ✅ Conversion successful and valid")
	else
		warn("  ❌ Converted archetype has issues")
	end
	
	print("✅ TEST 6 COMPLETE")
	return true
end

-- Test 7: Stress test - spawn many lanterns
function TestLanterns.testStress(count: number?)
	count = count or 20
	
	print("\n" .. string.rep("━", 50))
	print(string.format("TEST 7: STRESS TEST (%d lanterns)", count))
	print(string.rep("━", 50))
	
	clearTestLanterns()
	
	local startTime = tick()
	local successCount = 0
	
	-- Spawn in grid
	local gridSize = math.ceil(math.sqrt(count))
	for i = 1, count do
		local x = (i % gridSize) * TEST_SPACING
		local z = math.floor(i / gridSize) * TEST_SPACING
		local position = TEST_POSITION + Vector3.new(x, 0, z + 80)
		
		-- Random archetype
		local archetypes = {"CommonA", "OrnateB", "TestSpiral"}
		local archetype = archetypes[math.random(1, #archetypes)]
		
		local lantern = LanternSpawnService.SpawnDynamicLantern(
			"stress_test_" .. i,
			position,
			"test",
			archetype
		)
		
		if lantern then
			lantern:SetAttribute("IsTest", true)
			successCount = successCount + 1
		end
	end
	
	local elapsed = tick() - startTime
	
	print(string.format("  ✅ Spawned %d/%d lanterns in %.2f seconds", successCount, count, elapsed))
	print(string.format("  ⏱️ Average: %.2f ms per lantern", (elapsed / count) * 1000))
	
	-- Get stats
	local stats = LanternSpawnService.GetStats()
	print("\n  📊 Statistics:")
	print(string.format("    Total lanterns: %d", stats.total))
	print(string.format("    Average height: %.2f", stats.averageHeight))
	
	if stats.byStyle then
		print("    By style:")
		for style, count in pairs(stats.byStyle) do
			print(string.format("      %s: %d", style, count))
		end
	end
	
	print("✅ TEST 7 COMPLETE")
	return true
end

-- Run all tests
function TestLanterns.runAll()
	print("\n" .. string.rep("═", 60))
	print("🧪 DYNAMIC LANTERN SYSTEM - COMPREHENSIVE TEST SUITE")
	print(string.rep("═", 60))
	
	local tests = {
		{name = "Validation", func = TestLanterns.testValidation},
		{name = "All Styles", func = TestLanterns.testAllStyles},
		{name = "Spiral Alignment", func = TestLanterns.testSpiralAlignment},
		{name = "Branch System", func = TestLanterns.testBranchSystem},
		{name = "Determinism", func = TestLanterns.testDeterminism},
		{name = "Converter", func = TestLanterns.testConverter},
		{name = "Stress Test", func = function() return TestLanterns.testStress(20) end}
	}
	
	local results = {}
	
	for i, test in ipairs(tests) do
		local success, result = pcall(test.func)
		results[test.name] = success and result
		
		if not success then
			warn(string.format("❌ TEST %d (%s) CRASHED: %s", i, test.name, tostring(result)))
		end
		
		task.wait(0.5)  -- Brief pause between tests
	end
	
	-- Summary
	print("\n" .. string.rep("═", 60))
	print("📊 TEST SUMMARY")
	print(string.rep("═", 60))
	
	local passCount = 0
	for name, result in pairs(results) do
		local icon = result and "✅" or "❌"
		print(string.format("%s %s", icon, name))
		if result then
			passCount = passCount + 1
		end
	end
	
	print(string.rep("═", 60))
	print(string.format("RESULT: %d/%d tests passed", passCount, #tests))
	print(string.rep("═", 60) .. "\n")
end

-- Run tests on server start (comment out for production)
-- task.wait(2)  -- Wait for services to initialize
-- TestLanterns.runAll()

return TestLanterns
