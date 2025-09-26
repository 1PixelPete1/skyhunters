-- LanternGenerationService.lua
-- Server-side lantern generation with deterministic seed-based randomization

local LanternGenerationService = {}
local RunService = game:GetService("RunService")

-- Lantern type templates
local LANTERN_TEMPLATES = {
    Basic = {
        BaseCurve = "straight",
        SegmentCount = {Min = 3, Max = 5},
        Height = {Min = 3, Max = 4},
        MaterialWeight = "iron",
        Rarity = 1
    },
    Twisted = {
        BaseCurve = "sinusoidal",
        SegmentCount = {Min = 4, Max = 7},
        Height = {Min = 4, Max = 6},
        MaterialWeight = "copper",
        Rarity = 2
    },
    Ornate = {
        BaseCurve = "helical",
        SegmentCount = {Min = 5, Max = 8},
        Height = {Min = 5, Max = 7},
        MaterialWeight = "brass",
        Rarity = 3
    }
}

-- Curve mutations (rare overrides)
local CURVE_MUTATIONS = {
    spiral = {Chance = 0.01, Override = "spiral"},
    chaotic = {Chance = 0.005, Override = "chaotic"},
    perfect = {Chance = 0.002, Override = "perfect"}, -- Suspiciously straight
    fractal = {Chance = 0.001, Override = "fractal"}
}

-- Bell curve parameters for "artisan imperfection"
local IMPERFECTION_PARAMS = {
    Mean = 0,
    StdDev = 0.15, -- How much variation from perfect
    MaxDeviation = 0.5 -- Cap on wonkiness
}

function LanternGenerationService:GenerateLantern(lanternType, position, plotId)
    -- Generate deterministic seed from position and plot
    local seed = self:GenerateSeed(position, plotId)
    math.randomseed(seed)
    
    -- Get template
    local template = LANTERN_TEMPLATES[lanternType] or LANTERN_TEMPLATES.Basic
    
    -- Generate lantern specifications
    local specs = {
        seed = seed,
        type = lanternType,
        position = position,
        plotId = plotId,
        timestamp = tick(),
        
        -- Base properties from template
        segmentCount = math.random(template.SegmentCount.Min, template.SegmentCount.Max),
        totalHeight = self:RandomInRange(template.Height),
        baseCurve = template.BaseCurve,
        material = template.MaterialWeight,
        rarity = template.Rarity,
        
        -- Deformations (bell curve for natural variation)
        deformations = {},
        
        -- Check for rare mutations
        mutation = nil
    }
    
    -- Roll for curve mutation
    specs.mutation = self:RollMutation()
    if specs.mutation then
        specs.baseCurve = specs.mutation -- Override the curve type
    end
    
    -- Generate segment deformations using bell curve
    for i = 1, specs.segmentCount do
        specs.deformations[i] = {
            lean = self:BellCurveRandom() * 10, -- -5 to 5 degrees typically
            twist = self:BellCurveRandom() * 8,
            scale = 1 + self:BellCurveRandom() * 0.2, -- 0.8 to 1.2 typically
            offset = Vector3.new(
                self:BellCurveRandom() * 0.1,
                0,
                self:BellCurveRandom() * 0.1
            )
        }
    end
    
    -- Store in server memory for consistency
    self:StoreLanternSpecs(specs)
    
    -- Create the physical model
    local lanternModel = self:BuildLanternModel(specs)
    
    -- Trigger minion construction
    self:StartConstruction(lanternModel, specs)
    
    return lanternModel, specs
end

function LanternGenerationService:GenerateSeed(position, plotId)
    -- Deterministic seed based on position and plot
    -- This ensures the same lantern always generates at the same spot
    local x, y, z = math.floor(position.X * 100), math.floor(position.Y * 100), math.floor(position.Z * 100)
    local plotHash = 0
    for i = 1, #plotId do
        plotHash = plotHash + string.byte(plotId, i) * i
    end
    
    return x * 1000000 + y * 1000 + z + plotHash
end

function LanternGenerationService:BellCurveRandom()
    -- Box-Muller transform for normal distribution
    local u1 = math.random()
    local u2 = math.random()
    
    -- Avoid log(0)
    if u1 < 0.0001 then u1 = 0.0001 end
    
    local z0 = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
    
    -- Scale and clamp
    local value = z0 * IMPERFECTION_PARAMS.StdDev + IMPERFECTION_PARAMS.Mean
    return math.max(-IMPERFECTION_PARAMS.MaxDeviation, 
           math.min(IMPERFECTION_PARAMS.MaxDeviation, value))
end

function LanternGenerationService:RollMutation()
    local roll = math.random()
    local cumulative = 0
    
    for mutationType, data in pairs(CURVE_MUTATIONS) do
        cumulative = cumulative + data.Chance
        if roll <= cumulative then
            return data.Override
        end
    end
    
    return nil
end

function LanternGenerationService:BuildLanternModel(specs)
    local model = Instance.new("Model")
    model.Name = "Lantern_" .. specs.seed
    
    -- Build segments based on curve type
    local segments = self:GenerateSegments(specs)
    
    -- Create each segment (initially invisible for construction)
    for i, segment in ipairs(segments) do
        local part = self:CreateSegmentPart(segment, i, specs)
        part.Transparency = 1 -- Start invisible
        part.CanCollide = false
        part.Anchored = true
        part.Parent = model
        
        -- Tag for minion construction
        part:SetAttribute("SegmentIndex", i)
        part:SetAttribute("TargetSize", part.Size)
        part:SetAttribute("TargetTransparency", segment.type == "Chamber" and 0.3 or 0)
        
        if segment.type == "Chamber" then
            model.PrimaryPart = part
            part.Name = "HeadChamber"
        end
    end
    
    model:SetAttribute("LanternSeed", specs.seed)
    model:SetAttribute("LanternType", specs.type)
    model:SetAttribute("Rarity", specs.rarity)
    model:SetAttribute("Mutation", specs.mutation or "none")
    
    model.Parent = workspace
    return model
