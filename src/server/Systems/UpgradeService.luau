--!strict
-- UpgradeService.luau
-- Manages player upgrades and equipment

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local SafeRequire = require(ReplicatedStorage.Shared.SafeRequire)
local SaveService = require(script.Parent:WaitForChild("SaveService"))
local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService"))
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

export type Upgrade = {
	id: string,
	name: string,
	description: string,
	maxLevel: number,
	costPerLevel: {number},
	currency: "crumbs" | "crudeOil",
	upgradeType: string,
	icon: string?,
}

export type UpgradeEffect = {
	type: string,
	value: number,
}

local UpgradeService = {}
UpgradeService.__index = UpgradeService

-- Upgrade definitions
local UPGRADES: {[string]: Upgrade} = {
	-- Heart upgrades
	maxHearts1 = {
		id = "maxHearts1",
		name = "Iron Heart",
		description = "Increases maximum hearts by 1",
		maxLevel = 1,
		costPerLevel = {100},
		currency = "crumbs",
		upgradeType = "maxHearts",
	},
	maxHearts2 = {
		id = "maxHearts2",
		name = "Steel Heart",
		description = "Increases maximum hearts by 1 (requires Iron Heart)",
		maxLevel = 1,
		costPerLevel = {500},
		currency = "crumbs",
		upgradeType = "maxHearts",
	},
	maxHearts3 = {
		id = "maxHearts3",
		name = "Diamond Heart",
		description = "Increases maximum hearts by 2 (requires Steel Heart)",
		maxLevel = 1,
		costPerLevel = {2000},
		currency = "crumbs",
		upgradeType = "maxHearts",
	},
	
	-- Bag upgrades
	bagCapacity1 = {
		id = "bagCapacity1",
		name = "Leather Pouch",
		description = "Increases bag capacity by 4 slots",
		maxLevel = 1,
		costPerLevel = {50},
		currency = "crudeOil",
		upgradeType = "bagCapacity",
	},
	bagCapacity2 = {
		id = "bagCapacity2",
		name = "Traveler's Pack",
		description = "Increases bag capacity by 4 slots (requires Leather Pouch)",
		maxLevel = 1,
		costPerLevel = {150},
		currency = "crudeOil",
		upgradeType = "bagCapacity",
	},
	bagCapacity3 = {
		id = "bagCapacity3",
		name = "Explorer's Satchel",
		description = "Increases bag capacity by 8 slots (requires Traveler's Pack)",
		maxLevel = 1,
		costPerLevel = {500},
		currency = "crudeOil",
		upgradeType = "bagCapacity",
	},
	
	-- Movement upgrades
	moveSpeed1 = {
		id = "moveSpeed1",
		name = "Swift Boots",
		description = "Increases movement speed by 10% in Run state",
		maxLevel = 1,
		costPerLevel = {300},
		currency = "crumbs",
		upgradeType = "moveSpeed",
	},
	
	-- Recall upgrades
	recallSpeed1 = {
		id = "recallSpeed1",
		name = "Quick Recall",
		description = "Reduces recall time by 1 second",
		maxLevel = 1,
		costPerLevel = {200},
		currency = "crumbs",
		upgradeType = "recallSpeed",
	},
	
	-- Luck upgrades
	luckBonus1 = {
		id = "luckBonus1",
		name = "Lucky Charm",
		description = "Increases loot quality by 10%",
		maxLevel = 1,
		costPerLevel = {1000},
		currency = "crumbs",
		upgradeType = "luck",
	},
}

-- Upgrade prerequisites
local PREREQUISITES: {[string]: {string}} = {
	maxHearts2 = {"maxHearts1"},
	maxHearts3 = {"maxHearts2"},
	bagCapacity2 = {"bagCapacity1"},
	bagCapacity3 = {"bagCapacity2"},
}

-- Signals
local upgradeAppliedSignal = Signal.new()

