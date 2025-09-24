--[[
	TestMobilityInit.server.luau
	Simple test script to verify Mobility system is initializing
	Place in ServerScriptService temporarily
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Only run in Studio for testing
if not RunService:IsStudio() then
	return
end

print("[TestMobilityInit] Starting mobility test script")

-- Wait a bit for services to initialize
task.wait(3)

-- Check if Net is set up
local Net = require(ReplicatedStorage.Shared.Net)
print("[TestMobilityInit] Net module loaded:", Net ~= nil)

-- Check for mobility remotes
local remotes = {
	"MobilityRequest",
	"MobilityResponse", 
	"MobilityStateSync",
	"MobilityEffects"
}

print("[TestMobilityInit] Checking for mobility remotes...")
for _, remoteName in ipairs(remotes) do
	local exists = false
	
	-- Check if remote exists
	local netFolder = ReplicatedStorage:FindFirstChild("Net")
	if netFolder then
		local remotesFolder = netFolder:FindFirstChild("Remotes")
		if remotesFolder then
			local remote = remotesFolder:FindFirstChild("RE_" .. remoteName)
			if remote then
				exists = true
			end
		end
	end
	
	print(string.format("  [%s] %s", exists and "✓" or "✗", remoteName))
end

-- Try to manually fire a test state sync
task.wait(1)
print("[TestMobilityInit] Attempting to fire test state sync...")

local Players = game:GetService("Players")
Players.PlayerAdded:Connect(function(player)
	print("[TestMobilityInit] Player joined, attempting state sync in 2 seconds...")
	task.wait(2)
	
	-- Check if we can fire the event
	local success, err = pcall(function()
		Net.Fire(player, "MobilityStateSync", {
			Leap = {
				LastUsed = 0,
				ChargesRemaining = 2,
				IsOnCooldown = false,
				NextChargeTime = 0,
				IsEquipped = true
			},
			Dash = {
				LastUsed = 0,
				ChargesRemaining = 1,
				IsOnCooldown = false,
				NextChargeTime = 0,
				IsEquipped = true
			},
			LastValidPosition = Vector3.new(0, 50, 0),
			LastValidVelocity = Vector3.new(),
			ValidationPending = false,
			LastAbilityUse = 0
		})
	end)
	
	if success then
		print("[TestMobilityInit] Successfully sent test state sync!")
	else
		print("[TestMobilityInit] Failed to send state sync:", err)
	end
end)

print("[TestMobilityInit] Test script ready - join the game to test")
