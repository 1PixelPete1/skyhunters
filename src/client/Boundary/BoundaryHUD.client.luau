--!strict
-- BoundaryHUD: lightweight overlay showing version + soup stats + timings

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local Net = RS:WaitForChild("Net", 3)
local Remotes = Net and Net:FindFirstChild("Remotes")
local RE_Delta: RemoteEvent = Remotes and Remotes:FindFirstChild("RE_BoundaryDelta")
local RF_Get: RemoteFunction = Remotes and Remotes:FindFirstChild("RF_BoundaryGetSoup")

local BoundaryConfig = require(RS.Shared.Boundary.BoundaryConfig)

local screen = Instance.new("ScreenGui")
screen.Name = "BoundaryHUD"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.Enabled = false
screen.Parent = LP:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.Name = "Stats"
label.BackgroundTransparency = 0.3
label.BackgroundColor3 = Color3.fromRGB(20,20,20)
label.TextColor3 = Color3.fromRGB(220, 255, 220)
label.Font = Enum.Font.Code
label.TextSize = 14
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextYAlignment = Enum.TextYAlignment.Top
label.Size = UDim2.fromOffset(420, 110)
label.Position = UDim2.fromOffset(10, 10)
label.Parent = screen

local state = {
    version = -1,
    polylines = 0,
    segments = 0,
    ms_build = 0.0,
    ms_validate = 0.0,
    ms_draw = 0.0,
    redraws_this_frame = 0,
    queue_depth = 0,
    strategy = "",
    segments_drawn = 0,
}

local layers = { labels = false, gaps = false, normals = false }

local function updateText()
    label.Text = string.format(
        "Boundary v=%d\npolylines=%d segments=%d\nms_build=%.2f ms_validate=%.2f\nms_draw=%.2f redraws=%d queue=%d\nstrategy=%s drawn=%d",
        state.version, state.polylines, state.segments, state.ms_build, state.ms_validate,
        state.ms_draw, state.redraws_this_frame, state.queue_depth, state.strategy, state.segments_drawn
    )
end

local function onPayload(payload)
    if not payload or not payload.soup then return end
    local soup = payload.soup
    state.version = soup.version or state.version
    local polyCount = #(soup.polylines or {})
    local segs = 0
    for _, pl in ipairs(soup.polylines or {}) do segs += math.max(0, #(pl.pts or {}) - 1) end
    state.polylines = polyCount
    state.segments = segs
    if payload.stats and payload.stats.build then
        state.ms_build = payload.stats.build.ms_total or 0
    end
    if payload.stats and payload.stats.validate then
        state.ms_validate = payload.stats.validate.ms_total or 0
    end
    -- Pull renderer local stats if the new renderer is enabled
    local ok, RendererState = pcall(function() return require(script.Parent:WaitForChild("BoundaryState")) end)
    if ok and RendererState then
        state.ms_draw = RendererState.ms_draw or 0
        state.redraws_this_frame = RendererState.redraws_this_frame or 0
        state.queue_depth = RendererState.queue_depth or 0
        state.strategy = RendererState.strategy or ""
        state.segments_drawn = RendererState.segments_drawn or 0
    end
    updateText()
    print(string.format("[Boundary/HUD] pub_id=%s version=%d polylines=%d segments=%d ms_build=%.2f ms_validate=%.2f ms_draw=%.2f queue=%d strategy=%s",
        tostring(soup.version or state.version), state.version, state.polylines, state.segments, state.ms_build, state.ms_validate, state.ms_draw, state.queue_depth, state.strategy))
end

if RE_Delta then
    RE_Delta.OnClientEvent:Connect(function(payload)
        if payload and payload.replace then
            onPayload(payload)
        end
    end)
end

-- Initial fetch, then wait for events
task.defer(function()
    if RF_Get then
        local ok, resp = pcall(function() return RF_Get:InvokeServer() end)
        if ok and resp then
            onPayload({ soup = resp })
        end
    end
end)

-- Chat toggles
LP.Chatted:Connect(function(msg)
    local lower = msg:lower()
    if lower:match("^boundary%.debug ") then
        local onoff = lower:match("boundary%.debug%s+(%a+)")
        if onoff == "on" then screen.Enabled = true elseif onoff == "off" then screen.Enabled = false end
        print(string.format("[Boundary/HUD] visible=%s", tostring(screen.Enabled)))
    elseif lower:match("^boundary%.layers ") then
        local labelKey, onoff = lower:match("boundary%.layers%s+(%a+)%s+(%a+)")
        if labelKey and (layers :: any)[labelKey] ~= nil then
            (layers :: any)[labelKey] = (onoff == "on")
            updateText()
        end
    end
end)
