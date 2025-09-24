--!strict
-- OrganicIslandBuilder: builds small organic islands (spherical/cylindrical)
-- Uses overlapping FillBall operations for a natural shape; idempotent via padded clear.

local RS = game:GetService("ReplicatedStorage")

local WorldConfig = require(RS:WaitForChild("Config"):WaitForChild("WorldConfig"))

local OrganicIslandBuilder = {}

export type Options = {
    radius: number?,    -- approximate horizontal radius (studs)
    height: number?,    -- vertical span (studs)
    layers: number?,    -- number of overlapping layers to jitter
    jitter: number?,    -- [0..1] fraction of radius for XY jitter
}

local function numberOr(x: any, d: number): number
    if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
        return x
    end
    return d
end

local function matFromString(s: any, fallback: Enum.Material): Enum.Material
    if typeof(s) == "EnumItem" then
        return s :: Enum.Material
    end
    if type(s) == "string" then
        local ok, mat = pcall(function() return Enum.Material[s] end)
        if ok and typeof(mat) == "EnumItem" then
            return mat :: Enum.Material
        end
    end
    return fallback
end

-- Build a small islandlet at the given pivot CFrame.
function OrganicIslandBuilder.buildIslandletAt(pivotCF: CFrame, opts: Options?)
    local o = opts or {}
    local radius = math.max(6, numberOr(o.radius, 20))
    local height = math.max(8, numberOr(o.height, radius * 1.2))
    local layers = math.clamp(math.floor(numberOr(o.layers, 5)), 3, 8)
    local jitterFrac = math.clamp(numberOr(o.jitter, 0.2), 0, 0.8)

    local topMaterial = matFromString((WorldConfig.ISLANDS and WorldConfig.ISLANDS.TopMaterial) or "Ground", Enum.Material.Ground)
    local coreMaterial = matFromString((WorldConfig.ISLANDS and WorldConfig.ISLANDS.CoreMaterial) or "Rock", Enum.Material.Rock)

    local rng = Random.new(1031)
    local pivotPos = pivotCF.Position

    -- Clear a padded region to avoid accumulation across boots
    do
        local clearPad = math.floor(radius * 1.5)
        local clearHeight = height + clearPad
        local centerY = pivotPos.Y - (height * 0.5)
        local clearCF = CFrame.new(Vector3.new(pivotPos.X, centerY, pivotPos.Z))
        workspace.Terrain:FillBlock(clearCF, Vector3.new(clearPad*2, clearHeight, clearPad*2), Enum.Material.Air)
    end

    -- Stack overlapping spheres with slight XY jitter for organic shape
    for i = 0, layers - 1 do
        local t = if layers > 1 then i / (layers - 1) else 0.5
        local y = pivotPos.Y - (height * 0.5) + (t * height)
        local rScale = 0.9 + 0.2 * math.cos((t - 0.5) * math.pi) -- bulge mid, taper ends
        local r = radius * rScale
        local j = r * jitterFrac
        local jx = rng:NextNumber(-j, j)
        local jz = rng:NextNumber(-j, j)
        local center = Vector3.new(pivotPos.X + jx, y, pivotPos.Z + jz)
        workspace.Terrain:FillBall(center, r, coreMaterial)
    end

    -- Add a thin top skin to color surface
    do
        local topCenter = Vector3.new(pivotPos.X, pivotPos.Y, pivotPos.Z)
        local capR = radius * 0.92
        workspace.Terrain:FillBall(topCenter, capR, topMaterial)
    end

    print(string.format("[OrganicIsland] Sculpted islandlet pos=(%.1f,%.1f,%.1f) r=%.1f h=%.1f layers=%d",
        pivotPos.X, pivotPos.Y, pivotPos.Z, radius, height, layers))
end

return OrganicIslandBuilder