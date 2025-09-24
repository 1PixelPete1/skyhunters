--!strict
-- StateTransitionEffects.client.luau
-- Visual effects for player state transitions
-- FIXED: Proper cleanup on character reset to prevent flickering and frame drops

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for state remote
local stateRemote = ReplicatedStorage:WaitForChild("PlayerStateRemote")

-- Effect settings
local STATE_COLORS = {
	Build = Color3.fromRGB(100, 255, 100),    -- Green
	Neutral = Color3.fromRGB(100, 150, 255),  -- Blue  
	Run = Color3.fromRGB(255, 100, 100),      -- Red
	Recalling = Color3.fromRGB(100, 255, 255), -- Cyan
}

-- Current effects and state
local currentEffects = {}
local currentState = "Neutral"
local activeTweens = {}
local activeConnections = {}
local screenEffectsGui = nil
local colorCorrection = nil
local blurEffect = nil
local isCleaningUp = false

-- Cleanup function
local function cleanupEffects()
	if isCleaningUp then return end
	isCleaningUp = true
	
	print("[StateEffects] Cleaning up effects...")
	
	-- Cancel all active tweens
	for _, tween in pairs(activeTweens) do
		if tween and tween.PlaybackState ~= Enum.PlaybackState.Completed then
			tween:Cancel()
		end
	end
	activeTweens = {}
	
	-- Disconnect all connections
	for _, connection in pairs(activeConnections) do
		if connection then
			connection:Disconnect()
		end
	end
	activeConnections = {}
	
	-- Clean up lighting effects
	if colorCorrection then
		colorCorrection.Enabled = false
		colorCorrection.Brightness = 0
		colorCorrection.Contrast = 0
		colorCorrection.Saturation = 0
		colorCorrection.TintColor = Color3.new(1, 1, 1)
	end
	
	if blurEffect then
		blurEffect.Enabled = false
		blurEffect.Size = 0
	end
	
	-- Remove character particles
	local character = player.Character
	if character then
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local oldAttachment = rootPart:FindFirstChild("StateParticles")
			if oldAttachment then
				oldAttachment:Destroy()
			end
		end
	end
	
	isCleaningUp = false
	print("[StateEffects] Cleanup complete")
end

-- Create screen effects GUI
local function createScreenEffects()
	-- Clean up old GUI if it exists
	if screenEffectsGui and screenEffectsGui.Parent then
		screenEffectsGui:Destroy()
	end
	
	screenEffectsGui = Instance.new("ScreenGui")
	screenEffectsGui.Name = "StateEffects"
	screenEffectsGui.ResetOnSpawn = false
	screenEffectsGui.IgnoreGuiInset = true
	screenEffectsGui.DisplayOrder = -1
	screenEffectsGui.Parent = playerGui
	
	-- Border frame for state indication
	local borderFrame = Instance.new("Frame")
	borderFrame.Name = "StateBorder"
	borderFrame.Size = UDim2.new(1, 0, 1, 0)
	borderFrame.BackgroundTransparency = 1
	borderFrame.BorderSizePixel = 0
	borderFrame.Parent = screenEffectsGui
	
	-- Create border parts
	local borderThickness = 3
	local borders = {
		top = Instance.new("Frame"),
		bottom = Instance.new("Frame"),
		left = Instance.new("Frame"),
		right = Instance.new("Frame"),
	}
	
	borders.top.Size = UDim2.new(1, 0, 0, borderThickness)
	borders.top.Position = UDim2.new(0, 0, 0, 0)
	borders.top.BackgroundColor3 = STATE_COLORS[currentState] or STATE_COLORS.Neutral
	borders.top.BorderSizePixel = 0
	borders.top.BackgroundTransparency = 0.5
	borders.top.Parent = borderFrame
	
	borders.bottom.Size = UDim2.new(1, 0, 0, borderThickness)
	borders.bottom.Position = UDim2.new(0, 0, 1, -borderThickness)
	borders.bottom.BackgroundColor3 = STATE_COLORS[currentState] or STATE_COLORS.Neutral
	borders.bottom.BorderSizePixel = 0
	borders.bottom.BackgroundTransparency = 0.5
	borders.bottom.Parent = borderFrame
	
	borders.left.Size = UDim2.new(0, borderThickness, 1, 0)
	borders.left.Position = UDim2.new(0, 0, 0, 0)
	borders.left.BackgroundColor3 = STATE_COLORS[currentState] or STATE_COLORS.Neutral
	borders.left.BorderSizePixel = 0
	borders.left.BackgroundTransparency = 0.5
	borders.left.Parent = borderFrame
	
	borders.right.Size = UDim2.new(0, borderThickness, 1, -borderThickness * 2)
	borders.right.Position = UDim2.new(1, -borderThickness, 0, borderThickness)
	borders.right.BackgroundColor3 = STATE_COLORS[currentState] or STATE_COLORS.Neutral
	borders.right.BorderSizePixel = 0
	borders.right.BackgroundTransparency = 0.5
	borders.right.Parent = borderFrame
	
	-- Transition overlay
	local transitionOverlay = Instance.new("Frame")
	transitionOverlay.Name = "TransitionOverlay"
	transitionOverlay.Size = UDim2.new(1, 0, 1, 0)
	transitionOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
	transitionOverlay.BackgroundTransparency = 1
	transitionOverlay.BorderSizePixel = 0
	transitionOverlay.Parent = screenEffectsGui
	
	return borders, transitionOverlay
