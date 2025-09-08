--!strict
-- DottedMarkers strategy: cheap dotted hints using BillboardGui markers sampled along polylines

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local BoundaryConfig = require(RS.Shared.Boundary.BoundaryConfig)

local ROOT = workspace:FindFirstChild("BoundaryDots") or Instance.new("Folder")
ROOT.Name = "BoundaryDots"; ROOT.Parent = workspace

local dots: { BillboardGui } = {}
local enabled = true
local liveBatches = 0
local liveDots = 0
local lastRequested = 0
local lastStarved = 0

-- Track which dots are currently active
local activeDots: { [number]: boolean } = {}

local function ensureDot(idx: number): BillboardGui
    local g = dots[idx]
    if g and g.Parent then return g end
    local part = Instance.new("Part")
    part.Name = string.format("Dot_%05d", idx)
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Transparency = 1
    part.Size = Vector3.new(0.2,0.2,0.2)
    part.Parent = ROOT

    g = Instance.new("BillboardGui")
    g.Size = UDim2.fromOffset(6,6)
    g.AlwaysOnTop = false
    g.LightInfluence = 0
    g.Adornee = part
    g.Parent = part

    local f = Instance.new("Frame")
    f.AnchorPoint = Vector2.new(0.5,0.5)
    f.Position = UDim2.fromScale(0.5,0.5)
    f.Size = UDim2.fromScale(1,1)
    f.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
    f.BorderSizePixel = 0
    f.Parent = g

    dots[idx] = g
    return g
end

local function distanceAttenuation(worldPos: Vector3): number
    local char = LP.Character; local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return 1 end
    local d = (hrp.Position - worldPos).Magnitude
    local far = math.max(10, BoundaryConfig.lod_far_distance or 90)
    local near = math.max(5, BoundaryConfig.lod_near_distance or 35)
    if d <= near then return 1 elseif d >= far then return 0.2 else return 1 - (d-near)/(far-near)*0.8 end
end

local Strategy = {}

function Strategy.clearAll()
    -- Hide all dots by removing their adornees from workspace
    for i = 1, #dots do
        local g = dots[i]
        if g and g.Parent then
            local adornee = g.Adornee :: BasePart
            if adornee then
                adornee.Parent = nil
            end
        end
        activeDots[i] = false
    end
    liveDots = 0
    liveBatches = 0
end

function Strategy.renderSoup(payload): number
    local soup = payload.soup
    local spacing = BoundaryConfig.dotSpacing or BoundaryConfig.dot_spacing_studs or 3.5
    local used = 0
    local maxDots = BoundaryConfig.maxDotsPerPublish or BoundaryConfig.max_dots_total or 6000
    local lift = BoundaryConfig.dotLiftY or 0.05
    liveBatches = 0; liveDots = 0
    local planeY = ((require(RS.Config.WorldConfig).ISLANDS and require(RS.Config.WorldConfig).ISLANDS.DefaultHeightY) or 0) + (BoundaryConfig.dotLiftY or 0.05)
    for _, pl in ipairs(soup.polylines or {}) do
        local pts = pl.pts or {}
        for i = 1, #pts - 1 do
            local a = pts[i]; local b = pts[i+1]
            local seg = b - a
            local L = seg.Magnitude
            if L > 0 then
                local dir = seg / L
                local t = 0.0
                while t <= L do
                    if used >= maxDots then break end
                    used += 1
                    local g = ensureDot(used)
                    local worldX = a.X + dir.X * t
                    local worldZ = a.Y + dir.Y * t
                    local pointY = planeY
                    local adornee = g.Adornee :: BasePart
                    adornee.CFrame = CFrame.new(worldX, pointY + 0.0, worldZ)
                    local att = distanceAttenuation(Vector3.new(worldX, pointY, worldZ))
                    local frame = g:FindFirstChildOfClass("Frame") :: Frame
                    if frame then
                        frame.BackgroundTransparency = enabled and (1 - att*(BoundaryConfig.dotAlpha or 0.8)) or 1
                    end
                    t += spacing
                end
                if used >= maxDots then break end
            end
        end
        if used >= maxDots then break end
        liveBatches += 1
    end
    -- disable remaining
    local idx = used + 1
    while idx <= #dots do
        local g = dots[idx]
        if g and g.Parent then g.Parent.Parent = nil end
        idx += 1
    end
    liveDots = used
    return used
end

-- Render authoritative v3 batches (preferred path)
function Strategy.renderBatches(batches: { any }): number
    -- Count requested dots first
    local requested = 0
    for _, b in ipairs(batches or {}) do
        requested += #(b.points or {})
    end
    lastRequested = requested
    
    -- Render dots from batches
    local used = 0
    for _, b in ipairs(batches or {}) do
        local pts = b.points or {}
        for i = 1, #pts do
            used += 1
            local g = ensureDot(used)
            local p = pts[i]
            
            -- Use the Y coordinate from server (which now uses terrain raycast)
            local adornee = g.Adornee :: BasePart
            adornee.CFrame = CFrame.new(p.x, p.y, p.z)
            
            -- Set visibility based on enabled state
            if enabled then
                adornee.Parent = ROOT
                local att = distanceAttenuation(Vector3.new(p.x, p.y, p.z))
                local frame = g:FindFirstChildOfClass("Frame") :: Frame
                if frame then
                    frame.BackgroundTransparency = 1 - att*(BoundaryConfig.dotAlpha or 0.8)
                end
            else
                adornee.Parent = nil
            end
            
            -- Mark as active
            activeDots[used] = true
        end
    end
    
    -- Hide unused dots
    for i = used + 1, #dots do
        local g = dots[i]
        if g and g.Parent then
            local adornee = g.Adornee :: BasePart
            if adornee then
                adornee.Parent = nil
            end
        end
        activeDots[i] = false
    end
    
    liveDots = used
    lastStarved = math.max(0, requested - #dots)
    
    -- Pool metrics
    if (BoundaryConfig.debug_enabled) then
        print(string.format("[Boundary/Renderer/Pool] requested=%d pooled=%d starved=%d active=%d", requested, #dots, lastStarved, used))
    end
    return used
end

function Strategy.setEnabled(on: boolean)
    enabled = on and true or false
    
    -- Actually hide/show all dots by controlling their parent
    for idx = 1, #dots do
        local g = dots[idx]
        if g and g.Parent then
            local adornee = g.Adornee :: BasePart
            if adornee then
                if enabled then
                    -- Show by ensuring it's in workspace
                    if not adornee.Parent then
                        adornee.Parent = ROOT
                    end
                    -- Update transparency based on distance
                    local frame = g:FindFirstChildOfClass("Frame") :: Frame
                    if frame then
                        local att = distanceAttenuation(adornee.Position)
                        frame.BackgroundTransparency = 1 - att*(BoundaryConfig.dotAlpha or 0.8)
                    end
                else
                    -- Hide by removing from workspace entirely
                    adornee.Parent = nil
                end
            end
        end
    end
end

function Strategy.getStats(): { [string]: number }
    local activeCount = 0
    for i = 1, #activeDots do
        if activeDots[i] then activeCount += 1 end
    end
    return { batches = liveBatches, dots = liveDots, pool = #dots, requested = lastRequested, starved = lastStarved, active = activeCount }
end

return Strategy
