--[[
	MobilityController.client.luau
	Client-side mobility controller
	Handles input, prediction, and server reconciliation
	FIXED: FOV reset and character cleanup
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Safe module loading
local function safeRequire(module)
	local success, result = pcall(require, module)
	if success then
		return result
	else
		warn("[MobilityController] Failed to require module:", module:GetFullName())
		return nil
	end
end

local MobilityTypes = safeRequire(game.ReplicatedStorage.Shared.Mobility.MobilityTypes) or {}
local MobilityConfig = safeRequire(game.ReplicatedStorage.Shared.Mobility.MobilityConfig) or {
	-- Fallback config if module fails
	LeapVerticalBoost = 30,
	LeapHorizontalBoost = 15,
	DashPower = 80,
	DashDuration = 0.3,
	ZoomOutAmount = 10,
	ZoomOutDuration = 0.5,
	TeleportBackThreshold = 100
}
local Net = safeRequire(game.ReplicatedStorage.Shared.Net)

local MobilityEffects = safeRequire(script.Parent.MobilityEffects)
local MobilityUI = safeRequire(script.Parent.MobilityUI)

local MobilityController = {}
MobilityController.__index = MobilityController

local LocalPlayer = Players.LocalPlayer

local DEBUG_CHANNELS = {
	boot = false,
	init = false,
	character = false,
	input = false,
	ability = false,
	net = false,
	ui = false,
	effects = false,
	cleanup = false,
}

local function debugLog(channel: string, ...)
	if not DEBUG_CHANNELS[channel] then
		return
	end
	print(('[Diag][Mobility][%s]'):format(channel), ...)
end

function MobilityController.SetDebugChannel(channel: string, enabled: boolean)
	if DEBUG_CHANNELS[channel] == nil then
		return
	end
	DEBUG_CHANNELS[channel] = enabled and true or false
end

function MobilityController.SetDebugChannels(map: {[string]: boolean})
	for channel, enabled in pairs(map) do
		MobilityController.SetDebugChannel(channel, enabled)
	end
end

function MobilityController.new()
	local self = setmetatable({}, MobilityController)
	
	self.State = nil
	self.SequenceNumber = 0
	self.PendingRequests = {}
	self.LastLeapTime = 0
	self.JumpCount = 0
	self.IsJumpButtonDown = false
	self.JumpRequestArmed = false
	
	-- Only create if modules loaded successfully
	self.Effects = MobilityEffects and MobilityEffects.new() or nil
	self.UI = MobilityUI and MobilityUI.new() or nil
	
	-- Camera state tracking
	self.OriginalFOV = 70 -- Default Roblox FOV
	self.ActiveFOVTweens = {} -- Track active tweens for cleanup
	
	-- Connection tracking for cleanup
	self.Connections = {}
	
	return self
end

function MobilityController:Init()
	debugLog("init", "Initializing")
	
	-- Check if Net loaded
	if not Net then
		warn("[MobilityController] Net module not available - mobility system disabled")
		return
	end
	
	-- Character handling with proper cleanup
	if LocalPlayer.Character then
		self:OnCharacterAdded(LocalPlayer.Character)
	end
	
	-- Store character added connection for cleanup
	self.Connections.CharacterAdded = LocalPlayer.CharacterAdded:Connect(function(character)
		debugLog("character", "Character added", character:GetFullName())
		self:Cleanup() -- Clean up previous character state
		self:OnCharacterAdded(character)
	end)

	-- Handle character removing for cleanup
	self.Connections.CharacterRemoving = LocalPlayer.CharacterRemoving:Connect(function(character)
		debugLog("character", "Character removing", character:GetFullName())
		self:OnCharacterRemoving(character)
	end)
	
	-- Setup network handlers
	self:SetupNetworking()
	
	-- Setup input handlers
	self:SetupInput()
	
	debugLog("init", "Initialized")
end

function MobilityController:OnCharacterAdded(character: Model)
	debugLog("character", "Setting up character", character:GetFullName())
	
	self.Character = character
	self.Humanoid = character:WaitForChild("Humanoid", 5)
	self.HumanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
	
	if not self.Humanoid or not self.HumanoidRootPart then
		warn("[MobilityController] Failed to find character components")
		return
	end

	
	
	-- Store original FOV when character loads
	local camera = Workspace.CurrentCamera
	if camera then
		self.OriginalFOV = camera.FieldOfView
		debugLog("character", "Stored original FOV", self.OriginalFOV)
	end
	
	debugLog("character", "Character components ready", self.Humanoid, self.HumanoidRootPart)
	
	-- Reset jump count on landing (store connection for cleanup)
	if self.Connections.HumanoidStateChanged then
		self.Connections.HumanoidStateChanged:Disconnect()
	end
	
	self.Connections.HumanoidStateChanged = self.Humanoid.StateChanged:Connect(function(old, new)
		debugLog("character", "Humanoid state", old, "->", new)
		
		if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
			self.JumpCount = 0
			debugLog("character", "Jump count reset")
		elseif new == Enum.HumanoidStateType.Freefall then
			if tick() - self.LastLeapTime > 0.1 then -- Not from our leap
				self.JumpCount = 1 -- Regular jump counts as first jump
				debugLog("character", "Jump count set for regular jump")
			end
		end
	end)
	
	-- Initialize UI
	if self.UI then
		self.UI:SetupForCharacter(character)
		debugLog("ui", "UI setup complete")
	else
		warn("[MobilityController] UI module not available")
	end
	
	-- Set default state if not received from server
	task.wait(1)
	if not self.State then
		debugLog("init", "Applying default mobility state")
		self.State = {
			Leap = {
				LastUsed = 0,
				ChargesRemaining = 2,
				IsOnCooldown = false,
				NextChargeTime = 0,
				IsEquipped = true
			},
			Dash = {
				LastUsed = 0,
				ChargesRemaining = 1,
				IsOnCooldown = false,
				NextChargeTime = 0,
				IsEquipped = true
			},
			LastValidPosition = Vector3.new(0, 50, 0),
			LastValidVelocity = Vector3.new(),
			ValidationPending = false,
			LastAbilityUse = 0
		}
		self:UpdateUI()
	end
end

function MobilityController:OnCharacterRemoving(character: Model)
	debugLog("character", "Character removing cleanup", character:GetFullName())
	
	-- Cancel all active FOV tweens
	for _, tween in pairs(self.ActiveFOVTweens) do
		if tween then
			tween:Cancel()
		end
	end
	self.ActiveFOVTweens = {}
	
	-- Reset FOV to original
	local camera = Workspace.CurrentCamera
	if camera then
		camera.FieldOfView = self.OriginalFOV
		debugLog("character", "Reset FOV", self.OriginalFOV)
	end
	
	-- Clean up connections
	if self.Connections.HumanoidStateChanged then
		self.Connections.HumanoidStateChanged:Disconnect()
		self.Connections.HumanoidStateChanged = nil
	end
	
	-- Clean up UI
	if self.UI then
		self.UI:Cleanup()
	end
	
	-- Reset state
	self.Character = nil
	self.Humanoid = nil
	self.HumanoidRootPart = nil
	self.JumpCount = 0
	self.LastLeapTime = 0
end

function MobilityController:SetupNetworking()
	debugLog("net", "Setting up networking")

	if not Net then
		warn("[MobilityController] Net not available - skipping networking setup")
		return
	end

	local netRoot = ReplicatedStorage:FindFirstChild("Net")
	if not netRoot then
		netRoot = ReplicatedStorage:WaitForChild("Net", 5)
	end
	if not netRoot then
		warn("[MobilityController] Net folder missing; cannot bind remotes")
		return
	end

	local remotesFolder = netRoot:FindFirstChild("Remotes") or netRoot:WaitForChild("Remotes", 5)
	if not remotesFolder then
		warn("[MobilityController] Net remotes folder missing; cannot bind remotes")
		return
	end

	local requiredRemotes = {
		"MobilityRequest",
		"MobilityResponse",
		"MobilityStateSync",
		"MobilityEffects",
	}

	for _, remoteName in ipairs(requiredRemotes) do
		if not remotesFolder:FindFirstChild(remoteName) then
			local remote = remotesFolder:WaitForChild(remoteName, 5)
			if not remote then
				warn(string.format("[MobilityController] Remote '%s' not found; networking disabled", remoteName))
				return
			end
		end
	end

	-- Handle server responses
	local success = pcall(function()
		Net.On("MobilityResponse", function(response)
			debugLog("net", "MobilityResponse", response)
			self:HandleServerResponse(response)
		end)
		
		-- Handle state sync
		Net.On("MobilityStateSync", function(state)
			debugLog("net", "State sync received")
			if state and state.Leap and state.Dash then
				debugLog(
					"net",
					string.format(
						"Leap charges=%d cooldown=%s Dash cooldown=%s",
						state.Leap.ChargesRemaining,
						tostring(state.Leap.IsOnCooldown),
						tostring(state.Dash.IsOnCooldown)
					)
				)
				self.State = state
				self:UpdateUI()
			else
				warn("[MobilityController] Invalid state received")
			end
		end)
		
		-- Handle effects from other players
		Net.On("MobilityEffects", function(player, effectData)
			if player ~= LocalPlayer and self.Effects then
				debugLog("effects", "Remote effect", player.Name)
				self.Effects:PlayEffect(effectData)
			end
		end)
	end)
	
	if success then
		debugLog("net", "Networking ready")
	else
		warn("[MobilityController] Failed to setup networking")
	end
end

function MobilityController:SetupInput()
	debugLog("input", "Setting up input handlers")

	self.Connections.JumpRequest = UserInputService.JumpRequest:Connect(function()
		if not self.JumpRequestArmed then
			return
		end
		self.JumpRequestArmed = false

		debugLog(
			"input",
			string.format("Jump request count=%d hasState=%s", self.JumpCount, tostring(self.State ~= nil))
		)

		if not self.Humanoid then
			debugLog("ability", "Leap aborted: no humanoid")
			return
		end

		local humanoidState = self.Humanoid:GetState()
		local isAirborne = humanoidState == Enum.HumanoidStateType.Freefall
			or humanoidState == Enum.HumanoidStateType.FallingDown
		debugLog("input", "Humanoid state", humanoidState)

		if self.JumpCount >= 1 and isAirborne then
			local canLeap = true

			if self.State and self.State.Leap then
				canLeap = self.State.Leap.ChargesRemaining > 0
				debugLog("ability", string.format("Leap charges=%d", self.State.Leap.ChargesRemaining))
			else
				debugLog("ability", "No server state; attempting leap")
			end

			if canLeap then
				debugLog("ability", "Leap conditions met")
				self:PerformLeap()
			else
				debugLog("ability", "Leap denied: no charges")
			end
		else
			if not isAirborne then
				debugLog("ability", "Leap ignored: humanoid not airborne")
			else
				debugLog("ability", "Leap ignored: jump count too low")
			end
		end
	end)

	self.Connections.InputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.KeyCode == Enum.KeyCode.Space then
			self.IsJumpButtonDown = true
			if not gameProcessed then
				self.JumpRequestArmed = true
			end
		end

		if gameProcessed then
			return
		end

		if input.KeyCode == Enum.KeyCode.Q then
			debugLog("input", "Dash key pressed")

			local canDash = true

			if self.State and self.State.Dash then
				canDash = not self.State.Dash.IsOnCooldown
				debugLog("ability", string.format("Dash cooldown=%s", tostring(self.State.Dash.IsOnCooldown)))
			else
				debugLog("ability", "No server state; attempting dash")
			end

			if canDash then
				self:PerformDash()
			else
				debugLog("ability", "Dash denied: cooldown")
			end
		end
	end)

	self.Connections.InputEnded = UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Space then
			self.IsJumpButtonDown = false
		end
	end)

	debugLog("input", "Input handlers ready")
