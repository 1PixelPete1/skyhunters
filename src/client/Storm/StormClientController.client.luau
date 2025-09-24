-- DISABLED: This storm controller has been replaced by EnhancedStormController.client.luau
-- To prevent duplicate storm effects, this system is disabled.
local ENABLE_LEGACY_STORM = false
if not ENABLE_LEGACY_STORM then
    print("[StormClient] Legacy storm system disabled - using EnhancedStormController instead")
    return
end

--!strict
-- StormClientController.client.luau
-- Main client-side storm controller with robust error handling

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Safe require helper
local function safeRequire(path: Instance?, moduleName: string): any
    if not path then
        warn("[StormClient]", moduleName, "module not found")
        return nil
    end
    
    local success, result = pcall(require, path)
    if not success then
        warn("[StormClient] Failed to load", moduleName, ":", result)
        return nil
    end
    
    return result
end

-- Load shared modules with error handling
local sharedFolder = ReplicatedStorage:WaitForChild("Shared", 10)
if not sharedFolder then
    warn("[StormClient] Critical: Shared folder not found. Storm client disabled.")
    return
end

local StormTypes = safeRequire(sharedFolder:FindFirstChild("StormTypes"), "StormTypes")
local StormConfig = safeRequire(sharedFolder:FindFirstChild("StormConfig"), "StormConfig")

if not StormTypes or not StormConfig then
    warn("[StormClient] Critical: Required modules missing. Storm client disabled.")
    return
end

-- Load sub-modules with graceful fallback
local currentScript = script
local stormFolder = currentScript.Parent

local LanternConeController = safeRequire(stormFolder and stormFolder:FindFirstChild("LanternConeController"), "LanternConeController")
local fieldsFolder = stormFolder and stormFolder:FindFirstChild("Fields")
local overlaysFolder = stormFolder and stormFolder:FindFirstChild("Overlays")
local animFolder = stormFolder and stormFolder:FindFirstChild("Anim")

local RainBeams = safeRequire(fieldsFolder and fieldsFolder:FindFirstChild("RainBeams"), "RainBeams")
local RainShells = safeRequire(fieldsFolder and fieldsFolder:FindFirstChild("RainShells"), "RainShells")
local EdgeBand = safeRequire(fieldsFolder and fieldsFolder:FindFirstChild("EdgeBand"), "EdgeBand")
local GroundSplashes = safeRequire(fieldsFolder and fieldsFolder:FindFirstChild("GroundSplashes"), "GroundSplashes")
local StormOverlays = safeRequire(overlaysFolder and overlaysFolder:FindFirstChild("StormOverlays"), "StormOverlays")
local WindAnimator = safeRequire(animFolder and animFolder:FindFirstChild("WindAnimator"), "WindAnimator")
local WindGusts = safeRequire(fieldsFolder and fieldsFolder:FindFirstChild("WindGusts"), "WindGusts")
local FogController = safeRequire(fieldsFolder and fieldsFolder:FindFirstChild("FogController"), "FogController")
local DistantWind = safeRequire(fieldsFolder and fieldsFolder:FindFirstChild("DistantWind"), "DistantWind")

type StormState = StormTypes.StormState
type PerfTier = StormTypes.PerfTier
type PerfConfig = StormTypes.PerfConfig

local StormClientController = {}
StormClientController.CurrentState = nil :: StormState?
StormClientController.PerfTier = "HIGH" :: PerfTier
StormClientController.Active = false
StormClientController.Systems = {}
StormClientController.DebugMode = RunService:IsStudio()

-- FPS monitoring for performance tier
local fpsHistory = {}
local fpsCheckInterval = 0.5
local fpsHistorySize = 10
local lastFpsCheck = 0

local function calculateAverageFPS(): number
    if #fpsHistory == 0 then return 60 end
    
    local sum = 0
    for _, fps in ipairs(fpsHistory) do
        sum = sum + fps
    end
    
    return sum / #fpsHistory
end

local function updatePerfTier(fps: number)
    table.insert(fpsHistory, fps)
    if #fpsHistory > fpsHistorySize then
        table.remove(fpsHistory, 1)
    end
    
    local avgFPS = calculateAverageFPS()
    local controller = StormClientController
    
    -- Hysteresis to prevent rapid switching
    if avgFPS < 28 and controller.PerfTier ~= "LOW" then
        controller.PerfTier = "LOW"
        if controller.DebugMode then
            print("[StormClient] Performance tier changed to LOW (FPS:", avgFPS, ")")
        end
        controller:ReconfigureSystems()
    elseif avgFPS < 40 and avgFPS >= 28 and controller.PerfTier == "HIGH" then
        controller.PerfTier = "MED"
        if controller.DebugMode then
            print("[StormClient] Performance tier changed to MED (FPS:", avgFPS, ")")
        end
        controller:ReconfigureSystems()
    elseif avgFPS > 58 and controller.PerfTier ~= "HIGH" then
        if controller.PerfTier == "LOW" then
            controller.PerfTier = "MED"
        else
            controller.PerfTier = "HIGH"
        end
        if controller.DebugMode then
            print("[StormClient] Performance tier changed to", controller.PerfTier, "(FPS:", avgFPS, ")")
        end
        controller:ReconfigureSystems()
    end
