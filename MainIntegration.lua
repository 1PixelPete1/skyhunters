-- MainIntegration.lua
-- Central integration module for all lantern systems

local MainIntegration = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Server Modules (when on server)
local LanternService
local VoyageService
local MachineService
local HeadLanternService

-- Client Controllers (when on client)
local LightMergerController
local LightLODController
local ReservoirUI
local VoyageUI
local LanternFruitVisuals
local WeatherBlackoutController
local HeadLanternController

-- Determine context
local isServer = RunService:IsServer()
local isClient = RunService:IsClient()

function MainIntegration:Initialize()
    if isServer then
        self:InitializeServer()
    else
        self:InitializeClient()
    end
    
    self:SetupRemoteEvents()
end

function MainIntegration:InitializeServer()
    -- Load server modules
    LanternService = require(script.Parent.Server.LanternService)
    VoyageService = require(script.Parent.Server.VoyageService)
    MachineService = require(script.Parent.Server.MachineService)
    HeadLanternService = require(script.Parent.Server.HeadLanternService)
    
    -- Set up player connections
    Players.PlayerAdded:Connect(function(player)
        self:OnPlayerAdded(player)
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        self:OnPlayerRemoving(player)
    end)
    
    -- Start generation tick
    RunService.Heartbeat:Connect(function()
        LanternService:Tick()
    end)
end

function MainIntegration:InitializeClient()
    -- Load client controllers
    LightMergerController = require(script.Parent.Client.LightMergerController)
    LightLODController = require(script.Parent.Client.LightLODController)
    ReservoirUI = require(script.Parent.Client.ReservoirUI)
    VoyageUI = require(script.Parent.Client.VoyageUI)
    LanternFruitVisuals = require(script.Parent.Client.LanternFruitVisuals)
    WeatherBlackoutController = require(script.Parent.Client.WeatherBlackoutController)
    HeadLanternController = require(script.Parent.Client.HeadLanternController)
    
    -- Initialize UI systems
    LightLODController:Initialize()
    ReservoirUI:Initialize()
    VoyageUI:Initialize()
    WeatherBlackoutController:Initialize()
    HeadLanternController:Initialize()
    
    -- Connect to server updates
    self:ConnectClientRemotes()
end

function MainIntegration:SetupRemoteEvents()
    -- Create remote events/functions
    local remotes = {
        -- Basic operations
        "PlaceLantern",
        "RemoveLantern",
        "SellReservoir",
        
        -- Voyage system
        "StartVoyage",
        "CancelVoyage",
        "VoyageComplete",
        
        -- Machine system
        "PlaceMachine",
        "RemoveMachine",
        
        -- Head lantern system
        "PluckLantern",
        "HeadLanternBroken",
        
        -- Updates
        "ReservoirUpdate",
        "LanternTopologyChanged",
        "FruitMaturityUpdate"
    }
    
    local remotesFolder = Instance.new("Folder")
    remotesFolder.Name = "LanternRemotes"
    remotesFolder.Parent = ReplicatedStorage
    
    for _, remoteName in ipairs(remotes) do
        local remote = Instance.new("RemoteEvent")
        remote.Name = remoteName
        remote.Parent = remotesFolder
    end
    
    -- Add remote functions for data queries
    local functions = {
        "GetPlotData",
        "GetLanternStats",
        "GetMachineEffects"
    }
    
    for _, funcName in ipairs(functions) do
        local func = Instance.new("RemoteFunction")
        func.Name = funcName
        func.Parent = remotesFolder
    end
end

function MainIntegration:OnPlayerAdded(player)
    -- Load player data
    -- This would integrate with ProfileService
    
    -- Set up plot
    player.CharacterAdded:Connect(function(character)
        self:OnCharacterAdded(player, character)
    end)
    
    -- Initialize reservoir for player
    local plotId = self:GetPlayerPlotId(player)
    
    -- Send initial data to client
    task.wait(2) -- Wait for client to load
    local remotes = ReplicatedStorage.LanternRemotes
    
    -- Send reservoir amount
    local reservoir = LanternService:GetPlotReservoir(plotId)
    remotes.ReservoirUpdate:FireClient(player, reservoir)
end

