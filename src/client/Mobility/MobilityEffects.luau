--[[
	MobilityEffects.luau
	Visual effects for mobility abilities with pooled instances
]]

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local MobilityConfig = require(game.ReplicatedStorage.Shared.Mobility.MobilityConfig)

local MobilityEffects = {}
MobilityEffects.__index = MobilityEffects

local RING_TWEEN_TIME = 0.5
local SPEED_LINE_LIFETIME = 0.3
local GUST_RELEASE_DELAY = 0.75
local SOUND_RELEASE_DELAY = 5

function MobilityEffects.new()
	local self = setmetatable({}, MobilityEffects)

	self.random = Random.new()

	self.poolFolder = Instance.new("Folder")
	self.poolFolder.Name = "MobilityEffectsPool"
	self.poolFolder.Parent = Workspace

	self.anchorPart = Instance.new("Part")
	self.anchorPart.Name = "MobilityEffectsAnchor"
	self.anchorPart.Anchored = true
	self.anchorPart.CanCollide = false
	self.anchorPart.CanQuery = false
	self.anchorPart.CanTouch = false
	self.anchorPart.Transparency = 1
	self.anchorPart.Size = Vector3.new(0.1, 0.1, 0.1)
	self.anchorPart.Parent = Workspace

	self.gustPool = {}
	self.activeGust = {}
	self.ringPool = {}
	self.activeRings = {}
	self.speedLinePool = {}
	self.activeSpeedLines = {}
	self.soundPool = {}
	self.activeSounds = {}

	self:prefillPools()

	return self
end

function MobilityEffects:prefillPools()
	for _ = 1, 6 do
		self:returnGustEmitter(self:createGustEmitter())
	end

	for _ = 1, 4 do
		self:returnRing(self:createRing())
	end

	for _ = 1, 12 do
		self:returnSpeedLine(self:createSpeedLine())
	end

	for _ = 1, 4 do
		self:returnSound(self:createSoundSource())
	end
end

function MobilityEffects:createGustEmitter()
	local attachment = Instance.new("Attachment")
	attachment.Name = "MobilityGustAttachment"
	attachment.Parent = self.anchorPart

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.VelocityInheritance = 0
	emitter.Acceleration = Vector3.new(0, -10, 0)
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Parent = attachment

	local entry = {
		attachment = attachment,
		emitter = emitter,
		inPool = false,
	}

	return entry
end

function MobilityEffects:createRing()
	local part = Instance.new("Part")
	part.Name = "MobilityLeapRing"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Material = Enum.Material.ForceField
	part.Parent = self.poolFolder

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Cylinder
	mesh.Scale = Vector3.new(1, 0.1, 1)
	mesh.Parent = part

	local entry = {
		part = part,
		mesh = mesh,
		expandTween = nil,
		fadeTween = nil,
		inPool = false,
	}

	return entry
end

function MobilityEffects:createSpeedLine()
	local part = Instance.new("Part")
	part.Name = "MobilitySpeedLine"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.new(1, 1, 1)
	part.Transparency = 1
	part.CastShadow = false
	part.Size = Vector3.new(0.2, 0.2, 10)
	part.Parent = self.poolFolder

	local entry = {
		part = part,
		inPool = false,
	}

	return entry
end

function MobilityEffects:createSoundSource()
	local part = Instance.new("Part")
	part.Name = "MobilitySoundAnchor"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Parent = self.poolFolder

	local sound = Instance.new("Sound")
	sound.Volume = 0.5
	sound.PlaybackSpeed = 1
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.Parent = part

	local entry = {
		part = part,
		sound = sound,
		connection = nil,
		inPool = false,
	}

	return entry
end

function MobilityEffects:acquireFromPool(pool, createFn, activeSet)
	local entry = table.remove(pool)
	if not entry then
		entry = createFn(self)
	else
		entry.inPool = false
	end
	if activeSet then
		activeSet[entry] = true
	end
	return entry
end