end

function MobilityController:PerformLeap()
	debugLog("ability", "PerformLeap invoked")
	
	if not self.Character or not self.Humanoid or not self.HumanoidRootPart then 
		debugLog("ability", "Leap aborted: missing components")
		return 
	end
	
	debugLog("ability", "Executing leap")
	
	-- Predict on client immediately for responsiveness
	self.JumpCount = self.JumpCount + 1
	self.LastLeapTime = tick()
	
	-- Apply leap physics
	local lookDirection = self.HumanoidRootPart.CFrame.LookVector
	local upVector = Vector3.new(0, 1, 0)
	
	-- Combine vertical and forward boost
	local leapVelocity = (upVector * MobilityConfig.LeapVerticalBoost) + 
	                     (lookDirection * MobilityConfig.LeapHorizontalBoost)
	
	debugLog("ability", "Leap velocity", leapVelocity)
	
	-- Apply velocity
	self.HumanoidRootPart.AssemblyLinearVelocity = self.HumanoidRootPart.AssemblyLinearVelocity + leapVelocity
	
	-- Visual effects (client prediction)
	if self.Effects then
		self.Effects:PlayLeapEffect(self.HumanoidRootPart.Position, -upVector)
	end
	
	-- Camera zoom out effect
	self:ApplyCameraZoom()
	
	-- Send to server (only if Net is available)
	if Net and Net.Fire then
		self:SendMobilityRequest("Leap", upVector)
	else
		warn("[MobilityController] Cannot send to server - Net not available")
	end
	
	-- Update UI optimistically
	if self.State and self.State.Leap then
		self.State.Leap.ChargesRemaining = math.max(0, self.State.Leap.ChargesRemaining - 1)
		self:UpdateUI()
	end
	
	debugLog("ability", "Leap complete")
