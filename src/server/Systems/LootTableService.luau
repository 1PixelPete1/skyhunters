--!strict
-- LootTableService.luau
-- Manages loot tables and item drops with bell curve RNG

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SafeRequire = require(ReplicatedStorage.Shared.SafeRequire)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

export type ItemRarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

export type LootItem = {
	id: string,
	name: string,
	rarity: ItemRarity,
	weight: number,
	minCount: number,
	maxCount: number,
	icon: string?,
	description: string?,
}

export type LootTable = {
	id: string,
	name: string,
	items: {LootItem},
	guaranteedDrops: {LootItem}?,
	minDrops: number,
	maxDrops: number,
	rarityBonus: number, -- Multiplier for rare drops
}

export type LootRoll = {
	item: LootItem,
	count: number,
	rarity: ItemRarity,
}

local LootTableService = {}
LootTableService.__index = LootTableService

-- Rarity weights (bell curve distribution)
local RARITY_WEIGHTS = {
	Common = 100,     -- 50%
	Uncommon = 60,    -- 30%
	Rare = 30,        -- 15%
	Epic = 8,         -- 4%
	Legendary = 2,    -- 1%
}

-- Mock items for testing
local MOCK_ITEMS = {
	-- Common
	{id = "Wood", name = "Wood", rarity = "Common", weight = 100, minCount = 1, maxCount = 5},
	{id = "Stone", name = "Stone", rarity = "Common", weight = 100, minCount = 1, maxCount = 5},
	{id = "Fiber", name = "Plant Fiber", rarity = "Common", weight = 80, minCount = 2, maxCount = 8},
	
	-- Uncommon
	{id = "IronOre", name = "Iron Ore", rarity = "Uncommon", weight = 60, minCount = 1, maxCount = 3},
	{id = "Coal", name = "Coal", rarity = "Uncommon", weight = 50, minCount = 1, maxCount = 4},
	{id = "Leather", name = "Leather", rarity = "Uncommon", weight = 40, minCount = 1, maxCount = 2},
	
	-- Rare
	{id = "GoldOre", name = "Gold Ore", rarity = "Rare", weight = 30, minCount = 1, maxCount = 2},
	{id = "Crystal", name = "Crystal Shard", rarity = "Rare", weight = 25, minCount = 1, maxCount = 1},
	{id = "EnchantedWood", name = "Enchanted Wood", rarity = "Rare", weight = 20, minCount = 1, maxCount = 2},
	
	-- Epic
	{id = "DiamondOre", name = "Diamond Ore", rarity = "Epic", weight = 10, minCount = 1, maxCount = 1},
	{id = "MythrilOre", name = "Mythril Ore", rarity = "Epic", weight = 8, minCount = 1, maxCount = 1},
	{id = "DragonScale", name = "Dragon Scale", rarity = "Epic", weight = 5, minCount = 1, maxCount = 1},
	
	-- Legendary
	{id = "StarEssence", name = "Star Essence", rarity = "Legendary", weight = 2, minCount = 1, maxCount = 1},
	{id = "VoidCrystal", name = "Void Crystal", rarity = "Legendary", weight = 1, minCount = 1, maxCount = 1},
}

-- Loot tables
local lootTables: {[string]: LootTable} = {}

-- Signals
local lootDroppedSignal = Signal.new()

