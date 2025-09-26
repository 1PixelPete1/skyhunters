--!strict
-- LanternRemoteHandler.server.luau
-- Handles remote requests for spawning dynamic lanterns

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Only enable in Studio for security
if not RunService:IsStudio() then
	return
end

print("🔌 [LanternRemoteHandler] Setting up remote event handler...")

-- Create RemoteEvent for lantern spawning
local remoteEvent = Instance.new("RemoteEvent")
remoteEvent.Name = "SpawnDynamicLantern"
remoteEvent.Parent = ReplicatedStorage

-- Wait for modules to load
local Shared = ReplicatedStorage:WaitForChild("Shared")
local FeatureFlags = require(Shared:WaitForChild("FeatureFlags"))

local LanternSpawnService = nil
local loadAttempts = 0

-- Try to load the spawn service
repeat
	loadAttempts = loadAttempts + 1
	local success, result = pcall(function()
		return require(script.Parent:WaitForChild("LanternSpawnService", 2))
	end)
	
	if success then
		LanternSpawnService = result
		print("✅ [LanternRemoteHandler] LanternSpawnService loaded")
	else
		warn("⚠️ [LanternRemoteHandler] Waiting for LanternSpawnService... (attempt", loadAttempts, ")")
		task.wait(1)
	end
until LanternSpawnService or loadAttempts > 5

if not LanternSpawnService then
	warn("❌ [LanternRemoteHandler] Failed to load LanternSpawnService after", loadAttempts, "attempts")
	return
end

-- Handle spawn requests
remoteEvent.OnServerEvent:Connect(function(player: Player, position: Vector3?, archetypeName: string?)
	-- Validate player
	if not player or not player.Character then
		return
	end
	
	-- Check if dynamic lanterns are enabled
	if not FeatureFlags.get("Lanterns.DynamicEnabled") then
		warn("[LanternRemoteHandler] Dynamic lanterns are disabled")
		return
	end
	
	-- Validate position
	if not position or typeof(position) ~= "Vector3" then
		warn("[LanternRemoteHandler] Invalid position from", player.Name)
		return
	end
	
	-- Clamp position to reasonable range from player
	local character = player.Character
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart then
		local distance = (position - humanoidRootPart.Position).Magnitude
		if distance > 100 then
			warn("[LanternRemoteHandler] Position too far from player:", distance, "studs")
			return
		end
	end
	
	-- Validate archetype
	local archetype = archetypeName or "CommonA"
	local Archetypes = require(Shared:WaitForChild("LanternArchetypes"))
	if not Archetypes[archetype] then
		warn("[LanternRemoteHandler] Invalid archetype:", archetype, "- using CommonA")
		archetype = "CommonA"
	end
	
	-- Spawn the lantern
	print("[LanternRemoteHandler] Spawning lantern for", player.Name, "at", position, "with archetype", archetype)
	
	local lantern = LanternSpawnService.SpawnDynamicLantern(
		"player_" .. player.UserId,
		position,
		"designer",
		archetype
	)
	
	if lantern then
		lantern:SetAttribute("SpawnedBy", player.Name)
		lantern:SetAttribute("SpawnedByDesigner", true)
		print("✅ [LanternRemoteHandler] Lantern spawned successfully")
	else
		warn("❌ [LanternRemoteHandler] Failed to spawn lantern")
	end
end)

-- Chat commands for testing (Studio only)
if RunService:IsStudio() then
	Players.PlayerAdded:Connect(function(player)
		player.Chatted:Connect(function(message)
			local lower = message:lower()
			
			if lower == "/lantern" or lower == "/lantern help" then
				print("\n🏮 Lantern Commands:")
				print("  /lantern spawn - Spawn a lantern at your position")
				print("  /lantern clear - Clear all dynamic lanterns")
				print("  /lantern cleartest - Clear test lanterns only")
				print("  /lantern clearnear [radius] - Clear lanterns near spawn")
				print("  /lantern test - Run test suite")
				print("  /lantern stats - Show lantern statistics")
				print("  /lantern designer - Toggle designer UI")
				
			elseif lower == "/lantern spawn" or lower:match("^/lantern spawn ") then
				local parts = message:split(" ")
				local archetype = parts[3] or "CommonA"
				
				if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
					local pos = player.Character.HumanoidRootPart.Position + Vector3.new(5, 0, 5)
					local lantern = LanternSpawnService.SpawnDynamicLantern(
						"chat_command",
						pos,
						"command",
						archetype
					)
					if lantern then
						print("✅ Spawned", archetype, "lantern for", player.Name)
					end
				end
				
			elseif lower == "/lantern clear" then
				local count = LanternSpawnService.ClearAll()
				print("🧹 Cleared", count, "lanterns")
				
			elseif lower == "/lantern cleartest" then
				local CleanupService = require(script.Parent:WaitForChild("CleanupLanterns"))
				local count = CleanupService.cleanupTestLanterns()
				print("🧹 Cleared", count, "test lanterns")
				
			elseif lower:match("^/lantern clearnear") then
				local parts = message:split(" ")
				local radius = tonumber(parts[3]) or 50
				local CleanupService = require(script.Parent:WaitForChild("CleanupLanterns"))
				local count = CleanupService.cleanupNearSpawn(radius)
				print("🧹 Cleared", count, "lanterns within", radius, "studs of spawn")
				
			elseif lower == "/lantern test" then
				-- Enable test script
				local testScript = script.Parent:FindFirstChild("TestLanternSystem")
				if testScript then
					testScript:SetAttribute("AutoRun", true)
					testScript.Disabled = false
					print("🧪 Running test suite...")
				end
				
			elseif lower == "/lantern stats" then
				local stats = LanternSpawnService.GetStats()
				print("\n📊 Lantern Statistics:")
				print("  Total:", stats.total)
				print("  Average Height:", string.format("%.2f", stats.averageHeight))
				for archetype, count in pairs(stats.byArchetype) do
					print("  " .. archetype .. ":", count)
				end
				
			elseif lower == "/lantern designer" then
				-- Toggle designer UI
				player:SetAttribute("LanternDesignerEnabled", not player:GetAttribute("LanternDesignerEnabled"))
				local enabled = player:GetAttribute("LanternDesignerEnabled")
				print("🎨 Designer UI:", enabled and "Enabled" or "Disabled")
			end
		end)
	end)
	
	print("✅ [LanternRemoteHandler] Chat commands enabled (Studio only)")
	print("   Type '/lantern' for help")
end

return {}
