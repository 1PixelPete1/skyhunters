--!strict
-- ResourceNodeService.luau
-- Manages temporary resource nodes for exploration

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local SafeRequire = require(ReplicatedStorage.Shared.SafeRequire)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local LootTableService = require(script.Parent:WaitForChild("LootTableService"))
local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService"))

export type ResourceNode = {
	id: string,
	model: Model,
	position: Vector3,
	lootTableId: string,
	respawnTime: number,
	lastHarvested: number?,
	isActive: boolean,
	nodeType: string,
}

local ResourceNodeService = {}
ResourceNodeService.__index = ResourceNodeService

-- Constants
local NODE_CHECK_RADIUS = 8
local RESPAWN_TIME = 60 -- seconds
local NODE_COLORS = {
	BasicResource = Color3.fromRGB(139, 90, 43),  -- Brown
	RichResource = Color3.fromRGB(192, 192, 192),  -- Silver
	CrudeOilNode = Color3.fromRGB(20, 20, 20),     -- Black
	TreasureChest = Color3.fromRGB(255, 215, 0),   -- Gold
	EpicChest = Color3.fromRGB(138, 43, 226),      -- Purple
}

-- Private variables
local resourceNodes: {[string]: ResourceNode} = {}
local nodeFolder: Folder?
local nodeHarvestedSignal = Signal.new()

-- Initialize service
function ResourceNodeService:Init()
	-- Create node folder
	nodeFolder = Workspace:FindFirstChild("ResourceNodes")
	if not nodeFolder then
		nodeFolder = Instance.new("Folder")
		nodeFolder.Name = "ResourceNodes"
		nodeFolder.Parent = Workspace
	end
	
	-- Initialize loot service
	LootTableService:Init()
	
	-- Spawn initial nodes
	self:SpawnInitialNodes()
	
	-- Respawn loop
	RunService.Heartbeat:Connect(function()
		self:UpdateNodes()
	end)
	
	print("[ResourceNodeService] Initialized")
end

-- Spawn initial nodes for testing
function ResourceNodeService:SpawnInitialNodes()
	-- Spawn nodes around the world
	local nodeConfigs = {
		-- Near spawn hub
		{pos = Vector3.new(200, 105, 0), type = "BasicResource"},
		{pos = Vector3.new(-200, 105, 0), type = "BasicResource"},
		{pos = Vector3.new(0, 105, 200), type = "BasicResource"},
		{pos = Vector3.new(0, 105, -200), type = "BasicResource"},
		
		-- Further out
		{pos = Vector3.new(400, 105, 400), type = "RichResource"},
		{pos = Vector3.new(-400, 105, 400), type = "RichResource"},
		{pos = Vector3.new(400, 105, -400), type = "RichResource"},
		{pos = Vector3.new(-400, 105, -400), type = "RichResource"},
		
		-- Oil deposits
		{pos = Vector3.new(600, 105, 0), type = "CrudeOilNode"},
		{pos = Vector3.new(-600, 105, 0), type = "CrudeOilNode"},
		{pos = Vector3.new(0, 105, 600), type = "CrudeOilNode"},
		{pos = Vector3.new(0, 105, -600), type = "CrudeOilNode"},
		
		-- Treasure chests (on sky islands if they exist)
		{pos = Vector3.new(800, 200, 800), type = "TreasureChest"},
		{pos = Vector3.new(-800, 200, -800), type = "TreasureChest"},
	}
	
	for i, config in ipairs(nodeConfigs) do
		self:SpawnNode(config.pos, config.type)
	end
end

