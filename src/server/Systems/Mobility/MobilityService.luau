--[[
	MobilityService.luau
	Server-side orchestration for the mobility system
	Handles validation, state management, and equipment integration
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MobilityTypes = require(game.ReplicatedStorage.Shared.Mobility.MobilityTypes)
local MobilityConfig = require(game.ReplicatedStorage.Shared.Mobility.MobilityConfig)
local Net = require(game.ReplicatedStorage.Shared.Net)

local MobilityValidator = require(script.Parent.MobilityValidator)
local MobilityPersistence = require(script.Parent.MobilityPersistence)

local MobilityService = {}

-- Player state tracking
local playerStates: {[Player]: MobilityTypes.MobilityState} = {}
local playerSequences: {[Player]: number} = {}

-- Service state
local Validator = nil
local Persistence = nil
local Initialized = false

-- Debug flag
local DebugEnabled = true

function MobilityService.Init(services)
	MobilityService.services = services -- Store services reference
	if Initialized then
		warn("[MobilityService] Already initialized")
		return
	end
	
	print("[MobilityService] Starting initialization...")
	
	Validator = MobilityValidator.new()
	Persistence = MobilityPersistence.new()
	
	-- Setup remotes
	MobilityService:SetupRemotes()
	
	-- Connect player events
	Players.PlayerAdded:Connect(function(player)
		print("[MobilityService] Player added:", player.Name)
		MobilityService:OnPlayerAdded(player)
	end)
	
	Players.PlayerRemoving:Connect(function(player)
		print("[MobilityService] Player removing:", player.Name)
		MobilityService:OnPlayerRemoving(player)
	end)
	
	-- Handle already connected players
	for _, player in ipairs(Players:GetPlayers()) do
		print("[MobilityService] Setting up already connected player:", player.Name)
		MobilityService:OnPlayerAdded(player)
	end
	
	Initialized = true
	print("[MobilityService] Initialized successfully")
end

function MobilityService:SetupRemotes()
	print("[MobilityService] Setting up remotes...")
	
	-- Create remote events for mobility actions
	Net.Event("MobilityRequest") -- Client -> Server ability request
	Net.Event("MobilityResponse") -- Server -> Client validation response
	Net.Event("MobilityStateSync") -- Server -> Client state updates
	Net.Event("MobilityEffects") -- Server -> All clients for effects
	
	-- Connect request handler
	Net.On("MobilityRequest", function(player: Player, request: MobilityTypes.MobilityRequest)
		print("[MobilityService] Received MobilityRequest from", player.Name)
		print("  Type:", request.Type)
		print("  Position:", request.StartPosition)
		print("  Sequence:", request.SequenceNumber)
		MobilityService:HandleMobilityRequest(player, request)
	end)
	
	print("[MobilityService] Remotes setup complete")
end

function MobilityService:OnPlayerAdded(player: Player)
	print("[MobilityService] Initializing player state for", player.Name)
	
	-- Initialize player state
	playerStates[player] = {
		Leap = {
			LastUsed = 0,
			ChargesRemaining = MobilityConfig.LeapMaxCharges,
			IsOnCooldown = false,
			NextChargeTime = 0,
			IsEquipped = not MobilityConfig.RequiresEquipment
		},
		Dash = {
			LastUsed = 0,
			ChargesRemaining = MobilityConfig.DashMaxCharges,
			IsOnCooldown = false,
			NextChargeTime = 0,
			IsEquipped = not MobilityConfig.RequiresEquipment
		},
		LastValidPosition = Vector3.new(0, 50, 0),
		LastValidVelocity = Vector3.new(),
		ValidationPending = false,
		LastAbilityUse = 0  -- Track last ability use for validation
	}
	
	playerSequences[player] = 0
	
	print("[MobilityService] Player state initialized for", player.Name)
	print("  Leap charges:", playerStates[player].Leap.ChargesRemaining)
	print("  Dash charges:", playerStates[player].Dash.ChargesRemaining)
	
	-- Load persistent mobility upgrades
	task.spawn(function()
		local upgrades = Persistence:LoadPlayerUpgrades(player)
		if upgrades then
			print("[MobilityService] Loaded upgrades for", player.Name)
			self:ApplyUpgrades(player, upgrades)
		end
	end)
	
	-- Wait for character
	local function onCharacterAdded(character: Model)
		print("[MobilityService] Character added for", player.Name)
		self:SetupCharacter(player, character)
	end
	
	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
	
	-- Send initial state sync (with delay to ensure client is ready)
	task.spawn(function()
		task.wait(1)  -- Wait for client to initialize
		print("[MobilityService] Sending initial state sync to", player.Name)
		self:SyncState(player)
	end)
end

function MobilityService:SetupCharacter(player: Player, character: Model)
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	local state = playerStates[player]
	
	print("[MobilityService] Setting up character for", player.Name)
	
	if state then
		state.LastValidPosition = humanoidRootPart.Position
		state.LastValidVelocity = humanoidRootPart.AssemblyLinearVelocity
		
		-- Create mobility pack visuals
		self:CreateMobilityPack(character)
		
		-- Send state sync again when character spawns
		task.wait(0.5)
		self:SyncState(player)
	end
end

function MobilityService:CreateMobilityPack(character: Model)
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso then 
		print("[MobilityService] No torso found for mobility pack")
		return 
	end
	
	-- Remove existing pack if any
	local existingPack = character:FindFirstChild("MobilityPack")
	if existingPack then
		existingPack:Destroy()
	end
	
	-- Create the backpack model
	local packModel = Instance.new("Model")
	packModel.Name = "MobilityPack"
	packModel.Parent = character
	
	-- Main pack body (simple part for now, meshes later)
	local mainPack = Instance.new("Part")
	mainPack.Name = "MainPack"
	mainPack.Size = Vector3.new(1.5, 2, 0.8)
	mainPack.Material = Enum.Material.Metal
	mainPack.BrickColor = BrickColor.new("Dark grey")
	mainPack.CanCollide = false
	mainPack.Massless = true
	mainPack.Parent = packModel
	
	-- Leap indicator (changes color based on cooldown)
	local leapIndicator = Instance.new("Part")
	leapIndicator.Name = "LeapIndicator"
	leapIndicator.Shape = Enum.PartType.Ball
	leapIndicator.Size = Vector3.new(0.4, 0.4, 0.4)
	leapIndicator.Material = Enum.Material.Neon
	leapIndicator.BrickColor = BrickColor.new("Lime green")
	leapIndicator.CanCollide = false
	leapIndicator.Massless = true
	leapIndicator.Parent = packModel
	
	-- Position relative to main pack
	leapIndicator.CFrame = mainPack.CFrame * CFrame.new(0.4, 0.6, -0.5)
	
	-- Dash indicator
	local dashIndicator = leapIndicator:Clone()
	dashIndicator.Name = "DashIndicator"
	dashIndicator.CFrame = mainPack.CFrame * CFrame.new(-0.4, 0.6, -0.5)
	dashIndicator.Parent = packModel
	
	-- Weld everything to torso
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = mainPack
	weld.Parent = mainPack
	
	-- Position pack on back
	mainPack.CFrame = torso.CFrame * CFrame.new(0, 0, 1)
	
	-- Weld indicators to main pack
	local leapWeld = Instance.new("WeldConstraint")
	leapWeld.Part0 = mainPack
	leapWeld.Part1 = leapIndicator
	leapWeld.Parent = leapIndicator
	
	local dashWeld = Instance.new("WeldConstraint")
	dashWeld.Part0 = mainPack
	dashWeld.Part1 = dashIndicator
	dashWeld.Parent = dashIndicator
	
	print("[MobilityService] Mobility pack created for character")
	
	-- Start indicator update loop
	task.spawn(function()
		self:UpdatePackIndicators(character)
	end)
end

function MobilityService:UpdatePackIndicators(character: Model)
	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end
	
	local packModel = character:FindFirstChild("MobilityPack")
	if not packModel then return end
	
	local leapIndicator = packModel:FindFirstChild("LeapIndicator")
	local dashIndicator = packModel:FindFirstChild("DashIndicator")
	
	while packModel.Parent and playerStates[player] do
		local state = playerStates[player]
		
		-- Update leap indicator color
		if leapIndicator then
			if state.Leap.ChargesRemaining > 0 then
				leapIndicator.BrickColor = BrickColor.new("Lime green")
			else
				leapIndicator.BrickColor = BrickColor.new("Really red")
			end
		end
		
		-- Update dash indicator color
		if dashIndicator then
			if not state.Dash.IsOnCooldown then
				dashIndicator.BrickColor = BrickColor.new("Lime green")
			else
				dashIndicator.BrickColor = BrickColor.new("Really red")
			end
		end
		
		task.wait(0.1)
	end
end

function MobilityService:HandleMobilityRequest(player: Player, request: MobilityTypes.MobilityRequest)
	local state = playerStates[player]
	if not state then 
		print("[MobilityService] No state found for player:", player.Name)
		return 
	end
	
	local character = player.Character
	if not character then 
		print("[MobilityService] No character found for player:", player.Name)
		return 
	end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then 
		print("[MobilityService] No HumanoidRootPart found for player:", player.Name)
		return 
	end
	
	-- Validate sequence number (prevent replay attacks)
	local expectedSequence = (playerSequences[player] or 0) + 1
	if request.SequenceNumber ~= expectedSequence then
		print("[MobilityService] Invalid sequence. Expected:", expectedSequence, "Got:", request.SequenceNumber)
		self:SendResponse(player, false, request.SequenceNumber, nil, "Invalid sequence")
		return
	end
	playerSequences[player] = expectedSequence
	
	-- Check equipment requirements (for future inventory integration)
	if MobilityConfig.RequiresEquipment then
		local hasEquipment = self:CheckEquipment(player, request.Type)
		if not hasEquipment then
			print("[MobilityService] Equipment not equipped for", request.Type)
			self:SendResponse(player, false, request.SequenceNumber, nil, "Equipment not equipped")
			return
		end
	end
	
	-- Validate cooldowns and charges
	local abilityState = state[request.Type]
	if not abilityState then 
		print("[MobilityService] Invalid ability type:", request.Type)
		self:SendResponse(player, false, request.SequenceNumber, nil, "Invalid ability")
		return 
	end
	
	local currentTime = tick()
	
	if request.Type == "Leap" then
		print("[MobilityService] Processing Leap request")
		print("  Current charges:", abilityState.ChargesRemaining)
		
		-- Check leap charges
		if abilityState.ChargesRemaining <= 0 then
			print("[MobilityService] No charges remaining for Leap")
			self:SendResponse(player, false, request.SequenceNumber, nil, "No charges remaining")
			return
		end
		
		-- Perform leap
		abilityState.ChargesRemaining = abilityState.ChargesRemaining - 1
		abilityState.LastUsed = currentTime
		state.LastAbilityUse = currentTime  -- Track for validation
		
		print("[MobilityService] Leap approved. Remaining charges:", abilityState.ChargesRemaining)
		
		-- Schedule recharge
		if abilityState.ChargesRemaining < MobilityConfig.LeapMaxCharges then
			abilityState.NextChargeTime = currentTime + MobilityConfig.LeapRechargeRate
			task.delay(MobilityConfig.LeapRechargeRate, function()
				if playerStates[player] and abilityState.ChargesRemaining < MobilityConfig.LeapMaxCharges then
					abilityState.ChargesRemaining = abilityState.ChargesRemaining + 1
					print("[MobilityService] Leap charge restored for", player.Name, "New charges:", abilityState.ChargesRemaining)
					self:SyncState(player)
				end
			end)
		end
		
	elseif request.Type == "Dash" then
		print("[MobilityService] Processing Dash request")
		print("  Is on cooldown:", abilityState.IsOnCooldown)
		
		-- Check dash cooldown
		if abilityState.IsOnCooldown then
			print("[MobilityService] Dash is on cooldown")
			self:SendResponse(player, false, request.SequenceNumber, nil, "On cooldown")
			return
		end
		
		-- Perform dash
		abilityState.IsOnCooldown = true
		abilityState.LastUsed = currentTime
		state.LastAbilityUse = currentTime  -- Track for validation
		
		print("[MobilityService] Dash approved. Starting cooldown")
		
		-- Schedule cooldown reset
		task.delay(MobilityConfig.DashCooldown, function()
			if playerStates[player] then
				abilityState.IsOnCooldown = false
				print("[MobilityService] Dash cooldown ended for", player.Name)
				self:SyncState(player)
			end
		end)
	end
	
	-- Validate movement (only for ability movements)
	task.wait(0.1) -- Small delay to let physics apply
	
	local validationResult = Validator:ValidateAbilityMovement(
		player,
		request.StartPosition,
		humanoidRootPart.Position,
		request.Type
	)
	
	print("[MobilityService] Validation result for", request.Type)
	print("  Valid:", validationResult.IsValid)
	if validationResult.Reason then
		print("  Reason:", validationResult.Reason)
	end
	
	if not validationResult.IsValid then
		-- Only teleport back for extreme violations
		if (humanoidRootPart.Position - request.StartPosition).Magnitude > MobilityConfig.MaxPositionDelta * 2 then
			humanoidRootPart.CFrame = CFrame.new(state.LastValidPosition)
			self:SendResponse(player, false, request.SequenceNumber, state.LastValidPosition, validationResult.Reason)
		else
			-- Minor violation, just warn
			print("[MobilityService] Minor violation, allowing movement")
			self:SendResponse(player, true, request.SequenceNumber)
		end
	else
		-- Update valid position after successful ability
		state.LastValidPosition = humanoidRootPart.Position
		state.LastValidVelocity = humanoidRootPart.AssemblyLinearVelocity
		self:SendResponse(player, true, request.SequenceNumber)
		
		-- Broadcast effects to all clients
		self:BroadcastEffects(player, request)
	end
	
	-- Sync state to client
	self:SyncState(player)
end

function MobilityService:BroadcastEffects(player: Player, request: MobilityTypes.MobilityRequest)
	local effectData: MobilityTypes.EffectData = {
		Type = "Gust",
		Position = request.StartPosition,
		Direction = -request.Direction, -- Opposite direction for gust
		Power = request.Type == "Leap" and MobilityConfig.LeapPower or MobilityConfig.DashPower,
		Color = nil
	}
	
	print("[MobilityService] Broadcasting effects for", request.Type, "from", player.Name)
	
	-- Send to all clients for visual effects
	Net.FireAll("MobilityEffects", player, effectData)
end

function MobilityService:CheckEquipment(player: Player, abilityType: string): boolean
	-- Integration point for inventory system
	-- For now, return true if equipment check is disabled
	if not MobilityConfig.RequiresEquipment then
		return true
	end
	
	-- Check with InventoryIntegrationService
	local InventoryIntegration = self.services and self.services.InventoryIntegrationService
	if InventoryIntegration and InventoryIntegration.ValidateMobilityEquipment then
		local hasEquipment = InventoryIntegration:ValidateMobilityEquipment(player, abilityType)
		print("[MobilityService] Equipment check for", player.Name, abilityType, ":", hasEquipment)
		return hasEquipment
	end
	
	-- Fallback: check inventory directly
	local InventoryService = self.services and self.services.InventoryService
	if InventoryService then
		local inventory = InventoryService:GetPlayerInventory(player)
		if inventory and inventory.equipment and inventory.equipment.mobility then
			local equipmentMap = {
				["Leap"] = inventory.equipment.mobility.jump,
				["Dash"] = inventory.equipment.mobility.dash,
				["Grapple"] = inventory.equipment.mobility.grapple
			}
			return equipmentMap[abilityType] ~= nil
		end
	end
	
	return false
end

function MobilityService:ApplyUpgrades(player: Player, upgrades: {[string]: any})
	-- Integration point for upgrade system
	-- Modify ability stats based on player upgrades
	local state = playerStates[player]
	if not state then return end
	
	-- Example upgrades (to be expanded with inventory system):
	-- upgrades.LeapPower: number
	-- upgrades.DashCooldownReduction: number
	-- upgrades.AdditionalLeapCharges: number
end

function MobilityService:SendResponse(player: Player, success: boolean, sequenceNumber: number, correctedPosition: Vector3?, reason: string?)
	local response: MobilityTypes.MobilityResponse = {
		Success = success,
		SequenceNumber = sequenceNumber,
		CorrectedPosition = correctedPosition,
		Reason = reason
	}
	
	print("[MobilityService] Sending response to", player.Name)
	print("  Success:", success)
	print("  Sequence:", sequenceNumber)
	if reason then
		print("  Reason:", reason)
	end
	
	Net.Fire(player, "MobilityResponse", response)
end

function MobilityService:SyncState(player: Player)
	local state = playerStates[player]
	if not state then 
		print("[MobilityService] Cannot sync - no state for", player.Name)
		return 
	end
	
	print("[MobilityService] Syncing state to", player.Name)
	print("  Leap charges:", state.Leap.ChargesRemaining)
	print("  Dash cooldown:", state.Dash.IsOnCooldown)
	
	Net.Fire(player, "MobilityStateSync", state)
end

function MobilityService:OnPlayerRemoving(player: Player)
	-- Save upgrades
	task.spawn(function()
		local state = playerStates[player]
		if state then
			Persistence:SavePlayerUpgrades(player, {
				-- Save relevant upgrade data
			})
		end
	end)
	
	-- Cleanup
	playerStates[player] = nil
	playerSequences[player] = nil
	
	print("[MobilityService] Cleaned up player state for", player.Name)
end

return MobilityService
