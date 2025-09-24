--!strict
-- WindAnimator.luau
-- Stub for wind animation system (spring sway for props)

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local StormTypes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("StormTypes"))

type StormState = StormTypes.StormState
type ConePose = StormTypes.ConePose
type ForbiddenAzimuth = StormTypes.ForbiddenAzimuth
type PerfConfig = StormTypes.PerfConfig

local WindAnimator = {}
WindAnimator.__index = WindAnimator

-- Spring physics for smooth sway
local Spring = {}
Spring.__index = Spring

function Spring.new(stiffness: number, damping: number)
    local self = setmetatable({}, Spring)
    self.Stiffness = stiffness or 100
    self.Damping = damping or 10
    self.Position = Vector3.new()
    self.Velocity = Vector3.new()
    self.Target = Vector3.new()
    return self
end

function Spring:Update(dt: number)
    local displacement = self.Target - self.Position
    local springForce = displacement * self.Stiffness
    local dampingForce = self.Velocity * self.Damping
    
    local acceleration = springForce - dampingForce
    self.Velocity = self.Velocity + acceleration * dt
    self.Position = self.Position + self.Velocity * dt
    
    return self.Position
end

function Spring:SetTarget(target: Vector3)
    self.Target = target
end

-- Wind Animator implementation
function WindAnimator.new(perfConfig: PerfConfig)
    local self = setmetatable({}, WindAnimator)
    
    self.PerfConfig = perfConfig
    self.AnimatedProps = {}
    self.Springs = {}
    self.Active = false
    
    self:Initialize()
    
    return self
end

function WindAnimator:Initialize()
    -- Stub: Would scan for animatable props in the world
    -- For now, just prepare the system
    
    self.Active = true
    
    -- Example props to animate (would be found dynamically)
    local propsToAnimate = {
        -- Lantern posts
        "LanternPost",
        "StreetLamp",
        -- Banners and flags
        "Banner",
        "Flag", 
        "Shrine",
        -- Vegetation
        "Tree",
        "Bush",
        "Grass"
    }
    
    -- Set up springs for each prop type
    -- In production, would scan workspace for these
end

function WindAnimator:RegisterProp(prop: BasePart)
    if not prop:IsA("BasePart") then return end
    
    local spring = Spring.new(50, 8)  -- Tunable stiffness and damping
    
    table.insert(self.AnimatedProps, {
        part = prop,
        originalCFrame = prop.CFrame,
        spring = spring
    })
end

function WindAnimator:Update(state: StormState, conePose: ConePose, forbidden: ForbiddenAzimuth, lanternEnabled: boolean)
    if not self.Active or #self.AnimatedProps == 0 then return end
    
    -- Calculate wind force from storm state
    local windStrength = state.intensity
    local windDirection = state.vector
    
    -- Check for active gusts
    local currentTime = tick()
    local gustMultiplier = 1.0
    for _, gust in ipairs(state.gusts) do
        if currentTime >= gust.t and currentTime <= gust.t + gust.dur then
            -- Smoothly interpolate gust strength
            local gustProgress = (currentTime - gust.t) / gust.dur
            local gustEnvelope = math.sin(gustProgress * math.pi)  -- Smooth rise and fall
            gustMultiplier = 1 + (gust.mult - 1) * gustEnvelope
            break
        end
    end
    
    -- Apply wind to animated props
    for _, propData in ipairs(self.AnimatedProps) do
        local part = propData.part
        if not part.Parent then
            continue  -- Skip destroyed parts
        end
        
        -- Calculate sway based on wind
        local swayTarget = windDirection * windStrength * gustMultiplier * 2
        
        -- Add some noise for natural movement
        local noise = Vector3.new(
            math.sin(currentTime * 1.3) * 0.1,
            math.sin(currentTime * 2.1) * 0.05,
            math.cos(currentTime * 1.7) * 0.1
        )
        
        swayTarget = swayTarget + noise * windStrength
        
        -- Update spring target
        propData.spring:SetTarget(swayTarget)
        
        -- Update position
        local swayOffset = propData.spring:Update(1/60)  -- Fixed timestep for stability
        
        -- Apply rotation based on sway (lean into wind)
        local lean = CFrame.Angles(
            swayOffset.Z * 0.1,  -- Pitch
            0,
            -swayOffset.X * 0.1  -- Roll
        )
        
        -- Apply to part
        part.CFrame = propData.originalCFrame * lean * CFrame.new(swayOffset * 0.5)
    end
end

function WindAnimator:Cleanup()
    -- Reset all animated props to original positions
    for _, propData in ipairs(self.AnimatedProps) do
        if propData.part.Parent then
            propData.part.CFrame = propData.originalCFrame
        end
    end
    
    self.AnimatedProps = {}
    self.Springs = {}
    self.Active = false
end

return WindAnimator