end

-- Initialize all storm subsystems with error handling
function StormClientController:InitializeSystems()
    local perfConfig = StormConfig.Perf[self.PerfTier]
    if not perfConfig then
        warn("[StormClient] Invalid perf tier:", self.PerfTier)
        return
    end
    
    -- Initialize cone controller (always needed)
    if LanternConeController and LanternConeController.Init then
        local success, err = pcall(function()
            LanternConeController:Init()
        end)
        if not success then
            warn("[StormClient] Failed to init LanternConeController:", err)
        end
    end
    
    -- Initialize visual systems with error handling
    local function tryInitSystem(SystemClass: any, systemName: string): any?
        if not SystemClass then
            if self.DebugMode then
                warn("[StormClient]", systemName, "not available")
            end
            return nil
        end
        
        local success, systemOrError = pcall(function()
            return SystemClass.new(perfConfig, self.PerfTier)
        end)
        
        if success then
            if self.DebugMode then
                print("[StormClient]", systemName, "initialized")
            end
            return systemOrError
        else
            warn("[StormClient] Failed to initialize", systemName, ":", systemOrError)
            return nil
        end
    end
    
    self.Systems.RainBeams = tryInitSystem(RainBeams, "RainBeams")
    self.Systems.RainShells = tryInitSystem(RainShells, "RainShells")
    self.Systems.EdgeBand = tryInitSystem(EdgeBand, "EdgeBand")
    self.Systems.WindGusts = tryInitSystem(WindGusts, "WindGusts")
    self.Systems.DistantWind = tryInitSystem(DistantWind, "DistantWind")
    self.Systems.FogController = tryInitSystem(FogController, "FogController")
    if perfConfig.splashes then
        self.Systems.GroundSplashes = tryInitSystem(GroundSplashes, "GroundSplashes")
    end
    
    if perfConfig.overlays then
        self.Systems.StormOverlays = tryInitSystem(StormOverlays, "StormOverlays")
    end
    
    -- Wind animator (stub for now)
    self.Systems.WindAnimator = tryInitSystem(WindAnimator, "WindAnimator")
    
    if self.DebugMode then
        local activeCount = 0
        for _, system in pairs(self.Systems) do
            if system then activeCount = activeCount + 1 end
        end
        print("[StormClient] Initialized", activeCount, "systems at", self.PerfTier, "tier")
    end
end

-- Reconfigure systems when performance tier changes
function StormClientController:ReconfigureSystems()
    -- Clean up existing systems
    for name, system in pairs(self.Systems) do
        if system and system.Cleanup then
            local success, err = pcall(function()
                system:Cleanup()
            end)
            if not success then
                warn("[StormClient] Failed to cleanup", name, ":", err)
            end
        end
    end
    
    -- Clear systems
    self.Systems = {}
    
    -- Reinitialize with new tier
    self:InitializeSystems()
    
    -- Reapply current state if active
    if self.Active and self.CurrentState then
        self:UpdateSystems(0)
    end
end

-- Update all systems with current storm state
function StormClientController:UpdateSystems(dt: number?)
    if not self.CurrentState or not self.Active then return end
    
    -- Get cone data with error handling
    local conePose, forbiddenAzimuth, lanternEnabled
    
    if LanternConeController then
        local success, err = pcall(function()
            conePose = LanternConeController:GetConePose()
            forbiddenAzimuth = LanternConeController:GetForbiddenAzimuth()
            lanternEnabled = LanternConeController:IsEnabled()
        end)
        
        if not success then
            warn("[StormClient] Failed to get cone data:", err)
            -- Use defaults
            conePose = {
                origin = Vector3.new(),
                dir = Vector3.new(0, 0, -1),
                halfAngleDeg = 26,
                innerClear = 6,
                innerSoft = 12,
                outerSoft = 18
            }
            forbiddenAzimuth = {minDeg = 0, maxDeg = 0}
            lanternEnabled = false
        end
    else
        -- Fallback if cone controller is missing
        conePose = {
            origin = Vector3.new(),
            dir = Vector3.new(0, 0, -1),
            halfAngleDeg = 26,
            innerClear = 6,
            innerSoft = 12,
            outerSoft = 18
        }
        forbiddenAzimuth = {minDeg = 0, maxDeg = 0}
        lanternEnabled = false
    end
    
    -- Update each system with error handling
    for name, system in pairs(self.Systems) do
        if system and system.Update then
            local success, err = pcall(function()
                system:Update(self.CurrentState, conePose, forbiddenAzimuth, lanternEnabled, dt)
            end)
            
            if not success then
                warn("[StormClient] System update failed for", name, ":", err)
                -- Optionally disable the failing system
                if system.Cleanup then
                    pcall(function() system:Cleanup() end)
                end
                self.Systems[name] = nil
            end
        end
    end
