--!strict
-- EnhancedStormController.client.luau
-- Enhanced storm controller with Dense Storm Wall system integration

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

-- Import storm modules
local BlizzardSprites = require(script.Parent.Fields:WaitForChild("BlizzardSprites")) -- NEW: Proper blizzard effect
local RainWall = require(script.Parent.Fields:WaitForChild("RainWall")) -- NEW: Flickering rain wall
local WindGusts = require(script.Parent.Fields:WaitForChild("WindGusts"))
local RainShells = require(script.Parent.Fields:WaitForChild("RainShells"))
local RainBeams = require(script.Parent.Fields:WaitForChild("RainBeams"))
local SurroundingAirEffect = require(script.Parent.Fields:WaitForChild("SurroundingAirEffect"))
local SurroundingAirEffectEnhanced = require(script.Parent.Fields:WaitForChild("SurroundingAirEffectEnhanced"))
local RotatingWindSprites = require(script.Parent.Fields:WaitForChild("RotatingWindSprites"))
local StormOverlays = require(script.Parent.Overlays:WaitForChild("StormOverlays"))
local StormOverlaysEnhanced = require(script.Parent.Overlays:WaitForChild("StormOverlaysEnhanced"))
local LanternBackAttachment = require(script.Parent:WaitForChild("LanternBackAttachment"))
local StormDebugConfig = require(script.Parent:WaitForChild("StormDebugConfig"))

-- Import configuration and types
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local StormTypes = require(sharedFolder:WaitForChild("StormTypes"))
local StormConfig = require(sharedFolder:WaitForChild("StormConfig"))

type StormState = StormTypes.StormState
type ConePose = StormTypes.ConePose
type ForbiddenAzimuth = StormTypes.ForbiddenAzimuth
type PerfConfig = StormTypes.PerfConfig

local function detectDevice(): StormTypes.PerfTier
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        local camera = Workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
        if viewport.X * viewport.Y < 1920 * 1080 then
            return "LOW"
        else
            return "MED"
        end
    else
        local ok, level = pcall(function()
            return settings().Rendering.QualityLevel
        end)
        if ok and level and level ~= Enum.QualityLevel.Automatic and level.Value <= 10 then
            return "MED"
        else
            return "HIGH"
        end
    end
end

local EnhancedStormController = {}
EnhancedStormController.__index = EnhancedStormController

function EnhancedStormController.new()
    local self = setmetatable({}, EnhancedStormController)

    -- Performance detection
    self.perfTier = detectDevice()
    self.perfConfig = StormConfig.Perf[self.perfTier]

    -- Storm field systems
    self.blizzardSprites = BlizzardSprites.new(self.perfConfig, self.perfTier) -- NEW: Proper blizzard effect
    self.rainWall = RainWall.new(self.perfConfig, self.perfTier) -- NEW: Flickering rain wall
    self.windGusts = WindGusts.new(self.perfConfig, self.perfTier)
    self.rainShells = RainShells.new(self.perfConfig, self.perfTier)
    self.rainBeams = RainBeams.new(self.perfConfig, self.perfTier)
    self.surroundingAir = SurroundingAirEffect.new(self.perfConfig, self.perfTier) -- Original
    self.surroundingAirEnhanced = SurroundingAirEffectEnhanced.new(self.perfConfig, self.perfTier) -- Enhanced with debug
    self.rotatingSprites = RotatingWindSprites.new(self.perfConfig, self.perfTier) -- Simple rotating sprites
    self.stormOverlays = StormOverlays.new()
    self.stormOverlaysEnhanced = StormOverlaysEnhanced.new() -- Enhanced corner vignettes
    
    -- Lantern attachment system
    self.lanternAttachment = LanternBackAttachment.new()

    -- Storm state
    self.enabled = false
    self.stormState = {
        vector = Vector3.new(0.3, 0, -0.8),
        profile = "RAIN_HEAVY",
        intensity = 0,
        gusts = {},
    }

    -- Lantern system
    self.lanternEnabled = false
    self.conePose = {
        origin = Vector3.new(),
        dir = Vector3.new(0, 0, -1),
        halfAngleDeg = StormConfig.Cone.halfAngleDeg,
        innerClear = StormConfig.Cone.innerClear,
        innerSoft = StormConfig.Cone.innerSoft,
        outerSoft = StormConfig.Cone.outerSoft,
    }
    self.forbiddenAzimuth = {
        minDeg = 0,
        maxDeg = 0,
    }

    -- Atmosphere system
    self.atmosphere = nil
    self.originalAtmosphere = {
        density = 0,
        offset = 0,
        haze = 0,
        color = Color3.new(0.7, 0.75, 0.8),
    }

    -- Update connections
    self.updateConnection = nil
    self.characterConnection = nil

    return self
end

