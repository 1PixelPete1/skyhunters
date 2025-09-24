--!strict
-- RimBuilder: campfire-style stones around a pond rim, tangential orientation
-- PERFORMANCE NOTE: Default reduced from 32 to 8 stones per rim for 75% part reduction
-- Use larger stones with more variation to maintain visual quality with fewer parts

local RimBuilder = {}
local SSS = game:GetService("ServerScriptService")
local RenderQueue = require(SSS:WaitForChild("Systems"):WaitForChild("RenderQueueSystem"))

export type RimStyle = {
    StoneCount: number,
    InnerGap: number,
    ArcJitter: number,
    YawJitter: number,
    RollJitter: number,
    StoneSize: Vector3,
    SizeJitter: Vector3,
    Color: Color3,
    Material: Enum.Material,
}

local DEFAULT: RimStyle = {
    StoneCount = 8,  -- OPTIMIZED: Reduced from 32 to 8 for better performance
    InnerGap = 1.25,
    ArcJitter = 0.0, -- ensure stones sit on a perfect circle
    YawJitter = 8,
    RollJitter = 3,
    StoneSize = Vector3.new(4.5, 2.0, 2.2),  -- OPTIMIZED: Larger stones to compensate for fewer count
    SizeJitter = Vector3.new(1.0, 0.6, 0.8),  -- OPTIMIZED: More size variation
    Color = Color3.fromRGB(118,116,112),
    Material = Enum.Material.Rock,
}

local function rand(rng: Random, base: number, j: number): number
    return base + rng:NextNumber(-j, j)
end

-- New signature: centerXZ: Vector2
function RimBuilder.build(parent: Instance, centerXZ: Vector2 | Vector3, radius: number, style: RimStyle?)
    local s = (typeof(style) == "table" and (style :: any)) or DEFAULT
    local rng = Random.new()

    for _, child in ipairs(parent:GetChildren()) do
        if child.Name == "RimStone" then child:Destroy() end
    end

    local cx: number, cz: number
    if typeof(centerXZ) == "Vector3" then
        cx = centerXZ.X; cz = centerXZ.Z
    else
        cx = centerXZ.X; cz = centerXZ.Y
    end

    local r = radius + s.InnerGap + (s.StoneSize.X * 0.25)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Whitelist
    params.FilterDescendantsInstances = { workspace.Terrain }
    for i = 1, s.StoneCount do
        local t = (i / s.StoneCount) * 2*math.pi + rng:NextNumber(-s.ArcJitter, s.ArcJitter)
        local cosT, sinT = math.cos(t), math.sin(t)

        local baseXZ = Vector3.new(cx + r * cosT, 0, cz + r * sinT)
        -- Raycast down to terrain to place stones on the surface height
        local origin = baseXZ + Vector3.new(0, (workspace.FallenPartsDestroyHeight or -500) + 1000, 0)
        local hit = workspace:Raycast(origin, Vector3.new(0, -2000, 0), params)
        local surfY = (hit and hit.Position.Y) or 0

        local size = Vector3.new(
            math.max(0.9, s.StoneSize.X + rng:NextNumber(-s.SizeJitter.X, s.SizeJitter.X)),
            math.max(0.6, s.StoneSize.Y + rng:NextNumber(-s.SizeJitter.Y, s.SizeJitter.Y)),
            math.max(0.7, s.StoneSize.Z + rng:NextNumber(-s.SizeJitter.Z, s.SizeJitter.Z))
        )

        local tangent = Vector3.new(-sinT, 0, cosT).Unit
        local up = Vector3.yAxis
        local stoneTop = surfY + (size.Y * 0.5)
        local pos = Vector3.new(baseXZ.X, stoneTop, baseXZ.Z)
        local cframe = CFrame.fromMatrix(pos, tangent, up)
        cframe *= CFrame.fromOrientation(
            math.rad(rand(rng, 0, s.RollJitter)),
            math.rad(rand(rng, 0, s.YawJitter)),
            0
        )

        RenderQueue.EnqueueRimStone(parent, {
            Size = size,
            CFrame = cframe,
            Color = s.Color,
            Material = s.Material,
        })
    end
end

-- PERFORMANCE ANALYSIS: Check rim stone counts across the world
function RimBuilder.analyzePerformance()
    local analysis = {
        totalRimStones = 0,
        rimFolders = 0,
        averageStonesPerRim = 0,
        recommendation = ""
    }
    
    local pondRims = workspace:FindFirstChild("PondRims")
    if pondRims then
        for _, rimFolder in ipairs(pondRims:GetChildren()) do
            if rimFolder:IsA("Folder") then
                analysis.rimFolders = analysis.rimFolders + 1
                local stoneCount = 0
                
                for _, child in ipairs(rimFolder:GetChildren()) do
                    if child.Name == "RimStone" then
                        stoneCount = stoneCount + 1
                    end
                end
                
                analysis.totalRimStones = analysis.totalRimStones + stoneCount
            end
        end
    end
    
    if analysis.rimFolders > 0 then
        analysis.averageStonesPerRim = analysis.totalRimStones / analysis.rimFolders
    end
    
    -- Generate recommendation
    if analysis.averageStonesPerRim > 20 then
        analysis.recommendation = "HIGH: Consider reducing rim stone count for better performance"
    elseif analysis.averageStonesPerRim > 12 then
        analysis.recommendation = "MEDIUM: Rim stone count is moderate"
    else
        analysis.recommendation = "GOOD: Rim stone count is optimized"
    end
    
    print("[RimBuilder] Performance Analysis:")
    print(`  Total rim stones: {analysis.totalRimStones}`)
    print(`  Rim folders: {analysis.rimFolders}`)
    print(string.format("  Average stones per rim: %.1f", analysis.averageStonesPerRim))
    print(`  Recommendation: {analysis.recommendation}`)
    
    return analysis
end

return RimBuilder
