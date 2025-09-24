--!strict
-- PlayerStateService.luau
-- Core player state management system for QuietWinds
-- Manages Build, Neutral, and Run states with transitions

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Use canonical Shared + Config paths in ReplicatedStorage
local SafeRequire = require(ReplicatedStorage.Shared.SafeRequire)
local Types = require(ReplicatedStorage.Shared.Types)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

-- Import other services
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local SaveService = require(script.Parent:WaitForChild("SaveService"))
local WorldConfig = require(ReplicatedStorage.Config.WorldConfig)

export type PlayerState = "Build" | "Neutral" | "Run" | "Recalling"

export type StateData = {
	state: PlayerState,
	previousState: PlayerState?,
	enteredAt: number,
	metadata: {[string]: any}
}

export type PlayerStateManager = {
	playerId: number,
	currentState: StateData,
	stateHistory: {StateData},
	temporaryBag: TemporaryBag?,
	recallStartTime: number?,
	hearts: number,
	maxHearts: number,
	lastPosition: Vector3,
	plot: string?,
}

export type TemporaryBag = {
	items: {[string]: number}, -- itemId -> count
	crudeOil: number,
	maxSlots: number,
	usedSlots: number,
}

local PlayerStateService = {}
PlayerStateService.__index = PlayerStateService

-- State transition rules
local VALID_TRANSITIONS = {
	Build = {"Neutral", "Recalling"},
	Neutral = {"Build", "Run", "Recalling"},
	Run = {"Neutral", "Recalling"},
	Recalling = {"Build", "Neutral", "Run"}, -- Can transition to any state on cancel
}

-- Constants
local BASE_RECALL_DURATION = 4 -- seconds
local BASE_HEARTS = 3
local BASE_BAG_SLOTS = 8
local HUB_RADIUS = 150 -- Units from spawn
local SPAWN_POSITION = Vector3.new(0, 100, 0)

-- Private variables
local playerStates: {[Player]: PlayerStateManager} = {}
local stateChangedSignal = Signal.new()
local heartChangedSignal = Signal.new()
local bagUpdatedSignal = Signal.new()

-- Initialize service
function PlayerStateService:Init()
    -- Connect player events
    Players.PlayerAdded:Connect(function(player)
        self:InitializePlayer(player)
    end)
	
	Players.PlayerRemoving:Connect(function(player)
		self:CleanupPlayer(player)
	end)
	
	-- State monitoring loop
	RunService.Heartbeat:Connect(function(dt)
		self:UpdateStates(dt)
	end)
	
    -- Also initialize any players already in the server (order-agnostic init)
    for _, p in ipairs(Players:GetPlayers()) do
        self:InitializePlayer(p)
    end

    print("[PlayerStateService] Initialized")
end

-- Initialize player state
function PlayerStateService:InitializePlayer(player: Player)
    local profile = SaveService:GetProfile(player)
    if not profile then
        -- Attempt to create/load a profile synchronously
        pcall(function()
            profile = SaveService.LoadProfile(player)
        end)
    end
    if not profile then
        -- Fall back to a minimal ephemeral profile; SaveService will hydrate later
        warn("[PlayerStateService] No profile found for", player.Name, "- using defaults until SaveService hydrates")
        profile = {
            hearts = BASE_HEARTS,
            maxHearts = BASE_HEARTS,
            inventory = {},
            upgrades = {},
            balances = { aether = 0, crumbs = 0 },
        }
    end
	
	-- Create state manager
	local stateManager: PlayerStateManager = {
		playerId = player.UserId,
		currentState = {
			state = "Neutral",
			previousState = nil,
			enteredAt = tick(),
			metadata = {}
		},
		stateHistory = {},
		temporaryBag = nil,
		recallStartTime = nil,
        hearts = (profile.Data and profile.Data.hearts) or profile.hearts or BASE_HEARTS,
        maxHearts = (profile.Data and profile.Data.maxHearts) or profile.maxHearts or BASE_HEARTS,
        lastPosition = SPAWN_POSITION,
        plot = nil,
    }
	
	playerStates[player] = stateManager
	
	-- Wait for character
	if player.Character then
		self:OnCharacterAdded(player, player.Character)
	end
	
	player.CharacterAdded:Connect(function(character)
		self:OnCharacterAdded(player, character)
	end)
	
	print("[PlayerStateService] Initialized player", player.Name)
end

