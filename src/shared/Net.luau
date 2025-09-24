--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()

local function ensureFolder(parent: Instance, name: string): Instance
	local child = parent:FindFirstChild(name)
	if child then
		return child
	end

	if IS_SERVER then
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
		return folder
	end

	return parent:WaitForChild(name)
end

local NetFolder = ensureFolder(ReplicatedStorage, "Net")
local Remotes = ensureFolder(NetFolder, "Remotes")

local Net = {}

-- Bump when changing any remote payload shape
Net.CONTRACT_VERSION = 1

Net.Functions = {
	-- Pond/Lanterns contracts
	RF_ClaimPond = "RF_ClaimPond",
	RF_DepositOil = "RF_DepositOil",
	RF_PlaceBaseLantern = "RF_PlaceBaseLantern",
	RF_RefillBaseLantern = "RF_RefillBaseLantern",
	RF_ToggleRunLantern = "RF_ToggleRunLantern",
	RF_ApplyBaseLantern = "RF_ApplyBaseLantern",
	RF_StartVoyage = "RF_StartVoyage",

	-- Inventory System
	GetPlayerInventory = "GetPlayerInventory",
	MoveItem = "MoveItem",
	EquipItem = "EquipItem",
	UnequipItem = "UnequipItem",
	SwapHotbarSlots = "SwapHotbarSlots",
	DropItem = "DropItem",
}

Net.Events = {
	-- Lanterns & related
	RE_OnLanternStatesBatch = "RE_OnLanternStatesBatch",
	RE_OnMinionScatter = "RE_OnMinionScatter",
	RE_OnRunTension = "RE_OnRunTension",
	RE_OnFlameChanged = "RE_OnFlameChanged",
	RE_OnSafeZoneChanged = "RE_OnSafeZoneChanged",
	RE_OnCrowdDescriptor = "RE_OnCrowdDescriptor",

	-- Inventory System
	UpdateInventory = "UpdateInventory",
	UpdateHotbar = "UpdateHotbar",
	UpdateHotbarSlot = "UpdateHotbarSlot",
	ItemAdded = "ItemAdded",
	ItemRemoved = "ItemRemoved",
	EquipmentChanged = "EquipmentChanged",
	HotbarSlotSelected = "HotbarSlotSelected",
	UseHotbarItem = "UseHotbarItem",
}

local eventCache: { [string]: RemoteEvent } = {}
local functionCache: { [string]: RemoteFunction } = {}

local function getEvent(name: string): RemoteEvent
	local cached = eventCache[name]
	if cached and cached.Parent then
		return cached
	end

	local event = Remotes:FindFirstChild(name)
	if event then
		eventCache[name] = event :: RemoteEvent
		return event :: RemoteEvent
	end

	if IS_SERVER then
		local newEvent = Instance.new("RemoteEvent")
		newEvent.Name = name
		newEvent.Parent = Remotes
		eventCache[name] = newEvent
		return newEvent
	end

	event = Remotes:WaitForChild(name) :: RemoteEvent
	eventCache[name] = event
	return event
end

local function getFunction(name: string): RemoteFunction
	local cached = functionCache[name]
	if cached and cached.Parent then
		return cached
	end

	local func = Remotes:FindFirstChild(name)
	if func then
		functionCache[name] = func :: RemoteFunction
		return func :: RemoteFunction
	end

	if IS_SERVER then
		local newFunc = Instance.new("RemoteFunction")
		newFunc.Name = name
		newFunc.Parent = Remotes
		functionCache[name] = newFunc
		return newFunc
	end

	func = Remotes:WaitForChild(name) :: RemoteFunction
	functionCache[name] = func
	return func
end

function Net:GetEvent(name: string): RemoteEvent
	return getEvent(name)
end

function Net:GetFunction(name: string): RemoteFunction
	return getFunction(name)
end

function Net.Event(name: string): RemoteEvent
	return getEvent(name)
end

function Net.Function(name: string): RemoteFunction
	return getFunction(name)
end

function Net.On(eventName: string, callback)
	assert(type(eventName) == "string", "Net.On requires an event name")
	local event = getEvent(eventName)
	if IS_SERVER then
		return event.OnServerEvent:Connect(callback)
	end
	return event.OnClientEvent:Connect(callback)
end

function Net.Fire(arg1, arg2, ...)
	if IS_SERVER then
		local player = arg1 :: Player
		local eventName = arg2 :: string
		assert(typeof(player) == "Instance" and player:IsA("Player"), "Net.Fire (server) expects Player as first argument")
		assert(type(eventName) == "string", "Net.Fire expects event name string")
		local event = getEvent(eventName)
		event:FireClient(player, ...)
		return
	end

	local eventName = arg1 :: string
	assert(type(eventName) == "string", "Net.Fire (client) expects event name string")
	local event = getEvent(eventName)
	event:FireServer(arg2, ...)
end

function Net.FireAll(eventName: string, ...)
	assert(IS_SERVER, "Net.FireAll can only be used on the server")
	assert(type(eventName) == "string", "Net.FireAll expects event name string")
	local event = getEvent(eventName)
	event:FireAllClients(...)
end

function Net.Invoke(arg1, arg2, ...)
	if IS_SERVER then
		local player = arg1 :: Player
		local functionName = arg2 :: string
		assert(typeof(player) == "Instance" and player:IsA("Player"), "Net.Invoke (server) expects Player as first argument")
		assert(type(functionName) == "string", "Net.Invoke expects function name string")
		local func = getFunction(functionName)
		return func:InvokeClient(player, ...)
	end

	local functionName = arg1 :: string
	assert(type(functionName) == "string", "Net.Invoke (client) expects function name string")
	local func = getFunction(functionName)
	return func:InvokeServer(arg2, ...)
end

function Net.OnInvoke(functionName: string, callback)
	assert(type(functionName) == "string", "Net.OnInvoke expects function name string")
	local func = getFunction(functionName)
	if IS_SERVER then
		func.OnServerInvoke = callback
	else
		func.OnClientInvoke = callback
	end
end

return Net
