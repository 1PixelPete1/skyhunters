--!strict
-- MainIntegration.server.luau
-- Integration module to wire dynamic lanterns into existing systems

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local FeatureFlags = require(game.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FeatureFlags"))
local LanternSpawnService = require(script.Parent:WaitForChild("LanternSpawnService"))

-- Console commands (Studio only)
if RunService:IsStudio() then
	-- Store override seed
	local overrideSeed: number? = nil
	
	-- Register console commands
	Players.PlayerAdded:Connect(function(player)
		player.Chatted:Connect(function(message)
			local args = string.split(message, " ")
			
			if args[1] == "/lantern" then
				if args[2] == "seed" and args[3] then
					-- Set override seed
					overrideSeed = tonumber(args[3])
					print("Lantern seed override set to:", overrideSeed)
					
				elseif args[2] == "spawn" then
					-- Spawn at player's look point
					local character = player.Character
					if character then
						local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
						local head = character:FindFirstChild("Head")
						
						if humanoidRootPart and head then
							-- Cast ray from head in look direction
							local lookDir = head.CFrame.LookVector
							local rayResult = workspace:Raycast(
								head.Position,
								lookDir * 100,
								RaycastParams.new()
							)
							
							local spawnPos = if rayResult then 
								rayResult.Position 
							else 
								head.Position + lookDir * 10
							
							local archetype = args[3] or "CommonA"
							local lantern = LanternSpawnService.SpawnDynamicLantern(
								"console_spawn",
								spawnPos,
								"test",
								archetype
							)
							
							if lantern and overrideSeed then
								lantern:SetAttribute("OverrideSeed", overrideSeed)
							end
							
							print("Spawned lantern at:", spawnPos, "with archetype:", archetype)
						end
					end
					
				elseif args[2] == "design" then
					-- Toggle designer UI (handled by client)
					player:SetAttribute("LanternDesignerEnabled", 
						not player:GetAttribute("LanternDesignerEnabled"))
					print("Designer UI toggled")
					
				elseif args[2] == "clear_session" then
					-- Clear designer session
					local sessionFolder = workspace:FindFirstChild("__LanternDesignerSession")
					if sessionFolder then
						sessionFolder:Destroy()
						print("Designer session cleared")
					else
						print("No designer session found")
					end
					
				elseif args[2] == "clear" then
					-- Clear all dynamic lanterns
					local count = LanternSpawnService.ClearAll()
					print("Cleared", count, "dynamic lanterns")
					
				elseif args[2] == "stats" then
					-- Show statistics
					local stats = LanternSpawnService.GetStats()
					print("=== Lantern Statistics ===")
					print("Total:", stats.total)
					print("Average Height:", string.format("%.2f", stats.averageHeight))
					print("By Archetype:")
					for archetype, count in pairs(stats.byArchetype) do
						print("  ", archetype, ":", count)
					end
					print("By Style:")
					for style, count in pairs(stats.byStyle) do
						print("  ", style, ":", count)
					end
					
				elseif args[2] == "flag" and args[3] and args[4] then
					-- Set feature flag
					local flagName = args[3]
					local value = args[4] == "true"
					FeatureFlags.set(flagName, value)
					print("Set flag", flagName, "to", value)
					
				elseif args[2] == "flags" then
					-- Show all flags
					local flags = FeatureFlags.getAll()
					print("=== Feature Flags ===")
					for name, value in pairs(flags) do
						local desc = FeatureFlags.getDescription(name)
						print(name, ":", value, "-", desc or "")
					end
					
				else
					-- Help
					print("=== Lantern Console Commands ===")
					print("/lantern seed <number> - Set override seed for testing")
					print("/lantern spawn [archetype] - Spawn lantern at look point")
					print("/lantern design - Toggle designer UI")
					print("/lantern clear_session - Clear designer session")
					print("/lantern clear - Clear all dynamic lanterns")
					print("/lantern stats - Show statistics")
					print("/lantern flag <name> <true/false> - Set feature flag")
					print("/lantern flags - Show all feature flags")
				end
			end
		end)
	end)
end

-- Hook into existing lantern spawn systems
-- This would normally integrate with your existing spawn logic
-- For now, we'll create a simple test spawner

local function integrateWithExistingSystems()
	-- Example: Override existing lantern spawns if flag is enabled
	local existingSpawnFunction = _G.SpawnLantern  -- Assuming this exists
	
	if existingSpawnFunction and FeatureFlags.get("Lanterns.DynamicEnabled") then
		_G.SpawnLantern = function(plotId: string, position: Vector3, ...)
			-- Use dynamic system
			return LanternSpawnService.SpawnDynamicLantern(plotId, position, "standard", "CommonA")
		end
		print("Dynamic lantern system integrated")
	end
end

-- Initialize integration
if FeatureFlags.get("Lanterns.DynamicEnabled") then
	integrateWithExistingSystems()
	print("Dynamic Lantern System Active")
else
	print("Dynamic Lantern System Inactive (enable with Lanterns.DynamicEnabled flag)")
end

-- Export for other systems to use
return {
	SpawnLantern = LanternSpawnService.SpawnDynamicLantern,
	ClearLanterns = LanternSpawnService.ClearAll,
	GetStats = LanternSpawnService.GetStats
}
