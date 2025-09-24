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
	
	-- Debug flags
	self.DebugEnabled = true
	
	return self
end

function MobilityController:Init()
	print("[MobilityController] Initializing...")
	
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
		print("[MobilityController] Character added")
		self:Cleanup() -- Clean up previous character state
		self:OnCharacterAdded(character)
	end)
	
	-- Handle character removing for cleanup
	self.Connections.CharacterRemoving = LocalPlayer.CharacterRemoving:Connect(function(character)
		print("[MobilityController] Character removing - cleaning up")
		self:OnCharacterRemoving(character)
	end)
	
	-- Setup network handlers
	self:SetupNetworking()
	
	-- Setup input handlers
	self:SetupInput()
	
	print("[MobilityController] Initialized successfully")
end

function MobilityController:OnCharacterAdded(character: Model)
	print("[MobilityController] Setting up character:", character)
	
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
		print("[MobilityController] Stored original FOV:", self.OriginalFOV)
	end
	
	print("[MobilityController] Character components found - Humanoid:", self.Humanoid, "HRP:", self.HumanoidRootPart)
	
	-- Reset jump count on landing (store connection for cleanup)
	if self.Connections.HumanoidStateChanged then
		self.Connections.HumanoidStateChanged:Disconnect()
	end
	
	self.Connections.HumanoidStateChanged = self.Humanoid.StateChanged:Connect(function(old, new)
		if self.DebugEnabled then
			print("[MobilityController] Humanoid state changed:", old, "->", new)
		end
		
		if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
			self.JumpCount = 0
			if self.DebugEnabled then
				print("[MobilityController] Jump count reset to 0")
			end
		elseif new == Enum.HumanoidStateType.Freefall then
			if tick() - self.LastLeapTime > 0.1 then -- Not from our leap
				self.JumpCount = 1 -- Regular jump counts as first jump
				if self.DebugEnabled then
					print("[MobilityController] Jump count set to 1 (regular jump)")
				end
			end
		end
	end)
	
	-- Initialize UI
	if self.UI then
		self.UI:SetupForCharacter(character)
		print("[MobilityController] UI setup complete")
	else
		warn("[MobilityController] UI module not available")
	end
	
	-- Set default state if not received from server
	task.wait(1)
	if not self.State then
		print("[MobilityController] No state from server - using default state")
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
	print("[MobilityController] Character removing - performing cleanup")
	
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
		print("[MobilityController] Reset FOV to:", self.OriginalFOV)
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
	print("[MobilityController] Setting up networking...")
	
	if not Net then
		warn("[MobilityController] Net not available - skipping networking setup")
		return
	end
	
	-- Handle server responses
	local success = pcall(function()
		Net.On("MobilityResponse", function(response)
			print("[MobilityController] Received MobilityResponse:", response)
			self:HandleServerResponse(response)
		end)
		
		-- Handle state sync
		Net.On("MobilityStateSync", function(state)
			print("[MobilityController] Received state sync")
			if state and state.Leap and state.Dash then
				print("  Leap charges:", state.Leap.ChargesRemaining, "Cooldown:", state.Leap.IsOnCooldown)
				print("  Dash cooldown:", state.Dash.IsOnCooldown)
				self.State = state
				self:UpdateUI()
			else
				warn("[MobilityController] Invalid state received")
			end
		end)
		
		-- Handle effects from other players
		Net.On("MobilityEffects", function(player, effectData)
			if player ~= LocalPlayer and self.Effects then
				print("[MobilityController] Playing effect from other player:", player.Name)
				self.Effects:PlayEffect(effectData)
			end
		end)
	end)
	
	if success then
		print("[MobilityController] Networking setup complete")
	else
		warn("[MobilityController] Failed to setup networking")
	end
end

function MobilityController:SetupInput()
	print("[MobilityController] Setting up input handlers...")

	self.Connections.JumpRequest = UserInputService.JumpRequest:Connect(function()
		if not self.JumpRequestArmed then
			return
		end
		self.JumpRequestArmed = false

		print("[MobilityController] Jump request received")
		print("  Jump count:", self.JumpCount)
		print("  State exists:", self.State ~= nil)

		if not self.Humanoid then
			print("[MobilityController] No humanoid available; skipping leap")
			return
		end

		local humanoidState = self.Humanoid:GetState()
		local isAirborne = humanoidState == Enum.HumanoidStateType.Freefall
			or humanoidState == Enum.HumanoidStateType.FallingDown
		print("  Humanoid state:", humanoidState)

		if self.JumpCount >= 1 and isAirborne then
			local canLeap = true

			if self.State and self.State.Leap then
				canLeap = self.State.Leap.ChargesRemaining > 0
				print("  Leap charges:", self.State.Leap.ChargesRemaining)
			else
				print("  No state - attempting leap anyway")
			end

			if canLeap then
				print("[MobilityController] Conditions met for leap - performing leap")
				self:PerformLeap()
			else
				print("[MobilityController] No leap charges remaining")
			end
		else
			if not isAirborne then
				print("[MobilityController] Humanoid not airborne; ignoring leap request")
			else
				print("[MobilityController] Jump count too low for leap")
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
			print("[MobilityController] Q key pressed for dash")

			local canDash = true

			if self.State and self.State.Dash then
				canDash = not self.State.Dash.IsOnCooldown
				print("  Dash cooldown:", self.State.Dash.IsOnCooldown)
			else
				print("  No state - attempting dash anyway")
			end

			if canDash then
				self:PerformDash()
			else
				print("[MobilityController] Dash is on cooldown")
			end
		end
	end)

	self.Connections.InputEnded = UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Space then
			self.IsJumpButtonDown = false
		end
	end)

	print("[MobilityController] Input setup complete")
