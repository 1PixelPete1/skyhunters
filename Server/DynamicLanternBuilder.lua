-- DynamicLanternBuilder.lua
-- Builds lanterns with randomized segments and artisan imperfection

local DynamicLanternBuilder = {}

-- Lantern segment definitions
local SEGMENT_TYPES = {
    Base = {
        Models = {"LanternBase_1", "LanternBase_2", "LanternBase_3"},
        Height = {Min = 0.5, Max = 0.8},
        CanDeform = true
    },
    Pole = {
        Models = {"LanternPole_Straight", "LanternPole_Curved"},
        Height = {Min = 2, Max = 3},
        CanDeform = true,
        CanRepeat = true, -- Can have multiple pole segments
        MaxRepeat = 3
    },
    IronWork = {
        Models = {"IronCurl_1", "IronCurl_2", "IronCurl_3", "IronCurl_4", "IronCurl_5"},
        Height = {Min = 0.3, Max = 0.5},
        CanDeform = true,
        Decorative = true -- Optional segment
    },
    Chamber = {
        Models = {"GlassChamber_Round", "GlassChamber_Square", "GlassChamber_Hexagon"},
        Height = {Min = 0.8, Max = 1.2},
        CanDeform = false, -- Glass doesn't deform (factory-made)
        IsHead = true -- This is the pluckable part
    },
    Top = {
        Models = {"LanternTop_Point", "LanternTop_Flat", "LanternTop_Ornate"},
        Height = {Min = 0.3, Max = 0.5},
        CanDeform = true
    }
}

-- Rarity affects craftsmanship quality
local RARITY_QUALITY = {
    [1] = {Quality = 0.3, SegmentCount = {2, 3}}, -- Common - very wonky, few segments
    [2] = {Quality = 0.5, SegmentCount = {3, 4}}, -- Uncommon - somewhat wonky
    [3] = {Quality = 0.7, SegmentCount = {4, 5}}, -- Rare - mostly straight
    [4] = {Quality = 0.85, SegmentCount = {5, 6}}, -- Epic - nearly perfect
    [5] = {Quality = 0.95, SegmentCount = {6, 7}} -- Legendary - suspiciously perfect
}

