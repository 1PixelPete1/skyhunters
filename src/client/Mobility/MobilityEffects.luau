--[[
	MobilityEffects.luau
	Visual effects for mobility abilities
	Handles particles, trails, and gust effects
]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local MobilityConfig = require(game.ReplicatedStorage.Shared.Mobility.MobilityConfig)

local MobilityEffects = {}
MobilityEffects.__index = MobilityEffects

function MobilityEffects.new()
	local self = setmetatable({}, MobilityEffects)
	self.ActiveEffects = {}
	return self
end

function MobilityEffects:PlayLeapEffect(position: Vector3, direction: Vector3)
	-- Create gust particles going downward
	self:CreateGustEffect(position, direction, "Leap")
	
	-- Create expanding ring effect
	self:CreateRingEffect(position)
	
	-- Play sound
	self:PlaySound(position, "rbxasset://sounds/swoosh.wav", 0.8)
end

function MobilityEffects:PlayDashEffect(position: Vector3, direction: Vector3)
	-- Create directional gust
	self:CreateGustEffect(position, direction, "Dash")
	
	-- Create speed lines
	self:CreateSpeedLines(position, -direction)
	
	-- Play sound
	self:PlaySound(position, "rbxasset://sounds/swoosh.wav", 1.2)
end

function MobilityEffects:CreateGustEffect(position: Vector3, direction: Vector3, effectType: string)
	local attachment = Instance.new("Attachment")
	attachment.Position = position
	attachment.Parent = workspace.Terrain
	
	local particleEmitter = Instance.new("ParticleEmitter")
	particleEmitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	particleEmitter.Rate = 0
	particleEmitter.Lifetime = NumberRange.new(0.5, 1)
	particleEmitter.VelocityInheritance = 0
	
	-- Configure based on effect type
	if effectType == "Leap" then
		particleEmitter.Speed = NumberRange.new(20, 40)
		particleEmitter.SpreadAngle = Vector2.new(30, 30)
		particleEmitter.Color = ColorSequence.new(Color3.new(0.9, 0.9, 0.9))
		particleEmitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 2),
			NumberSequenceKeypoint.new(1, 0)
		})
	else -- Dash
		particleEmitter.Speed = NumberRange.new(40, 60)
		particleEmitter.SpreadAngle = Vector2.new(15, 15)
		particleEmitter.Color = ColorSequence.new(Color3.new(0.8, 0.9, 1))
		particleEmitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(0.5, 1.5),
			NumberSequenceKeypoint.new(1, 0)
		})
	end
	
	particleEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 0.7),
		NumberSequenceKeypoint.new(1, 1)
	})
	
	particleEmitter.Acceleration = Vector3.new(0, -10, 0)
	particleEmitter.EmissionDirection = Enum.NormalId.Front
	
	-- Set direction
	attachment.CFrame = CFrame.lookAt(position, position + direction)
	particleEmitter.Parent = attachment
	
	-- Emit particles
	particleEmitter:Emit(MobilityConfig.GustParticleCount)
	
	-- Cleanup
	Debris:AddItem(attachment, 2)
end

function MobilityEffects:CreateRingEffect(position: Vector3)
	local part = Instance.new("Part")
	part.Name = "LeapRing"
	part.Size = Vector3.new(4, 0.2, 4)
	part.Material = Enum.Material.ForceField
	part.BrickColor = BrickColor.new("Cyan")
	part.Transparency = 0.5
	part.CanCollide = false
	part.Anchored = true
	part.Position = position
	part.Parent = workspace
	
	-- Create mesh for ring shape
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Cylinder
	mesh.Scale = Vector3.new(1, 0.1, 1)
	mesh.Parent = part
	
	-- Expand and fade
	local expandTween = TweenService:Create(
		mesh,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Scale = Vector3.new(3, 0.1, 3)}
	)
	
	local fadeTween = TweenService:Create(
		part,
		TweenInfo.new(0.5, Enum.EasingStyle.Linear),
		{Transparency = 1}
	)
	
	expandTween:Play()
	fadeTween:Play()
	
	Debris:AddItem(part, 1)
end

function MobilityEffects:CreateSpeedLines(position: Vector3, direction: Vector3)
	local lineCount = 5
	local spread = 3
	
	for i = 1, lineCount do
		local offset = Vector3.new(
			(math.random() - 0.5) * spread,
			(math.random() - 0.5) * spread,
			0
		)
		
		local startPos = position + offset
		local endPos = startPos + (direction * 10)
		
		local line = Instance.new("Part")
		line.Name = "SpeedLine"
		line.Size = Vector3.new(0.2, 0.2, 10)
		line.Material = Enum.Material.Neon
		line.BrickColor = BrickColor.new("White")
		line.Transparency = 0.3
		line.CanCollide = false
		line.Anchored = true
		line.CFrame = CFrame.lookAt(startPos, endPos) * CFrame.new(0, 0, -5)
		line.Parent = workspace
		
		-- Fade out
		local fadeTween = TweenService:Create(
			line,
			TweenInfo.new(0.3, Enum.EasingStyle.Linear),
			{
				Transparency = 1,
				Size = Vector3.new(0.1, 0.1, 15)
			}
		)
		fadeTween:Play()
		
		Debris:AddItem(line, 0.5)
	end
end

function MobilityEffects:PlayEffect(effectData: any)
	if effectData.Type == "Gust" then
		if effectData.Power > 50 then
			self:PlayLeapEffect(effectData.Position, effectData.Direction)
		else
			self:PlayDashEffect(effectData.Position, effectData.Direction)
		end
	end
end

function MobilityEffects:PlaySound(position: Vector3, soundId: string, pitch: number?)
	local part = Instance.new("Part")
	part.Transparency = 1
	part.CanCollide = false
	part.Anchored = true
	part.Position = position
	part.Parent = workspace
	
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = 0.5
	sound.Pitch = pitch or 1
	sound.Parent = part
	
	sound:Play()
	
	sound.Ended:Connect(function()
		part:Destroy()
	end)
	
	Debris:AddItem(part, 5)
end

function MobilityEffects:Cleanup()
	for _, effect in pairs(self.ActiveEffects) do
		if effect then
			effect:Destroy()
		end
	end
	self.ActiveEffects = {}
end

return MobilityEffects
