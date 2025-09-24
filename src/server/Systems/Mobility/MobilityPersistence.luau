--[[
	MobilityPersistence.luau
	Handles saving and loading of mobility upgrades and stats
	Integrates with the existing SaveService pattern
]]

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local MobilityPersistence = {}
MobilityPersistence.__index = MobilityPersistence

local DATASTORE_NAME = "MobilityData_v1"
local DATASTORE_SCOPE = "PlayerUpgrades"

export type MobilityUpgrades = {
	LeapLevel: number,
	DashLevel: number,
	LeapCharges: number,
	CooldownReduction: number,
	PowerBoost: number,
	TotalLeaps: number,
	TotalDashes: number,
	LastSaved: number
}

function MobilityPersistence.new()
	local self = setmetatable({}, MobilityPersistence)
	
	-- Only use DataStore in production
	if RunService:IsStudio() then
		self.DataStore = nil
		self.Cache = {} -- Use memory cache in Studio
		warn("[MobilityPersistence] Running in Studio - using memory cache")
	else
		self.DataStore = DataStoreService:GetDataStore(DATASTORE_NAME, DATASTORE_SCOPE)
	end
	
	return self
end

function MobilityPersistence:LoadPlayerUpgrades(player: Player): MobilityUpgrades?
	local key = tostring(player.UserId)
	
	-- Studio mode - return from cache
	if not self.DataStore then
		return self.Cache[key] or self:GetDefaultUpgrades()
	end
	
	-- Production mode - load from DataStore
	local success, result = pcall(function()
		return self.DataStore:GetAsync(key)
	end)
	
	if success and result then
		-- Migrate old data if necessary
		return self:MigrateData(result)
	elseif not success then
		warn(string.format("[MobilityPersistence] Failed to load data for %s: %s", player.Name, tostring(result)))
	end
	
	return self:GetDefaultUpgrades()
end

function MobilityPersistence:SavePlayerUpgrades(player: Player, upgrades: MobilityUpgrades)
	local key = tostring(player.UserId)
	
	-- Add timestamp
	upgrades.LastSaved = os.time()
	
	-- Studio mode - save to cache
	if not self.DataStore then
		self.Cache[key] = upgrades
		return true
	end
	
	-- Production mode - save to DataStore
	local success, result = pcall(function()
		self.DataStore:SetAsync(key, upgrades)
	end)
	
	if not success then
		warn(string.format("[MobilityPersistence] Failed to save data for %s: %s", player.Name, tostring(result)))
	end
	
	return success
end

function MobilityPersistence:GetDefaultUpgrades(): MobilityUpgrades
	return {
		LeapLevel = 1,
		DashLevel = 1,
		LeapCharges = 2,
		CooldownReduction = 0,
		PowerBoost = 0,
		TotalLeaps = 0,
		TotalDashes = 0,
		LastSaved = os.time()
	}
end

function MobilityPersistence:MigrateData(data: any): MobilityUpgrades
	-- Handle data migration from older versions
	local migrated = self:GetDefaultUpgrades()
	
	-- Copy over existing fields
	for key, value in pairs(data) do
		if migrated[key] ~= nil then
			migrated[key] = value
		end
	end
	
	return migrated
end

function MobilityPersistence:IncrementStat(player: Player, stat: string, amount: number?)
	local upgrades = self:LoadPlayerUpgrades(player)
	if not upgrades then return end
	
	amount = amount or 1
	
	if upgrades[stat] and type(upgrades[stat]) == "number" then
		upgrades[stat] = upgrades[stat] + amount
		self:SavePlayerUpgrades(player, upgrades)
	end
end

return MobilityPersistence