function MobilityEffects:returnToPool(pool, entry, activeSet, resetFn)
	if entry.inPool then
		return
	end
	entry.inPool = true
	if activeSet then
		activeSet[entry] = nil
	end
	if resetFn then
		resetFn(entry)
	end
	pool[#pool + 1] = entry
end

function MobilityEffects:acquireGustEmitter()
	return self:acquireFromPool(self.gustPool, MobilityEffects.createGustEmitter, self.activeGust)
end

function MobilityEffects:returnGustEmitter(entry)
	self:returnToPool(self.gustPool, entry, self.activeGust, function(item)
		item.attachment.Parent = self.anchorPart
		item.attachment.CFrame = CFrame.new()
		item.emitter.Speed = NumberRange.new(0, 0)
		item.emitter.SpreadAngle = Vector2.new()
		item.emitter.Color = ColorSequence.new(Color3.new(1, 1, 1))
		item.emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		item.emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
	end)
end

function MobilityEffects:acquireRing()
	return self:acquireFromPool(self.ringPool, MobilityEffects.createRing, self.activeRings)
end

function MobilityEffects:returnRing(entry)
	self:returnToPool(self.ringPool, entry, self.activeRings, function(item)
		if item.expandTween then
			item.expandTween:Cancel()
			item.expandTween = nil
		end
		if item.fadeTween then
			item.fadeTween:Cancel()
			item.fadeTween = nil
		end
		item.part.Transparency = 1
		item.mesh.Scale = Vector3.new(1, 0.1, 1)
		item.part.Parent = self.poolFolder
	end)
end

function MobilityEffects:acquireSpeedLine()
	return self:acquireFromPool(self.speedLinePool, MobilityEffects.createSpeedLine, self.activeSpeedLines)
end

function MobilityEffects:returnSpeedLine(entry)
	self:returnToPool(self.speedLinePool, entry, self.activeSpeedLines, function(item)
		item.part.Transparency = 1
		item.part.Size = Vector3.new(0.2, 0.2, 10)
		item.part.Parent = self.poolFolder
	end)
end

function MobilityEffects:acquireSound()
	return self:acquireFromPool(self.soundPool, MobilityEffects.createSoundSource, self.activeSounds)
end

function MobilityEffects:returnSound(entry)
	self:returnToPool(self.soundPool, entry, self.activeSounds, function(item)
		if item.connection then
			item.connection:Disconnect()
			item.connection = nil
		end
		item.sound:Stop()
		item.part.Parent = self.poolFolder
	end)
end

local function configureGust(emitter: ParticleEmitter, effectType: string)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})

	if effectType == "Leap" then
		emitter.Speed = NumberRange.new(20, 40)
		emitter.SpreadAngle = Vector2.new(30, 30)
		emitter.Color = ColorSequence.new(Color3.new(0.9, 0.9, 0.9))
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 2),
			NumberSequenceKeypoint.new(1, 0),
		})
	else
		emitter.Speed = NumberRange.new(40, 60)
		emitter.SpreadAngle = Vector2.new(15, 15)
		emitter.Color = ColorSequence.new(Color3.new(0.8, 0.9, 1))
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(0.5, 1.5),
			NumberSequenceKeypoint.new(1, 0),
		})
	end
end

function MobilityEffects:playGustEffect(position: Vector3, direction: Vector3, effectType: string)
	local entry = self:acquireGustEmitter()
	local attachment = entry.attachment
	local emitter = entry.emitter

	local lookDirection = direction.Magnitude > 0 and direction.Unit or Vector3.new(0, -1, 0)
	attachment.WorldCFrame = CFrame.lookAt(position, position + lookDirection)

	configureGust(emitter, effectType)
	emitter:Emit(MobilityConfig.GustParticleCount)

	task.delay(GUST_RELEASE_DELAY, function()
		self:returnGustEmitter(entry)
	end)
end

function MobilityEffects:playRingEffect(position: Vector3)
	local entry = self:acquireRing()
	local part = entry.part
	local mesh = entry.mesh

	part.Parent = Workspace
	part.CFrame = CFrame.new(position)
	part.Transparency = 0.5
	mesh.Scale = Vector3.new(1, 0.1, 1)

	local expandTween = TweenService:Create(
		mesh,
		TweenInfo.new(RING_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Scale = Vector3.new(3, 0.1, 3)}
	)

	local fadeTween = TweenService:Create(
		part,
		TweenInfo.new(RING_TWEEN_TIME, Enum.EasingStyle.Linear),
		{Transparency = 1}
	)

	entry.expandTween = expandTween
	entry.fadeTween = fadeTween

	local released = false
	local function ensureRelease()
		if released then
			return
		end
		released = true
		self:returnRing(entry)
	end

	expandTween.Completed:Connect(ensureRelease)
	fadeTween.Completed:Connect(ensureRelease)

	expandTween:Play()
	fadeTween:Play()

	task.delay(RING_TWEEN_TIME + 0.1, ensureRelease)
