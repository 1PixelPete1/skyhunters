local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = RS:WaitForChild("Remotes")
local RF_GetPondDisc: RemoteFunction = Remotes:WaitForChild("RF_GetPondDisc")

local ZoneOverlay = {}

local container = Instance.new("Folder")
container.Name = "PlacementZone"
container.Parent = workspace
container.Archivable = false

local active = false

local function clear()
    container:ClearAllChildren()
end

local function tile(pos: Vector3, size: number, inside: boolean)
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.Material = Enum.Material.SmoothPlastic
    p.Color = inside and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 0, 0)
    p.Transparency = inside and 0.7 or 0.85
    p.Size = Vector3.new(size, 0.1, size)
    p.CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0))
    p.Parent = container
end

function ZoneOverlay.show(plotKey: string)
    clear()
    active = true
    local center, radius = RF_GetPondDisc:InvokeServer(plotKey)
    if not center or not radius then return end
    local step = 4
    for x = -radius, radius, step do
        for z = -radius, radius, step do
            local world = center + Vector3.new(x, 0, z)
            local inside = (x*x + z*z) <= (radius*radius)
            if inside then
                tile(world, step, true)
            end
        end
    end
end

function ZoneOverlay.hide()
    active = false
    clear()
end

return ZoneOverlay

