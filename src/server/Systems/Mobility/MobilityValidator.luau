--[[
	MobilityValidator.luau
	Server-side movement validation and anti-cheat
	Ensures legitimate movement and prevents exploits
]]

local MobilityConfig = require(game.ReplicatedStorage.Shared.Mobility.MobilityConfig)

local MobilityValidator = {}
MobilityValidator.__index = MobilityValidator

export type ValidationResult = {
	IsValid: boolean,
	Reason: string?,
	CorrectPosition: Vector3?
}

function MobilityValidator.new()
	local self = setmetatable({}, MobilityValidator)
	self.PlayerHistory = {} -- Track movement history per player
	return self
end

-- Validate ability-specific movement (more lenient)
function MobilityValidator:ValidateAbilityMovement(
	player: Player, 
	startPos: Vector3, 
	endPos: Vector3, 
	abilityType: string
): ValidationResult
	
	-- Calculate movement metrics
	local distance = (endPos - startPos).Magnitude
	local maxAllowedDistance = self:GetMaxAbilityDistance(abilityType)
	
	-- Be more lenient with ability movement validation
	-- Allow 2x the expected distance to account for terrain and physics variations
	if distance > maxAllowedDistance * 2 then
		return {
			IsValid = false,
			Reason = string.format("Movement too far: %d > %d", distance, maxAllowedDistance * 2),
			CorrectPosition = startPos
		}
	end
	
	-- Skip wall-phase check for abilities as they might go over obstacles
	-- This prevents false positives on uneven terrain
	
	-- Check extreme vertical limits (prevent infinite jumping)
	local verticalChange = endPos.Y - startPos.Y
	if abilityType == "Leap" and verticalChange > MobilityConfig.LeapPower * 3 then
		return {
			IsValid = false,
			Reason = "Excessive vertical movement",
			CorrectPosition = Vector3.new(endPos.X, startPos.Y + MobilityConfig.LeapPower * 2, endPos.Z)
		}
	end
	
	-- Update player history
	if not self.PlayerHistory[player] then
		self.PlayerHistory[player] = {}
	end
	
	table.insert(self.PlayerHistory[player], {
		Position = endPos,
		Time = tick(),
		Ability = abilityType
	})
	
	-- Cleanup old history (keep last 10 seconds)
	self:CleanupHistory(player)
	
	-- Only check for extreme speed hacking patterns
	if self:DetectExtremeSpeedHack(player) then
		return {
			IsValid = false,
			Reason = "Extreme movement pattern detected",
			CorrectPosition = startPos
		}
	end
	
	return {
		IsValid = true,
		Reason = nil,
		CorrectPosition = nil
	}
end

-- Validate normal movement (not used anymore, but kept for reference)
function MobilityValidator:ValidateMovement(
	player: Player, 
	startPos: Vector3, 
	endPos: Vector3, 
	abilityType: string
): ValidationResult
	
	-- Calculate movement metrics
	local distance = (endPos - startPos).Magnitude
	local maxAllowedDistance = self:GetMaxDistance(abilityType)
	
	-- Check if movement is within allowed range
	if distance > maxAllowedDistance then
		return {
			IsValid = false,
			Reason = string.format("Movement too far: %d > %d", distance, maxAllowedDistance),
			CorrectPosition = startPos
		}
	end
	
	-- Check for noclip/wall phasing
	local raycast = workspace:Raycast(startPos, endPos - startPos)
	if raycast and raycast.Instance and not raycast.Instance:IsDescendantOf(player.Character) then
		-- Potential wall phase detected
		return {
			IsValid = false,
			Reason = "Movement through solid object detected",
			CorrectPosition = startPos
		}
	end
	
	-- Check vertical limits (prevent infinite jumping)
	local verticalChange = endPos.Y - startPos.Y
	if abilityType == "Leap" and verticalChange > MobilityConfig.LeapPower * 2 then
		return {
			IsValid = false,
			Reason = "Excessive vertical movement",
			CorrectPosition = Vector3.new(endPos.X, startPos.Y + MobilityConfig.LeapPower, endPos.Z)
		}
	end
	
	-- Update player history
	if not self.PlayerHistory[player] then
		self.PlayerHistory[player] = {}
	end
	
	table.insert(self.PlayerHistory[player], {
		Position = endPos,
		Time = tick(),
		Ability = abilityType
	})
	
	-- Cleanup old history (keep last 10 seconds)
	self:CleanupHistory(player)
	
	-- Check for speed hacking patterns
	if self:DetectSpeedHack(player) then
		return {
			IsValid = false,
			Reason = "Abnormal movement pattern detected",
			CorrectPosition = startPos
		}
	end
	
	return {
		IsValid = true,
		Reason = nil,
		CorrectPosition = nil
	}
