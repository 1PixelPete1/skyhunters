--!strict
-- Dev Pond placement tool (Studio-only via server guard)

local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Net = RS:WaitForChild("Net")
local Remotes = Net:WaitForChild("Remotes")
local RF_Add: RemoteFunction = Remotes:WaitForChild("RF_AddPond")

-- Track authoritative player state; only allow placement in Build
local currentPlayerState = "Neutral"
do
    local ok, ev = pcall(function() return RS:WaitForChild("PlayerStateRemote") end)
    if ok and ev and ev:IsA("RemoteEvent") then
        ev.OnClientEvent:Connect(function(eventType, data)
            if eventType == "StateChanged" and data and data.state then
                currentPlayerState = data.state
            end
        end)
        pcall(function() ev:FireServer("RequestState") end)
    end
end

-- DISABLED: Old ghost system - now using unified PlacementClient ghost
-- Tool still works for activating pond placement mode
local tool = script:FindFirstAncestorOfClass("Tool") :: Tool?
if not tool then script.Disabled = true; return end

local radius = 10  -- Default radius

-- Just handle activation, let PlacementClient handle the ghost
tool.Activated:Connect(function()
    -- CRITICAL: Enforce Build state for pond placement
    if currentPlayerState ~= "Build" then
        warn(string.format("[PondTool] Cannot place pond - current state is '%s', must be in 'Build' state", currentPlayerState))
        return
    end
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
