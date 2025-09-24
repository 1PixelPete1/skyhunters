--!strict
-- PlayerStateHandler.server.luau
-- Server-side handler for player state remote events

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Create remotes
local stateRemote = Instance.new("RemoteEvent")
stateRemote.Name = "PlayerStateRemote"
stateRemote.Parent = ReplicatedStorage

local resourceRemote = Instance.new("RemoteEvent")
resourceRemote.Name = "ResourceNodeRemote"
resourceRemote.Parent = ReplicatedStorage

-- Load services
local serverSystems = script.Parent.Parent.Systems
local PlayerStateService = require(serverSystems:WaitForChild("PlayerStateService"))
local LootTableService = require(serverSystems:WaitForChild("LootTableService"))
local ResourceNodeService = require(serverSystems:WaitForChild("ResourceNodeService"))
local UpgradeService = require(serverSystems:WaitForChild("UpgradeService"))

-- Initialize services
print("[PlayerStateHandler] Initializing services...")

-- Initialize PlayerStateService
PlayerStateService:Init()

-- Initialize UpgradeService
UpgradeService:Init()

-- Initialize ResourceNodeService (which also initializes LootTableService)
ResourceNodeService:Init()

-- Handle remote events from client
stateRemote.OnServerEvent:Connect(function(player: Player, action: string, data: any)
    if action == "StartRecall" then
        PlayerStateService:StartRecall(player)
        
    elseif action == "CancelRecall" then
        PlayerStateService:CancelRecall(player)
        
    elseif action == "DebugDamage" then
        if game:GetService("RunService"):IsStudio() then
            PlayerStateService:DamagePlayer(player, tonumber(data) or 1)
        end
        
    elseif action == "DebugHeal" then
        if game:GetService("RunService"):IsStudio() then
            PlayerStateService:HealPlayer(player, tonumber(data) or 1)
        end
        
    elseif action == "RequestState" then
        -- Send current state to client
        local state = PlayerStateService:GetPlayerState(player)
		local stateManager = PlayerStateService:GetPlayerStateManager(player)
		
		if state and stateManager then
			stateRemote:FireClient(player, "StateChanged", {
				state = state,
				metadata = stateManager.currentState.metadata
			})
			
			-- Send hearts
			stateRemote:FireClient(player, "HeartsChanged", {
				hearts = stateManager.hearts,
				maxHearts = stateManager.maxHearts
			})
			
			-- Send bag if in Run state
			if state == "Run" and stateManager.temporaryBag then
				stateRemote:FireClient(player, "BagUpdated", stateManager.temporaryBag)
			end
		end
	end
end)

-- Test commands for development
game.Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		local args = string.split(message, " ")
		local command = args[1]:lower()
		
		if command == "/state" then
			-- Print current state
			local state = PlayerStateService:GetPlayerState(player)
			print(string.format("%s is in %s state", player.Name, state or "unknown"))
			
		elseif command == "/damage" and args[2] then
			-- Test damage
			local amount = tonumber(args[2]) or 1
			PlayerStateService:DamagePlayer(player, amount)
			print(string.format("Damaged %s for %d", player.Name, amount))
			
		elseif command == "/heal" and args[2] then
			-- Test heal
			local amount = tonumber(args[2]) or 1
			PlayerStateService:HealPlayer(player, amount)
			print(string.format("Healed %s for %d", player.Name, amount))
			
		elseif command == "/giveitem" and args[2] and args[3] then
			-- Test give item
			local itemId = args[2]
			local count = tonumber(args[3]) or 1
			local success = PlayerStateService:AddToTemporaryBag(player, itemId, count)
			print(string.format("Gave %s x%d to %s: %s", itemId, count, player.Name, tostring(success)))
			
		elseif command == "/spawnnode" and args[2] then
			-- Spawn resource node
			local nodeType = args[2]
			local character = player.Character
			if character then
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local pos = hrp.Position + hrp.CFrame.LookVector * 10
					ResourceNodeService:SpawnNodeAtPosition(pos, nodeType)
					print(string.format("Spawned %s node", nodeType))
				end
			end
			
		elseif command == "/testloot" and args[2] then
			-- Test loot table
			local tableId = args[2]
			local iterations = tonumber(args[3]) or 100
			LootTableService:TestDistribution(tableId, iterations)
			
		elseif command == "/recall" then
			-- Force recall
			PlayerStateService:StartRecall(player)
			print(string.format("Started recall for %s", player.Name))
		end
	end)
end)

print("[PlayerStateHandler] Initialized successfully!")

-- Export for other scripts to require
return {
	PlayerStateService = PlayerStateService,
	LootTableService = LootTableService,
	ResourceNodeService = ResourceNodeService,
	UpgradeService = UpgradeService
}