end

-- Create or get lighting effects
local function setupLightingEffects()
	-- Clean up old effects
	local oldColorCorrection = Lighting:FindFirstChild("StateColorCorrection")
	if oldColorCorrection then
		oldColorCorrection:Destroy()
	end
	
	local oldBlur = Lighting:FindFirstChild("StateBlur")
	if oldBlur then
		oldBlur:Destroy()
	end
	
	-- Create ColorCorrection effect
	colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "StateColorCorrection"
	colorCorrection.Brightness = 0
	colorCorrection.Contrast = 0
	colorCorrection.Saturation = 0
	colorCorrection.TintColor = Color3.new(1, 1, 1)
	colorCorrection.Enabled = false
	colorCorrection.Parent = Lighting
	
	-- Create Blur effect  
	blurEffect = Instance.new("BlurEffect")
	blurEffect.Name = "StateBlur"
	blurEffect.Size = 0
	blurEffect.Enabled = false
	blurEffect.Parent = Lighting
end

-- Particle emitter for character
local function createCharacterParticles(character: Model, color: Color3)
	if not character or not character.Parent then return end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	
	-- Remove old particles
	local oldAttachment = rootPart:FindFirstChild("StateParticles")
	if oldAttachment then
		oldAttachment:Destroy()
	end
	
	-- Don't create new particles during cleanup
	if isCleaningUp then return end
	
	-- Create new particles
	local attachment = Instance.new("Attachment")
	attachment.Name = "StateParticles"
	attachment.Parent = rootPart
	
	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particles.Rate = 20
	particles.Lifetime = NumberRange.new(1, 2)
	particles.Speed = NumberRange.new(2, 5)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Color = ColorSequence.new(color)
	particles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Parent = attachment
	
	return attachment
end

