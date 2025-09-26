-- MinionVisualController.lua
-- Client-side minion animations and visual feedback

local MinionVisualController = {}
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Active minion visuals
local activeMinions = {} -- {jobId = {model, currentSegment, animation}}
local segmentVisuals = {} -- {jobId = {segments = {}}}

-- Minion appearance variations
local MINION_STYLES = {
    Eager = {
        Color = Color3.fromRGB(255, 200, 100),
        HammerSpeed = 2,
        Size = Vector3.new(1, 1.2, 1)
    },
    Perfectionist = {
        Color = Color3.fromRGB(100, 150, 255),
        HammerSpeed = 0.7,
        Size = Vector3.new(1.1, 1, 1.1)
    },
    Lazy = {
        Color = Color3.fromRGB(150, 150, 150),
        HammerSpeed = 0.5,
        Size = Vector3.new(1.2, 0.9, 1.2)
    },
    Cheerful = {
        Color = Color3.fromRGB(255, 100, 255),
        HammerSpeed = 1.5,
        Size = Vector3.new(0.9, 1.1, 0.9)
    },
    Grumpy = {
        Color = Color3.fromRGB(100, 255, 100),
        HammerSpeed = 1,
        Size = Vector3.new(1.3, 0.8, 1.3)
    },
    Nervous = {
        Color = Color3.fromRGB(255, 255, 100),
        HammerSpeed = 3,
        Size = Vector3.new(0.8, 1, 0.8)
    },
    Proud = {
        Color = Color3.fromRGB(200, 100, 200),
        HammerSpeed = 1.2,
        Size = Vector3.new(1, 1.3, 1)
    }
}

function MinionVisualController:Initialize()
    -- Connect to server events
    self:ConnectRemoteEvents()
    
    -- Start animation loop
    RunService.Heartbeat:Connect(function()
        self:UpdateMinionAnimations()
    end)
end

function MinionVisualController:CreateMinionModel(personality, position)
    -- Create simple minion model (placeholder for actual model)
    local minion = Instance.new("Model")
    minion.Name = "CraftingMinion"
    
    -- Body
    local body = Instance.new("Part")
    body.Name = "Body"
    body.Size = Vector3.new(1, 1.5, 0.8) * (MINION_STYLES[personality].Size or Vector3.new(1, 1, 1))
    body.Material = Enum.Material.SmoothPlastic
    body.Color = MINION_STYLES[personality].Color or Color3.fromRGB(150, 150, 150)
    body.TopSurface = Enum.SurfaceType.Smooth
    body.BottomSurface = Enum.SurfaceType.Smooth
    body.Parent = minion
    
    -- Head
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(0.8, 0.8, 0.8) * (MINION_STYLES[personality].Size or Vector3.new(1, 1, 1))
    head.Shape = Enum.PartType.Ball
    head.Material = Enum.Material.SmoothPlastic
    head.Color = body.Color
    head.TopSurface = Enum.SurfaceType.Smooth
    head.BottomSurface = Enum.SurfaceType.Smooth
    head.Parent = minion
    
    -- Hammer
    local hammer = Instance.new("Part")
    hammer.Name = "Hammer"
    hammer.Size = Vector3.new(0.3, 1, 0.5)
    hammer.Material = Enum.Material.Metal
    hammer.Color = Color3.fromRGB(100, 100, 100)
    hammer.Parent = minion
    
    -- Position parts
    body.CFrame = CFrame.new(position)
    head.CFrame = body.CFrame * CFrame.new(0, 1, 0)
    hammer.CFrame = body.CFrame * CFrame.new(1, 0, 0)
    
    -- Welds
    local headWeld = Instance.new("WeldConstraint")
    headWeld.Part0 = body
    headWeld.Part1 = head
    headWeld.Parent = body
    
    local hammerWeld = Instance.new("WeldConstraint")
    hammerWeld.Part0 = body
    hammerWeld.Part1 = hammer
    hammerWeld.Parent = body
    
    -- Make primary part
    minion.PrimaryPart = body
    
    -- Anchoring
    for _, part in pairs(minion:GetChildren()) do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.CanCollide = false
        end
    end
    
    minion.Parent = workspace
    return minion
end