function DynamicLanternBuilder:GenerateLanternPlan(rarity, seed)
    math.randomseed(seed or tick())
    
    local quality = RARITY_QUALITY[rarity] or RARITY_QUALITY[1]
    local segmentCount = math.random(quality.SegmentCount[1], quality.SegmentCount[2])
    
    local plan = {
        rarity = rarity,
        quality = quality.Quality,
        seed = seed,
        segments = {},
        totalHeight = 0,
        deformations = {}
    }
    
    -- Always start with base
    table.insert(plan.segments, {
        type = "Base",
        model = SEGMENT_TYPES.Base.Models[math.random(#SEGMENT_TYPES.Base.Models)],
        height = self:RandomInRange(SEGMENT_TYPES.Base.Height),
        deform = self:GenerateDeformation(quality.Quality)
    })
    
    -- Add pole segments (1-3 based on segment count)
    local poleCount = math.min(math.random(1, 3), segmentCount - 3) -- Leave room for chamber and top
    for i = 1, poleCount do
        table.insert(plan.segments, {
            type = "Pole",
            model = SEGMENT_TYPES.Pole.Models[math.random(#SEGMENT_TYPES.Pole.Models)],
            height = self:RandomInRange(SEGMENT_TYPES.Pole.Height),
            deform = self:GenerateDeformation(quality.Quality)
        })
    end
    
    -- Maybe add decorative ironwork (higher rarity = more likely)
    if math.random() < (rarity / 5) then
        table.insert(plan.segments, {
            type = "IronWork",
            model = SEGMENT_TYPES.IronWork.Models[math.random(#SEGMENT_TYPES.IronWork.Models)],
            height = self:RandomInRange(SEGMENT_TYPES.IronWork.Height),
            deform = self:GenerateDeformation(quality.Quality * 0.5) -- Extra wonky decorations
        })
    end
    
    -- Always add chamber (the functional part)
    table.insert(plan.segments, {
        type = "Chamber",
        model = SEGMENT_TYPES.Chamber.Models[math.random(#SEGMENT_TYPES.Chamber.Models)],
        height = self:RandomInRange(SEGMENT_TYPES.Chamber.Height),
        deform = {lean = 0, twist = 0, bulge = 1, stretch = 1} -- No deformation for glass
    })
    
    -- Always end with top
    table.insert(plan.segments, {
        type = "Top",
        model = SEGMENT_TYPES.Top.Models[math.random(#SEGMENT_TYPES.Top.Models)],
        height = self:RandomInRange(SEGMENT_TYPES.Top.Height),
        deform = self:GenerateDeformation(quality.Quality)
    })
    
    -- Calculate total height
    for _, segment in ipairs(plan.segments) do
        plan.totalHeight = plan.totalHeight + segment.height
    end
    
    -- Generate overall lantern deformation (affects entire structure)
    plan.overallDeform = {
        lean = (math.random() - 0.5) * 20 * (1 - quality.Quality), -- -10 to 10 degrees
        twist = (math.random() - 0.5) * 15 * (1 - quality.Quality), -- -7.5 to 7.5 degrees
        sway = math.random() * 0.1 * (1 - quality.Quality) -- 0 to 0.1 units of sway
    }
    
    return plan
end

function DynamicLanternBuilder:BuildLanternFromPlan(plan, position, useMinionConstruction)
    local lanternModel = Instance.new("Model")
    lanternModel.Name = "DynamicLantern_" .. plan.seed
    
    local segments = {}
    local currentHeight = 0
    
    if useMinionConstruction then
        -- Return segment data for minion to build
        for i, segmentPlan in ipairs(plan.segments) do
            table.insert(segments, {
                index = i,
                type = segmentPlan.type,
                model = segmentPlan.model,
                position = position + Vector3.new(0, currentHeight, 0),
                height = segmentPlan.height,
                deform = segmentPlan.deform,
                isHead = segmentPlan.type == "Chamber"
            })
            currentHeight = currentHeight + segmentPlan.height
        end
        
        return {
            model = lanternModel,
            segments = segments,
            plan = plan
        }
    else
        -- Build immediately without minions
        for i, segmentPlan in ipairs(plan.segments) do
            local segment = self:CreateSegment(segmentPlan, position + Vector3.new(0, currentHeight, 0))
            segment.Parent = lanternModel
            currentHeight = currentHeight + segmentPlan.height
            
            if segmentPlan.type == "Chamber" then
                lanternModel.PrimaryPart = segment
                segment.Name = "HeadChamber" -- Mark as pluckable
            end
        end
        
        -- Apply overall deformation
        self:ApplyOverallDeformation(lanternModel, plan.overallDeform)
        
        lanternModel.Parent = workspace
        return lanternModel
    end
end

function DynamicLanternBuilder:CreateSegment(segmentPlan, position)
    -- This creates the actual part (placeholder for now)
    -- In production, this would load the actual model
    
    local part = Instance.new("Part")
    part.Name = segmentPlan.type .. "_Segment"
    part.Size = Vector3.new(1, segmentPlan.height, 1)
    part.Position = position
    part.Anchored = true
    part.CanCollide = false
    
    -- Apply material based on type
    if segmentPlan.type == "Chamber" then
        part.Material = Enum.Material.Glass
        part.Transparency = 0.3
        part.Color = Color3.fromRGB(200, 200, 255)
    elseif segmentPlan.type == "Base" or segmentPlan.type == "Top" then
        part.Material = Enum.Material.Slate
        part.Color = Color3.fromRGB(80, 80, 90)
    else
        part.Material = Enum.Material.Metal
        part.Color = Color3.fromRGB(60, 60, 65)
    end
    
    -- Apply segment deformation
    if segmentPlan.deform then
        self:ApplySegmentDeformation(part, segmentPlan.deform)
    end
    
    return part
end

function DynamicLanternBuilder:GenerateDeformation(quality)
    local deformStrength = 1 - quality
    
    return {
        lean = (math.random() - 0.5) * 10 * deformStrength, -- Degrees
        twist = (math.random() - 0.5) * 8 * deformStrength, -- Degrees
        bulge = 1 + (math.random() - 0.5) * 0.3 * deformStrength, -- Scale factor
        stretch = 1 + (math.random() - 0.5) * 0.2 * deformStrength -- Height factor
    }
end

function DynamicLanternBuilder:ApplySegmentDeformation(part, deform)
    -- Apply deformation to individual segment
    part.CFrame = part.CFrame * CFrame.Angles(
        math.rad(deform.lean),
        math.rad(deform.twist),
        0
    )
    
    part.Size = part.Size * Vector3.new(
        deform.bulge,
        deform.stretch,
        deform.bulge
    )
end

function DynamicLanternBuilder:ApplyOverallDeformation(model, deform)
    -- Apply overall lantern lean/twist
    if model.PrimaryPart then
        local originalCFrame = model.PrimaryPart.CFrame
        model:SetPrimaryPartCFrame(
            originalCFrame * CFrame.Angles(
                math.rad(deform.lean),
                math.rad(deform.twist),
                math.rad(deform.sway * 5)
            )
        )
    end
end

function DynamicLanternBuilder:RandomInRange(range)
    return range.Min + (math.random() * (range.Max - range.Min))
end

-- Head lantern specific functions
function DynamicLanternBuilder:CanPluckHead(lanternModel)
    -- Check if lantern has a chamber segment
    return lanternModel:FindFirstChild("HeadChamber") ~= nil
end

function DynamicLanternBuilder:PluckHead(lanternModel)
    local head = lanternModel:FindFirstChild("HeadChamber")
    if not head then return nil end
    
    -- Create plucked version
    local pluckedHead = head:Clone()
    pluckedHead.Name = "PluckedHead"
    
    -- Make original transparent (showing it's missing)
    head.Transparency = 0.8
    head.Material = Enum.Material.ForceField
    
    -- Start regrow timer
    task.spawn(function()
        self:RegrowHead(lanternModel, head)
    end)
    
    return pluckedHead
end

function DynamicLanternBuilder:RegrowHead(lanternModel, headPart)
    -- Gradually regrow the head over time
    local regrowTime = 300 -- 5 minutes
    local steps = 50
    local stepTime = regrowTime / steps
    
    for i = 1, steps do
        task.wait(stepTime)
        if headPart and headPart.Parent then
            local progress = i / steps
            headPart.Transparency = 0.8 - (0.5 * progress) -- 0.8 to 0.3
            
            -- Add glow effect as it regrows
            if i == steps then
                headPart.Material = Enum.Material.Glass
                headPart.Transparency = 0.3
            end
        else
            break
        end
    end
end

return DynamicLanternBuilder