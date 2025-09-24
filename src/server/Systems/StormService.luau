--!strict
-- StormService.luau
-- Server-side storm orchestration and state management with robust error handling

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Safe require with error handling
local function safeRequire(path: Instance?): any
    if not path then
        warn("[StormService] Missing required module path")
        return nil
    end
    
    local success, result = pcall(require, path)
    if not success then
        warn("[StormService] Failed to require module:", path:GetFullName(), "-", result)
        return nil
    end
    
    return result
end

-- Try to load shared modules
local sharedFolder = ReplicatedStorage:WaitForChild("Shared", 10)
if not sharedFolder then
    warn("[StormService] Critical: Could not find Shared folder in ReplicatedStorage")
    return {}  -- Return empty table to prevent server crash
end

local StormTypes = safeRequire(sharedFolder:FindFirstChild("StormTypes"))
local StormConfig = safeRequire(sharedFolder:FindFirstChild("StormConfig"))

-- Fallback if modules fail to load
if not StormTypes or not StormConfig then
    warn("[StormService] Critical: Required modules failed to load. Storm system disabled.")
    return {
        Init = function()
            warn("[StormService] Storm system is disabled due to missing dependencies")
        end
    }
end

type StormState = StormTypes.StormState
type StormProfile = StormTypes.StormProfile
type GustEvent = StormTypes.GustEvent

local StormService = {}
StormService.CurrentState = nil :: StormState?
StormService.Initialized = false
StormService.DebugMode = RunService:IsStudio()

-- Safe initialization of remotes
local function setupRemotes()
    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotesFolder then
        remotesFolder = Instance.new("Folder")
        remotesFolder.Name = "Remotes"
        remotesFolder.Parent = ReplicatedStorage
        if StormService.DebugMode then
            print("[StormService] Created Remotes folder")
        end
    end
    
    local stormStateRemote = remotesFolder:FindFirstChild("StormState") :: RemoteEvent?
    if not stormStateRemote then
        stormStateRemote = Instance.new("RemoteEvent")
        stormStateRemote.Name = "StormState"
        stormStateRemote.Parent = remotesFolder
    end
    
    return stormStateRemote
end

-- Safe initialization of state values
local function setupStateValues()
    local stormStateFolder = ReplicatedStorage:FindFirstChild("StormState") :: Folder?
    if not stormStateFolder then
        stormStateFolder = Instance.new("Folder")
        stormStateFolder.Name = "StormState"
        stormStateFolder.Parent = ReplicatedStorage
    end
    
    local stormVector = stormStateFolder:FindFirstChild("Vector") :: Vector3Value?
    if not stormVector then
        stormVector = Instance.new("Vector3Value")
        stormVector.Name = "Vector"
        stormVector.Value = Vector3.new(0, 0, 0)
        stormVector.Parent = stormStateFolder
    end
    
    local stormIntensity = stormStateFolder:FindFirstChild("Intensity") :: NumberValue?
    if not stormIntensity then
        stormIntensity = Instance.new("NumberValue")
        stormIntensity.Name = "Intensity"
        stormIntensity.Value = 0
        stormIntensity.Parent = stormStateFolder
    end
    
    local stormProfile = stormStateFolder:FindFirstChild("Profile") :: StringValue?
    if not stormProfile then
        stormProfile = Instance.new("StringValue")
        stormProfile.Name = "Profile"
        stormProfile.Value = "RAIN_HEAVY"
        stormProfile.Parent = stormStateFolder
    end
    
    return {
        folder = stormStateFolder,
        vector = stormVector,
        intensity = stormIntensity,
        profile = stormProfile
    }
end

-- Cache remotes and values
local stormStateRemote: RemoteEvent?
local stateValues: {folder: Folder, vector: Vector3Value, intensity: NumberValue, profile: StringValue}?

-- Generate random storm vectors with bias toward horizontal movement
local function generateStormVector(): Vector3
    local yaw = math.random() * math.pi * 2
    local pitch = (math.random() - 0.5) * 0.2  -- Slight vertical component
    
    local vector = Vector3.new(
        math.cos(yaw) * math.cos(pitch),
        math.sin(pitch),
        math.sin(yaw) * math.cos(pitch)
    )
    
    return vector.Unit
end