-- Initialize service
function LootTableService:Init()
	-- Create default loot tables
	self:CreateDefaultTables()
	
	print("[LootTableService] Initialized with", #lootTables, "loot tables")
end

-- Create default loot tables
function LootTableService:CreateDefaultTables()
	-- Basic resource node
	self:RegisterLootTable({
		id = "BasicResource",
		name = "Basic Resource Node",
		items = {
			MOCK_ITEMS[1], -- Wood
			MOCK_ITEMS[2], -- Stone
			MOCK_ITEMS[3], -- Fiber
			MOCK_ITEMS[4], -- Iron Ore
		},
		minDrops = 1,
		maxDrops = 3,
		rarityBonus = 1.0,
	})
	
	-- Rich resource node
	self:RegisterLootTable({
		id = "RichResource",
		name = "Rich Resource Node",
		items = {
			MOCK_ITEMS[4], -- Iron Ore
			MOCK_ITEMS[5], -- Coal
			MOCK_ITEMS[6], -- Leather
			MOCK_ITEMS[7], -- Gold Ore
			MOCK_ITEMS[8], -- Crystal
		},
		minDrops = 2,
		maxDrops = 4,
		rarityBonus = 1.5,
	})
	
	-- Treasure chest
	self:RegisterLootTable({
		id = "TreasureChest",
		name = "Treasure Chest",
		items = {
			MOCK_ITEMS[7], -- Gold Ore
			MOCK_ITEMS[8], -- Crystal
			MOCK_ITEMS[9], -- Enchanted Wood
			MOCK_ITEMS[10], -- Diamond Ore
			MOCK_ITEMS[11], -- Mythril Ore
			MOCK_ITEMS[12], -- Dragon Scale
		},
		guaranteedDrops = {
			{id = "CrudeOil", name = "Crude Oil", rarity = "Common", weight = 100, minCount = 5, maxCount = 15}
		},
		minDrops = 2,
		maxDrops = 5,
		rarityBonus = 2.0,
	})
	
	-- Epic chest
	self:RegisterLootTable({
		id = "EpicChest",
		name = "Epic Chest",
		items = {
			MOCK_ITEMS[10], -- Diamond Ore
			MOCK_ITEMS[11], -- Mythril Ore
			MOCK_ITEMS[12], -- Dragon Scale
			MOCK_ITEMS[13], -- Star Essence
			MOCK_ITEMS[14], -- Void Crystal
		},
		guaranteedDrops = {
			{id = "CrudeOil", name = "Crude Oil", rarity = "Common", weight = 100, minCount = 20, maxCount = 50}
		},
		minDrops = 3,
		maxDrops = 6,
		rarityBonus = 3.0,
	})
	
	-- Crude oil node
	self:RegisterLootTable({
		id = "CrudeOilNode",
		name = "Crude Oil Deposit",
		items = {},
		guaranteedDrops = {
			{id = "CrudeOil", name = "Crude Oil", rarity = "Common", weight = 100, minCount = 10, maxCount = 30}
		},
		minDrops = 0,
		maxDrops = 0,
		rarityBonus = 1.0,
	})
	
	-- Enemy drops
	self:RegisterLootTable({
		id = "BasicEnemy",
		name = "Basic Enemy",
		items = {
			MOCK_ITEMS[1], -- Wood
			MOCK_ITEMS[2], -- Stone
			MOCK_ITEMS[3], -- Fiber
			MOCK_ITEMS[6], -- Leather
		},
		minDrops = 0,
		maxDrops = 2,
		rarityBonus = 1.0,
	})
end

-- Register a loot table
function LootTableService:RegisterLootTable(lootTable: LootTable)
	lootTables[lootTable.id] = lootTable
end

-- Bell curve random (Box-Muller transform)
function LootTableService:BellCurveRandom(mean: number, stdDev: number): number
	local u1 = math.random()
	local u2 = math.random()
	
	local z0 = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
	
	return mean + z0 * stdDev
end

-- Get weighted random item
function LootTableService:GetWeightedRandomItem(items: {LootItem}, rarityBonus: number): LootItem?
	if #items == 0 then return nil end
	
	local totalWeight = 0
	local adjustedWeights = {}
	
	-- Calculate adjusted weights with rarity bonus
	for _, item in ipairs(items) do
		local weight = item.weight
		
		-- Apply rarity bonus for rarer items
		if item.rarity == "Rare" then
			weight = weight * (1 + rarityBonus * 0.5)
		elseif item.rarity == "Epic" then
			weight = weight * (1 + rarityBonus * 1.0)
		elseif item.rarity == "Legendary" then
			weight = weight * (1 + rarityBonus * 2.0)
		end
		
		adjustedWeights[item] = weight
		totalWeight = totalWeight + weight
	end
	
	-- Roll
	local roll = math.random() * totalWeight
	local current = 0
	
	for _, item in ipairs(items) do
		current = current + adjustedWeights[item]
		if roll <= current then
			return item
		end
	end
	
	return items[#items] -- Fallback
end

-- Roll loot from table
function LootTableService:RollLoot(tableId: string, luckModifier: number?): {LootRoll}
	local lootTable = lootTables[tableId]
	if not lootTable then
		warn("[LootTableService] Unknown loot table:", tableId)
		return {}
	end
	
	local rolls: {LootRoll} = {}
	local luck = luckModifier or 0
	
	-- Add guaranteed drops
	if lootTable.guaranteedDrops then
		for _, item in ipairs(lootTable.guaranteedDrops) do
			local count = math.random(item.minCount, item.maxCount)
			table.insert(rolls, {
				item = item,
				count = count,
				rarity = item.rarity,
			})
		end
	end
	
	-- Determine number of drops (bell curve)
	local dropCount = lootTable.minDrops
	if lootTable.maxDrops > lootTable.minDrops then
		local mean = (lootTable.minDrops + lootTable.maxDrops) / 2
		local stdDev = (lootTable.maxDrops - lootTable.minDrops) / 4
		
		-- Add luck to mean
		mean = mean + luck * 0.5
		
		local bellValue = self:BellCurveRandom(mean, stdDev)
		dropCount = math.clamp(
			math.floor(bellValue + 0.5),
			lootTable.minDrops,
			lootTable.maxDrops
		)
	end
	
	-- Roll items
	for i = 1, dropCount do
		local item = self:GetWeightedRandomItem(lootTable.items, lootTable.rarityBonus + luck * 0.1)
		if item then
			local count = math.random(item.minCount, item.maxCount)
			
			-- Luck can increase count
			if luck > 0 and math.random() < luck * 0.1 then
				count = count + 1
			end
			
			table.insert(rolls, {
				item = item,
				count = count,
				rarity = item.rarity,
			})
		end
	end
	
	-- Fire signal
	lootDroppedSignal:Fire(tableId, rolls)
	
	return rolls
end

-- Roll multiple times (for testing distribution)
function LootTableService:TestDistribution(tableId: string, iterations: number)
	local rarityCount = {}
	local itemCount = {}
	
	for i = 1, iterations do
		local rolls = self:RollLoot(tableId, 0)
		
		for _, roll in ipairs(rolls) do
			rarityCount[roll.rarity] = (rarityCount[roll.rarity] or 0) + 1
			itemCount[roll.item.id] = (itemCount[roll.item.id] or 0) + roll.count
		end
	end
	
	print(string.format("[LootTableService] Distribution test for '%s' (%d iterations):", tableId, iterations))
	print("Rarity distribution:")
	for rarity, count in pairs(rarityCount) do
		print(string.format("  %s: %.2f%%", rarity, (count / iterations) * 100))
	end
	
	print("Item distribution:")
	for itemId, count in pairs(itemCount) do
		print(string.format("  %s: %.2f average", itemId, count / iterations))
	end
end

-- Get loot table
function LootTableService:GetLootTable(tableId: string): LootTable?
	return lootTables[tableId]
end

-- Get all items of rarity
function LootTableService:GetItemsByRarity(rarity: ItemRarity): {LootItem}
	local items = {}
	
	for _, item in ipairs(MOCK_ITEMS) do
		if item.rarity == rarity then
			table.insert(items, item)
		end
	end
	
	return items
end

-- Get loot dropped signal
function LootTableService:GetLootDroppedSignal()
	return lootDroppedSignal
end

return LootTableService