function MainIntegration:OnCharacterAdded(player, character)
    -- Handle death for head lantern durability
    local humanoid = character:WaitForChild("Humanoid")
    
    humanoid.Died:Connect(function()
        if HeadLanternService then
            local broke, message = HeadLanternService:OnPlayerDeath(player)
            if broke then
                -- Notify client
                ReplicatedStorage.LanternRemotes.HeadLanternBroken:FireClient(player, message)
            end
        end
    end)
end

function MainIntegration:ConnectClientRemotes()
    local remotes = ReplicatedStorage:WaitForChild("LanternRemotes")
    
    -- Reservoir updates
    remotes.ReservoirUpdate.OnClientEvent:Connect(function(amount)
        ReservoirUI:UpdateReservoir(amount)
        
        -- Update fruit visuals based on maturity (amount as percentage to next resource)
        local maturity = (amount % 1) * 100
        -- Update all lanterns' fruits
        -- This would need lantern references
    end)
    
    -- Lantern topology changes (for light merger)
    remotes.LanternTopologyChanged.OnClientEvent:Connect(function(lightData)
        LightMergerController:UpdateLights(lightData)
        
        -- Register lights with LOD system
        for _, light in ipairs(lightData) do
            LightLODController:RegisterLight(light.id, nil, light.position)
        end
    end)
    
    -- Voyage completion
    remotes.VoyageComplete.OnClientEvent:Connect(function(rewards)
        VoyageUI:ShowRewards(rewards)
    end)
    
    -- Head lantern break
    remotes.HeadLanternBroken.OnClientEvent:Connect(function(message)
        HeadLanternController:RemoveHeadLantern()
        -- Show notification
    end)
end

-- Server-side remote handlers
function MainIntegration:ConnectServerRemotes()
    local remotes = ReplicatedStorage.LanternRemotes
    
    -- Sell reservoir
    remotes.SellReservoir.OnServerEvent:Connect(function(player)
        local plotId = self:GetPlayerPlotId(player)
        local gold, amount = LanternService:SellReservoir(player, plotId)
        
        -- Update client
        remotes.ReservoirUpdate:FireClient(player, 0)
    end)
    
    -- Start voyage
    remotes.StartVoyage.OnServerEvent:Connect(function(player)
        local plotId = self:GetPlayerPlotId(player)
        local reservoir = LanternService:GetPlotReservoir(plotId)
        
        if reservoir > 0 then
            -- Clear reservoir
            LanternService:SellReservoir(player, plotId)
            
            -- Start voyage
            VoyageService:StartVoyage(player, plotId, reservoir)
        end
    end)
    
    -- Place machine
    remotes.PlaceMachine.OnServerEvent:Connect(function(player, machineType, position)
        local plotId = self:GetPlayerPlotId(player)
        -- Validate player has machine in inventory
        
        MachineService:PlaceMachine(plotId, machineType, 1, position)
        
        -- Recalculate all lantern multipliers
        self:UpdatePlotMultipliers(plotId)
    end)
    
    -- Pluck lantern for head
    remotes.PluckLantern.OnServerEvent:Connect(function(player, lanternId)
        local plotId = self:GetPlayerPlotId(player)
        local success, curseData = HeadLanternService:PluckLantern(player, plotId, lanternId)
        
        if success then
            -- Send head lantern data to client
            local headData = HeadLanternService:GetHeadLanternData(player)
            -- Fire client event to equip visuals
        end
    end)
end

function MainIntegration:UpdatePlotMultipliers(plotId)
    -- Recalculate all lantern stats with machine effects
    -- This would iterate through plot lanterns and apply MachineService multipliers
end

function MainIntegration:GetPlayerPlotId(player)
    -- This would interface with your plot system
    -- For now, return a placeholder
    return "plot_" .. player.UserId
end

-- M0/M1/M2 Feature Toggles
MainIntegration.Config = {
    -- M0 features (all enabled)
    EnableLightMerger = true,
    EnableReservoir = true,
    EnableWeatherBlackout = false, -- Guarded for testing
    
    -- M1 features
    EnableVoyages = true,
    EnableMachines = true,
    EnableFruitVisuals = true,
    
    -- M2 features
    EnableHeadLanterns = true,
    EnableLightLOD = true,
    EnableCurses = true
}

return MainIntegration