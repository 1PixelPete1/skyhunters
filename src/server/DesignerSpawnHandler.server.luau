--!strict
-- DesignerSpawnHandler.server.luau
-- Handles spawn requests from the Designer UI

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LanternSpawnService = require(script.Parent:WaitForChild("LanternSpawnService"))

-- Create RemoteEvent
local spawnRemote = ReplicatedStorage:FindFirstChild("SpawnDesignerLantern")
if not spawnRemote then
	spawnRemote = Instance.new("RemoteEvent")
	spawnRemote.Name = "SpawnDesignerLantern"
	spawnRemote.Parent = ReplicatedStorage
end

-- Handle spawn requests
spawnRemote.OnServerEvent:Connect(function(player, mode: string, position: Vector3, archetypeName: string, seed: number?)
	print(string.format("Designer spawn request from %s: mode=%s, archetype=%s, seed=%s", 
		player.Name, mode, archetypeName, tostring(seed)))
	
	-- Spawn lantern
	local lantern = LanternSpawnService.SpawnDynamicLantern(
		"designer_" .. player.UserId .. "_" .. tick(),
		position,
		"designer",
		archetypeName
	)
	
	if lantern then
		-- Mark as designer-spawned
		lantern:SetAttribute("SpawnedByDesigner", true)
		lantern:SetAttribute("DesignerPlayer", player.Name)
		
		if mode == "preview" then
			lantern:SetAttribute("IsPreview", true)
			-- Make semi-transparent
			for _, part in ipairs(lantern:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Transparency = math.min(0.7, part.Transparency + 0.4)
					part.Material = Enum.Material.ForceField
				end
			end
		end
		
		print(string.format("✅ Spawned %s for %s at %s", mode, player.Name, tostring(position)))
	else
		warn(string.format("❌ Failed to spawn lantern for %s", player.Name))
	end
end)

print("✅ Designer spawn handler initialized")