end

function MobilityController:PerformDash()
	debugLog("ability", "PerformDash invoked")
	
	if not self.Character or not self.Humanoid or not self.HumanoidRootPart then 
		debugLog("ability", "Dash aborted: missing components")
		return 
	end
	
	debugLog("ability", "Executing dash")
	
	-- Get dash direction (camera look direction or character facing)
	local camera = Workspace.CurrentCamera
	local dashDirection = camera.CFrame.LookVector
	dashDirection = Vector3.new(dashDirection.X, 0, dashDirection.Z).Unit -- Horizontal only
	
	debugLog("ability", "Dash direction", dashDirection)
	
	-- Apply dash physics (client prediction)
	local dashVelocity = dashDirection * MobilityConfig.DashPower
	
	-- Create dash movement
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(10000, 0, 10000)
	bodyVelocity.Velocity = dashVelocity
	bodyVelocity.Parent = self.HumanoidRootPart
	
	debugLog("ability", "Dash velocity", dashVelocity)
	
	-- Remove after dash duration
	task.spawn(function()
		task.wait(MobilityConfig.DashDuration)
		if bodyVelocity and bodyVelocity.Parent then
			bodyVelocity:Destroy()
		end
	end)
	
	-- Visual effects
	if self.Effects then
		self.Effects:PlayDashEffect(self.HumanoidRootPart.Position, -dashDirection)
	end
	
	-- Camera zoom effect
	self:ApplyCameraZoom()
	
	-- Send to server (only if Net is available)
	if Net and Net.Fire then
		self:SendMobilityRequest("Dash", dashDirection)
	else
		warn("[MobilityController] Cannot send to server - Net not available")
	end
	
	-- Update UI optimistically
	if self.State and self.State.Dash then
		self.State.Dash.IsOnCooldown = true
		self:UpdateUI()
		
		-- Reset cooldown locally after duration
		task.spawn(function()
			task.wait(MobilityConfig.DashCooldown or 3)
			if self.State and self.State.Dash then
				self.State.Dash.IsOnCooldown = false
				self:UpdateUI()
			end
		end)
	end
	
	debugLog("ability", "Dash complete")