end

function MobilityController:PerformLeap()
	print("[MobilityController] PerformLeap called")
	
	if not self.Character or not self.Humanoid or not self.HumanoidRootPart then 
		print("[MobilityController] Missing character components for leap")
		return 
	end
	
	print("[MobilityController] Executing leap ability")
	
	-- Predict on client immediately for responsiveness
	self.JumpCount = self.JumpCount + 1
	self.LastLeapTime = tick()
	
	-- Apply leap physics
	local lookDirection = self.HumanoidRootPart.CFrame.LookVector
	local upVector = Vector3.new(0, 1, 0)
	
	-- Combine vertical and forward boost
	local leapVelocity = (upVector * MobilityConfig.LeapVerticalBoost) + 
	                     (lookDirection * MobilityConfig.LeapHorizontalBoost)
	
	print("[MobilityController] Applying leap velocity:", leapVelocity)
	
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
	
	print("[MobilityController] Leap executed successfully")
end

function MobilityController:PerformDash()
	print("[MobilityController] PerformDash called")
	
	if not self.Character or not self.Humanoid or not self.HumanoidRootPart then 
		print("[MobilityController] Missing character components for dash")
		return 
	end
	
	print("[MobilityController] Executing dash ability")
	
	-- Get dash direction (camera look direction or character facing)
	local camera = Workspace.CurrentCamera
	local dashDirection = camera.CFrame.LookVector
	dashDirection = Vector3.new(dashDirection.X, 0, dashDirection.Z).Unit -- Horizontal only
	
	print("[MobilityController] Dash direction:", dashDirection)
	
	-- Apply dash physics (client prediction)
	local dashVelocity = dashDirection * MobilityConfig.DashPower
	
	-- Create dash movement
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(10000, 0, 10000)
	bodyVelocity.Velocity = dashVelocity
	bodyVelocity.Parent = self.HumanoidRootPart
	
	print("[MobilityController] BodyVelocity applied with velocity:", dashVelocity)
	
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
	
	print("[MobilityController] Dash executed successfully")
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
	
	print("[MobilityController] Camera zoom - Start FOV:", startFOV, "Target:", targetFOV, "Original:", self.OriginalFOV)
	
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
	
	self.SequenceNumber = self.SequenceNumber + 1
	
	local request = {
		Type = abilityType,
		StartPosition = self.HumanoidRootPart.Position,
		Direction = direction,
		Timestamp = tick(),
		SequenceNumber = self.SequenceNumber
	}
	
	print("[MobilityController] Sending mobility request:")
	print("  Type:", abilityType)
	print("  Position:", request.StartPosition)
	print("  Direction:", direction)
	print("  Sequence:", self.SequenceNumber)
	
	-- Store pending request for reconciliation
	self.PendingRequests[self.SequenceNumber] = request
	
	-- Send to server
	local success = pcall(function()
		Net.Fire("MobilityRequest", request)
	end)
	
	if success then
		print("[MobilityController] Request sent to server")
	else
		warn("[MobilityController] Failed to send request to server")
	end
end

function MobilityController:HandleServerResponse(response)
	print("[MobilityController] Processing server response")
	print("  Success:", response.Success)
	print("  Sequence:", response.SequenceNumber)
	print("  Reason:", response.Reason or "none")
	
	local pendingRequest = self.PendingRequests[response.SequenceNumber]
	if not pendingRequest then 
		print("[MobilityController] No pending request found for sequence:", response.SequenceNumber)
		return 
	end
	
	-- Clear processed request
	self.PendingRequests[response.SequenceNumber] = nil
	
	-- Handle rejection/correction
	if not response.Success then
		print("[MobilityController] Request rejected by server:", response.Reason)
		
		if response.CorrectedPosition and self.HumanoidRootPart then
			-- Server correction - smooth interpolation instead of teleport
			local currentPos = self.HumanoidRootPart.Position
			local correctedPos = response.CorrectedPosition
			
			print("[MobilityController] Position correction needed")
			print("  Current:", currentPos)
			print("  Corrected:", correctedPos)
			print("  Distance:", (currentPos - correctedPos).Magnitude)
			
			-- Only correct if significantly different
			if (currentPos - correctedPos).Magnitude > MobilityConfig.TeleportBackThreshold then
				print("[MobilityController] Applying position correction")
				-- Smooth correction
				local tween = TweenService:Create(
					self.HumanoidRootPart,
					TweenInfo.new(0.2, Enum.EasingStyle.Linear),
					{Position = correctedPos}
				)
				tween:Play()
			else
				print("[MobilityController] Correction distance too small, ignoring")
			end
		end
		
		-- Show error message
		if response.Reason and self.UI then
			self.UI:ShowError(response.Reason)
		end
	else
		print("[MobilityController] Request approved by server")
	end
end

function MobilityController:UpdateUI()
	if not self.State then 
		print("[MobilityController] Cannot update UI - no state")
		return 
	end
	
	if not self.UI then
		print("[MobilityController] UI module not available")
		return
	end
	
	print("[MobilityController] Updating UI")
	
	-- Update cooldown displays
	self.UI:UpdateLeapCooldown(self.State.Leap)
	self.UI:UpdateDashCooldown(self.State.Dash)
end

function MobilityController:Cleanup()
	print("[MobilityController] Performing full cleanup")
	
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
			print("[MobilityController] Disconnected:", name)
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





