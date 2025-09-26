--!strict
-- SimpleLanternTest.server.luau
-- Simple test to spawn a single lantern without complex dependencies

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Only run if manually triggered or in Studio test mode
if not RunService:IsStudio() then
	return
end

print("\n🧪 Simple Lantern Test")
print("=====================")

-- Wait a bit for other systems to initialize
wait(3)

-- Step 1: Check for modules
local shared = ReplicatedStorage:WaitForChild("Shared", 5)
if not shared then
	warn("❌ Can't run test - Shared folder not found")
	return
end

-- Step 2: Enable the system
local FeatureFlags = require(shared:WaitForChild("FeatureFlags"))
FeatureFlags.set("Lanterns.DynamicEnabled", true)
print("✅ Enabled dynamic lanterns")

-- Step 3: Check for LanternKit
local kit = ReplicatedStorage:FindFirstChild("LanternKit")
if not kit then
	warn("❌ LanternKit not found - run SetupLanternKit first!")
	return
end
print("✅ LanternKit found")

-- Step 4: Load the spawn service
local LanternSpawnService = require(script.Parent:WaitForChild("LanternSpawnService"))
print("✅ LanternSpawnService loaded")

-- Step 5: Spawn a test lantern
print("\n🏮 Spawning test lantern...")
local testPosition = Vector3.new(0, 10, 0)
local lantern = LanternSpawnService.SpawnDynamicLantern(
	"simple_test",
	testPosition,
	"test",
	"CommonA"
)

if lantern then
	print("✅ Successfully spawned lantern at", testPosition)
	print("   Seed:", lantern:GetAttribute("Seed"))
	print("   Style:", lantern:GetAttribute("Style"))
	print("   Height:", lantern:GetAttribute("Height"))
	
	-- Make it glow for visibility
	local head = lantern:FindFirstChild("Head", true)
	if head then
		local body = head:FindFirstChild("Body")
		if body and body:IsA("BasePart") then
			body.Material = Enum.Material.Neon
			body.BrickColor = BrickColor.new("Bright yellow")
			print("✅ Added glow effect")
		end
	end
	
	print("\n✨ Test complete! Lantern spawned successfully.")
	print("   The lantern will remain for inspection.")
	print("   Use '/lantern clear' to remove it.")
else
	warn("❌ Failed to spawn lantern")
end

print("\n📝 Next steps:")
print("1. Check workspace for 'DynamicLantern' model")
print("2. Try '/lantern spawn' in chat")
print("3. Press Alt+D for Designer UI")
print("4. Run TestLanternSystem for full test suite")

return {}