function MinionVisualController:SpawnMinion(jobId, jobData, targetPosition)
    -- Calculate spawn position (near the first segment)
    local spawnPos = targetPosition + Vector3.new(2, 0, 0)
    
    -- Create minion model
    local minionModel = self:CreateMinionModel(jobData.minionData.personality.type, spawnPos)
    
    -- Store reference
    activeMinions[jobId] = {
        model = minionModel,
        personality = jobData.minionData.personality.type,
        currentSegment = 1,
        hammerSpeed = MINION_STYLES[jobData.minionData.personality.type].HammerSpeed or 1,
        isHammering = false,
        hammerAngle = 0
    }
    
    -- Spawn effect
    self:PlaySpawnEffect(spawnPos)
    
    -- Start hammering animation
    self:StartHammering(jobId)
end

function MinionVisualController:StartHammering(jobId)
    local minion = activeMinions[jobId]
    if not minion then return end
    
    minion.isHammering = true
end

function MinionVisualController:UpdateMinionAnimations()
    for jobId, minion in pairs(activeMinions) do
        if minion.isHammering and minion.model and minion.model.Parent then
            -- Animate hammer swing
            local hammer = minion.model:FindFirstChild("Hammer")
            if hammer then
                minion.hammerAngle = minion.hammerAngle + (minion.hammerSpeed * 0.2)
                local swingAngle = math.sin(minion.hammerAngle) * 45
                
                hammer.CFrame = minion.model.PrimaryPart.CFrame * 
                    CFrame.new(1, 0, 0) * 
                    CFrame.Angles(math.rad(swingAngle), 0, 0)
                
                -- Add impact effect at swing bottom
                if math.sin(minion.hammerAngle) < -0.9 and math.sin(minion.hammerAngle - 0.2) > -0.9 then
                    self:PlayHammerImpact(hammer.Position)
                end
            end
            
            -- Subtle body movement
            local body = minion.model.PrimaryPart
            if body then
                local bobAmount = math.sin(minion.hammerAngle * 0.5) * 0.05
                body.CFrame = body.CFrame * CFrame.new(0, bobAmount, 0)
            end
        end
    end
end

function MinionVisualController:MoveMinion(jobId, segmentIndex, targetPosition)
    local minion = activeMinions[jobId]
    if not minion or not minion.model then return end
    
    minion.isHammering = false
    minion.currentSegment = segmentIndex
    
    -- Calculate new position near segment
    local newPos = targetPosition + Vector3.new(1.5, 0, 0) + Vector3.new(
        math.random() - 0.5,
        0,
        math.random() - 0.5
    ) * 0.5
    
    -- Tween to new position
    local tween = TweenService:Create(
        minion.model.PrimaryPart,
        TweenInfo.new(0.5, Enum.EasingStyle.Quad),
        {CFrame = CFrame.new(newPos)}
    )
    
    tween:Play()
    tween.Completed:Connect(function()
        minion.isHammering = true
    end)
end

function MinionVisualController:UpdateSegmentProgress(jobId, segmentIndex, progress)
    -- Create/update visual segment being built
    if not segmentVisuals[jobId] then
        segmentVisuals[jobId] = {segments = {}}
    end
    
    local segment = segmentVisuals[jobId].segments[segmentIndex]
    if segment and segment.Parent then
        -- Scale up the segment based on progress
        local targetSize = segment:GetAttribute("TargetSize") or Vector3.new(1, 1, 1)
        segment.Size = targetSize * Vector3.new(
            math.min(progress, 1),
            math.min(progress * 1.2, 1), -- Height grows slightly faster
            math.min(progress, 1)
        )
        
        -- Add construction particles at low progress
        if progress < 0.5 then
            self:ShowConstructionDust(segment.Position)
        end
    end
end

function MinionVisualController:CompleteSegment(jobId, segmentIndex, quality)
    local segment = segmentVisuals[jobId] and segmentVisuals[jobId].segments[segmentIndex]
    if not segment then return end
    
    -- Apply final quality-based deformation
    local deformAmount = 1 - quality
    
    -- Add wobble based on quality
    local wobbleX = (math.random() - 0.5) * deformAmount * 0.3
    local wobbleZ = (math.random() - 0.5) * deformAmount * 0.3
    
    segment.CFrame = segment.CFrame * CFrame.Angles(
        math.rad(wobbleX * 10),
        0,
        math.rad(wobbleZ * 10)
    )
    
    -- Completion effect
    self:PlaySegmentCompleteEffect(segment.Position)
end

function MinionVisualController:MinionBreak(jobId)
    local minion = activeMinions[jobId]
    if not minion then return end
    
    minion.isHammering = false
    
    -- Play break animation (minion wipes forehead, stretches, etc.)
    local body = minion.model.PrimaryPart
    if body then
        -- Simple stretch animation
        TweenService:Create(body, TweenInfo.new(0.5), {
            CFrame = body.CFrame * CFrame.new(0, 0.2, 0)
        }):Play()
        
        task.wait(0.5)
        
        TweenService:Create(body, TweenInfo.new(0.5), {
            CFrame = body.CFrame * CFrame.new(0, -0.2, 0)
        }):Play()
    end
    
    task.wait(1)
    minion.isHammering = true
