-- MinionCrafterService.lua
-- Server-side management of crafting minions

local MinionCrafterService = {}
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Constants
local DEFAULT_MINIONS_PER_PLAYER = 3
local MAX_MINIONS_PER_PLAYER = 10
local BASE_CRAFT_SPEED = 1.0 -- Multiplier
local CRAFT_TICK_RATE = 0.1 -- How often to update crafting progress

-- Active crafting jobs
local craftingJobs = {} -- {jobId = {minion, target, progress, speed, startTime}}
local playerMinions = {} -- {playerId = {available = {}, busy = {}, total = number}}

function MinionCrafterService:Initialize()
    -- Start crafting tick
    RunService.Heartbeat:Connect(function()
        self:UpdateCraftingJobs()
    end)
end

function MinionCrafterService:GetPlayerMinions(player)
    if not playerMinions[player.UserId] then
        playerMinions[player.UserId] = {
            available = {},
            busy = {},
            total = DEFAULT_MINIONS_PER_PLAYER,
            speedMultiplier = 1.0
        }
        
        -- Create initial minion pool
        for i = 1, DEFAULT_MINIONS_PER_PLAYER do
            local minionId = "minion_" .. player.UserId .. "_" .. i
            playerMinions[player.UserId].available[minionId] = {
                id = minionId,
                level = 1,
                personality = self:RollMinionPersonality()
            }
        end
    end
    
    return playerMinions[player.UserId]
end

function MinionCrafterService:RollMinionPersonality()
    -- Different personalities affect animation style
    local personalities = {
        "Eager", -- Hammers fast but sloppy
        "Perfectionist", -- Slow but creates better quality
        "Lazy", -- Needs more breaks
        "Cheerful", -- Whistles while working
        "Grumpy", -- Complains but works steady
        "Nervous", -- Jittery animations
        "Proud", -- Shows off completed work
    }
    
    return {
        type = personalities[math.random(#personalities)],
        hammerSpeed = 0.8 + math.random() * 0.4, -- 0.8 to 1.2
        breakFrequency = math.random() * 0.3, -- How often they pause
        qualityBonus = math.random() * 0.2 - 0.1 -- -0.1 to +0.1
    }
end

function MinionCrafterService:AssignMinionToCraft(player, targetObject, craftType, segments)
    local minions = self:GetPlayerMinions(player)
    
    -- Check for available minion
    local minionId, minionData = next(minions.available)
    if not minionId then
        return false, "No available minions"
    end
    
    -- Move minion to busy
    minions.available[minionId] = nil
    minions.busy[minionId] = minionData
    
    -- Create crafting job
    local jobId = "job_" .. tick()
    craftingJobs[jobId] = {
        minionId = minionId,
        minionData = minionData,
        playerId = player.UserId,
        target = targetObject,
        craftType = craftType, -- "lantern", "building", etc.
        segments = segments or {},
        currentSegment = 1,
        segmentProgress = 0,
        totalProgress = 0,
        speed = BASE_CRAFT_SPEED * minions.speedMultiplier * minionData.personality.hammerSpeed,
        startTime = tick(),
        quality = 0.5 + (minionData.personality.qualityBonus or 0) -- Affects final deformation
    }
    
    -- Fire client event to spawn minion visual
    self:FireMinionSpawned(player, jobId, craftingJobs[jobId])
    
    return true, jobId
end

function MinionCrafterService:UpdateCraftingJobs()
    local dt = CRAFT_TICK_RATE
    
    for jobId, job in pairs(craftingJobs) do
        if job.currentSegment <= #job.segments then
            -- Update segment progress
            job.segmentProgress = job.segmentProgress + (job.speed * dt)
            
            -- Check for personality-based breaks
            if math.random() < job.minionData.personality.breakFrequency * dt then
                -- Minion takes a quick break (no progress this tick)
                self:FireMinionBreak(jobId)
            else
                -- Progress the current segment
                if job.segmentProgress >= 1 then
                    -- Complete current segment
                    self:CompleteSegment(jobId, job.currentSegment)
                    
                    job.currentSegment = job.currentSegment + 1
                    job.segmentProgress = 0
                    
                    -- Move minion to next segment position
                    if job.currentSegment <= #job.segments then
                        self:FireMinionMoved(jobId, job.currentSegment)
                    end
                else
                    -- Update visual progress
                    self:FireCraftingProgress(jobId, job.currentSegment, job.segmentProgress)
                end
            end
        else
            -- Job complete
            self:CompleteCraftingJob(jobId)
        end
        
        -- Update total progress for UI
        job.totalProgress = (job.currentSegment - 1 + job.segmentProgress) / #job.segments
    end
end

function MinionCrafterService:CompleteSegment(jobId, segmentIndex)
    local job = craftingJobs[jobId]
    if not job then return end
    
    -- Apply quality-based deformation to completed segment
    local deformAmount = 1 - job.quality -- Higher quality = less deform
    
    -- Fire event for visual completion
    self:FireSegmentCompleted(jobId, segmentIndex, deformAmount)
    
    -- Minion celebrates based on personality
    if job.minionData.personality.type == "Proud" then
        self:FireMinionCelebrate(jobId, "flex")
    elseif job.minionData.personality.type == "Cheerful" then
        self:FireMinionCelebrate(jobId, "dance")
    end
end

function MinionCrafterService:CompleteCraftingJob(jobId)
    local job = craftingJobs[jobId]
    if not job then return end
    
    -- Return minion to available pool
    local minions = playerMinions[job.playerId]
    if minions then
        minions.busy[job.minionId] = nil
        minions.available[job.minionId] = job.minionData
    end
    
    -- Calculate final quality based on minion work
    local finalQuality = job.quality
    
    -- Fire completion event
    self:FireCraftingCompleted(jobId, job.target, finalQuality)
    
    -- Clean up
    craftingJobs[jobId] = nil
end

function MinionCrafterService:UpgradePlayerMinions(player, amount)
    local minions = self:GetPlayerMinions(player)
    
    amount = amount or 1
    local newTotal = math.min(minions.total + amount, MAX_MINIONS_PER_PLAYER)
    
    for i = minions.total + 1, newTotal do
        local minionId = "minion_" .. player.UserId .. "_" .. i
        minions.available[minionId] = {
            id = minionId,
            level = 1,
            personality = self:RollMinionPersonality()
        }
    end
    
    minions.total = newTotal
    return newTotal
end

function MinionCrafterService:BoostMinionSpeed(player, multiplier, duration)
    local minions = self:GetPlayerMinions(player)
    
    minions.speedMultiplier = minions.speedMultiplier * multiplier
    
    if duration then
        task.wait(duration)
        minions.speedMultiplier = minions.speedMultiplier / multiplier
    end
end

-- Network events (stubs)
function MinionCrafterService:FireMinionSpawned(player, jobId, jobData)
    -- Fire to client to create visual minion
end

function MinionCrafterService:FireMinionMoved(jobId, segmentIndex)
    -- Fire to all clients to move minion visual
end

function MinionCrafterService:FireCraftingProgress(jobId, segmentIndex, progress)
    -- Fire to all clients to show building progress
end

function MinionCrafterService:FireSegmentCompleted(jobId, segmentIndex, quality)
    -- Fire to all clients to finalize segment
end

function MinionCrafterService:FireMinionBreak(jobId)
    -- Fire to all clients to play break animation
end

function MinionCrafterService:FireMinionCelebrate(jobId, celebrationType)
    -- Fire to all clients to play celebration
end

function MinionCrafterService:FireCraftingCompleted(jobId, target, quality)
    -- Fire to all clients to finalize object
end

return MinionCrafterService