end

function MobilityValidator:GetMaxAbilityDistance(abilityType: string): number
	if abilityType == "Leap" then
		-- Leap allows both vertical and horizontal movement
		-- Be generous to account for physics and terrain
		return (MobilityConfig.LeapPower + MobilityConfig.LeapHorizontalBoost) * 2
	elseif abilityType == "Dash" then
		-- Dash is primarily horizontal
		return MobilityConfig.DashDistance * 2.5 -- Very generous margin
	else
		-- Normal movement
		return 30 -- Increased from 20 for terrain tolerance
	end
end

function MobilityValidator:GetMaxDistance(abilityType: string): number
	if abilityType == "Leap" then
		-- Leap allows both vertical and horizontal movement
		return MobilityConfig.LeapPower + MobilityConfig.LeapHorizontalBoost
	elseif abilityType == "Dash" then
		-- Dash is primarily horizontal
		return MobilityConfig.DashDistance * 1.5 -- Allow some margin
	else
		-- Normal movement
		return 20 -- Max walking distance per validation
	end
end

function MobilityValidator:DetectExtremeSpeedHack(player: Player): boolean
	local history = self.PlayerHistory[player]
	if not history or #history < 3 then
		return false
	end
	
	-- Check recent movement speeds
	local suspiciousCount = 0
	local currentTime = tick()
	
	for i = #history - 1, math.max(1, #history - 5), -1 do
		local prev = history[i]
		local curr = history[i + 1]
		
		local deltaTime = curr.Time - prev.Time
		if deltaTime <= 0 then continue end
		
		local distance = (curr.Position - prev.Position).Magnitude
		local speed = distance / deltaTime
		
		-- Check if speed is extremely high (only flag extreme violations)
		local maxSpeed = 100 -- Increased base movement speed tolerance
		if curr.Ability == "Leap" or curr.Ability == "Dash" then
			maxSpeed = 400 -- Very high tolerance for abilities
		end
		
		if speed > maxSpeed then
			suspiciousCount = suspiciousCount + 1
		end
	end
	
	-- Only flag if multiple extreme violations
	return suspiciousCount >= 5  -- Increased from 3 for more tolerance
end

function MobilityValidator:DetectSpeedHack(player: Player): boolean
	local history = self.PlayerHistory[player]
	if not history or #history < 3 then
		return false
	end
	
	-- Check recent movement speeds
	local suspiciousCount = 0
	local currentTime = tick()
	
	for i = #history - 1, math.max(1, #history - 5), -1 do
		local prev = history[i]
		local curr = history[i + 1]
		
		local deltaTime = curr.Time - prev.Time
		if deltaTime <= 0 then continue end
		
		local distance = (curr.Position - prev.Position).Magnitude
		local speed = distance / deltaTime
		
		-- Check if speed is suspiciously high
		local maxSpeed = 50 -- Base movement speed
		if curr.Ability == "Leap" or curr.Ability == "Dash" then
			maxSpeed = 200 -- Allow higher speed during abilities
		end
		
		if speed > maxSpeed then
			suspiciousCount = suspiciousCount + 1
		end
	end
	
	-- Flag if multiple suspicious movements
	return suspiciousCount >= 3
end

function MobilityValidator:CleanupHistory(player: Player)
	local history = self.PlayerHistory[player]
	if not history then return end
	
	local currentTime = tick()
	local cleanedHistory = {}
	
	for _, entry in ipairs(history) do
		if currentTime - entry.Time < 10 then
			table.insert(cleanedHistory, entry)
		end
	end
	
	self.PlayerHistory[player] = cleanedHistory
end

function MobilityValidator:ValidatePosition(player: Player, position: Vector3): boolean
	-- Check if position is within world bounds
	local maxCoordinate = 10000
	if math.abs(position.X) > maxCoordinate or 
	   math.abs(position.Y) > maxCoordinate or 
	   math.abs(position.Z) > maxCoordinate then
		return false
	end
	
	-- Check if position is above the void
	if position.Y < -500 then
		return false
	end
	
	return true
end

function MobilityValidator:OnPlayerRemoving(player: Player)
	self.PlayerHistory[player] = nil
end

return MobilityValidator