function EnhancedStormController:Initialize()
    print("[EnhancedStorm] Initializing Dense Storm Wall system - Performance tier:", self.perfTier)

    -- Setup atmosphere
    self:InitializeAtmosphere()

    -- Setup lantern tracking
    self:InitializeLanternTracking()

    -- Connect to storm state updates
    self:ConnectStormRemotes()

    -- Start update loop
    self.updateConnection = RunService.Heartbeat:Connect(function(dt)
        self:Update(dt)
    end)

    print("[EnhancedStorm] Dense Storm Wall system initialized successfully")
end

function EnhancedStormController:InitializeAtmosphere()
    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    if not atmosphere then
        atmosphere = Instance.new("Atmosphere")
        atmosphere.Parent = Lighting
    end

    self.atmosphere = atmosphere
    self.originalAtmosphere.density = atmosphere.Density
    self.originalAtmosphere.offset = atmosphere.Offset
    self.originalAtmosphere.haze = atmosphere.Haze
    self.originalAtmosphere.color = atmosphere.Color
end

function EnhancedStormController:InitializeLanternTracking()
    local player = Players.LocalPlayer
    if not player then return end

    -- Initialize lantern state
    self.lanternEnabled = player:GetAttribute("LanternEnabled") == true

    local function setupCharacterTracking(character)
        if not character then return end
        
        -- Attach the lantern backpack to the character
        self.lanternAttachment:Attach(character)
        print("[EnhancedStorm] Attached lantern backpack to character:", character.Name)
        
        -- Track character for lantern position/direction
        self.characterConnection = RunService.Heartbeat:Connect(function()
            self:UpdateLanternPose(character)
        end)
    end

    if player.Character then
        setupCharacterTracking(player.Character)
    end

    player.CharacterAdded:Connect(setupCharacterTracking)
    player.CharacterRemoving:Connect(function()
        if self.characterConnection then
            self.characterConnection:Disconnect()
            self.characterConnection = nil
        end
        -- Clean up lantern attachment when character is removed
        self.lanternAttachment:Cleanup()
    end)
end

function EnhancedStormController:UpdateLanternPose(character)
    local player = Players.LocalPlayer
    if not player then return end

    -- Update lantern enabled state
    self.lanternEnabled = player:GetAttribute("LanternEnabled") == true

    -- Get camera for lantern direction
    local camera = Workspace.CurrentCamera
    if not camera then return end

    -- Update cone pose
    self.conePose.origin = camera.CFrame.Position
    self.conePose.dir = camera.CFrame.LookVector

    -- Calculate forbidden azimuth for lantern cone
    if self.lanternEnabled then
        local forward = camera.CFrame.LookVector
        local angle = math.deg(math.atan2(forward.Z, forward.X))
        local halfAngle = self.conePose.halfAngleDeg + StormConfig.Cone.forbiddenPadDeg
        
        self.forbiddenAzimuth.minDeg = (angle - halfAngle) % 360
        self.forbiddenAzimuth.maxDeg = (angle + halfAngle) % 360
    else
        self.forbiddenAzimuth.minDeg = 0
        self.forbiddenAzimuth.maxDeg = 0
    end
end

function EnhancedStormController:ConnectStormRemotes()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then
        warn("[EnhancedStorm] Remotes folder missing - creating test storm")
        -- Create test storm for development
        self:SetTestStorm()
        return
    end

    local stormRemote = remotes:FindFirstChild("StormState")
    if stormRemote and stormRemote:IsA("RemoteEvent") then
        stormRemote.OnClientEvent:Connect(function(state: StormState)
            self:OnStormStateReceived(state)
        end)
    else
        warn("[EnhancedStorm] StormState remote missing - creating test storm")
        self:SetTestStorm()
    end
end

function EnhancedStormController:SetTestStorm()
    -- Create test storm for development/testing
    self.stormState = {
        vector = Vector3.new(0.4, -0.1, -0.7).Unit,
        profile = "RAIN_HEAVY",
        intensity = 0.8, -- Heavy storm for testing
        gusts = {},
    }
    self.enabled = true
    
    -- Enable lantern for testing
    local player = Players.LocalPlayer
    if player then
        player:SetAttribute("LanternEnabled", true)
        self.lanternEnabled = true
        print("[EnhancedStorm] Test lantern enabled")
    end
    
    print("[EnhancedStorm] Test storm activated - intensity:", self.stormState.intensity)
end

function EnhancedStormController:OnStormStateReceived(state: StormState)
    self.stormState = state
    
    if state.intensity > 0.05 and not self.enabled then
        self.enabled = true
        print("[EnhancedStorm] Storm started - intensity:", state.intensity)
    elseif state.intensity <= 0.05 and self.enabled then
        self.enabled = false
        print("[EnhancedStorm] Storm ended")
    end
end

