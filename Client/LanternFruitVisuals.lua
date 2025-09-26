-- LanternFruitVisuals.lua
-- Handles fruit growth and burst effects on lanterns

local LanternFruitVisuals = {}
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Visual settings
local FRUIT_COLORS = {
    Unripe = Color3.fromRGB(150, 200, 150),
    Ripe = Color3.fromRGB(220, 180, 255), -- Opal shimmer
    Overripe = Color3.fromRGB(255, 220, 180)
}

local activeFruits = {} -- {lanternId = {fruits = {}, maturity = 0}}

function LanternFruitVisuals:CreateFruit(lanternModel)
    local fruit = Instance.new("Part")
    fruit.Name = "LanternFruit"
    fruit.Size = Vector3.new(0.3, 0.4, 0.3)
    fruit.Shape = Enum.PartType.Ball
    fruit.Material = Enum.Material.ForceField
    fruit.TopSurface = Enum.SurfaceType.Smooth
    fruit.BottomSurface = Enum.SurfaceType.Smooth
    fruit.CanCollide = false
    fruit.Color = FRUIT_COLORS.Unripe
    
    -- Glow effect
    local pointLight = Instance.new("PointLight")
    pointLight.Brightness = 0.5
    pointLight.Range = 3
    pointLight.Color = FRUIT_COLORS.Unripe
    pointLight.Parent = fruit
    
    -- Position randomly around lantern
    local angle = math.random() * math.pi * 2
    local height = math.random() * 2 - 1
    local radius = 1.5 + math.random() * 0.5
    
    fruit.CFrame = lanternModel.PrimaryPart.CFrame * 
        CFrame.new(
            math.cos(angle) * radius,
            height,
            math.sin(angle) * radius
        )
    
    -- Weld to lantern
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = lanternModel.PrimaryPart
    weld.Part1 = fruit
    weld.Parent = fruit
    
    fruit.Parent = lanternModel
    
    -- Gentle bobbing animation
    local startCFrame = fruit.CFrame
    local connection
    connection = RunService.Heartbeat:Connect(function()
        if fruit.Parent then
            local time = tick()
            local offset = math.sin(time * 2) * 0.1
            fruit.CFrame = startCFrame * CFrame.new(0, offset, 0)
        else
            connection:Disconnect()
        end
    end)
    
    return fruit
end

function LanternFruitVisuals:UpdateLanternFruits(lanternId, lanternModel, maturity)
    if not activeFruits[lanternId] then
        activeFruits[lanternId] = {
            fruits = {},
            maturity = 0
        }
    end
    
    local data = activeFruits[lanternId]
    data.maturity = maturity
    
    -- Determine fruit count based on maturity
    local targetFruitCount = math.floor(maturity / 20) -- 1 fruit per 20%
    targetFruitCount = math.min(targetFruitCount, 5) -- Max 5 fruits
    
    -- Add fruits if needed
    while #data.fruits < targetFruitCount do
        local fruit = self:CreateFruit(lanternModel)
        table.insert(data.fruits, fruit)
    end
    
    -- Update fruit colors based on maturity
    local color
    if maturity < 50 then
        color = FRUIT_COLORS.Unripe
    elseif maturity < 100 then
        -- Lerp to ripe color
        local t = (maturity - 50) / 50
        color = FRUIT_COLORS.Unripe:Lerp(FRUIT_COLORS.Ripe, t)
    else
        -- Overripe shimmer
        local t = math.sin(tick() * 3) * 0.5 + 0.5
        color = FRUIT_COLORS.Ripe:Lerp(FRUIT_COLORS.Overripe, t)
    end
    
    for _, fruit in ipairs(data.fruits) do
        if fruit and fruit.Parent then
            fruit.Color = color
            if fruit:FindFirstChild("PointLight") then
                fruit.PointLight.Color = color
            end
        end
    end
end

function LanternFruitVisuals:BurstFruit(lanternId, lanternModel)
    local data = activeFruits[lanternId]
    if not data then return end
    
    -- Create burst effect for each fruit
    for _, fruit in ipairs(data.fruits) do
        if fruit and fruit.Parent then
            self:CreateBurstEffect(fruit.Position)
            fruit:Destroy()
        end
    end
    
    -- Clear fruit data
    data.fruits = {}
    data.maturity = 0
end

function LanternFruitVisuals:CreateBurstEffect(position)
    -- Opal shimmer particle burst
    local attachment = Instance.new("Attachment")
    attachment.Position = position
    attachment.Parent = workspace.Terrain
    
    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    emitter.Rate = 0
    emitter.Lifetime = NumberRange.new(1, 2)
    emitter.Speed = NumberRange.new(5, 10)
    emitter.VelocityInheritance = 0
    emitter.EmissionDirection = Enum.NormalId.Top
    emitter.SpreadAngle = Vector2.new(360, 360)
    
    -- Opal colors
    emitter.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 220, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 200))
    })
    
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.7, 0.3),
        NumberSequenceKeypoint.new(1, 1)
    })
    
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(0.5, 1),
        NumberSequenceKeypoint.new(1, 0)
    })
    
    emitter.Parent = attachment
    
    -- Emit burst
    emitter:Emit(30)
    
    -- Clean up after effect
    task.wait(3)
    attachment:Destroy()
end

return LanternFruitVisuals