-- Initialize service
function UpgradeService:Init()
	-- Create remote for client requests
	local remoteFunction = Instance.new("RemoteFunction")
	remoteFunction.Name = "UpgradeRemote"
	remoteFunction.Parent = ReplicatedStorage
	
	remoteFunction.OnServerInvoke = function(player: Player, action: string, upgradeId: string?)
		if action == "GetUpgrades" then
			return self:GetPlayerUpgrades(player)
		elseif action == "GetAvailable" then
			return self:GetAvailableUpgrades(player)
		elseif action == "Purchase" and upgradeId then
			return self:PurchaseUpgrade(player, upgradeId)
		elseif action == "GetStats" then
			return self:GetPlayerStats(player)
		end
		return false, "INVALID_ACTION"
	end
	
	print("[UpgradeService] Initialized")
end

-- Get player upgrades
function UpgradeService:GetPlayerUpgrades(player: Player): {[string]: number}
	local profile = SaveService:GetProfile(player)
	if not profile then
		return {}
	end
	
	local upgrades = profile.Data.upgrades or {}
	local result = {}
	
	-- Convert to simple format
	for upgradeId, level in pairs(upgrades) do
		if type(level) == "number" and level > 0 then
			result[upgradeId] = level
		end
	end
	
	return result
end

-- Check prerequisites
function UpgradeService:CheckPrerequisites(player: Player, upgradeId: string): boolean
	local prereqs = PREREQUISITES[upgradeId]
	if not prereqs then
		return true
	end
	
	local playerUpgrades = self:GetPlayerUpgrades(player)
	
	for _, prereqId in ipairs(prereqs) do
		local prereqUpgrade = UPGRADES[prereqId]
		if not prereqUpgrade then continue end
		
		local level = playerUpgrades[prereqId] or 0
		if level < prereqUpgrade.maxLevel then
			return false
		end
	end
	
	return true
end

-- Get available upgrades
function UpgradeService:GetAvailableUpgrades(player: Player): {Upgrade}
	local playerUpgrades = self:GetPlayerUpgrades(player)
	local available = {}
	
	for upgradeId, upgrade in pairs(UPGRADES) do
		local currentLevel = playerUpgrades[upgradeId] or 0
		
		-- Check if not maxed
		if currentLevel >= upgrade.maxLevel then
			continue
		end
		
		-- Check prerequisites
		if not self:CheckPrerequisites(player, upgradeId) then
			continue
		end
		
		table.insert(available, upgrade)
	end
	
	return available
end

-- Purchase upgrade
function UpgradeService:PurchaseUpgrade(player: Player, upgradeId: string): (boolean, string?)
	local upgrade = UPGRADES[upgradeId]
	if not upgrade then
		return false, "INVALID_UPGRADE"
	end
	
	local profile = SaveService:GetProfile(player)
	if not profile then
		return false, "NO_PROFILE"
	end
	
	-- Check current level
	local currentLevel = (profile.Data.upgrades and profile.Data.upgrades[upgradeId]) or 0
	if currentLevel >= upgrade.maxLevel then
		return false, "MAX_LEVEL"
	end
	
	-- Check prerequisites
	if not self:CheckPrerequisites(player, upgradeId) then
		return false, "MISSING_PREREQUISITES"
	end
	
	-- Calculate cost
	local nextLevel = currentLevel + 1
	local cost = upgrade.costPerLevel[nextLevel]
	if not cost then
		return false, "INVALID_LEVEL"
	end
	
	-- Check currency
	local currency = upgrade.currency
	local balance = 0
	
	if currency == "crumbs" then
		balance = profile.Data.balances and profile.Data.balances.crumbs or 0
	elseif currency == "crudeOil" then
		balance = profile.Data.crudeOil or 0
	else
		return false, "INVALID_CURRENCY"
	end
	
	if balance < cost then
		return false, "INSUFFICIENT_FUNDS"
	end
	
	-- Deduct cost
	if currency == "crumbs" then
		profile.Data.balances.crumbs = balance - cost
	elseif currency == "crudeOil" then
		profile.Data.crudeOil = balance - cost
	end
	
	-- Apply upgrade
	profile.Data.upgrades = profile.Data.upgrades or {}
	profile.Data.upgrades[upgradeId] = nextLevel
	
	-- Apply effects
	self:ApplyUpgradeEffects(player, upgradeId, nextLevel)
	
	-- Fire signal
	upgradeAppliedSignal:Fire(player, upgradeId, nextLevel)
	
	-- Save profile
	SaveService:SaveProfile(player)
	
	print(string.format("[UpgradeService] %s purchased %s level %d", player.Name, upgradeId, nextLevel))
	
	return true, upgradeId
