--!strict
-- Dev Pond placement tool (Studio-only via server guard)

local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Net = RS:WaitForChild("Net")
local Remotes = Net:WaitForChild("Remotes")
local RF_Add: RemoteFunction = Remotes:WaitForChild("RF_AddPond")

-- DISABLED: Old ghost system - now using unified PlacementClient ghost
-- Tool still works for activating pond placement mode
local tool = script:FindFirstAncestorOfClass("Tool") :: Tool?
if not tool then script.Disabled = true; return end

local radius = 10  -- Default radius

-- Just handle activation, let PlacementClient handle the ghost
tool.Activated:Connect(function()
    -- Get mouse world position
    local cam = workspace.CurrentCamera
    if not cam then return end
    local m = UIS:GetMouseLocation()
    local r = cam:ViewportPointToRay(m.X, m.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {}
    local hit = workspace:Raycast(r.Origin, r.Direction * 1000, params)
    if hit then
        local v2 = Vector2.new(hit.Position.X, hit.Position.Z)
        RF_Add:InvokeServer(v2, radius)
    end
end)

-- Size adjustment (still works even though ghost is handled elsewhere)
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Equals or input.KeyCode == Enum.KeyCode.Plus then
        radius = math.min(20, radius + 1)
        print("[PondTool] radius=", radius)
    elseif input.KeyCode == Enum.KeyCode.Minus then
        radius = math.max(6, radius - 1)
        print("[PondTool] radius=", radius)
    end
end)