end

function MinionVisualController:MinionCelebrate(jobId, celebrationType)
    local minion = activeMinions[jobId]
    if not minion or not minion.model then return end
    
    minion.isHammering = false
    
    if celebrationType == "flex" then
        -- Proud minion flexes
        self:PlayFlexAnimation(minion.model)
    elseif celebrationType == "dance" then
        -- Cheerful minion dances
        self:PlayDanceAnimation(minion.model)
    else
        -- Default celebration - jump
        self:PlayJumpAnimation(minion.model)
    end
    
    task.wait(2)
    minion.isHammering = true
end

function MinionVisualController:CompleteJob(jobId)
    local minion = activeMinions[jobId]
    if not minion then return end
    
    -- Final celebration
    self:MinionCelebrate(jobId, "dance")
    
    -- Despawn effect
    task.wait(1)
    self:PlayDespawnEffect(minion.model.PrimaryPart.Position)
    
    -- Clean up
    if minion.model then
        minion.model:Destroy()
    end
    
    activeMinions[jobId] = nil
    segmentVisuals[jobId] = nil
end

-- Visual effects
function MinionVisualController:PlaySpawnEffect(position)
    -- Poof of smoke effect when minion appears
    local effect = Instance.new("Part")
    effect.Size = Vector3.new(2, 2, 2)
    effect.Position = position
    effect.Anchored = true
    effect.CanCollide = false
    effect.Transparency = 0.5
    effect.Material = Enum.Material.ForceField
    effect.Color = Color3.new(1, 1, 1)
    effect.Shape = Enum.PartType.Ball
    effect.Parent = workspace
    
    TweenService:Create(effect, TweenInfo.new(0.5), {
        Size = Vector3.new(4, 4, 4),
        Transparency = 1
    }):Play()
    
    task.wait(0.5)
    effect:Destroy()
end

function MinionVisualController:PlayHammerImpact(position)
    -- Small dust cloud on hammer impact
    -- This would be a particle effect in production
end

function MinionVisualController:ShowConstructionDust(position)
    -- Sawdust/metal shaving particles during construction
    -- Particle effect stub
end

function MinionVisualController:PlaySegmentCompleteEffect(position)
    -- Sparkle effect when segment is done
    -- Particle effect stub
end

function MinionVisualController:PlayDespawnEffect(position)
    -- Reverse of spawn effect
    self:PlaySpawnEffect(position)
end

-- Animation stubs
function MinionVisualController:PlayFlexAnimation(model)
    -- Proud minion flex animation
    local body = model.PrimaryPart
    if body then
        TweenService:Create(body, TweenInfo.new(0.3), {
            Size = body.Size * 1.2
        }):Play()
        
        task.wait(0.5)
        
        TweenService:Create(body, TweenInfo.new(0.3), {
            Size = body.Size / 1.2
        }):Play()
    end
end

function MinionVisualController:PlayDanceAnimation(model)
    -- Cheerful minion dance
    local body = model.PrimaryPart
    if body then
        for i = 1, 4 do
            TweenService:Create(body, TweenInfo.new(0.2), {
                CFrame = body.CFrame * CFrame.new(0.2, 0, 0)
            }):Play()
            task.wait(0.2)
            
            TweenService:Create(body, TweenInfo.new(0.2), {
                CFrame = body.CFrame * CFrame.new(-0.4, 0, 0)
            }):Play()
            task.wait(0.2)
            
            TweenService:Create(body, TweenInfo.new(0.2), {
                CFrame = body.CFrame * CFrame.new(0.2, 0, 0)
            }):Play()
            task.wait(0.2)
        end
    end
end

function MinionVisualController:PlayJumpAnimation(model)
    -- Simple jump celebration
    local body = model.PrimaryPart
    if body then
        TweenService:Create(body, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            CFrame = body.CFrame * CFrame.new(0, 2, 0)
        }):Play()
        
        task.wait(0.3)
        
        TweenService:Create(body, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            CFrame = body.CFrame * CFrame.new(0, -2, 0)
        }):Play()
    end
end

function MinionVisualController:ConnectRemoteEvents()
    -- Connect to server events when remotes are set up
    -- This is a stub for now
end

return MinionVisualController