--[[
	CustomResetHandler.client.luau
	Overrides default reset behavior to prevent state system issues
	Place in StarterPlayer > StarterPlayerScripts
]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

-- Configuration
local RESET_MODE = "teleport" -- Options: "teleport", "disable", "default"
local SPAWN_POSITION = Vector3.new(0, 50, 0) -- Default spawn position

print("[CustomResetHandler] Initializing with mode:", RESET_MODE)

if RESET_MODE == "disable" then
	-- Completely disable reset button
	local success = pcall(function()
		StarterGui:SetCore("ResetButtonCallback", false)
	end)
	
	if success then
		print("[CustomResetHandler] Reset button disabled")
	else
		warn("[CustomResetHandler] Failed to disable reset button")
	end
	
elseif RESET_MODE == "teleport" then
	-- Override reset to teleport instead of kill
	local resetBindable = Instance.new("BindableEvent")
	
	resetBindable.Event:Connect(function()
		print("[CustomResetHandler] Reset requested - teleporting to spawn")
		
		local character = LocalPlayer.Character
		if not character then return end
		
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart then return end
		
		-- Find spawn location (customize as needed)
		local spawnCFrame = CFrame.new(SPAWN_POSITION)
		
		-- Check for spawn points in workspace
		local spawnLocation = workspace:FindFirstChild("SpawnLocation")
		if spawnLocation and spawnLocation:IsA("SpawnLocation") then
			spawnCFrame = spawnLocation.CFrame + Vector3.new(0, 5, 0)
		end
		
		-- Teleport player
		humanoidRootPart.CFrame = spawnCFrame
		humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		
		-- Reset any temporary states (if state system is available)
		local stateRemote = ReplicatedStorage:FindFirstChild("PlayerStateRemote")
		if stateRemote then
			-- Request state reset to Neutral
			stateRemote:FireServer("RequestStateChange", "Neutral")
			print("[CustomResetHandler] Requested state change to Neutral")
		end
		
		-- Heal player if damaged
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.Health = humanoid.MaxHealth
		end
		
		-- Clear any status effects or debuffs here
		-- Example: Remove mobility pack cooldowns, clear inventory, etc.
		
		print("[CustomResetHandler] Player reset to spawn")
	end)
	
	-- Set the custom reset callback
	local success = false
	local attempts = 0
	
	while not success and attempts < 10 do
		success = pcall(function()
			StarterGui:SetCore("ResetButtonCallback", resetBindable)
		end)
		
		if not success then
			attempts = attempts + 1
			task.wait(1)
		end
	end
	
	if success then
		print("[CustomResetHandler] Custom reset handler installed")
	else
		warn("[CustomResetHandler] Failed to set custom reset callback after", attempts, "attempts")
	end
	
elseif RESET_MODE == "default" then
	-- Keep default behavior but add cleanup
	print("[CustomResetHandler] Using default reset with enhanced cleanup")
	
	-- Monitor for character removal to ensure cleanup
	LocalPlayer.CharacterRemoving:Connect(function(character)
		print("[CustomResetHandler] Character removing - ensuring cleanup")
		
		-- Force cleanup of any lingering effects
		local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
		if playerGui then
			-- Clean up state effects GUI
			local stateEffects = playerGui:FindFirstChild("StateEffects")
			if stateEffects then
				stateEffects:Destroy()
			end
			
			-- Clean up mobility UI
			local mobilityUI = playerGui:FindFirstChild("MobilityUI")
			if mobilityUI then
				mobilityUI:Destroy()
			end
		end
		
		-- Clean up lighting effects
		local Lighting = game:GetService("Lighting")
		local colorCorrection = Lighting:FindFirstChild("StateColorCorrection")
		if colorCorrection then
			colorCorrection:Destroy()
		end
		
		local blurEffect = Lighting:FindFirstChild("StateBlur")
		if blurEffect then
			blurEffect:Destroy()
		end
	end)
end

print("[CustomResetHandler] Initialized with mode:", RESET_MODE)
