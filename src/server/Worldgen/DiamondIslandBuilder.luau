--!strict
-- DiamondIslandBuilder: Sculpt a flat-topped diamond (inverted pyramid) island from SmoothTerrain.
-- Idempotent: clears a padded region to Air before sculpting.

local DiamondIslandBuilder = {}

local Terrain = workspace.Terrain
local RS = game:GetService("ReplicatedStorage")
local WorldConfig = require(RS:WaitForChild("Config"):WaitForChild("WorldConfig"))

export type Options = {
    topSkin: number?,                 -- thickness of the flat top skin (studs)
    topMaterial: Enum.Material?,      -- surface material
    coreMaterial: Enum.Material?,     -- core/side material
    padXZ: number?,                   -- horizontal clear pad
    padY: number?,                    -- vertical clear pad
    minSlice: number?,                -- minimum XZ for last slice to avoid degenerate fills
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

-- Build a flat-topped diamond island whose top plane is at topPos.Y, tapering to an apex below.
function DiamondIslandBuilder.buildAt(topPos: Vector3, radius: number, height: number, opts: Options?)
    local islands = WorldConfig.ISLANDS or {}
    local o = opts or {}

    local topSkin = math.max(0, numberOr(o.topSkin ~= nil and o.topSkin or islands.TopSkinThickness, 2))
    local topMaterial = o.topMaterial or matFromString(islands.TopMaterial, Enum.Material.Ground)
    local coreMaterial = o.coreMaterial or matFromString(islands.CoreMaterial, Enum.Material.Rock)
    local minSlice = math.max(0.5, numberOr(o.minSlice, 1))

    -- Clear region padding scales with island size
    local padXZ = math.max(12, numberOr(o.padXZ, math.floor(radius * 0.75)))
    local padY  = math.max(16, numberOr(o.padY, math.floor(height * 0.5)))

    local topY = topPos.Y
    local sizeX = radius * 2
    local sizeZ = radius * 2

    -- 1) Idempotent clear (Air) of a padded box around the entire shape
    do
        local clearX = sizeX + 2 * padXZ
        local clearZ = sizeZ + 2 * padXZ
        local clearY = height + topSkin + 2 * padY
        local clearCenterY = topY - (height + topSkin) * 0.5
        local clearCF = CFrame.new(Vector3.new(topPos.X, clearCenterY, topPos.Z))
        Terrain:FillBlock(clearCF, Vector3.new(clearX, clearY, clearZ), Enum.Material.Air)
    end

    -- Helper: robust FillCylinder with ball-stack fallback
    local function safeFillCylinder(cf: CFrame, h: number, r: number, mat: Enum.Material)
        local ok = pcall(function()
            Terrain:FillCylinder(cf, h, r, mat)
        end)
        if not ok then
            -- Fallback: stack overlapping balls to approximate a cylinder
            local steps = math.max(2, math.ceil(h / math.max(0.75, r * 0.4)))
            local dh = h / steps
            for j = 1, steps do
                local yj = cf.Position.Y + (j - 0.5 - steps * 0.5) * dh
                Terrain:FillBall(Vector3.new(cf.Position.X, yj, cf.Position.Z), r, mat)
            end
        end
    end

    -- 2) Top flat cap (surface) at pivot/top - cylinder so silhouette is circular
    if topSkin > 0 then
        local capCenterY = topY - (topSkin * 0.5)
        local capCF = CFrame.new(Vector3.new(topPos.X, capCenterY, topPos.Z))
        safeFillCylinder(capCF, topSkin, radius, topMaterial)
    end

    -- 3) Tapered core: stack circular slices (cylinders) shrinking linearly to apex
    if height > 0 then
        local steps = math.clamp(math.ceil(height / 2), 8, 64)
        local sliceH = height / steps
        for i = 1, steps do
            local t = i / steps         -- 0→1 as we go downwards
            local scale = 1 - t         -- 1→0 linearly
            local r = math.max(minSlice * 0.5, radius * scale)
            local y = topY - topSkin - (i - 0.5) * sliceH
            local cf = CFrame.new(Vector3.new(topPos.X, y, topPos.Z))
            safeFillCylinder(cf, sliceH, r, coreMaterial)
        end
    end

    print(string.format(
        "[SkyDiamond] Sculpted pos=(%.1f,%.1f,%.1f) r=%.1f h=%.1f topSkin=%.1f",
        topPos.X, topPos.Y, topPos.Z, radius, height, topSkin
    ))
end

-- Clear only: remove a padded region for an existing island so it disappears
function DiamondIslandBuilder.clearRegion(topPos: Vector3, radius: number, height: number, opts: Options?)
    local islands = WorldConfig.ISLANDS or {}
    local o = opts or {}
    local topSkin = math.max(0, numberOr(o.topSkin ~= nil and o.topSkin or islands.TopSkinThickness, 2))

    local padXZ = math.max(12, numberOr(o.padXZ, math.floor(radius * 0.75)))
    local padY  = math.max(16, numberOr(o.padY, math.floor(height * 0.5)))

    local topY = topPos.Y
    local sizeX = radius * 2
    local sizeZ = radius * 2
    local clearX = sizeX + 2 * padXZ
    local clearZ = sizeZ + 2 * padXZ
    local clearY = height + topSkin + 2 * padY
    local clearCenterY = topY - (height + topSkin) * 0.5
    local clearCF = CFrame.new(Vector3.new(topPos.X, clearCenterY, topPos.Z))
    Terrain:FillBlock(clearCF, Vector3.new(clearX, clearY, clearZ), Enum.Material.Air)
end

return DiamondIslandBuilder