-- Handle character spawn
function PlayerStateService:OnCharacterAdded(player: Player, character: Model)
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	local stateManager = playerStates[player]
	
	if not stateManager then return end
	
	-- Restore hearts (custom health system)
	self:SetupHeartSystem(player, character)
	
	-- Determine initial state based on position
	task.wait(0.5) -- Let character settle
	self:UpdatePlayerStateByPosition(player)
end

-- Setup custom heart-based health system
function PlayerStateService:SetupHeartSystem(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid")
	local stateManager = playerStates[player]
	
	if not stateManager then return end
	
	-- Disable default health regen
	humanoid.Health = humanoid.MaxHealth
	humanoid.HealthChanged:Connect(function(health)
		if health <= 0 then
			-- Prevent death, handle custom defeat
			humanoid.Health = humanoid.MaxHealth
			self:HandlePlayerDefeat(player)
		end
	end)
	
	-- Create heart UI indicator (server tells client to create)
	self:UpdateClientHearts(player, stateManager.hearts, stateManager.maxHearts)
end

-- Update player state based on position
function PlayerStateService:UpdatePlayerStateByPosition(player: Player)
	local character = player.Character
	if not character then return end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end
	
	local stateManager = playerStates[player]
	if not stateManager then return end
	
	local position = humanoidRootPart.Position
	stateManager.lastPosition = position
	
    -- Check if in own plot
    local plotKey = PlotService:GetPlotKeyFromPosition(position)
    if plotKey then
        local plotOwner = PlotService:GetPlotOwner(plotKey)
        if plotOwner == player then
            stateManager.plot = plotKey
            if stateManager.currentState.state ~= "Build" and stateManager.currentState.state ~= "Recalling" then
                self:TransitionState(player, "Build")
            end
            return
        end
    else
        -- Fallback: if plot ownership mapping isn't ready yet, treat island bounds as build zone
        local half = (WorldConfig and WorldConfig.ISLANDS and WorldConfig.ISLANDS.SizeStuds or 192) / 2
        if math.abs(position.X) <= half and math.abs(position.Z) <= half then
            if stateManager.currentState.state ~= "Build" and stateManager.currentState.state ~= "Recalling" then
                self:TransitionState(player, "Build")
            end
            return
        end
    end
	
	-- Check if within hub radius
	local distanceFromSpawn = (position - SPAWN_POSITION).Magnitude
    if distanceFromSpawn <= HUB_RADIUS then
        if stateManager.currentState.state ~= "Neutral" and stateManager.currentState.state ~= "Recalling" then
            self:TransitionState(player, "Neutral")
        end
    else
        -- Outside hub, enter Run state
        if stateManager.currentState.state ~= "Run" and stateManager.currentState.state ~= "Recalling" then
            self:TransitionState(player, "Run")
        end
    end
end

-- State transition
function PlayerStateService:TransitionState(player: Player, newState: PlayerState, metadata: {[string]: any}?)
	local stateManager = playerStates[player]
	if not stateManager then return false end
	
	local currentState = stateManager.currentState.state
	
	-- Check if transition is valid
	if not table.find(VALID_TRANSITIONS[currentState], newState) then
		warn(string.format("[PlayerStateService] Invalid transition from %s to %s", currentState, newState))
		return false
	end
	
	-- Handle exit logic
	self:OnStateExit(player, currentState, newState)
	
	-- Update state
	local previousState = stateManager.currentState
	stateManager.currentState = {
		state = newState,
		previousState = currentState,
		enteredAt = tick(),
		metadata = metadata or {}
	}
	
	-- Add to history
	table.insert(stateManager.stateHistory, 1, previousState)
	if #stateManager.stateHistory > 10 then
		table.remove(stateManager.stateHistory)
	end
	
	-- Handle enter logic
	self:OnStateEnter(player, newState, currentState)
	
	-- Fire signal
	stateChangedSignal:Fire(player, newState, currentState)
	
	-- Update client
	self:UpdateClientState(player, newState, metadata)
	
	return true
end

-- State exit handler
function PlayerStateService:OnStateExit(player: Player, exitingState: PlayerState, enteringState: PlayerState)
	local stateManager = playerStates[player]
	if not stateManager then return end
	
	if exitingState == "Run" then
		-- If successfully returning home, transfer temporary items
		if enteringState == "Build" or enteringState == "Neutral" then
			self:TransferTemporaryItems(player)
		else
			-- Lost items (fell or defeated)
			stateManager.temporaryBag = nil
		end
	elseif exitingState == "Recalling" then
		-- Cancel recall
		stateManager.recallStartTime = nil
	end
end

-- State enter handler
function PlayerStateService:OnStateEnter(player: Player, enteringState: PlayerState, exitedState: PlayerState)
	local stateManager = playerStates[player]
	if not stateManager then return end
	
	if enteringState == "Build" then
		-- Enable building mode
		print(string.format("[PlayerStateService] %s entered Build mode", player.Name))
		
	elseif enteringState == "Neutral" then
		-- Neutral state in hub
		print(string.format("[PlayerStateService] %s entered Neutral mode", player.Name))
		
	elseif enteringState == "Run" then
		-- Initialize temporary bag
		stateManager.temporaryBag = {
			items = {},
			crudeOil = 0,
			maxSlots = self:GetBagSlots(player),
			usedSlots = 0
		}
		print(string.format("[PlayerStateService] %s entered Run mode", player.Name))
		
	elseif enteringState == "Recalling" then
		-- Start recall timer
		stateManager.recallStartTime = tick()
		print(string.format("[PlayerStateService] %s started recall", player.Name))
	end
end

-- Start recall process
function PlayerStateService:StartRecall(player: Player): boolean
    local stateManager = playerStates[player]
    if not stateManager then return false end
    
    -- In Run state: start channel (move cancels). Otherwise: instant recall.
    if stateManager.currentState.state == "Run" then
        return self:TransitionState(player, "Recalling", {
            recallPosition = stateManager.lastPosition
        })
    else
        -- Instant teleport back to home and set appropriate state
        self:_teleportHome(player)
        if stateManager.plot then
            self:TransitionState(player, "Build")
        else
            self:TransitionState(player, "Neutral")
        end
        return true
    end
end

-- Cancel recall
function PlayerStateService:CancelRecall(player: Player): boolean
	local stateManager = playerStates[player]
	if not stateManager then return false end
	
	if stateManager.currentState.state ~= "Recalling" then
		return false
	end
	
	-- Return to previous state
	local previousState = stateManager.currentState.previousState or "Run"
	return self:TransitionState(player, previousState)
end

-- Complete recall
function PlayerStateService:CompleteRecall(player: Player)
    local stateManager = playerStates[player]
    if not stateManager then return end
    
    -- Allow CompleteRecall from Recalling or as a safety from other states
	
    -- Teleport to home
    self:_teleportHome(player)
	
	-- Transition to appropriate state
	if stateManager.plot then
		self:TransitionState(player, "Build")
	else
		self:TransitionState(player, "Neutral")
	end
end

-- Update states (called every frame)
function PlayerStateService:UpdateStates(dt: number)
    for player, stateManager in pairs(playerStates) do
        -- Update position-based state
        if player.Character then
            self:UpdatePlayerStateByPosition(player)
        end
        
        -- Handle recall timer
        if stateManager.currentState.state == "Recalling" and stateManager.recallStartTime then
            local elapsed = tick() - stateManager.recallStartTime
            local recallDuration = self:GetRecallDuration(player)
            -- Cancel if player moved too far from start position
            local meta = stateManager.currentState.metadata or {}
            local startPos: Vector3? = meta.recallPosition
            local moved = false
            if startPos and player.Character then
                local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    moved = (hrp.Position - startPos).Magnitude > 2.0
                end
            end
            if moved then
                self:CancelRecall(player)
            elseif elapsed >= recallDuration then
                self:CompleteRecall(player)
            end
        end
    end
end

-- Helper: teleport player to home (plot origin if known, else SPAWN_POSITION)
function PlayerStateService:_teleportHome(player: Player)
    local stateManager = playerStates[player]
    local target = SPAWN_POSITION
    if stateManager and stateManager.plot then
        local plotData = PlotService:GetPlotData(stateManager.plot)
        if plotData and plotData.origin then
            target = plotData.origin + Vector3.new(0, 10, 0)
        end
    end
    local character = player.Character
    if character then
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(target)
        end
    end
end

-- Handle player defeat (lost all hearts)
function PlayerStateService:HandlePlayerDefeat(player: Player)
	local stateManager = playerStates[player]
	if not stateManager then return end
	
	-- Play defeat animation/effect
	self:PlayDefeatEffect(player)
	
	-- Clear temporary items
	stateManager.temporaryBag = nil
	
	-- Reset hearts
	stateManager.hearts = stateManager.maxHearts
	
	-- Teleport to spawn after delay
	task.wait(2) -- Fade to black duration
	
	local character = player.Character
	if character then
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			humanoidRootPart.CFrame = CFrame.new(SPAWN_POSITION)
		end
	end
	
	-- Set state to neutral
	self:TransitionState(player, "Neutral")
	
	-- Update client
	self:UpdateClientHearts(player, stateManager.hearts, stateManager.maxHearts)
end

-- Play defeat effect
function PlayerStateService:PlayDefeatEffect(player: Player)
	-- Tell client to show defeat screen
	local remoteEvent = ReplicatedStorage:FindFirstChild("PlayerStateRemote")
	if remoteEvent then
		remoteEvent:FireClient(player, "ShowDefeat", {
			message = "You fell into the void...",
			fadeTime = 2
		})
	end
end

-- Damage player (hearts)
function PlayerStateService:DamagePlayer(player: Player, damage: number)
	local stateManager = playerStates[player]
	if not stateManager then return end
	
	stateManager.hearts = math.max(0, stateManager.hearts - damage)
	
	-- Update client
	self:UpdateClientHearts(player, stateManager.hearts, stateManager.maxHearts)
	heartChangedSignal:Fire(player, stateManager.hearts, stateManager.maxHearts)
	
	-- Check for defeat
	if stateManager.hearts <= 0 then
		self:HandlePlayerDefeat(player)
	end
end

-- Heal player
function PlayerStateService:HealPlayer(player: Player, amount: number)
	local stateManager = playerStates[player]
	if not stateManager then return end
	
	stateManager.hearts = math.min(stateManager.maxHearts, stateManager.hearts + amount)
	
	-- Update client
	self:UpdateClientHearts(player, stateManager.hearts, stateManager.maxHearts)
	heartChangedSignal:Fire(player, stateManager.hearts, stateManager.maxHearts)
end

-- Add to temporary bag
function PlayerStateService:AddToTemporaryBag(player: Player, itemId: string, count: number): boolean
	local stateManager = playerStates[player]
	if not stateManager or not stateManager.temporaryBag then 
		return false 
	end
	
	local bag = stateManager.temporaryBag
	
	-- Special case for crude oil
	if itemId == "CrudeOil" then
		bag.crudeOil = bag.crudeOil + count
		bagUpdatedSignal:Fire(player, bag)
		self:UpdateClientBag(player, bag)
		return true
	end
	
	-- Check slot limit for new items
	if not bag.items[itemId] and bag.usedSlots >= bag.maxSlots then
		return false -- Bag full
	end
	
	-- Add item
	if bag.items[itemId] then
		bag.items[itemId] = bag.items[itemId] + count
	else
		bag.items[itemId] = count
		bag.usedSlots = bag.usedSlots + 1
	end
	
	bagUpdatedSignal:Fire(player, bag)
	self:UpdateClientBag(player, bag)
	return true
end

-- Transfer temporary items to permanent inventory
function PlayerStateService:TransferTemporaryItems(player: Player)
    local stateManager = playerStates[player]
    if not stateManager or not stateManager.temporaryBag then
        return
    end
    
    local bag = stateManager.temporaryBag
    local profile = SaveService:GetProfile(player)
    
    if not profile then
        warn("[PlayerStateService] No profile found for item transfer")
        return
    end
    
    -- Transfer crude oil
    if bag.crudeOil > 0 then
        if profile.Data then
            profile.Data.crudeOil = (profile.Data.crudeOil or 0) + bag.crudeOil
        else
            profile.crudeOil = (profile.crudeOil or 0) + bag.crudeOil
        end
    end
    
    -- Transfer items
    for itemId, count in pairs(bag.items) do
        local inventory
        if profile.Data then
            inventory = profile.Data.inventory or {}
            inventory[itemId] = (inventory[itemId] or 0) + count
            profile.Data.inventory = inventory
        else
            inventory = profile.inventory or {}
            inventory[itemId] = (inventory[itemId] or 0) + count
            profile.inventory = inventory
        end
    end
	
	-- Clear temporary bag
	stateManager.temporaryBag = nil
	
	print(string.format("[PlayerStateService] Transferred temporary items for %s", player.Name))
end

-- Get bag slots for player
function PlayerStateService:GetBagSlots(player: Player): number
    local profile = SaveService:GetProfile(player)
    if not profile then
        return BASE_BAG_SLOTS
    end
    
    -- Check for bag upgrades (support both boolean tiers and numeric level)
    local upgrades = (profile.Data and profile.Data.upgrades) or profile.upgrades or {}
    local bonus = 0
    if typeof(upgrades) == "table" then
        if upgrades.bagCapacity1 then bonus += 4 end
        if upgrades.bagCapacity2 then bonus += 4 end
        if upgrades.bagCapacity3 then bonus += 8 end
        -- Numeric fallback
        local lvl = upgrades.bagCapacity or 0
        if lvl >= 1 then bonus = math.max(bonus, 4) end
        if lvl >= 2 then bonus = math.max(bonus, 8) end
        if lvl >= 3 then bonus = math.max(bonus, 16) end
    end
    
    return BASE_BAG_SLOTS + bonus
end

-- Get recall duration for player
function PlayerStateService:GetRecallDuration(player: Player): number
    local profile = SaveService:GetProfile(player)
    if not profile then
        return BASE_RECALL_DURATION
    end
    
    -- Check for recall speed upgrades (boolean tier or numeric level)
    local upgrades = (profile.Data and profile.Data.upgrades) or profile.upgrades or {}
    local reduction = 0
    if typeof(upgrades) == "table" then
        if upgrades.recallSpeed1 then reduction += 1 end
        local lvl = upgrades.recallSpeed or 0
        reduction = math.max(reduction, lvl) -- 1 second per level
    end
    
    return math.max(1, BASE_RECALL_DURATION - reduction) -- Minimum 1 second
end

-- Update client state
function PlayerStateService:UpdateClientState(player: Player, state: PlayerState, metadata: {[string]: any}?)
	local remoteEvent = ReplicatedStorage:FindFirstChild("PlayerStateRemote")
	if not remoteEvent then
		remoteEvent = Instance.new("RemoteEvent")
		remoteEvent.Name = "PlayerStateRemote"
		remoteEvent.Parent = ReplicatedStorage
		
		-- Set up handler for client requests
		remoteEvent.OnServerEvent:Connect(function(requestingPlayer, action)
			if action == "RequestState" then
				local stateManager = playerStates[requestingPlayer]
				if stateManager then
					remoteEvent:FireClient(requestingPlayer, "StateChanged", {
						state = stateManager.currentState.state,
						metadata = stateManager.currentState.metadata or {}
					})
				end
			end
		end)
	end
	
	remoteEvent:FireClient(player, "StateChanged", {
		state = state,
		metadata = metadata or {}
	})
end

-- Update client hearts
function PlayerStateService:UpdateClientHearts(player: Player, hearts: number, maxHearts: number)
    local remoteEvent = ReplicatedStorage:FindFirstChild("PlayerStateRemote")
    if remoteEvent then
        print(string.format("[PlayerStateService] UpdateClientHearts %s %d/%d", player.Name, hearts, maxHearts))
        remoteEvent:FireClient(player, "HeartsChanged", {
            hearts = hearts,
            maxHearts = maxHearts
        })
    end
end

-- Update client bag
function PlayerStateService:UpdateClientBag(player: Player, bag: TemporaryBag)
	local remoteEvent = ReplicatedStorage:FindFirstChild("PlayerStateRemote")
	if remoteEvent then
		remoteEvent:FireClient(player, "BagUpdated", bag)
	end
end

-- Cleanup player
function PlayerStateService:CleanupPlayer(player: Player)
	-- Transfer items if in Run state
	local stateManager = playerStates[player]
	if stateManager and stateManager.currentState.state == "Run" then
		-- Player disconnected while exploring, lose items
		stateManager.temporaryBag = nil
	end
	
	playerStates[player] = nil
end

-- Public API
function PlayerStateService:GetPlayerState(player: Player): PlayerState?
	local stateManager = playerStates[player]
	return stateManager and stateManager.currentState.state
end

function PlayerStateService:GetPlayerStateManager(player: Player): PlayerStateManager?
	return playerStates[player]
end

function PlayerStateService:GetStateChangedSignal()
	return stateChangedSignal
end

function PlayerStateService:GetHeartChangedSignal()
	return heartChangedSignal
end

function PlayerStateService:GetBagUpdatedSignal()
	return bagUpdatedSignal
end

return PlayerStateService
