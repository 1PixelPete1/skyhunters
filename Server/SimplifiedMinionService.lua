-- SimplifiedMinionService.lua
-- Minions as pure visual feedback for predetermined construction

local SimplifiedMinionService = {}
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Constants
local BASE_BUILD_TIME = 10 -- seconds to build a lantern
local SEGMENT_BUILD_TIME = 2 -- seconds per segment

-- Active construction jobs
local activeJobs = {} -- {jobId = {model, segments, progress, minion, startTime}}

-- Radial buffs (boombox, etc.)
local activeBuffs = {} -- {buffId = {position, radius, multiplier, endTime}}

function SimplifiedMinionService:Initialize()
    RunService.Heartbeat:Connect(function()
        self:UpdateConstructions()
        self:CleanExpiredBuffs()
    end)
end

function SimplifiedMinionService:StartConstruction(lanternModel, player)
    -- Construction is purely visual - lantern properties are already set
    local segments = self:GetSegments(lanternModel)
    if #segments == 0 then return end
    
    local jobId = "construction_" .. lanternModel:GetAttribute("LanternSeed")
    
    activeJobs[jobId] = {
        model = lanternModel,
        segments = segments,
        currentSegment = 1,
        segmentProgress = 0,
        player = player,
        startTime = tick(),
        speedMultiplier = 1
    }
    
    -- Spawn minion visual at first segment
    self:SpawnMinionVisual(jobId)
    
    return jobId
end

function SimplifiedMinionService:GetSegments(model)
    local segments = {}
    
    for _, part in ipairs(model:GetChildren()) do
        if part:IsA("BasePart") then
            local index = part:GetAttribute("SegmentIndex")
            if index then
                segments[index] = {
                    part = part,
                    targetSize = part:GetAttribute("TargetSize"),
                    targetTransparency = part:GetAttribute("TargetTransparency") or 0
                }
                
                -- Start with segment invisible and small
                part.Size = part:GetAttribute("TargetSize") * 0.1
                part.Transparency = 1
            end
        end
    end
    
    -- Sort by index
    local sortedSegments = {}
    for i = 1, #segments do
        if segments[i] then
            table.insert(sortedSegments, segments[i])
        end
    end
    
    return sortedSegments
end

function SimplifiedMinionService:UpdateConstructions()
    local dt = RunService.Heartbeat:Wait()
    
    for jobId, job in pairs(activeJobs) do
        if job.currentSegment <= #job.segments then
            -- Check for nearby buffs
            local speedMultiplier = self:GetSpeedMultiplier(job.model.PrimaryPart.Position)
            
            -- Update segment progress
            local progressRate = (1 / SEGMENT_BUILD_TIME) * speedMultiplier
            job.segmentProgress = job.segmentProgress + progressRate * dt
            
            if job.segmentProgress >= 1 then
                -- Complete current segment
                self:CompleteSegment(job, job.currentSegment)
                
                -- Move to next segment
                job.currentSegment = job.currentSegment + 1
                job.segmentProgress = 0
                
                -- Move minion visual if not done
                if job.currentSegment <= #job.segments then
                    self:MoveMinionToSegment(jobId, job.currentSegment)
                end
            else
                -- Update visual progress of current segment
                self:UpdateSegmentVisual(job.segments[job.currentSegment], job.segmentProgress)
            end
        else
            -- Construction complete
            self:CompleteConstruction(jobId)
        end
    end
end

function SimplifiedMinionService:UpdateSegmentVisual(segment, progress)
    if not segment.part or not segment.part.Parent then return end
    
    -- Scale up the segment
    local targetSize = segment.targetSize
    segment.part.Size = targetSize * Vector3.new(
        0.1 + (0.9 * progress), -- Width grows from 10% to 100%
        0.1 + (0.9 * progress), -- Same for depth
        0.2 + (0.8 * progress)  -- Height grows from 20% to 100%
    )
    
    -- Fade in
    segment.part.Transparency = 1 - (1 - segment.targetTransparency) * progress
end

function SimplifiedMinionService:CompleteSegment(job, segmentIndex)
    local segment = job.segments[segmentIndex]
    if not segment then return end
    
    -- Set final size and transparency
    segment.part.Size = segment.targetSize
    segment.part.Transparency = segment.targetTransparency
    
    -- Fire visual effect
    self:FireSegmentComplete(segment.part.Position)
end

function SimplifiedMinionService:CompleteConstruction(jobId)
    local job = activeJobs[jobId]
    if not job then return end
    
    -- Despawn minion
    self:DespawnMinionVisual(jobId)
    
    -- Fire completion effects
    self:FireConstructionComplete(job.model)
    
    -- Clean up
    activeJobs[jobId] = nil
end

-- Radial buff system
function SimplifiedMinionService:AddRadialBuff(position, radius, multiplier, duration)
    local buffId = "buff_" .. tick()
    
    activeBuffs[buffId] = {
        position = position,
        radius = radius,
        multiplier = multiplier,
        endTime = tick() + (duration or math.huge)
    }
    
    return buffId
end

function SimplifiedMinionService:GetSpeedMultiplier(position)
    local totalMultiplier = 1
    
    for _, buff in pairs(activeBuffs) do
        local distance = (position - buff.position).Magnitude
        if distance <= buff.radius then
            -- Stack multiplicatively with falloff
            local falloff = 1 - (distance / buff.radius) * 0.5 -- 50% falloff at edge
            totalMultiplier = totalMultiplier * (1 + (buff.multiplier - 1) * falloff)
        end
    end
    
    return totalMultiplier
end

function SimplifiedMinionService:CleanExpiredBuffs()
    local now = tick()
    for buffId, buff in pairs(activeBuffs) do
        if now > buff.endTime then
            activeBuffs[buffId] = nil
        end
    end
end

-- Visual minion stubs (these fire to client)
function SimplifiedMinionService:SpawnMinionVisual(jobId)
    -- Fire to client to spawn minion model
    local job = activeJobs[jobId]
    if job and job.segments[1] then
        self:FireMinionSpawn(job.player, jobId, job.segments[1].part.Position)
    end
end

function SimplifiedMinionService:MoveMinionToSegment(jobId, segmentIndex)
    local job = activeJobs[jobId]
    if job and job.segments[segmentIndex] then
        self:FireMinionMove(jobId, job.segments[segmentIndex].part.Position)
    end
end

function SimplifiedMinionService:DespawnMinionVisual(jobId)
    self:FireMinionDespawn(jobId)
end

-- Network event stubs
function SimplifiedMinionService:FireMinionSpawn(player, jobId, position)
    -- Fire to client
end

function SimplifiedMinionService:FireMinionMove(jobId, position)
    -- Fire to all clients
end

function SimplifiedMinionService:FireMinionDespawn(jobId)
    -- Fire to all clients
end

function SimplifiedMinionService:FireSegmentComplete(position)
    -- Fire effect to all clients
end

function SimplifiedMinionService:FireConstructionComplete(model)
    -- Fire celebration to all clients
end

return SimplifiedMinionService