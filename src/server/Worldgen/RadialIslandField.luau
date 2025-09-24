-- RadialIslandField
-- Generates island models around a hub in concentric rings.
-- Uses OrganicIslandBuilder to sculpt small organic islandlets.
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local WorldConfig = require(RS:WaitForChild("Config"):WaitForChild("WorldConfig"))

local WorldgenFolder = SSS:FindFirstChild('Worldgen') or script.Parent
if not WorldgenFolder then
    error('Worldgen folder not found for RadialIslandField')
end
local OrganicIslandBuilder = require(WorldgenFolder:WaitForChild('OrganicIslandBuilder'))

local RadialIslandField = {}

export type RadialConfig = {
    GapFromSpawn: number?,
    RingCount: number?,
    IslandsPerRing: number?,
    RingSpacing: number?,
    ElevationY: number?,
    Seed: number?,
}

local function numberOr(x: any, d: number): number
    if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
        return x
    end
    return d
end

local function getHalfSize()
    local size = WorldConfig.ISLANDS.SizeStuds
    if type(size) == "number" then
        return size * 0.5
    end
    if typeof(size) == "Vector3" then
        return math.max(0, size.X) * 0.5 -- approximate X footprint
    end
    return 96 -- fallback for plane_64m = 192
end

function RadialIslandField.generate(rootFolder: Instance, hubPos: Vector3, cfg: RadialConfig?)
    local rc = cfg or (WorldConfig.WORLDGEN and WorldConfig.WORLDGEN.Radial) or {}
    local gap = numberOr(rc.GapFromSpawn, 200)
    local ringCount = math.max(1, math.floor(numberOr(rc.RingCount, 1)))
    local islandsPerRing = math.max(3, math.floor(numberOr(rc.IslandsPerRing, 12)))
    local ringSpacing = numberOr(rc.RingSpacing, 350)
    local elevationY = numberOr(rc.ElevationY, hubPos.Y)
    local seed = numberOr(rc.Seed, 12345)

    local rng = Random.new(seed)

    -- Ensure center gap clears island half-size margin so footprints don't encroach hub
    local margin = getHalfSize() + 24
    local startRadius = gap + margin

    local totalPlaced = 0

    for ring = 1, ringCount do
        local ringRadius = startRadius + (ring - 1) * ringSpacing
        local angleStep = (2 * math.pi) / islandsPerRing
        for i = 1, islandsPerRing do
            local jitter = rng:NextNumber(-angleStep * 0.25, angleStep * 0.25)
            local angle = (i - 1) * angleStep + jitter
            local x = hubPos.X + math.cos(angle) * ringRadius
            local z = hubPos.Z + math.sin(angle) * ringRadius
            local pos = Vector3.new(x, elevationY, z)

            -- Create a model with invisible pivot and call builder
            local model = Instance.new("Model")
            model.Name = string.format("Island_R%d_%02d", ring, i)
            model.Parent = rootFolder

            local pivot = Instance.new("Part")
            pivot.Name = "Pivot"
            pivot.Anchored = true
            pivot.CanCollide = false
            pivot.Transparency = 1
            pivot.Size = Vector3.new(1, 1, 1)
            pivot.CFrame = CFrame.new(pos)
            pivot.Parent = model
            model.PrimaryPart = pivot

            local r = rng:NextNumber(16, 26)
            OrganicIslandBuilder.buildIslandletAt(pivot.CFrame, { radius = r, height = r * 1.25, layers = 5, jitter = 0.22 })
            totalPlaced += 1
        end
    end

    print(string.format("[Worldgen] Radial islands placed count=%d gap=%.1f rings=%d perRing=%d", totalPlaced, gap, ringCount, islandsPerRing))
    return totalPlaced
end

return RadialIslandField

