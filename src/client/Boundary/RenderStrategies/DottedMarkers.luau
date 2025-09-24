--!strict
-- DottedMarkers strategy: cheap dotted hints using BillboardGui markers sampled along polylines

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
local poolTarget = 0 -- target pool size requested by last draw
local createBudget = 0 -- per-frame creation budget to avoid spikes

-- Track which dots are currently active
local activeDots: { [number]: boolean } = {}

local function ensureDot(idx: number): BillboardGui?
    local g = dots[idx]
    if g and g.Parent then return g end
    -- Respect per-frame creation budget when growing the pool
    if idx > #dots and createBudget <= 0 then
        return nil
    end
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
    createBudget = math.max(0, createBudget - 1)
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
local lastBatches: { any }? = nil
local lastCamPos: Vector3? = nil
local lastLodTick = 0.0

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
    local maxPlaceThisFrame = math.min(maxDots, (#dots + createBudget))
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
                    if used >= maxPlaceThisFrame then break end
                    local idx = used + 1
                    local g = ensureDot(idx)
                    if not g then
                        -- No budget left to create more dots this frame
                        t = L + spacing -- break inner while
                        break
                    end
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
                    used += 1
                    t += spacing
                end
                if used >= maxPlaceThisFrame then break end
            end
        end
        if used >= maxPlaceThisFrame then break end
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
    poolTarget = math.max(poolTarget, used)
    return used
end

-- Render authoritative v3 batches (preferred path)
local function doRender(batches: { any }): number
    -- Count requested dots first
    local requested = 0
    for _, b in ipairs(batches or {}) do
        requested += #(b.points or {})
    end
    lastRequested = requested
    
    -- Render dots from batches
    local used = 0
    local cam = workspace.CurrentCamera
    local nearD = math.max(5, BoundaryConfig.lod_near_distance or 35)
    local farD = math.max(nearD + 1, BoundaryConfig.lod_far_distance or 90)
    local maxExtra = math.max(0, BoundaryConfig.dot_lod_max_extra or 3) -- max extra dots per segment near camera
    local maxDots = BoundaryConfig.maxDotsPerPublish or BoundaryConfig.max_dots_total or 6000

    local function extrasForDistance(d: number): number
        if maxExtra <= 0 then return 0 end
        if d <= nearD then return maxExtra end
        if d >= farD then return 0 end
        local t = (farD - d) / (farD - nearD) -- 0..1
        return math.clamp(math.floor(t * maxExtra + 0.0001), 0, maxExtra)
    end

    for _, b in ipairs(batches or {}) do
        local pts = b.points or {}
        local prev: any = nil
        for i = 1, #pts do
            local p = pts[i]
            -- place base point
            used += 1
            if used > maxDots then break end
            do
                local g = ensureDot(used)
                if not g then used -= 1; break end
                local adornee = g.Adornee :: BasePart
                adornee.CFrame = CFrame.new(p.x, p.y, p.z)
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
                activeDots[used] = true
            end

            -- place extra points between prev and current when near camera
            if prev and cam then
                local ax, ay, az = prev.x, prev.y, prev.z
                local bx, by, bz = p.x, p.y, p.z
                local mid = Vector3.new((ax+bx)*0.5, (ay+by)*0.5, (az+bz)*0.5)
                local d = (cam.CFrame.Position - mid).Magnitude
                local extra = extrasForDistance(d)
                if extra > 0 then
                    for k = 1, extra do
                        if used >= maxDots then break end
                        local t = k / (extra + 1)
                        local sx = ax + (bx - ax) * t
                        local sy = ay + (by - ay) * t
                        local sz = az + (bz - az) * t
                        used += 1
                        local g2 = ensureDot(used)
                        if not g2 then used -= 1; break end
                        local adornee2 = g2.Adornee :: BasePart
                        adornee2.CFrame = CFrame.new(sx, sy, sz)
                        if enabled then
                            adornee2.Parent = ROOT
                            local att2 = distanceAttenuation(Vector3.new(sx, sy, sz))
                            local frame2 = g2:FindFirstChildOfClass("Frame") :: Frame
                            if frame2 then
                                frame2.BackgroundTransparency = 1 - att2*(BoundaryConfig.dotAlpha or 0.8)
                            end
                        else
                            adornee2.Parent = nil
                        end
                        activeDots[used] = true
                    end
                end
            end
            prev = p
        end
        if used >= maxDots then break end
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

function Strategy.renderBatches(batches: { any }): number
    lastBatches = batches
    return doRender(batches)
end

function Strategy.setEnabled(on: boolean)
    enabled = on and true or false
    
    -- Count how many dots we should have active
    local expectedActive = 0
    for i = 1, #activeDots do
        if activeDots[i] then expectedActive += 1 end
    end
    
    -- Actually hide/show all dots by controlling visibility
    local actuallyShown = 0
    for idx = 1, #dots do
        if activeDots[idx] then  -- Only process dots that should be active
            local g = dots[idx]
            if g and g.Parent then
                local adornee = g.Adornee :: BasePart
                if adornee then
                    if enabled then
                        -- Show by ensuring it's in workspace
                        if not adornee.Parent then
                            adornee.Parent = ROOT
                        end
                        actuallyShown += 1
                        -- Update transparency based on distance
                        local frame = g:FindFirstChildOfClass("Frame") :: Frame
                        if frame then
                            local att = distanceAttenuation(adornee.Position)
                            frame.BackgroundTransparency = 1 - att*(BoundaryConfig.dotAlpha or 0.8)
                        end
                    else
                        -- Hide by using transparency instead of removing parent
                        local frame = g:FindFirstChildOfClass("Frame") :: Frame
                        if frame then
                            frame.BackgroundTransparency = 1
                        end
                    end
                end
            end
        end
    end
    
    -- If we have missing dots when enabling, trigger a recovery
    if enabled and actuallyShown < expectedActive then
        warn(string.format("[Boundary/DottedMarkers] Recovery needed: expected=%d actual=%d", expectedActive, actuallyShown))
        -- Request a full redraw by clearing and requesting new data
        task.defer(function()
            local RF_Get = RS:WaitForChild("Net"):WaitForChild("Remotes"):FindFirstChild("RF_BoundaryGetSoup")
            if RF_Get then
                local ok, resp = pcall(function() return RF_Get:InvokeServer() end)
                if ok and resp and resp.full and resp.full.batches then
                    Strategy.renderBatches(resp.full.batches)
                end
            end
        end)
    end
end

function Strategy.getStats(): { [string]: number }
    local activeCount = 0
    for i = 1, #activeDots do
        if activeDots[i] then activeCount += 1 end
    end
    return { batches = liveBatches, dots = liveDots, pool = #dots, requested = lastRequested, starved = lastStarved, active = activeCount }
end

-- Lightweight LOD refresh based on camera movement (throttled)
RunService.Heartbeat:Connect(function()
    -- Refill creation budget and pre-grow pool gradually
    createBudget = (BoundaryConfig.dot_pool_grow_per_frame or 64)
    local deficit = math.max(0, poolTarget - #dots)
    local toCreate = math.min(deficit, createBudget)
    for i = 1, toCreate do
        ensureDot(#dots + 1)
    end

    if not enabled then return end
    if not lastBatches then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local now = os.clock()
    if now - lastLodTick < 0.25 then return end
    local pos = cam.CFrame.Position
    if lastCamPos and (pos - lastCamPos).Magnitude < 4.0 then return end
    lastCamPos = pos
    lastLodTick = now
    -- Re-render with current camera-based density
    doRender(lastBatches)
end)

return Strategy