-- Spawn a resource node
function ResourceNodeService:SpawnNode(position: Vector3, nodeType: string): ResourceNode?
	local lootTable = LootTableService:GetLootTable(nodeType)
	if not lootTable then
		warn("[ResourceNodeService] Unknown node type:", nodeType)
		return nil
	end
	
	-- Create node model
	local model = Instance.new("Model")
	model.Name = nodeType .. "_Node"
	
	-- Create visual (simple part for now)
	local part = Instance.new("Part")
	part.Name = "NodePart"
	part.Size = Vector3.new(4, 4, 4)
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Neon
	part.Color = NODE_COLORS[nodeType] or Color3.fromRGB(100, 100, 100)
	part.Transparency = 0.3
	part.Parent = model
	
	-- Add glow effect
	local pointLight = Instance.new("PointLight")
	pointLight.Brightness = 2
	pointLight.Range = 10
	pointLight.Color = part.Color
	pointLight.Parent = part
	
	-- Add floating animation
	local floatHeight = 2
	local floatSpeed = 1
	task.spawn(function()
		local startY = position.Y
		local time = 0
		while part.Parent do
			time = time + RunService.Heartbeat:Wait()
			part.Position = Vector3.new(
				position.X,
				startY + math.sin(time * floatSpeed) * floatHeight,
				position.Z
			)
			part.Rotation = Vector3.new(0, time * 30, 0)
		end
	end)
	
	-- Add selection box
	local selectionBox = Instance.new("SelectionBox")
	selectionBox.Adornee = part
	selectionBox.Color3 = part.Color
	selectionBox.LineThickness = 0.1
	selectionBox.Transparency = 0.5
	selectionBox.Parent = part
	
	-- Create interaction detector
	local detector = Instance.new("Part")
	detector.Name = "Detector"
	detector.Size = Vector3.new(NODE_CHECK_RADIUS, NODE_CHECK_RADIUS, NODE_CHECK_RADIUS)
	detector.Position = position
	detector.Anchored = true
	detector.CanCollide = false
	detector.Transparency = 1
	detector.Parent = model
	
	model.Parent = nodeFolder
	
	-- Create node data
	local nodeId = tostring(tick()) .. "_" .. nodeType
	local node: ResourceNode = {
		id = nodeId,
		model = model,
		position = position,
		lootTableId = nodeType,
		respawnTime = RESPAWN_TIME,
		lastHarvested = nil,
		isActive = true,
		nodeType = nodeType,
	}
	
	resourceNodes[nodeId] = node
	
	-- Setup interaction
	self:SetupNodeInteraction(node)
	
	return node
end

-- Setup node interaction
function ResourceNodeService:SetupNodeInteraction(node: ResourceNode)
	local detector = node.model:FindFirstChild("Detector")
	if not detector then return end
	
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not node.isActive then return end
		
		-- Check for nearby players
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			if not character then continue end
			
			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
			if not humanoidRootPart then continue end
			
			local distance = (humanoidRootPart.Position - node.position).Magnitude
			if distance <= NODE_CHECK_RADIUS / 2 then
				-- Check if player is in Run state
				local playerState = PlayerStateService:GetPlayerState(player)
				if playerState == "Run" then
					self:HarvestNode(node, player)
					break
				end
			end
		end
	end)
	
	-- Store connection for cleanup
	node.model:SetAttribute("ConnectionId", tostring(connection))
end

-- Harvest a node
function ResourceNodeService:HarvestNode(node: ResourceNode, player: Player)
	if not node.isActive then return end
	
	-- Mark as inactive
	node.isActive = false
	node.lastHarvested = tick()
	
	-- Roll loot
	local stateManager = PlayerStateService:GetPlayerStateManager(player)
	local luckModifier = 0
	if stateManager then
		-- Could add luck stat here
		luckModifier = 0
	end
	
	local loot = LootTableService:RollLoot(node.lootTableId, luckModifier)
	
	-- Add to player's temporary bag
	local successCount = 0
	local failCount = 0
	
	for _, roll in ipairs(loot) do
		local success = PlayerStateService:AddToTemporaryBag(player, roll.item.id, roll.count)
		if success then
			successCount = successCount + 1
		else
			failCount = failCount + 1
		end
	end
	
	-- Visual feedback
	self:PlayHarvestEffect(node)
	
	-- Hide node
	local nodePart = node.model:FindFirstChild("NodePart")
	if nodePart then
		-- Shrink and fade animation
		local tweenInfo = TweenInfo.new(
			0.5,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.In
		)
		
		local tween = TweenService:Create(nodePart, tweenInfo, {
			Size = Vector3.new(0.1, 0.1, 0.1),
			Transparency = 1,
		})
		
		tween:Play()
		tween.Completed:Connect(function()
			nodePart.Transparency = 1
			nodePart.Size = Vector3.new(4, 4, 4)
		end)
	end
	
	-- Fire signal
	nodeHarvestedSignal:Fire(node, player, loot)
	
	-- Notify player
	self:NotifyHarvest(player, loot, failCount > 0)
	
	print(string.format("[ResourceNodeService] %s harvested %s node", player.Name, node.nodeType))
end

