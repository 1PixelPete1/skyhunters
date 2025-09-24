--[[
	MobilityTest.client.luau
	Simple all-in-one mobility test - no dependencies
	Place in StarterPlayer > StarterPlayerScripts
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

print("[MobilityTest] Simple mobility test active!")
print("[MobilityTest] Press SPACE for double jump/leap")
print("[MobilityTest] Press Q for dash")

-- Configuration
local LEAP_VERTICAL_BOOST = 30
local LEAP_HORIZONTAL_BOOST = 15
local DASH_POWER = 80
local DASH_DURATION = 0.3

-- State
local jumpCount = 0
local lastLeapTime = 0
local dashCooldown = false

-- Reset jump count on landing
Humanoid.StateChanged:Connect(function(old, new)
	if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
		jumpCount = 0
		print("[MobilityTest] Landed - jump count reset")
	elseif new == Enum.HumanoidStateType.Freefall then
		if tick() - lastLeapTime > 0.1 then
			jumpCount = 1
			print("[MobilityTest] Regular jump - count: 1")
		end
	end
end)

-- Handle double jump (leap)
UserInputService.JumpRequest:Connect(function()
	print("[MobilityTest] Jump requested - count:", jumpCount)
	
	if jumpCount >= 1 then
		-- Perform leap
		jumpCount = jumpCount + 1
		lastLeapTime = tick()
		
		print("[MobilityTest] LEAP ACTIVATED!")
		
		-- Apply leap physics
		local lookDirection = HumanoidRootPart.CFrame.LookVector
		local upVector = Vector3.new(0, 1, 0)
		local leapVelocity = (upVector * LEAP_VERTICAL_BOOST) + (lookDirection * LEAP_HORIZONTAL_BOOST)
		
		HumanoidRootPart.AssemblyLinearVelocity = HumanoidRootPart.AssemblyLinearVelocity + leapVelocity
		
		-- Visual effect (simple)
		local effect = Instance.new("Part")
		effect.Name = "LeapEffect"
		effect.Size = Vector3.new(4, 0.2, 4)
		effect.Material = Enum.Material.ForceField
		effect.BrickColor = BrickColor.new("Cyan")
		effect.Transparency = 0.5
		effect.CanCollide = false
		effect.Anchored = true
		effect.Position = HumanoidRootPart.Position - Vector3.new(0, 3, 0)
		effect.Parent = Workspace
		
		-- Fade out effect
		for i = 1, 10 do
			task.wait(0.05)
			effect.Transparency = 0.5 + (i * 0.05)
			effect.Size = effect.Size + Vector3.new(0.5, 0, 0.5)
		end
		effect:Destroy()
	end
end)

-- Handle dash (Q key)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.Q and not dashCooldown then
		print("[MobilityTest] DASH ACTIVATED!")
		
		dashCooldown = true
		
		-- Get dash direction
		local camera = Workspace.CurrentCamera
		local dashDirection = camera.CFrame.LookVector
		dashDirection = Vector3.new(dashDirection.X, 0, dashDirection.Z).Unit
		
		-- Apply dash
		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.MaxForce = Vector3.new(10000, 0, 10000)
		bodyVelocity.Velocity = dashDirection * DASH_POWER
		bodyVelocity.Parent = HumanoidRootPart
		
		-- Visual effect
		for i = 1, 5 do
			local line = Instance.new("Part")
			line.Name = "DashLine"
			line.Size = Vector3.new(0.2, 0.2, 10)
			line.Material = Enum.Material.Neon
			line.BrickColor = BrickColor.new("White")
			line.Transparency = 0.3
			line.CanCollide = false
			line.Anchored = true
			line.CFrame = HumanoidRootPart.CFrame * CFrame.new(
				math.random(-2, 2),
				math.random(-2, 2),
				-5
			)
			line.Parent = Workspace
			
			-- Fade out
			task.spawn(function()
				for j = 1, 10 do
					task.wait(0.03)
					line.Transparency = 0.3 + (j * 0.07)
				end
				line:Destroy()
			end)
		end
		
		-- Remove dash after duration
		task.wait(DASH_DURATION)
		bodyVelocity:Destroy()
		
		-- Cooldown
		task.wait(2.5)
		dashCooldown = false
		print("[MobilityTest] Dash ready!")
	end
end)

-- Handle respawn
LocalPlayer.CharacterAdded:Connect(function(newChar)
	Character = newChar
	Humanoid = newChar:WaitForChild("Humanoid")
	HumanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
	jumpCount = 0
	lastLeapTime = 0
	dashCooldown = false
	print("[MobilityTest] Character respawned - mobility ready!")
end)

print("[MobilityTest] Ready! Use SPACE for double jump, Q for dash")
