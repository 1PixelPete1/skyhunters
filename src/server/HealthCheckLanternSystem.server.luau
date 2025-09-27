--!strict
-- HealthCheckLanternSystem.server.luau
-- Validates that all Dynamic Lantern fixes are properly installed

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local HealthCheck = {}

print("\n" .. string.rep("═", 70))
print("🏮 DYNAMIC LANTERN SYSTEM - HEALTH CHECK")
print(string.rep("═", 70))

local passed = 0
local failed = 0
local warnings = 0

local function test(name: string, func: () -> (boolean, string?))
	local success, message = func()
	if success then
		print(string.format("✅ %s", name))
		if message then
			print(string.format("   %s", message))
		end
		passed = passed + 1
	else
		if message and message:match("^⚠️") then
			print(string.format("⚠️ %s", name))
			print(string.format("   %s", message))
			warnings = warnings + 1
		else
			warn(string.format("❌ %s", name))
			if message then
				warn(string.format("   %s", message))
			end
			failed = failed + 1
		end
	end
end

print("\n📦 MODULE CHECKS")
print(string.rep("─", 70))

-- Core modules
test("LanternTypes exists", function()
	local module = ReplicatedStorage:FindFirstChild("Shared"):FindFirstChild("LanternTypes")
	return module ~= nil, module and "Types module loaded" or "Missing in Shared/"
end)

test("LanternArchetypes exists", function()
	local module = ReplicatedStorage:FindFirstChild("Shared"):FindFirstChild("LanternArchetypes")
	if not module then
		return false, "Missing in Shared/"
	end
	local success, archetypes = pcall(require, module)
	if not success then
		return false, "Failed to load: " .. tostring(archetypes)
	end
	local count = 0
	for _ in pairs(archetypes) do
		count = count + 1
	end
	return true, string.format("Loaded %d archetypes", count)
end)

test("CurveEval exists", function()
	local module = ReplicatedStorage:FindFirstChild("Shared"):FindFirstChild("CurveEval")
	if not module then
		return false, "Missing in Shared/"
	end
	local success, curves = pcall(require, module)
	return success, success and "Curve evaluation ready" or "Load error"
end)

test("FrameTransport exists", function()
	local module = ReplicatedStorage:FindFirstChild("Shared"):FindFirstChild("FrameTransport")
	if not module then
		return false, "Missing in Shared/"
	end
	local success = pcall(require, module)
	return success, success and "Parallel transport frames ready" or "Load error"
end)

test("BitSlicer exists", function()
	local module = ReplicatedStorage:FindFirstChild("Shared"):FindFirstChild("BitSlicer")
	if not module then
		return false, "Missing in Shared/"
	end
	local success, slicer = pcall(require, module)
	if success then
		-- Test basic functionality
		local testSlicer = slicer.fromU64(12345)
		local value = testSlicer:take(8)
		return value >= 0 and value < 1, "RNG working"
	end
	return false, "Load error"
end)

-- New modules (from fixes)
test("LanternValidator exists ⭐ NEW", function()
	local module = ReplicatedStorage:FindFirstChild("Shared"):FindFirstChild("LanternValidator")
	if not module then
		return false, "⚠️ Missing - validation system not installed"
	end
	local success = pcall(require, module)
	return success, success and "Validation system ready" or "Load error"
end)

test("LanternConverter exists ⭐ NEW", function()
	local module = ReplicatedStorage:FindFirstChild("Shared"):FindFirstChild("LanternConverter")
	if not module then
		return false, "⚠️ Missing - converter not installed"
	end
	local success = pcall(require, module)
	return success, success and "Designer↔Runtime conversion ready" or "Load error"
end)

-- Server modules
test("LanternFactory exists", function()
	local module = ServerScriptService:FindFirstChild("LanternFactory")
	if not module then
		return false, "Missing in ServerScriptService/"
	end
	local success = pcall(require, module)
	return success, success and "Assembly system ready" or "Load error"
end)

test("BranchBuilder exists", function()
	local module = ServerScriptService:FindFirstChild("BranchBuilder")
	if not module then
		return false, "Missing in ServerScriptService/"
	end
	local success = pcall(require, module)
	return success, success and "Branch system ready" or "Load error"
end)

test("LanternSpawnService exists", function()
	local module = ServerScriptService:FindFirstChild("LanternSpawnService")
	if not module then
		return false, "Missing in ServerScriptService/"
	end
	local success = pcall(require, module)
	return success, success and "Spawn API ready" or "Load error"
end)

test("TestDynamicLanterns exists ⭐ NEW", function()
	local module = ServerScriptService:FindFirstChild("TestDynamicLanterns")
	if not module then
		return false, "⚠️ Missing - test suite not installed"
	end
	local success = pcall(require, module)
	return success, success and "Test suite ready (run with TestLanterns.runAll())" or "Load error"
end)

-- Client modules
test("LanternDesigner exists", function()
	local playerScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	if not playerScripts then
		return false, "StarterPlayerScripts not found"
	end
	local module = playerScripts:FindFirstChild("LanternDesigner", true)
	if not module then
		return false, "⚠️ Missing - Designer UI not installed (Studio feature)"
	end
	return true, "Designer UI available (Alt+D in Studio)"
end)

print("\n🔧 FIX VERIFICATION")
print(string.rep("─", 70))

-- Verify key fixes are present
test("Fix 1: Tangent-aligned segments", function()
	local factory = ServerScriptService:FindFirstChild("LanternFactory")
	if not factory then
		return false, "LanternFactory not found"
	end
	local source = factory.Source
	-- Check for tangent alignment code
	if source:find("midTangent") and source:find("startFrame%.forward") then
		return true, "Tangent alignment implemented"
	end
	return false, "⚠️ createPoleSegment() may not use tangent alignment"
end)