-- Play harvest effect
function ResourceNodeService:PlayHarvestEffect(node: ResourceNode)
	local nodePart = node.model:FindFirstChild("NodePart")
	if not nodePart then return end
	
	-- Create particle effect
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, 0, 0)
	attachment.Parent = nodePart
	
	local particleEmitter = Instance.new("ParticleEmitter")
	particleEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particleEmitter.Rate = 100
	particleEmitter.Lifetime = NumberRange.new(0.5, 1)
	particleEmitter.Speed = NumberRange.new(5, 10)
	particleEmitter.SpreadAngle = Vector2.new(360, 360)
	particleEmitter.Color = ColorSequence.new(nodePart.Color)
	particleEmitter.Parent = attachment
	
	-- Stop after burst
	task.wait(0.2)
	particleEmitter.Enabled = false
	
	task.wait(2)
	attachment:Destroy()
end

-- Notify player of harvest
function ResourceNodeService:NotifyHarvest(player: Player, loot: {any}, bagFull: boolean)
	local remoteEvent = ReplicatedStorage:FindFirstChild("ResourceNodeRemote")
	if not remoteEvent then
		remoteEvent = Instance.new("RemoteEvent")
		remoteEvent.Name = "ResourceNodeRemote"
		remoteEvent.Parent = ReplicatedStorage
	end
	
	local lootData = {}
	for _, roll in ipairs(loot) do
		table.insert(lootData, {
			name = roll.item.name,
			count = roll.count,
			rarity = roll.rarity,
		})
	end
	
	remoteEvent:FireClient(player, "HarvestComplete", {
		loot = lootData,
		bagFull = bagFull,
	})
end

-- Update nodes (respawn check)
function ResourceNodeService:UpdateNodes()
	local currentTime = tick()
	
	for _, node in pairs(resourceNodes) do
		if not node.isActive and node.lastHarvested then
			local timeSinceHarvest = currentTime - node.lastHarvested
			
			if timeSinceHarvest >= node.respawnTime then
				-- Respawn node
				self:RespawnNode(node)
			end
		end
	end
end

-- Respawn a node
function ResourceNodeService:RespawnNode(node: ResourceNode)
	node.isActive = true
	node.lastHarvested = nil
	
	local nodePart = node.model:FindFirstChild("NodePart")
	if nodePart then
		-- Grow and fade in animation
		nodePart.Size = Vector3.new(0.1, 0.1, 0.1)
		nodePart.Transparency = 1
		
		local tweenInfo = TweenInfo.new(
			0.5,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out
		)
		
		local tween = TweenService:Create(nodePart, tweenInfo, {
			Size = Vector3.new(4, 4, 4),
			Transparency = 0.3,
		})
		
		tween:Play()
		
		-- Respawn particles
		self:PlayRespawnEffect(node)
	end
end

-- Play respawn effect
function ResourceNodeService:PlayRespawnEffect(node: ResourceNode)
	local nodePart = node.model:FindFirstChild("NodePart")
	if not nodePart then return end
	
	-- Create expanding ring effect
	local ring = Instance.new("Part")
	ring.Name = "RespawnRing"
	ring.Size = Vector3.new(0.2, 0.2, 0.2)
	ring.Position = nodePart.Position
	ring.Anchored = true
	ring.CanCollide = false
	ring.Material = Enum.Material.ForceField
	ring.Color = nodePart.Color
	ring.Transparency = 0
	ring.Parent = node.model
	
	-- Create mesh
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = ring
	
	-- Expand and fade
	local tweenInfo = TweenInfo.new(
		1,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	
	local tween = TweenService:Create(ring, tweenInfo, {
		Size = Vector3.new(10, 0.2, 10),
		Transparency = 1,
	})
	
	tween:Play()
	tween.Completed:Connect(function()
		ring:Destroy()
	end)
end

-- Get node harvested signal
function ResourceNodeService:GetNodeHarvestedSignal()
	return nodeHarvestedSignal
end

-- Spawn node at position (public API)
function ResourceNodeService:SpawnNodeAtPosition(position: Vector3, nodeType: string)
	return self:SpawnNode(position, nodeType)
end

-- Remove all nodes
function ResourceNodeService:ClearAllNodes()
	for _, node in pairs(resourceNodes) do
		if node.model then
			node.model:Destroy()
		end
	end
	resourceNodes = {}
end

return ResourceNodeService