end

-- Handle storm state changes from server
function StormClientController:OnStateChanged(newState: StormState)
    self.CurrentState = newState
    
    if self.DebugMode then
        print("[StormClient] State changed - Profile:", newState.profile, "Intensity:", newState.intensity)
    end
    
    if newState.intensity > 0 and not self.Active then
        self:Start()
    elseif newState.intensity == 0 and self.Active then
        self:Stop()
    end
    
    if self.Active then
        self:UpdateSystems(0)
    end
end

-- Start storm rendering
function StormClientController:Start()
    if self.Active then return end
    
    self.Active = true
    self:InitializeSystems()
    self:UpdateSystems(0)
    
    -- Connect render loop with error handling
    self.RenderConnection = RunService.Heartbeat:Connect(function(dt)
        local success, err = pcall(function()
            self:OnHeartbeat(dt)
        end)
        
        if not success then
            warn("[StormClient] Heartbeat error:", err)
            -- Disconnect if critical error
            if self.RenderConnection then
                self.RenderConnection:Disconnect()
                self.RenderConnection = nil
            end
            self.Active = false
        end
    end)
    
    print("[StormClient] Storm started")
end

-- Stop storm rendering
function StormClientController:Stop()
    if not self.Active then return end
    
    self.Active = false
    
    -- Disconnect render loop
    if self.RenderConnection then
        self.RenderConnection:Disconnect()
        self.RenderConnection = nil
    end
    
    -- Clean up all systems with error handling
    for name, system in pairs(self.Systems) do
        if system and system.Cleanup then
            local success, err = pcall(function()
                system:Cleanup()
            end)
            if not success then
                warn("[StormClient] Cleanup failed for", name, ":", err)
            end
        end
    end
    
    self.Systems = {}
    
    print("[StormClient] Storm stopped")
end

-- Frame update
function StormClientController:OnHeartbeat(dt: number)
    if not self.Active then return end
    
    -- FPS monitoring
    lastFpsCheck = lastFpsCheck + dt
    if lastFpsCheck >= fpsCheckInterval then
        local fps = 1 / dt
        updatePerfTier(fps)
        lastFpsCheck = 0
    end
    
    -- Update all systems
    self:UpdateSystems(dt)
end

-- Initialize the controller
function StormClientController:Init()
    print("[StormClient] Initializing storm client controller...")
    
    -- Wait for remotes folder
    local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
    if not remotesFolder then
        warn("[StormClient] Remotes folder not found. Creating fallback...")
        remotesFolder = Instance.new("Folder")
        remotesFolder.Name = "Remotes"
        remotesFolder.Parent = ReplicatedStorage
    end
    
    -- Wait for storm state remote
    local stormStateRemote = remotesFolder:WaitForChild("StormState", 10) :: RemoteEvent?
    if not stormStateRemote then
        warn("[StormClient] StormState remote not found. Storm effects disabled.")
        return
    end
    
    -- Listen for state updates with error handling
    stormStateRemote.OnClientEvent:Connect(function(state: any)
        -- Validate state
        if type(state) ~= "table" then
            warn("[StormClient] Invalid state received from server")
            return
        end
        
        if not state.vector or not state.profile or not state.intensity then
            warn("[StormClient] Incomplete state received from server")
            return
        end
        
        local success, err = pcall(function()
            self:OnStateChanged(state :: StormState)
        end)
        
        if not success then
            warn("[StormClient] Failed to process state change:", err)
        end
    end)
    
    -- Check for existing state values
    local stormStateFolder = ReplicatedStorage:FindFirstChild("StormState")
    if stormStateFolder then
        local vector = stormStateFolder:FindFirstChild("Vector") :: Vector3Value?
        local intensity = stormStateFolder:FindFirstChild("Intensity") :: NumberValue?
        local profile = stormStateFolder:FindFirstChild("Profile") :: StringValue?
        
        if vector and intensity and profile and intensity.Value > 0 then
            -- Reconstruct state from values
            local existingState: StormState = {
                vector = vector.Value,
                profile = profile.Value :: StormTypes.StormProfile,
                intensity = intensity.Value,
                gusts = {}  -- Server will send full state with gusts
            }
            
            local success, err = pcall(function()
                self:OnStateChanged(existingState)
            end)
            
            if not success then
                warn("[StormClient] Failed to apply existing state:", err)
            end
        end
    end
    
    print("[StormClient] Storm client controller initialized")
end

-- Auto-initialize when required with error handling
task.spawn(function()
    local success, err = pcall(function()
        StormClientController:Init()
    end)
    
    if not success then
        warn("[StormClient] Failed to initialize:", err)
    end
end)

return StormClientController