end

function MobilityController:ApplyCameraZoom()
	local camera = Workspace.CurrentCamera
	if not camera then return end
	
	-- Cancel any existing FOV tweens
	for i, tween in pairs(self.ActiveFOVTweens) do
		if tween then
			tween:Cancel()
		end
		self.ActiveFOVTweens[i] = nil
	end
	
	-- Store current FOV as the one to return to
	local startFOV = camera.FieldOfView
	local targetFOV = self.OriginalFOV + MobilityConfig.ZoomOutAmount
	
	debugLog(
		"effects",
		string.format(
			"Camera zoom start=%.2f target=%.2f original=%.2f",
			startFOV,
			targetFOV,
			self.OriginalFOV
		)
	)
	
	-- Zoom out
	local zoomOutTween = TweenService:Create(
		camera,
		TweenInfo.new(MobilityConfig.ZoomOutDuration * 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{FieldOfView = targetFOV}
	)
	
	self.ActiveFOVTweens[1] = zoomOutTween
	zoomOutTween:Play()
	
	-- Zoom back in after delay
	task.spawn(function()
		task.wait(MobilityConfig.ZoomOutDuration)
		
		-- Make sure camera still exists and character hasn't been removed
		if camera.Parent and self.Character then
			local zoomInTween = TweenService:Create(
				camera,
				TweenInfo.new(MobilityConfig.ZoomOutDuration * 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{FieldOfView = self.OriginalFOV}
			)
			
			self.ActiveFOVTweens[2] = zoomInTween
			zoomInTween:Play()
			
			-- Clean up tween references after completion
			zoomInTween.Completed:Connect(function()
				self.ActiveFOVTweens[2] = nil
			end)
		end
		
		-- Clean up zoom out reference
		self.ActiveFOVTweens[1] = nil
	end)
end

function MobilityController:SendMobilityRequest(abilityType: string, direction: Vector3)
	if not Net or not Net.Fire then
		warn("[MobilityController] Cannot send request - Net not available")
		return
	end

	local netRoot = ReplicatedStorage:FindFirstChild("Net")
	local remotes = netRoot and netRoot:FindFirstChild("Remotes")
	local mobilityRequestRemote = remotes and remotes:FindFirstChild("MobilityRequest")
	if not mobilityRequestRemote then
		warn("[MobilityController] MobilityRequest remote missing; request skipped")
		return
	end

	self.SequenceNumber = self.SequenceNumber + 1
	
	local request = {
		Type = abilityType,
		StartPosition = self.HumanoidRootPart.Position,
		Direction = direction,
		Timestamp = tick(),
		SequenceNumber = self.SequenceNumber
	}
	
	debugLog(
		"net",
		string.format("Send request type=%s seq=%d", abilityType, self.SequenceNumber),
		request.StartPosition,
		direction
	)
	
	-- Store pending request for reconciliation
	self.PendingRequests[self.SequenceNumber] = request
	
	-- Send to server
	local success = pcall(function()
		Net.Fire("MobilityRequest", request)
	end)
	
	if success then
		debugLog("net", "Request dispatched", self.SequenceNumber)
	else
		warn("[MobilityController] Failed to send request to server")
	end
end

function MobilityController:HandleServerResponse(response)
	debugLog(
		"net",
		string.format(
			"Response success=%s seq=%d reason=%s",
			tostring(response.Success),
			response.SequenceNumber,
			response.Reason or "none"
		)
	)
	
	local pendingRequest = self.PendingRequests[response.SequenceNumber]
	if not pendingRequest then 
		debugLog("net", "No pending request", response.SequenceNumber)
		return 
	end
	
	-- Clear processed request
	self.PendingRequests[response.SequenceNumber] = nil
	
	-- Handle rejection/correction
	if not response.Success then
		debugLog("net", "Request rejected", response.Reason)
		
		if response.CorrectedPosition and self.HumanoidRootPart then
			-- Server correction - smooth interpolation instead of teleport
			local currentPos = self.HumanoidRootPart.Position
			local correctedPos = response.CorrectedPosition
			
			debugLog("net", "Position correction", currentPos, correctedPos, (currentPos - correctedPos).Magnitude)
			
			-- Only correct if significantly different
			if (currentPos - correctedPos).Magnitude > MobilityConfig.TeleportBackThreshold then
				debugLog("net", "Applying correction")
				-- Smooth correction
				local tween = TweenService:Create(
					self.HumanoidRootPart,
					TweenInfo.new(0.2, Enum.EasingStyle.Linear),
					{Position = correctedPos}
				)
				tween:Play()
			else
				debugLog("net", "Correction below threshold")
			end
		end
		
		-- Show error message
		if response.Reason and self.UI then
			self.UI:ShowError(response.Reason)
		end
	else
		debugLog("net", "Request approved", response.SequenceNumber)
	end
end

function MobilityController:UpdateUI()
	if not self.State then 
		debugLog("ui", "Update skipped: no state")
		return 
	end
	
	if not self.UI then
		debugLog("ui", "Update skipped: UI missing")
		return
	end
	
	debugLog("ui", "Updating mobility UI")
	
	-- Update cooldown displays
	self.UI:UpdateLeapCooldown(self.State.Leap)
	self.UI:UpdateDashCooldown(self.State.Dash)
end

function MobilityController:Cleanup()
	debugLog("cleanup", "Performing cleanup")
	
	-- Cancel all FOV tweens
	for _, tween in pairs(self.ActiveFOVTweens) do
		if tween then
			tween:Cancel()
		end
	end
	self.ActiveFOVTweens = {}
	
	-- Reset camera FOV
	local camera = Workspace.CurrentCamera
	if camera then
		camera.FieldOfView = self.OriginalFOV
	end
	
	-- Disconnect all connections
	for name, connection in pairs(self.Connections) do
		if connection then
			connection:Disconnect()
			debugLog("cleanup", "Disconnected", name)
		end
	end
	self.Connections = {}
	
	-- Clean up UI
	if self.UI then
		self.UI:Cleanup()
	end
	
	-- Clean up effects
	if self.Effects then
		self.Effects:Cleanup()
	end
end

return MobilityController