-- State transition effects (with proper cleanup)
local function playStateTransition(newState: string, oldState: string)
	if isCleaningUp then return end
	
	-- Ensure UI exists
	if not screenEffectsGui or not screenEffectsGui.Parent then
		createScreenEffects()
	end
	
	local borderFrame = screenEffectsGui:FindFirstChild("StateBorder")
	local transitionOverlay = screenEffectsGui:FindFirstChild("TransitionOverlay")
	
	if not borderFrame or not transitionOverlay then
		warn("[StateEffects] UI elements missing, recreating...")
		createScreenEffects()
		borderFrame = screenEffectsGui:FindFirstChild("StateBorder")
		transitionOverlay = screenEffectsGui:FindFirstChild("TransitionOverlay")
	end
	
	local color = STATE_COLORS[newState] or Color3.new(1, 1, 1)
	
	-- Cancel old tweens before creating new ones
	for i, tween in pairs(activeTweens) do
		if tween and tween.PlaybackState ~= Enum.PlaybackState.Completed then
			tween:Cancel()
		end
		activeTweens[i] = nil
	end
	
	-- Flash effect (only if overlay exists)
	if transitionOverlay then
		transitionOverlay.BackgroundColor3 = color
		transitionOverlay.BackgroundTransparency = 0.8
		
		local flashTween = TweenService:Create(transitionOverlay, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
			BackgroundTransparency = 1
		})
		table.insert(activeTweens, flashTween)
		flashTween:Play()
	end
	
	-- Border color change
	if borderFrame then
		for _, child in pairs(borderFrame:GetChildren()) do
			if child:IsA("Frame") then
				local borderTween = TweenService:Create(child, TweenInfo.new(0.5), {
					BackgroundColor3 = color
				})
				table.insert(activeTweens, borderTween)
				borderTween:Play()
			end
		end
	end
	
	-- Character particles
	local character = player.Character
	if character then
		createCharacterParticles(character, color)
	end
	
	-- State-specific effects
	if newState == "Build" then
		-- Green tint and slight brightness
		if colorCorrection then
			colorCorrection.Enabled = true
			local tween = TweenService:Create(colorCorrection, TweenInfo.new(0.5), {
				Brightness = 0.05,
				Saturation = 0.1,
				TintColor = Color3.fromRGB(240, 255, 240)
			})
			table.insert(activeTweens, tween)
			tween:Play()
		end
		
	elseif newState == "Neutral" then
		-- Neutral, clear effects
		if colorCorrection then
			local tween = TweenService:Create(colorCorrection, TweenInfo.new(0.5), {
				Brightness = 0,
				Saturation = 0,
				TintColor = Color3.new(1, 1, 1)
			})
			table.insert(activeTweens, tween)
			tween:Play()
			
			tween.Completed:Connect(function()
				if colorCorrection then
					colorCorrection.Enabled = false
				end
			end)
		end
		
	elseif newState == "Run" then
		-- Red tint and increased contrast for danger
		if colorCorrection then
			colorCorrection.Enabled = true
			local tween = TweenService:Create(colorCorrection, TweenInfo.new(0.5), {
				Brightness = -0.05,
				Contrast = 0.1,
				Saturation = -0.1,
				TintColor = Color3.fromRGB(255, 240, 240)
			})
			table.insert(activeTweens, tween)
			tween:Play()
		end
		
		-- Add slight camera shake (with cleanup tracking)
		task.spawn(function()
			if isCleaningUp then return end
			
			local shakeTime = 0.3
			local shakeMagnitude = 0.2
			local startTime = tick()
			
			while tick() - startTime < shakeTime and not isCleaningUp do
				local offset = Vector3.new(
					math.random() * shakeMagnitude - shakeMagnitude/2,
					math.random() * shakeMagnitude - shakeMagnitude/2,
					0
				) * (1 - (tick() - startTime) / shakeTime)
				
				if camera and camera.Parent then
					camera.CFrame = camera.CFrame * CFrame.new(offset)
				end
				RunService.RenderStepped:Wait()
			end
		end)
		
	elseif newState == "Recalling" then
		-- Cyan pulse and blur
		if blurEffect then
			blurEffect.Enabled = true
			local blurTween = TweenService:Create(blurEffect, TweenInfo.new(0.5), {
				Size = 10
			})
			table.insert(activeTweens, blurTween)
			blurTween:Play()
		end
		
		-- Pulsing border (with cleanup tracking)
		task.spawn(function()
			while currentState == "Recalling" and not isCleaningUp do
				if not borderFrame or not borderFrame.Parent then break end
				
				for _, child in pairs(borderFrame:GetChildren()) do
					if child:IsA("Frame") then
						local pulseTween = TweenService:Create(child, TweenInfo.new(0.5), {
							BackgroundTransparency = 0.2
						})
						table.insert(activeTweens, pulseTween)
						pulseTween:Play()
					end
				end
				task.wait(0.5)
				
				if isCleaningUp then break end
				
				for _, child in pairs(borderFrame:GetChildren()) do
					if child:IsA("Frame") then
						local pulseTween = TweenService:Create(child, TweenInfo.new(0.5), {
							BackgroundTransparency = 0.5
						})
						table.insert(activeTweens, pulseTween)
						pulseTween:Play()
					end
				end
				task.wait(0.5)
			end
			
			-- Clear blur when done
			if blurEffect and not isCleaningUp then
				local clearTween = TweenService:Create(blurEffect, TweenInfo.new(0.5), {
					Size = 0
				})
				table.insert(activeTweens, clearTween)
				clearTween:Play()
				
				clearTween.Completed:Connect(function()
					if blurEffect then
						blurEffect.Enabled = false
					end
				end)
			end
		end)
	end
	
	print(string.format("[StateEffects] Transitioned from %s to %s", oldState, newState))
end

-- Handle state changes
local stateConnection = stateRemote.OnClientEvent:Connect(function(eventType, data)
	if eventType == "StateChanged" then
		local oldState = currentState
		currentState = data.state
		playStateTransition(currentState, oldState)
	end
end)
table.insert(activeConnections, stateConnection)

-- Handle character respawn with cleanup
local characterConnection = player.CharacterAdded:Connect(function(character)
	-- Clean up effects from previous character
	cleanupEffects()
	
	-- Reinitialize
	task.wait(0.5)
	setupLightingEffects()
	createScreenEffects()
	
	-- Apply current state effects
	task.wait(0.5)
	if currentState and STATE_COLORS[currentState] then
		createCharacterParticles(character, STATE_COLORS[currentState])
		
		-- Reapply state-specific lighting
		if currentState == "Build" and colorCorrection then
			colorCorrection.Enabled = true
			colorCorrection.Brightness = 0.05
			colorCorrection.Saturation = 0.1
			colorCorrection.TintColor = Color3.fromRGB(240, 255, 240)
		elseif currentState == "Run" and colorCorrection then
			colorCorrection.Enabled = true
			colorCorrection.Brightness = -0.05
			colorCorrection.Contrast = 0.1
			colorCorrection.Saturation = -0.1
			colorCorrection.TintColor = Color3.fromRGB(255, 240, 240)
		end
	end
end)
table.insert(activeConnections, characterConnection)

-- Handle character removing
local removingConnection = player.CharacterRemoving:Connect(function(character)
	print("[StateEffects] Character removing, cleaning up...")
	cleanupEffects()
end)
table.insert(activeConnections, removingConnection)

-- Initialize
setupLightingEffects()
createScreenEffects()

-- Request current state after a delay
task.wait(1)
stateRemote:FireServer("RequestState")

print("[StateTransitionEffects] Initialized with cleanup support")
