--!strict
-- CleanupLanterns.server.luau
-- Utility script to clean up unwanted lanterns

local RunService = game:GetService("RunService")
local workspace = game:GetService("Workspace")

local CleanupService = {}

-- Clean up all lanterns near spawn
function CleanupService.cleanupNearSpawn(radius: number?)
	radius = radius or 50 -- Default 50 studs from spawn
	
	local spawnLocation = workspace:FindFirstChild("SpawnLocation") or workspace:FindFirstChild("Spawn")
	local spawnPos = spawnLocation and spawnLocation.Position or Vector3.new(0, 0, 0)
	
	local cleanedCount = 0
	print("🧹 [CleanupLanterns] Cleaning up lanterns within", radius, "studs of spawn...")
	
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and (obj.Name == "DynamicLantern" or obj:GetAttribute("IsTestLantern")) then
			local primaryPart = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
			if primaryPart then
				local distance = (primaryPart.Position - spawnPos).Magnitude
				if distance <= radius then
					obj:Destroy()
					cleanedCount = cleanedCount + 1
					print("   Removed lantern at distance:", math.floor(distance))
				end
			end
		end
	end
	
	print("✅ [CleanupLanterns] Cleaned up", cleanedCount, "lanterns near spawn")
	return cleanedCount
end

-- Clean up all test lanterns
function CleanupService.cleanupTestLanterns()
	local cleanedCount = 0
	print("🧹 [CleanupLanterns] Cleaning up test lanterns...")
	
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj:GetAttribute("IsTestLantern") == true then
			obj:Destroy()
			cleanedCount = cleanedCount + 1
		end
	end
	
	print("✅ [CleanupLanterns] Cleaned up", cleanedCount, "test lanterns")
	return cleanedCount
end

-- Clean up ALL dynamic lanterns
function CleanupService.cleanupAllLanterns()
	local cleanedCount = 0
	print("🧹 [CleanupLanterns] Cleaning up ALL dynamic lanterns...")
	
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj.Name == "DynamicLantern" then
			obj:Destroy()
			cleanedCount = cleanedCount + 1
		end
	end
	
	print("✅ [CleanupLanterns] Cleaned up", cleanedCount, "lanterns total")
	return cleanedCount
end

-- Auto-cleanup on server start (Studio only)
if RunService:IsStudio() then
	-- Clean up lanterns near spawn on startup
	task.wait(1) -- Wait for workspace to load
	CleanupService.cleanupNearSpawn(75) -- Clean within 75 studs of spawn
	
	-- Also clean up any test lanterns
	CleanupService.cleanupTestLanterns()
	
	print("💡 [CleanupLanterns] Tip: Use these commands in command bar:")
	print("   require(script).cleanupNearSpawn(50) -- Clean within 50 studs")
	print("   require(script).cleanupTestLanterns() -- Clean test lanterns only")
	print("   require(script).cleanupAllLanterns() -- Clean ALL lanterns")
end

return CleanupService
