--[[
	MobilityUI.luau
	UI components for mobility system
	Displays cooldown indicators and charge counts
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local MobilityConfig = require(game.ReplicatedStorage.Shared.Mobility.MobilityConfig)
local MobilityTypes = require(game.ReplicatedStorage.Shared.Mobility.MobilityTypes)

local MobilityUI = {}
MobilityUI.__index = MobilityUI

local LocalPlayer = Players.LocalPlayer

function MobilityUI.new()
	local self = setmetatable({}, MobilityUI)
	self.ScreenGui = nil
	self.LeapIndicator = nil
	self.DashIndicator = nil
	self.ErrorLabel = nil
	return self
end

function MobilityUI:SetupForCharacter(character: Model)
	-- Clean up existing UI
	if self.ScreenGui then
		self.ScreenGui:Destroy()
	end
	
	-- Create main GUI
	self.ScreenGui = Instance.new("ScreenGui")
	self.ScreenGui.Name = "MobilityUI"
	self.ScreenGui.ResetOnSpawn = false
	self.ScreenGui.Parent = LocalPlayer.PlayerGui
	
	-- Create container frame
	local container = Instance.new("Frame")
	container.Name = "AbilityContainer"
	container.Size = UDim2.new(0, 200, 0, 100)
	container.Position = UDim2.new(0.5, -100, 1, -150)
	container.BackgroundTransparency = 1
	container.Parent = self.ScreenGui
	
	-- Create leap indicator
	self.LeapIndicator = self:CreateAbilityIndicator(
		"Leap",
		UDim2.new(0, 0, 0, 0),
		"rbxasset://textures/ui/Jump.png",
		container
	)
	
	-- Create dash indicator
	self.DashIndicator = self:CreateAbilityIndicator(
		"Dash", 
		UDim2.new(0, 110, 0, 0),
		"rbxasset://textures/ui/Movement.png",
		container
	)
	
	-- Create error message label
	self.ErrorLabel = self:CreateErrorLabel()
end

function MobilityUI:CreateAbilityIndicator(name: string, position: UDim2, icon: string, parent: Instance)
	local frame = Instance.new("Frame")
	frame.Name = name .. "Frame"
	frame.Size = UDim2.new(0, 80, 0, 80)
	frame.Position = position
	frame.BackgroundTransparency = 1
	frame.Parent = parent
	
	-- Background circle
	local background = Instance.new("ImageLabel")
	background.Name = "Background"
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
	background.BorderSizePixel = 0
	background.BackgroundTransparency = 0.3
	background.Parent = frame
	
	-- Make it circular
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = background
	
	-- Icon
	local iconLabel = Instance.new("ImageLabel")
	iconLabel.Name = "Icon"
	iconLabel.Size = UDim2.new(0.6, 0, 0.6, 0)
	iconLabel.Position = UDim2.new(0.2, 0, 0.2, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Image = icon
	iconLabel.ImageColor3 = Color3.new(1, 1, 1)
	iconLabel.Parent = frame
	
	-- Cooldown overlay (circular progress)
	local cooldownFrame = Instance.new("Frame")
	cooldownFrame.Name = "CooldownOverlay"
	cooldownFrame.Size = UDim2.new(1, 0, 1, 0)
	cooldownFrame.BackgroundTransparency = 1
	cooldownFrame.Parent = frame
	
	-- Create radial cooldown effect using UIGradient rotation
	local cooldownImage = Instance.new("ImageLabel")
	cooldownImage.Name = "CooldownRing"
	cooldownImage.Size = UDim2.new(1, 0, 1, 0)
	cooldownImage.BackgroundTransparency = 1
	cooldownImage.Image = "rbxasset://textures/ui/Circle.png"
	cooldownImage.ImageColor3 = Color3.new(0.2, 0.2, 0.2)
	cooldownImage.ImageTransparency = 0.5
	cooldownImage.Visible = false
	cooldownImage.Parent = cooldownFrame
	
	-- Charge counter
	local chargeLabel = Instance.new("TextLabel")
	chargeLabel.Name = "ChargeCount"
	chargeLabel.Size = UDim2.new(0, 30, 0, 30)
	chargeLabel.Position = UDim2.new(1, -30, 1, -30)
	chargeLabel.BackgroundColor3 = Color3.new(0, 0, 0)
	chargeLabel.BackgroundTransparency = 0.3
	chargeLabel.Text = "2"
	chargeLabel.TextColor3 = Color3.new(1, 1, 1)
	chargeLabel.TextScaled = true
	chargeLabel.Font = Enum.Font.SourceSansBold
	chargeLabel.Parent = frame
	
	local chargeCorner = Instance.new("UICorner")
	chargeCorner.CornerRadius = UDim.new(0.5, 0)
	chargeCorner.Parent = chargeLabel
	
	-- Keybind label
	local keybindLabel = Instance.new("TextLabel")
	keybindLabel.Name = "Keybind"
	keybindLabel.Size = UDim2.new(0, 80, 0, 20)
	keybindLabel.Position = UDim2.new(0, 0, 1, 5)
	keybindLabel.BackgroundTransparency = 1
	keybindLabel.Text = name == "Leap" and "[SPACE]" or "[Q]"
	keybindLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
	keybindLabel.TextScaled = true
	keybindLabel.Font = Enum.Font.SourceSans
	keybindLabel.Parent = frame
	
	return {
		Frame = frame,
		Background = background,
		Icon = iconLabel,
		CooldownRing = cooldownImage,
		ChargeLabel = chargeLabel,
		KeybindLabel = keybindLabel
	}
end

function MobilityUI:CreateErrorLabel()
	local label = Instance.new("TextLabel")
	label.Name = "ErrorMessage"
	label.Size = UDim2.new(0, 400, 0, 50)
	label.Position = UDim2.new(0.5, -200, 0.5, -25)
	label.BackgroundColor3 = Color3.new(0.8, 0, 0)
	label.BackgroundTransparency = 0.2
	label.Text = ""
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.SourceSansBold
	label.Visible = false
	label.Parent = self.ScreenGui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
	
	return label
end

function MobilityUI:UpdateLeapCooldown(leapState: MobilityTypes.AbilityState)
	if not self.LeapIndicator then return end
	
	-- Update charge count
	self.LeapIndicator.ChargeLabel.Text = tostring(leapState.ChargesRemaining)
	
	-- Update colors based on availability
	if leapState.ChargesRemaining > 0 then
		self.LeapIndicator.Icon.ImageColor3 = Color3.new(0, 1, 0)
		self.LeapIndicator.ChargeLabel.BackgroundColor3 = Color3.new(0, 0.5, 0)
		self.LeapIndicator.CooldownRing.Visible = false
	else
		self.LeapIndicator.Icon.ImageColor3 = Color3.new(0.5, 0.5, 0.5)
		self.LeapIndicator.ChargeLabel.BackgroundColor3 = Color3.new(0.5, 0, 0)
		self.LeapIndicator.CooldownRing.Visible = true
		
		-- Animate cooldown ring
		self:AnimateCooldown(self.LeapIndicator.CooldownRing, MobilityConfig.LeapRechargeRate)
	end
end

function MobilityUI:UpdateDashCooldown(dashState: MobilityTypes.AbilityState)
	if not self.DashIndicator then return end
	
	-- Update charge count (usually 1 for dash)
	self.DashIndicator.ChargeLabel.Text = dashState.IsOnCooldown and "0" or "1"
	
	-- Update colors based on availability
	if not dashState.IsOnCooldown then
		self.DashIndicator.Icon.ImageColor3 = Color3.new(0, 1, 0)
		self.DashIndicator.ChargeLabel.BackgroundColor3 = Color3.new(0, 0.5, 0)
		self.DashIndicator.CooldownRing.Visible = false
	else
		self.DashIndicator.Icon.ImageColor3 = Color3.new(0.5, 0.5, 0.5)
		self.DashIndicator.ChargeLabel.BackgroundColor3 = Color3.new(0.5, 0, 0)
		self.DashIndicator.CooldownRing.Visible = true
		
		-- Animate cooldown ring
		self:AnimateCooldown(self.DashIndicator.CooldownRing, MobilityConfig.DashCooldown)
	end
end

function MobilityUI:AnimateCooldown(ring: ImageLabel, duration: number)
	-- Simple fade animation for now
	-- Could be enhanced with radial progress later
	ring.ImageTransparency = 0.5
	
	local tween = TweenService:Create(
		ring,
		TweenInfo.new(duration, Enum.EasingStyle.Linear),
		{ImageTransparency = 1}
	)
	
	tween:Play()
end

function MobilityUI:ShowError(message: string)
	if not self.ErrorLabel then return end
	
	self.ErrorLabel.Text = message
	self.ErrorLabel.Visible = true
	
	-- Fade in
	self.ErrorLabel.BackgroundTransparency = 1
	local fadeIn = TweenService:Create(
		self.ErrorLabel,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad),
		{BackgroundTransparency = 0.2}
	)
	fadeIn:Play()
	
	-- Auto hide after 2 seconds
	task.wait(2)
	
	-- Fade out
	local fadeOut = TweenService:Create(
		self.ErrorLabel,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad),
		{BackgroundTransparency = 1}
	)
	fadeOut:Play()
	fadeOut.Completed:Connect(function()
		self.ErrorLabel.Visible = false
	end)
end

function MobilityUI:Cleanup()
	if self.ScreenGui then
		self.ScreenGui:Destroy()
		self.ScreenGui = nil
	end
end

return MobilityUI