end

function MobilityEffects:playSpeedLines(position: Vector3, direction: Vector3)
	local lineCount = 5
	local spread = 3
	local dashDuration = math.max(MobilityConfig.DashDuration, SPEED_LINE_LIFETIME)

	local forward = direction.Magnitude > 0 and direction.Unit or Vector3.new(0, 0, -1)

	for _ = 1, lineCount do
		local entry = self:acquireSpeedLine()
		local part = entry.part

		local offset = Vector3.new(
			(self.random:NextNumber() - 0.5) * spread,
			(self.random:NextNumber() - 0.5) * spread,
			0
		)
		local startPos = position + offset
		local endPos = startPos + (forward * 10)

		part.Parent = Workspace
		part.Size = Vector3.new(0.2, 0.2, 10)
		part.CFrame = CFrame.lookAt(startPos, endPos) * CFrame.new(0, 0, -5)
		part.Transparency = 0.3

		local fadeTween = TweenService:Create(
			part,
			TweenInfo.new(dashDuration, Enum.EasingStyle.Linear),
			{
				Transparency = 1,
				Size = Vector3.new(0.1, 0.1, 15),
			}
		)

		fadeTween:Play()

		task.delay(dashDuration, function()
			fadeTween:Cancel()
			self:returnSpeedLine(entry)
		end)
	end
end

function MobilityEffects:playSound(position: Vector3, soundId: string, pitch: number?)
	local entry = self:acquireSound()
	local part = entry.part
	local sound = entry.sound

	part.Parent = Workspace
	part.CFrame = CFrame.new(position)

	sound.SoundId = soundId
	sound.PlaybackSpeed = pitch or 1
	sound.TimePosition = 0
	sound:Play()

	if entry.connection then
		entry.connection:Disconnect()
	end

	entry.connection = sound.Ended:Connect(function()
		self:returnSound(entry)
	end)

	task.delay(SOUND_RELEASE_DELAY, function()
		self:returnSound(entry)
	end)
end

function MobilityEffects:PlayLeapEffect(position: Vector3, direction: Vector3)
	self:playGustEffect(position, direction, "Leap")
	self:playRingEffect(position)
	self:playSound(position, "rbxasset://sounds/swoosh.wav", 0.8)
end

function MobilityEffects:PlayDashEffect(position: Vector3, direction: Vector3)
	self:playGustEffect(position, direction, "Dash")
	self:playSpeedLines(position, -direction)
	self:playSound(position, "rbxasset://sounds/swoosh.wav", 1.2)
end

function MobilityEffects:PlayEffect(effectData)
	if effectData.Type == "Gust" then
		if effectData.Power > 50 then
			self:PlayLeapEffect(effectData.Position, effectData.Direction)
		else
			self:PlayDashEffect(effectData.Position, effectData.Direction)
		end
	end
end

function MobilityEffects:Cleanup()
	for entry in pairs(self.activeGust) do
		entry.attachment:Destroy()
	end
	for _, entry in ipairs(self.gustPool) do
		entry.attachment:Destroy()
	end
	self.gustPool = {}
	self.activeGust = {}

	for entry in pairs(self.activeRings) do
		entry.part:Destroy()
	end
	for _, entry in ipairs(self.ringPool) do
		entry.part:Destroy()
	end
	self.ringPool = {}
	self.activeRings = {}

	for entry in pairs(self.activeSpeedLines) do
		entry.part:Destroy()
	end
	for _, entry in ipairs(self.speedLinePool) do
		entry.part:Destroy()
	end
	self.speedLinePool = {}
	self.activeSpeedLines = {}

	for entry in pairs(self.activeSounds) do
		if entry.connection then
			entry.connection:Disconnect()
		end
		entry.part:Destroy()
	end
	for _, entry in ipairs(self.soundPool) do
		if entry.connection then
			entry.connection:Disconnect()
		end
		entry.part:Destroy()
	end
	self.soundPool = {}
	self.activeSounds = {}

	if self.poolFolder then
		self.poolFolder:Destroy()
		self.poolFolder = nil
	end

	if self.anchorPart then
		self.anchorPart:Destroy()
		self.anchorPart = nil
	end
end

return MobilityEffects

