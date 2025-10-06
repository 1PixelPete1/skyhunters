--[[
	MobilityClient.client.luau
	Standalone client script for mobility system
	Place this directly in the client folder
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DEBUG_CHANNELS = {
	boot = false,
	resolve = false,
	init = false,
}

local function debugLog(channel: string, ...)
	if not DEBUG_CHANNELS[channel] then
		return
	end
	print(('[Diag][MobilityClient][%s]'):format(channel), ...)
end

local function setDebugChannel(channel: string, enabled: boolean)
	if DEBUG_CHANNELS[channel] == nil then
		return
	end
	DEBUG_CHANNELS[channel] = enabled and true or false
end

local function setDebugChannels(map: {[string]: boolean})
	for channel, enabled in pairs(map) do
		setDebugChannel(channel, enabled)
	end
end

_G.MobilityClientDebug = {
	set = setDebugChannel,
	setMany = setDebugChannels,
}

debugLog("boot", "Starting mobility client")

-- Wait for player
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	LocalPlayer = Players.LocalPlayer
end

debugLog("boot", "LocalPlayer", LocalPlayer and LocalPlayer.Name or "<none>")

-- Safe require function
local function safeRequire(path)
	local success, result = pcall(require, path)
	if success then
		return result
	else
		warn("[MobilityClient] Failed to require:", path:GetFullName())
		return nil
	end
end

-- Try to find the mobility modules
local function findMobilityModules()
	-- Try multiple possible locations
	local possiblePaths = {
		script.Parent:FindFirstChild("Mobility"),
		script.Parent.Parent:FindFirstChild("Mobility"),
		LocalPlayer.PlayerScripts:FindFirstChild("Mobility"),
		LocalPlayer.PlayerScripts.Client:FindFirstChild("Mobility"),
	}
	
	for _, path in ipairs(possiblePaths) do
		if path then
			debugLog("resolve", "Found mobility folder", path:GetFullName())
			return path
		end
	end
	
	-- If not found, wait for it
	debugLog("resolve", "Mobility folder not found, waiting")
	local mobilityFolder = LocalPlayer.PlayerScripts:WaitForChild("Mobility", 10)
	if mobilityFolder then
		debugLog("resolve", "Mobility folder after wait", mobilityFolder:GetFullName())
		return mobilityFolder
	end
	
	return nil
end

-- Main initialization
task.spawn(function()
	-- Small delay to ensure everything is loaded
	task.wait(1)
	
	debugLog("init", "Scanning for mobility modules")
	
	local mobilityFolder = findMobilityModules()
	if not mobilityFolder then
		warn("[MobilityClient] Could not find Mobility folder - trying direct require")
		
		-- Try to require the controller directly from this script's sibling
		local controllerModule = script.Parent:FindFirstChild("MobilityController")
		if controllerModule then
			debugLog("resolve", "Found MobilityController sibling")
			local MobilityController = safeRequire(controllerModule)
			if MobilityController then
				local controller = MobilityController.new()
				if controller and controller.Init then
					controller:Init()
					debugLog("init", "Controller initialised via sibling")
				end
			end
		else
			warn("[MobilityClient] MobilityController not found as sibling either")
		end
		return
	end
	
	-- Load the controller
	local controllerModule = mobilityFolder:FindFirstChild("MobilityController")
	if not controllerModule then
		warn("[MobilityClient] MobilityController module not found in folder")
		return
	end
	
	debugLog("resolve", "Loading MobilityController", controllerModule:GetFullName())
	
	local MobilityController = safeRequire(controllerModule)
	if not MobilityController then
		warn("[MobilityClient] Failed to require MobilityController")
		return
	end
	
	debugLog("resolve", "MobilityController module loaded")
	
	-- Create and initialize controller
	local controller = MobilityController.new()
	if not controller then
		warn("[MobilityClient] Failed to create controller instance")
		return
	end
	
	debugLog("init", "Controller instance created")
	
	if controller.Init then
		controller:Init()
		debugLog("init", "MobilityController initialised")
		
		-- Store globally for debugging
		_G.MobilityController = controller
		debugLog("init", "Controller stored in _G")
	else
		warn("[MobilityClient] Controller has no Init method")
	end
end)

debugLog("boot", "Mobility client script loaded")