function EnhancedStormController:UpdateAtmosphere(dt: number)
    if not self.atmosphere then return end

    local intensity = self.stormState.intensity
    local stormConfig = StormConfig.DenseStorm

    -- Calculate target atmosphere values
    local targetDensity = self.originalAtmosphere.density + (0.8 * intensity) -- Heavy fog
    local targetOffset = self.originalAtmosphere.offset - (0.3 * intensity)   -- Lower visibility
    local targetHaze = self.originalAtmosphere.haze + (4 * intensity)         -- Atmospheric haze

    -- Storm color (darker, more blue-grey)
    local stormColor = Color3.fromRGB(80, 90, 105)
    local targetColor = self.originalAtmosphere.color:Lerp(stormColor, intensity * 0.7)

    -- Lantern reduces atmospheric effects
    if self.lanternEnabled then
        local reductionFactor = 0.6 -- 40% atmosphere reduction in lantern area
        targetDensity = targetDensity * reductionFactor
        targetOffset = targetOffset + (self.originalAtmosphere.offset - targetOffset) * 0.4
        targetHaze = targetHaze * reductionFactor
    end

    -- Smooth transitions
    local lerpSpeed = 2 * dt
    self.atmosphere.Density = self.atmosphere.Density + (targetDensity - self.atmosphere.Density) * lerpSpeed
    self.atmosphere.Offset = self.atmosphere.Offset + (targetOffset - self.atmosphere.Offset) * lerpSpeed
    self.atmosphere.Haze = self.atmosphere.Haze + (targetHaze - self.atmosphere.Haze) * lerpSpeed
    self.atmosphere.Color = self.atmosphere.Color:Lerp(targetColor, lerpSpeed)
end

function EnhancedStormController:Update(dt: number)
    -- Update atmosphere effects
    self:UpdateAtmosphere(dt)

    -- Update all storm field systems
    if self.enabled and self.stormState.intensity > 0 then
        local deltaTime = math.min(dt, 1/20) -- Cap delta time for stability
        
        -- Get current gust style from debug config
        local gustConfig = StormDebugConfig:GetGustConfig()
        local useVolumetric = gustConfig and gustConfig.style == "volumetric"
        
        -- Use BlizzardSprites as the primary wind effect system
        self.blizzardSprites:Update(self.stormState, self.conePose, self.forbiddenAzimuth, self.lanternEnabled, deltaTime)
        
        -- Update flickering rain wall for depth
        self.rainWall:Update(self.stormState, self.conePose, self.forbiddenAzimuth, self.lanternEnabled, deltaTime)
        
        -- Update ring sprite systems - just use the new rotating sprites
        self.rotatingSprites:Update(self.stormState, self.conePose, self.forbiddenAzimuth, self.lanternEnabled, deltaTime)
        
        -- Disabled old ring systems - they look bad
        if false then
            local ringConfig = StormDebugConfig:GetRingConfig()
            if ringConfig and ringConfig.enabled then
                -- Use enhanced version
                self.surroundingAirEnhanced:Update(self.stormState, self.conePose, self.forbiddenAzimuth, self.lanternEnabled, deltaTime)
            else
                -- Fallback to original if disabled
                self.surroundingAir:Update(self.stormState, self.conePose, self.forbiddenAzimuth, self.lanternEnabled, deltaTime)
            end
        end
        
        -- Update supporting rain systems
        self.rainShells:Update(self.stormState, self.conePose, self.forbiddenAzimuth, self.lanternEnabled, deltaTime)
        self.rainBeams:Update(self.stormState, self.conePose, self.forbiddenAzimuth, self.lanternEnabled, deltaTime)
        
        -- Update enhanced corner vignettes instead of full overlay
        self.stormOverlaysEnhanced:Update(self.stormState, self.conePose, self.forbiddenAzimuth, self.lanternEnabled, deltaTime)
    end
end

function EnhancedStormController:Cleanup()
    print("[EnhancedStorm] Cleaning up Dense Storm Wall system")

    -- Disconnect update loop
    if self.updateConnection then
        self.updateConnection:Disconnect()
        self.updateConnection = nil
    end

    if self.characterConnection then
        self.characterConnection:Disconnect()
        self.characterConnection = nil
    end

    -- Cleanup storm field systems
    self.blizzardSprites:Cleanup() -- Clean up blizzard effect
    self.rainWall:Cleanup() -- Clean up rain wall
    self.windGusts:Cleanup()
    self.rainShells:Cleanup()
    self.rainBeams:Cleanup()
    self.surroundingAir:Cleanup()
    self.surroundingAirEnhanced:Cleanup()
    self.rotatingSprites:Cleanup()
    self.stormOverlays:Cleanup()
    self.stormOverlaysEnhanced:Cleanup()
    
    -- Cleanup lantern attachment
    self.lanternAttachment:Cleanup()

    -- Restore original atmosphere
    if self.atmosphere then
        self.atmosphere.Density = self.originalAtmosphere.density
        self.atmosphere.Offset = self.originalAtmosphere.offset
        self.atmosphere.Haze = self.originalAtmosphere.haze
        self.atmosphere.Color = self.originalAtmosphere.color
    end

    self.enabled = false
    print("[EnhancedStorm] Cleanup complete")
end

-- Auto-initialize
local controller = EnhancedStormController.new()
controller:Initialize()

-- Cleanup on script destruction
script.AncestryChanged:Connect(function()
    if not script.Parent then
        controller:Cleanup()
    end
end)

return controller