end

function LanternGenerationService:GenerateSegments(specs)
    local segments = {}
    local currentHeight = 0
    
    -- Generate curve path based on type
    local curveFunction = self:GetCurveFunction(specs.baseCurve)
    
    for i = 1, specs.segmentCount do
        local t = i / specs.segmentCount -- Progress along curve (0 to 1)
        local curveOffset = curveFunction(t, specs)
        
        local segmentType = "Pole"
        if i == 1 then
            segmentType = "Base"
        elseif i == specs.segmentCount - 1 then
            segmentType = "Chamber"
        elseif i == specs.segmentCount then
            segmentType = "Top"
        end
        
        local segment = {
            type = segmentType,
            position = specs.position + Vector3.new(curveOffset.X, currentHeight, curveOffset.Z),
            height = specs.totalHeight / specs.segmentCount,
            deformation = specs.deformations[i],
            curveT = t
        }
        
        currentHeight = currentHeight + segment.height
        table.insert(segments, segment)
    end
    
    return segments
end

function LanternGenerationService:GetCurveFunction(curveType)
    local curves = {
        straight = function(t, specs)
            return Vector3.new(0, 0, 0)
        end,
        
        sinusoidal = function(t, specs)
            local amplitude = 0.5
            local frequency = 2
            return Vector3.new(
                math.sin(t * math.pi * frequency) * amplitude,
                0,
                math.cos(t * math.pi * frequency) * amplitude * 0.5
            )
        end,
        
        helical = function(t, specs)
            local radius = 0.3
            local rotations = 1.5
            return Vector3.new(
                math.sin(t * math.pi * 2 * rotations) * radius,
                0,
                math.cos(t * math.pi * 2 * rotations) * radius
            )
        end,
        
        spiral = function(t, specs) -- Mutation
            local radius = t * 0.8 -- Expanding spiral
            local rotations = 3
            return Vector3.new(
                math.sin(t * math.pi * 2 * rotations) * radius,
                0,
                math.cos(t * math.pi * 2 * rotations) * radius
            )
        end,
        
        chaotic = function(t, specs) -- Mutation
            -- Use seed for consistent chaos
            math.randomseed(specs.seed + math.floor(t * 100))
            return Vector3.new(
                (math.random() - 0.5) * 0.8,
                0,
                (math.random() - 0.5) * 0.8
            )
        end,
        
        perfect = function(t, specs) -- Mutation (suspiciously straight)
            return Vector3.new(0, 0, 0)
        end,
        
        fractal = function(t, specs) -- Mutation (recursive pattern)
            local scale1 = math.sin(t * math.pi * 2) * 0.5
            local scale2 = math.sin(t * math.pi * 8) * 0.1
            local scale3 = math.sin(t * math.pi * 32) * 0.02
            return Vector3.new(
                scale1 + scale2 + scale3,
                0,
                (scale1 + scale2) * 0.7
            )
        end
    }
    
    return curves[curveType] or curves.straight
end

function LanternGenerationService:CreateSegmentPart(segment, index, specs)
    local part = Instance.new("Part")
    part.Name = segment.type .. "_" .. index
    part.Size = Vector3.new(1, segment.height, 1) * segment.deformation.scale
    part.CFrame = CFrame.new(segment.position) * 
                  CFrame.Angles(
                      math.rad(segment.deformation.lean),
                      math.rad(segment.deformation.twist),
                      0
                  )
    
    -- Material based on segment type
    if segment.type == "Chamber" then
        part.Material = Enum.Material.Glass
        part.Color = Color3.fromRGB(200, 200, 255)
    elseif segment.type == "Base" or segment.type == "Top" then
        part.Material = Enum.Material.Slate
        part.Color = Color3.fromRGB(80, 80, 90)
    else
        -- Material based on lantern material weight
        if specs.material == "copper" then
            part.Material = Enum.Material.CorrodedMetal
            part.Color = Color3.fromRGB(150, 100, 80)
        elseif specs.material == "brass" then
            part.Material = Enum.Material.Metal
            part.Color = Color3.fromRGB(180, 150, 100)
        else -- iron
            part.Material = Enum.Material.Metal
            part.Color = Color3.fromRGB(60, 60, 65)
        end
    end
    
    return part
end

function LanternGenerationService:StartConstruction(lanternModel, specs)
    -- Get segments for minion to build
    local segments = {}
    for _, part in ipairs(lanternModel:GetChildren()) do
        if part:IsA("BasePart") then
            local index = part:GetAttribute("SegmentIndex")
            if index then
                segments[index] = part
            end
        end
    end
    
    -- Fire event to trigger minion construction
    -- The minions are just visual - the lantern properties are already determined
    self:FireConstructionStart(lanternModel, segments, specs)
end

function LanternGenerationService:StoreLanternSpecs(specs)
    -- Store specs for consistency (in case of server restart, etc.)
    -- This would integrate with your save system
end

function LanternGenerationService:FireConstructionStart(model, segments, specs)
    -- Fire to MinionCrafterService to handle visual construction
    -- This is where minions would be assigned
end

-- Radial buff system
function LanternGenerationService:ApplyRadialBuff(position, radius, buffType, multiplier)
    -- Find all active constructions within radius
    -- Apply speed multiplier to minions
    -- This would interface with MinionCrafterService
end

function LanternGenerationService:RandomInRange(range)
    return range.Min + (math.random() * (range.Max - range.Min))
end

return LanternGenerationService