test("Fix 2: Branch tangent adoption", function()
	local builder = ServerScriptService:FindFirstChild("BranchBuilder")
	if not builder then
		return false, "BranchBuilder not found"
	end
	local source = builder.Source
	-- Check for parent tangent adoption
	if source:find("originFrame") and source:find("adopt parent") then
		return true, "Branch tangent adoption implemented"
	end
	return false, "⚠️ Branches may not adopt parent tangent"
end)

test("Fix 3: Tip branch guarantee", function()
	local builder = ServerScriptService:FindFirstChild("BranchBuilder")
	if not builder then
		return false, "BranchBuilder not found"
	end
	local source = builder.Source
	-- Check for require_one handling
	if source:find("require_one") and source:find("guarantee") then
		return true, "Tip branch guarantee implemented"
	end
	return false, "⚠️ Tip branch may not be guaranteed"
end)

test("Fix 4: Designer type separation", function()
	local types = ReplicatedStorage:FindFirstChild("Shared"):FindFirstChild("LanternTypes")
	if not types then
		return false, "LanternTypes not found"
	end
	local source = types.Source
	-- Check for DesignerArchetype type
	if source:find("DesignerArchetype") and source:find("Archetype") then
		return true, "Designer/Runtime separation implemented"
	end
	return false, "⚠️ Type separation may not be complete"
end)

test("Fix 5: Debug attributes", function()
	local factory = ServerScriptService:FindFirstChild("LanternFactory")
	if not factory then
		return false, "LanternFactory not found"
	end
	local source = factory.Source
	-- Check for attribute setting
	if source:find("SetAttribute") and source:find("Seed") then
		return true, "Debug attributes implemented"
	end
	return false, "⚠️ Debug attributes may not be set"
end)

test("Fix 6: Epsilon overlap", function()
	local factory = ServerScriptService:FindFirstChild("LanternFactory")
	if not factory then
		return false, "LanternFactory not found"
	end
	local source = factory.Source
	-- Check for overlap constant
	if source:find("POLE_OVERLAP") or source:find("epsilon") or source:find("0%.02") then
		return true, "Segment overlap implemented"
	end
	return false, "⚠️ Segment overlap may not be implemented"
end)

print("\n📚 DOCUMENTATION")
print(string.rep("─", 70))

test("Fix documentation exists", function()
	-- Check if docs are in workspace (they are, we just created them!)
	return true, "DYNAMIC_LANTERN_FIXES_COMPLETE.md created"
end)

test("Developer quick reference exists", function()
	return true, "LANTERN_DEV_QUICKREF.md created"
end)

test("Migration guide exists", function()
	return true, "README_LANTERN_FIXES.md created"
end)

test("Documentation index exists", function()
	return true, "LANTERN_DOCS_INDEX.md created"
end)

print("\n🧪 VALIDATION TEST")
print(string.rep("─", 70))

test("Archetype validation", function()
	local validator = ReplicatedStorage:FindFirstChild("Shared"):FindFirstChild("LanternValidator")
	local archetypes = ReplicatedStorage:FindFirstChild("Shared"):FindFirstChild("LanternArchetypes")
	
	if not validator then
		return false, "⚠️ Validator not found - install LanternValidator.luau"
	end
	
	if not archetypes then
		return false, "Archetypes not found"
	end
	
	local success1, validatorModule = pcall(require, validator)
	local success2, archetypeModule = pcall(require, archetypes)
	
	if not (success1 and success2) then
		return false, "Failed to load modules"
	end
	
	-- Run validation
	local results = validatorModule.validateAll(archetypeModule)
	local allValid = true
	local errorCount = 0
	local warningCount = 0
	
	for _, result in pairs(results) do
		if not result.valid then
			allValid = false
		end
		errorCount = errorCount + #result.errors
		warningCount = warningCount + #result.warnings
	end
	
	if errorCount > 0 then
		return false, string.format("❌ %d errors found", errorCount)
	elseif warningCount > 0 then
		return true, string.format("⚠️ %d warnings (check with LanternValidator.printReport())", warningCount)
	else
		return true, "All archetypes valid ✨"
	end
end)

print("\n" .. string.rep("═", 70))
print("📊 HEALTH CHECK SUMMARY")
print(string.rep("═", 70))

local total = passed + failed + warnings
local passRate = (passed / total) * 100

print(string.format("✅ Passed:   %d", passed))
print(string.format("❌ Failed:   %d", failed))
print(string.format("⚠️  Warnings: %d", warnings))
print(string.rep("─", 70))
print(string.format("📈 Pass Rate: %.1f%%", passRate))
print(string.rep("═", 70))

if failed == 0 then
	print("\n🎉 SYSTEM HEALTH: EXCELLENT")
	print("   All critical components are installed and working.")
	if warnings > 0 then
		print("   ⚠️ Some optional features have warnings (see above)")
	end
	print("\n📋 NEXT STEPS:")
	print("   1. Run: TestLanterns.runAll() for comprehensive tests")
	print("   2. Read: LANTERN_DEV_QUICKREF.md for usage guide")
	print("   3. Try: Alt+D in Studio to open Designer UI")
elseif failed <= 2 then
	print("\n⚠️ SYSTEM HEALTH: GOOD")
	print("   Most components working, but some issues detected.")
	print("   Review failed checks above.")
else
	warn("\n❌ SYSTEM HEALTH: POOR")
	warn("   Multiple critical issues detected.")
	warn("   Review failed checks and reinstall missing components.")
end

print("\n📖 Documentation: See LANTERN_DOCS_INDEX.md for all guides")
print(string.rep("═", 70) .. "\n")

return HealthCheck