-- Select a random storm profile
local function selectRandomProfile(): StormProfile
    local profiles: {StormProfile} = {"RAIN_HEAVY", "RAIN_LIGHT", "SNOW", "DUST"}
    return profiles[math.random(1, #profiles)]
end

-- Initialize a new storm
function StormService:InitStorm(profile: StormProfile?, customVector: Vector3?)
    if not self.Initialized then
        warn("[StormService] Cannot init storm - service not initialized")
        return nil
    end
    
    local selectedProfile = profile or selectRandomProfile()
    local profileConfig = StormConfig.Profiles[selectedProfile]
    
    if not profileConfig then
        warn("[StormService] Invalid storm profile:", selectedProfile, "- using RAIN_HEAVY")
        selectedProfile = "RAIN_HEAVY"
        profileConfig = StormConfig.Profiles[selectedProfile]
    end
    
    local state: StormState = {
        vector = customVector or generateStormVector(),
        profile = selectedProfile,
        intensity = profileConfig.intensity,
        gusts = profileConfig.gusts
    }
    
    self.CurrentState = state
    
    local success = self:ReplicateState()
    if success and self.DebugMode then
        print("[StormService] Storm initialized:", selectedProfile, "intensity:", profileConfig.intensity)
    end
    
    return state
end

-- Replicate current state to all clients
function StormService:ReplicateState(): boolean
    if not self.CurrentState then 
        if self.DebugMode then
            warn("[StormService] No state to replicate")
        end
        return false
    end
    
    if not stormStateRemote or not stateValues then
        warn("[StormService] Remotes not initialized for replication")
        return false
    end
    
    -- Update value objects for easy access
    local success, err = pcall(function()
        stateValues.vector.Value = self.CurrentState.vector
        stateValues.intensity.Value = self.CurrentState.intensity
        stateValues.profile.Value = self.CurrentState.profile
        
        -- Fire remote to all clients with full state
        stormStateRemote:FireAllClients(self.CurrentState)
    end)
    
    if not success then
        warn("[StormService] Failed to replicate state:", err)
        return false
    end
    
    return true
end

-- Update storm intensity (for dynamic changes)
function StormService:SetIntensity(intensity: number)
    if not self.CurrentState then
        warn("[StormService] No active storm to set intensity")
        return
    end
    
    self.CurrentState.intensity = math.clamp(intensity, 0, 1)
    self:ReplicateState()
end

-- Stop the current storm
function StormService:StopStorm()
    if not self.CurrentState then
        if self.DebugMode then
            print("[StormService] No storm to stop")
        end
        return
    end
    
    self.CurrentState.intensity = 0
    self:ReplicateState()
    
    -- Delay clearing to allow fade out
    task.delay(2, function()
        self.CurrentState = nil
        if self.DebugMode then
            print("[StormService] Storm stopped and cleared")
        end
    end)
end

-- Handle round/game state changes
function StormService:OnRoundStart()
    -- Initialize with random storm
    self:InitStorm()
    
    -- Schedule intensity changes based on game progression
    task.spawn(function()
        -- Example: Ramp up intensity over time
        for i = 0.5, 0.9, 0.1 do
            task.wait(30)  -- Every 30 seconds
            if self.CurrentState then
                self:SetIntensity(i)
            end
        end
    end)
end

function StormService:OnRoundEnd()
    self:StopStorm()
end

-- Setup debug commands for Studio testing
local function setupDebugCommands(service: typeof(StormService))
    if not RunService:IsStudio() then
        return
    end
    
    local function onPlayerCommand(player: Player, command: string, ...)
        if command ~= "storm" then
            return
        end
        
        local args = {...}
        local subCommand = args[1] :: string?
        
        if not subCommand then
            print("[StormService] Commands: /storm start [profile], /storm stop, /storm intensity <0-1>, /storm vector <x> <y> <z>")
            return
        end
        
        if subCommand == "start" then
            local profile = args[2] :: StormProfile?
            service:InitStorm(profile)
        elseif subCommand == "stop" then
            service:StopStorm()
        elseif subCommand == "intensity" then
            local intensity = tonumber(args[2])
            if intensity then
                service:SetIntensity(intensity)
            else
                warn("[StormService] Invalid intensity value")
            end
        elseif subCommand == "vector" then
            local x, y, z = tonumber(args[2]), tonumber(args[3]), tonumber(args[4])
            if x and y and z then
                if service.CurrentState then
                    service.CurrentState.vector = Vector3.new(x, y, z).Unit
                    service:ReplicateState()
                else
                    warn("[StormService] No active storm to set vector")
                end
            else
                warn("[StormService] Invalid vector values. Usage: /storm vector <x> <y> <z>")
            end
        else
            print("[StormService] Unknown command:", subCommand)
        end
    end
    
    -- Set up chat commands
    Players.PlayerAdded:Connect(function(player)
        player.Chatted:Connect(function(msg)
            local parts = string.split(msg, " ")
            if parts[1] == "/storm" then
                table.remove(parts, 1)
                onPlayerCommand(player, "storm", table.unpack(parts))
            end
        end)
    end)
    
    print("[StormService] Debug commands enabled. Type '/storm' for help")
end

-- Service initialization (called by server boot system)
function StormService.Init(services: any)
    if StormService.Initialized then
        warn("[StormService] Already initialized")
        return
    end
    
    print("[StormService] Initializing...")
    
    -- Setup remotes and state values with error handling
    local success, err = pcall(function()
        stormStateRemote = setupRemotes()
        stateValues = setupStateValues()
    end)
    
    if not success then
        warn("[StormService] Failed to initialize remotes:", err)
        return
    end
    
    StormService.Initialized = true
    
    -- Setup debug commands if in Studio
    setupDebugCommands(StormService)
    
    -- Auto-start test storm after delay (Studio only)
    if RunService:IsStudio() then
        task.delay(5, function()
            print("[StormService] Starting test storm in 5 seconds...")
            StormService:InitStorm("RAIN_HEAVY")
        end)
    end
    
    print("[StormService] Initialization complete")
end

-- Public API
return StormService