end

-- Apply upgrade effects
function UpgradeService:ApplyUpgradeEffects(player: Player, upgradeId: string, level: number)
	local upgrade = UPGRADES[upgradeId]
	if not upgrade then return end
	
	local profile = SaveService:GetProfile(player)
	if not profile then return end
	
	-- Handle different upgrade types
	if upgrade.upgradeType == "maxHearts" then
		-- Calculate total heart upgrades
		local totalBonus = 0
		if profile.Data.upgrades.maxHearts1 then totalBonus = totalBonus + 1 end
		if profile.Data.upgrades.maxHearts2 then totalBonus = totalBonus + 1 end
		if profile.Data.upgrades.maxHearts3 then totalBonus = totalBonus + 2 end
		
		-- Update max hearts
		local baseHearts = 3
		profile.Data.maxHearts = baseHearts + totalBonus
		
		-- Heal to new max if current is at old max
		local stateManager = PlayerStateService:GetPlayerStateManager(player)
		if stateManager and stateManager.hearts == stateManager.maxHearts then
			PlayerStateService:HealPlayer(player, totalBonus)
		end
		
		-- Update state manager
		if stateManager then
			stateManager.maxHearts = profile.Data.maxHearts
			PlayerStateService:UpdateClientHearts(player, stateManager.hearts, stateManager.maxHearts)
		end
		
	elseif upgrade.upgradeType == "bagCapacity" then
		-- Bag capacity is checked dynamically by PlayerStateService
		-- No immediate effect needed
		
	elseif upgrade.upgradeType == "moveSpeed" then
		-- Apply movement speed bonus
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChild("Humanoid")
			if humanoid then
				-- Store original speed if not stored
				if not humanoid:GetAttribute("BaseWalkSpeed") then
					humanoid:SetAttribute("BaseWalkSpeed", humanoid.WalkSpeed)
				end
				
				local baseSpeed = humanoid:GetAttribute("BaseWalkSpeed") or 16
				humanoid.WalkSpeed = baseSpeed * 1.1 -- 10% increase
			end
		end
	end
end

-- Get player stats (for UI)
function UpgradeService:GetPlayerStats(player: Player): {[string]: any}
	local profile = SaveService:GetProfile(player)
	if not profile then
		return {}
	end
	
	local stateManager = PlayerStateService:GetPlayerStateManager(player)
	
	return {
		hearts = stateManager and stateManager.hearts or profile.Data.hearts or 3,
		maxHearts = stateManager and stateManager.maxHearts or profile.Data.maxHearts or 3,
		bagSlots = PlayerStateService:GetBagSlots(player),
		crudeOil = profile.Data.crudeOil or 0,
		crumbs = (profile.Data.balances and profile.Data.balances.crumbs) or 0,
		upgrades = self:GetPlayerUpgrades(player),
		luckBonus = self:GetLuckBonus(player),
		recallSpeed = self:GetRecallSpeed(player),
		moveSpeedMultiplier = self:GetMoveSpeedMultiplier(player),
	}
end

-- Get luck bonus
function UpgradeService:GetLuckBonus(player: Player): number
	local upgrades = self:GetPlayerUpgrades(player)
	local bonus = 0
	
	if upgrades.luckBonus1 then
		bonus = bonus + 0.1
	end
	
	return bonus
end

-- Get recall speed reduction
function UpgradeService:GetRecallSpeed(player: Player): number
	local upgrades = self:GetPlayerUpgrades(player)
	local reduction = 0
	
	if upgrades.recallSpeed1 then
		reduction = reduction + 1 -- 1 second reduction
	end
	
	return reduction
end

-- Get movement speed multiplier
function UpgradeService:GetMoveSpeedMultiplier(player: Player): number
	local upgrades = self:GetPlayerUpgrades(player)
	local multiplier = 1.0
	
	if upgrades.moveSpeed1 then
		multiplier = multiplier * 1.1
	end
	
	return multiplier
end

-- Get upgrade applied signal
function UpgradeService:GetUpgradeAppliedSignal()
	return upgradeAppliedSignal
end

return UpgradeService
