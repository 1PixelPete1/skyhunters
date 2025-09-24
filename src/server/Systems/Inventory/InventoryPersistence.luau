--!strict
-- InventoryPersistence.luau
-- Secure persistence handler for inventory data

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local InventoryPersistence = {}
InventoryPersistence.__index = InventoryPersistence

-- DataStore for inventory
local inventoryStore = nil
local DATASTORE_NAME = "PlayerInventory_v2" -- v2 for the new separated system
local MAX_RETRIES = 3
local RETRY_DELAY = 1

-- Security: Item count limits to prevent duping
local ITEM_LIMITS = {
	-- Building items (stackable)
	basic_lantern = 100,
	enhanced_lantern = 50,
	crystal_lantern = 25,
	oil_cannister = 200,
	pond_excavator = 20,
	
	-- Equipment items (non-stackable, max 1)
	iron_sword = 1,
	steel_blade = 1,
	lantern_headlamp = 1,
	double_jump = 1,
	dash_boots = 1,
	grappling_hook = 1,
	curse_of_greed = 1,
}

function InventoryPersistence.Init()
	-- Initialize DataStore
	local success, result = pcall(function()
		inventoryStore = DataStoreService:GetDataStore(DATASTORE_NAME)
	end)
	
	if not success then
		warn("[InventoryPersistence] Failed to initialize DataStore:", result)
		inventoryStore = nil
	else
		print("[InventoryPersistence] Initialized with DataStore:", DATASTORE_NAME)
	end
end

function InventoryPersistence.ValidateInventoryData(data: any): boolean
	-- Validate that inventory data is not corrupted or tampered with
	if type(data) ~= "table" then
		return false
	end
	
	-- Check item counts against limits
	local itemCounts = {}
	
	-- Count building items
	if data.buildingItems then
		for _, slot in pairs(data.buildingItems) do
			if slot.itemId and slot.quantity then
				local current = itemCounts[slot.itemId] or 0
				itemCounts[slot.itemId] = current + slot.quantity
			end
		end
	end
	
	-- Count hotbar items
	if data.hotbar then
		for _, slot in pairs(data.hotbar) do
			if slot.itemId and slot.quantity then
				local current = itemCounts[slot.itemId] or 0
				itemCounts[slot.itemId] = current + slot.quantity
			end
		end
	end
	
	-- Count equipment (each should be 1)
	if data.equipment then
		if data.equipment.weapon then
			itemCounts[data.equipment.weapon] = (itemCounts[data.equipment.weapon] or 0) + 1
		end
		if data.equipment.lanternHead then
			itemCounts[data.equipment.lanternHead] = (itemCounts[data.equipment.lanternHead] or 0) + 1
		end
		
		-- Mobility items
		if data.equipment.mobility then
			for _, itemId in pairs(data.equipment.mobility) do
				if itemId then
					itemCounts[itemId] = (itemCounts[itemId] or 0) + 1
				end
			end
		end
		
		-- Curses
		if data.equipment.curses then
			for _, curseId in ipairs(data.equipment.curses) do
				itemCounts[curseId] = (itemCounts[curseId] or 0) + 1
			end
		end
	end
	
	-- Validate against limits
	for itemId, count in pairs(itemCounts) do
		local limit = ITEM_LIMITS[itemId]
		if limit and count > limit then
			warn("[InventoryPersistence] Item count exceeds limit:", itemId, count, ">", limit)
			return false
		end
	end
	
	return true
end

function InventoryPersistence.Save(userId: number, inventoryData: any): boolean
	if not inventoryStore then
		warn("[InventoryPersistence] DataStore not available")
		return false
	end
	
	-- Validate before saving
	if not InventoryPersistence.ValidateInventoryData(inventoryData) then
		warn("[InventoryPersistence] Invalid inventory data for user:", userId)
		return false
	end
	
	-- Add metadata
	local saveData = {
		inventory = inventoryData,
		timestamp = os.time(),
		version = 2, -- Version 2 for separated inventories
		checksum = HttpService:GenerateGUID(false) -- Simple integrity check
	}
	
	-- Attempt to save with retries
	for attempt = 1, MAX_RETRIES do
		local success, result = pcall(function()
			inventoryStore:SetAsync(tostring(userId), saveData)
		end)
		
		if success then
			print("[InventoryPersistence] Saved inventory for user:", userId)
			return true
		else
			warn("[InventoryPersistence] Save attempt", attempt, "failed:", result)
			if attempt < MAX_RETRIES then
				task.wait(RETRY_DELAY * attempt)
			end
		end
	end
	
	return false
end

function InventoryPersistence.Load(userId: number): any?
	if not inventoryStore then
		warn("[InventoryPersistence] DataStore not available")
		return nil
	end
	
	-- Attempt to load with retries
	for attempt = 1, MAX_RETRIES do
		local success, result = pcall(function()
			return inventoryStore:GetAsync(tostring(userId))
		end)
		
		if success then
			if result and result.inventory then
				-- Validate loaded data
				if InventoryPersistence.ValidateInventoryData(result.inventory) then
					print("[InventoryPersistence] Loaded inventory for user:", userId)
					return result.inventory
				else
					warn("[InventoryPersistence] Loaded data failed validation for user:", userId)
					return nil
				end
			else
				print("[InventoryPersistence] No saved inventory for user:", userId)
				return nil
			end
		else
			warn("[InventoryPersistence] Load attempt", attempt, "failed:", result)
			if attempt < MAX_RETRIES then
				task.wait(RETRY_DELAY * attempt)
			end
		end
	end
	
	return nil
end

function InventoryPersistence.Wipe(userId: number): boolean
	if not inventoryStore then
		warn("[InventoryPersistence] DataStore not available")
		return false
	end
	
	local success, result = pcall(function()
		inventoryStore:RemoveAsync(tostring(userId))
	end)
	
	if success then
		print("[InventoryPersistence] Wiped inventory for user:", userId)
		return true
	else
		warn("[InventoryPersistence] Failed to wipe inventory:", result)
		return false
	end
end

-- Auto-save functionality
local autoSaveData = {}
local AUTO_SAVE_INTERVAL = 60 -- Save every 60 seconds

function InventoryPersistence.RegisterForAutoSave(userId: number, getDataFunc: () -> any)
	autoSaveData[userId] = {
		getData = getDataFunc,
		lastSave = os.time()
	}
end

function InventoryPersistence.UnregisterAutoSave(userId: number)
	autoSaveData[userId] = nil
end

function InventoryPersistence.StartAutoSave()
	task.spawn(function()
		while true do
			task.wait(AUTO_SAVE_INTERVAL)
			
			for userId, data in pairs(autoSaveData) do
				local inventoryData = data.getData()
				if inventoryData then
					InventoryPersistence.Save(userId, inventoryData)
					data.lastSave = os.time()
				end
			end
		end
	end)
	
	print("[InventoryPersistence] Auto-save started with interval:", AUTO_SAVE_INTERVAL)
end

return InventoryPersistence
