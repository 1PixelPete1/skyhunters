--[[
	MobilityClient.client.luau
	Standalone client script for mobility system
	Place this directly in the client folder
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

print("[MobilityClient] Starting standalone mobility client...")

-- Wait for player
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	LocalPlayer = Players.LocalPlayer
end

print("[MobilityClient] LocalPlayer found:", LocalPlayer.Name)

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
			print("[MobilityClient] Found Mobility folder at:", path:GetFullName())
			return path
		end
	end
	
	-- If not found, wait for it
	print("[MobilityClient] Mobility folder not found, waiting...")
	local mobilityFolder = LocalPlayer.PlayerScripts:WaitForChild("Mobility", 10)
	if mobilityFolder then
		print("[MobilityClient] Mobility folder found after wait at:", mobilityFolder:GetFullName())
		return mobilityFolder
	end
	
	return nil
end

-- Main initialization
task.spawn(function()
	-- Small delay to ensure everything is loaded
	task.wait(1)
	
	print("[MobilityClient] Looking for mobility modules...")
	
	local mobilityFolder = findMobilityModules()
	if not mobilityFolder then
		warn("[MobilityClient] Could not find Mobility folder - trying direct require")
		
		-- Try to require the controller directly from this script's sibling
		local controllerModule = script.Parent:FindFirstChild("MobilityController")
		if controllerModule then
			print("[MobilityClient] Found MobilityController as sibling")
			local MobilityController = safeRequire(controllerModule)
			if MobilityController then
				local controller = MobilityController.new()
				if controller and controller.Init then
					controller:Init()
					print("[MobilityClient] MobilityController initialized from sibling!")
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
	
	print("[MobilityClient] Loading MobilityController from:", controllerModule:GetFullName())
	
	local MobilityController = safeRequire(controllerModule)
	if not MobilityController then
		warn("[MobilityClient] Failed to require MobilityController")
		return
	end
	
	print("[MobilityClient] MobilityController module loaded successfully")
	
	-- Create and initialize controller
	local controller = MobilityController.new()
	if not controller then
		warn("[MobilityClient] Failed to create controller instance")
		return
	end
	
	print("[MobilityClient] Controller instance created")
	
	if controller.Init then
		controller:Init()
		print("[MobilityClient] MobilityController initialized successfully!")
		
		-- Store globally for debugging
		_G.MobilityController = controller
		print("[MobilityClient] Controller stored in _G.MobilityController for debugging")
	else
		warn("[MobilityClient] Controller has no Init method")
	end
end)

print("[MobilityClient] Standalone client script loaded")
