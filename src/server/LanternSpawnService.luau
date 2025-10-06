--!strict
-- LanternSpawnService.luau
-- Spawn facade for dynamic lanterns

local FeatureFlags = require(game.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FeatureFlags"))
local LanternFactory = require(script.Parent:WaitForChild("LanternFactory"))

local LanternSpawnService = {}

-- Spawn a dynamic lantern at the specified location
function LanternSpawnService.SpawnDynamicLantern(
	plotId: string,
	pos: Vector3,
	kind: string,
	archetypeName: string?,
	options: LanternFactory.AssembleOptions?
): Model?
	-- Check if dynamic lanterns are enabled
	if not FeatureFlags.get("Lanterns.DynamicEnabled") then
		return nil
	end
	
	-- Default archetype if not specified
	local archetype = archetypeName or "CommonA"
	
	-- Validate archetype exists
	local Shared = game.ReplicatedStorage:WaitForChild("Shared")
	local Archetypes = require(Shared:WaitForChild("LanternArchetypes"))
	if not Archetypes[archetype] then
		warn("Invalid archetype specified:", archetype, "- using CommonA")
		archetype = "CommonA"
	end
	
	-- Create the lantern
	local lantern = LanternFactory.assembleLantern(plotId, pos, archetype, options)
	
	if lantern then
		-- Set additional attributes
		lantern:SetAttribute("PlotId", plotId)
		lantern:SetAttribute("Kind", kind)
		lantern:SetAttribute("SpawnTime", os.time())
		
		-- Parent to workspace
		lantern.Parent = workspace
		
		-- If light socket is enabled, tag for LightMerger
		if FeatureFlags.get("Lanterns.UseLightSocket") then
			local head = lantern:FindFirstChild("Head")
			if head then
				local lightSocket = head:FindFirstChild("LightSocket", true)
				if lightSocket then
					-- Tag for light system to pick up
					lightSocket:AddTag("LanternLightSocket")
				end
			end
		end
	end
	
	return lantern
end

-- Batch spawn multiple lanterns (for testing or mass placement)
function LanternSpawnService.SpawnMultiple(
	positions: {Vector3},
	plotId: string?,
	archetypeName: string?,
	options: LanternFactory.AssembleOptions?
): {Model}
	local lanterns = {}
	
	for i, pos in ipairs(positions) do
		local id = plotId or ("plot_" .. tostring(i))
		local lantern = LanternSpawnService.SpawnDynamicLantern(id, pos, "standard", archetypeName, options)
		if lantern then
			table.insert(lanterns, lantern)
		end
	end
	
	return lanterns
end

-- Clear all dynamic lanterns (for testing)
function LanternSpawnService.ClearAll(): number
	local count = 0
	
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj.Name == "DynamicLantern" then
			obj:Destroy()
			count = count + 1
		end
	end
	
	return count
end

-- Get statistics about spawned lanterns
function LanternSpawnService.GetStats(): {[string]: any}
	local stats = {
		total = 0,
		byArchetype = {},
		byStyle = {},
		averageHeight = 0,
		totalHeight = 0
	}
	
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj.Name == "DynamicLantern" then
			stats.total = stats.total + 1
			
			-- Count by archetype
			local archetype = obj:GetAttribute("Archetype") or "unknown"
			stats.byArchetype[archetype] = (stats.byArchetype[archetype] or 0) + 1
			
			-- Count by style
			local style = obj:GetAttribute("Style") or "unknown"
			stats.byStyle[style] = (stats.byStyle[style] or 0) + 1
			
			-- Sum heights
			local height = obj:GetAttribute("Height") or 0
			stats.totalHeight = stats.totalHeight + height
		end
	end
	
	if stats.total > 0 then
		stats.averageHeight = stats.totalHeight / stats.total
	end
	
	return stats
end

return LanternSpawnService
