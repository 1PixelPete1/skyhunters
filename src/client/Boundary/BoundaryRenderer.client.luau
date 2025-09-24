--!strict
-- BoundaryRenderer: draws PolylineSoup from server using pluggable strategies

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")

local Net = RS:WaitForChild("Net", 3)
local Remotes = Net and Net:FindFirstChild("Remotes")
local RE_Delta: RemoteEvent = Remotes and Remotes:FindFirstChild("RE_BoundaryDelta")
local RF_Get: RemoteFunction = Remotes and Remotes:FindFirstChild("RF_BoundaryGetSoup")

local BoundaryConfig = require(RS.Shared.Boundary.BoundaryConfig)
local State = (function()
    local ok, m = pcall(function() return require(script.Parent:WaitForChild("BoundaryState")) end)
    return ok and m or nil
end)()
local BoundaryMask = (function()
    local ok, m = pcall(function()
        return require(script.Parent:FindFirstChild("BoundaryMask") or error("no mask"))
    end)
    return ok and m or nil
end)()
-- Lazy strategy loader with fallback
-- Force default to DottedMarkers strategy; no beams/lines in V3
local StrategyCache: { [string]: any } = {}
local function requireDotted(): any
    if StrategyCache.DottedMarkers ~= nil then return StrategyCache.DottedMarkers end
    local folder = script.Parent:FindFirstChild("RenderStrategies")
    local mod = folder and folder:FindFirstChild("DottedMarkers")
    if not (mod and mod:IsA("ModuleScript")) then
        warn("[Boundary/StrategyFail] name=DottedMarkers reason=module_missing fallback=None")
        StrategyCache.DottedMarkers = { clearAll = function() end, renderSoup = function() return 0 end, setEnabled=function() end, getStats=function() return {batches=0,dots=0,pool=0} end }
        return StrategyCache.DottedMarkers
    end
    local ok, res = pcall(require, mod)
    if not ok then
        warn(string.format("[Boundary/StrategyFail] name=%s reason=%s fallback=None", "DottedMarkers", tostring(res)))
        StrategyCache.DottedMarkers = { clearAll = function() end, renderSoup = function() return 0 end, setEnabled=function() end, getStats=function() return {batches=0,dots=0,pool=0} end }
        return StrategyCache.DottedMarkers
    end
    StrategyCache.DottedMarkers = res
    return res
end

if not BoundaryConfig.boundary_renderer_enabled then
    script.Disabled = true
    return
end

local soupQueue: { any } = {}
local queuedVersion: { [number]: boolean } = {}
local processing = false
local activeStrategyOverride: string? = nil
local lastDrawLog = 0.0
local gotSoupAt: number? = nil
local liveBatchesById: { [string]: any } = {}
local hasV3 = false

local function toolEquipped(): boolean
    local lp = Players.LocalPlayer
    local char = lp and lp.Character
    if not char then return false end
    for _, inst in ipairs(char:GetChildren()) do
        if inst:IsA("Tool") then
            local itemType = inst:GetAttribute("ItemType")
            if itemType == "pond" or itemType == "lantern" or itemType == "oil" then
                return true
            end
            -- Fallback heuristic for legacy tools by name; avoid run/toggle tools
            local name = string.lower(inst.Name or "")
            if (name:find("pond") or (name:find("lantern") and not name:find("run") and not name:find("toggle"))) then
                return true
            end
        end
    end
    return false
end

local function pickStrategyName(): string return "DottedMarkers" end

local function aabbOfPoints(points: { Vector2 }, padStud: number): (number, number, number, number)
    local minX, minZ = math.huge, math.huge
    local maxX, maxZ = -math.huge, -math.huge
    for _, p in ipairs(points) do
        if p.X < minX then minX = p.X end
        if p.Y < minZ then minZ = p.Y end
        if p.X > maxX then maxX = p.X end
        if p.Y > maxZ then maxZ = p.Y end
    end
    if minX == math.huge then minX, minZ, maxX, maxZ = 0, 0, 0, 0 end
    return minX - padStud, minZ - padStud, maxX + padStud, maxZ + padStud
end

local function enqueueSoup(payload)
    local v = payload.version or (payload.soup and payload.soup.version) or 0
    if queuedVersion[v] then return end
    table.insert(soupQueue, payload)
    queuedVersion[v] = true
end

local function toArray(map: { [string]: any }): { any }
    local arr = {}
    for _, v in pairs(map) do table.insert(arr, v) end
    return arr
end

local function inferPlaneYFromBatches(): number?
    for _, b in pairs(liveBatchesById) do
        local pts = b.points or {}
        if #pts > 0 and pts[1].y ~= nil then return pts[1].y end
    end
    return nil
end

local function drawSoup(payload)
    local t0 = os.clock()
    local name = pickStrategyName()
    local strategy = requireDotted()
    -- Apply full replace or delta onto liveBatchesById
    if payload.replace and payload.full and payload.full.batches and #payload.full.batches > 0 then
        liveBatchesById = {}
        for _, b in ipairs(payload.full.batches) do
            if b and b.id then liveBatchesById[b.id] = b end
        end
        hasV3 = true
    elseif payload.delta then
        local d = payload.delta
        if d.junctionsRemove or d.junctionsAdd then
            -- junctions are processed by mask; renderer ignores here for dots
        end
        if d.adds then
            for _, b in ipairs(d.adds) do if b and b.id then liveBatchesById[b.id] = b end end
        end
        if d.removes then
            -- FIXED: Actually remove batches (was no-op before)
            for _, id in ipairs(d.removes) do 
                liveBatchesById[id] = nil
            end
        end
    else
        -- Ignore legacy-only payloads (no batches); wait for v3
        if not hasV3 then
            if not (strategy and strategy.clearAll) then
                -- no-op
            end
            -- do not draw anything yet; prevent floating legacy paths
            return
        end
    end
    -- Render batches if present; fall back to legacy if none
    local segments = 0
    if next(liveBatchesById) ~= nil then
        local batchesArr = toArray(liveBatchesById)
        local ok, res = pcall(function()
            if strategy.clearAll then strategy.clearAll() end
            if strategy.renderBatches then return strategy.renderBatches(batchesArr) else return 0 end
        end)
        if ok then segments = res or 0 else warn("[Boundary/Renderer] warn=render_batches_failed") end
        -- publish plane to state for placement snapping
        local plane = inferPlaneYFromBatches()
        if plane ~= nil then if State and State.setPlaneY then pcall(State.setPlaneY, plane) end end
    else
        -- No batches yet (or cleared map). If we haven't seen v3, ignore; else keep last frame (pool persists)
        return
    end
    local ms = (os.clock() - t0) * 1000
    if State and State.set then
        pcall(State.set, #soupQueue, 1, ms, name, segments)
    else
        warn("[Boundary/Renderer] skip_state_set")
    end
    local now = os.clock()
    local heartbeatMs = BoundaryConfig.client_log_heartbeat_ms or 500
    if (now - lastDrawLog) * 1000 >= heartbeatMs then
        lastDrawLog = now
        print(string.format("[Boundary/Renderer] strategy=%s pub_id=%s draws=%d queue=%d ms_draw=%.2f", name, tostring(payload.version or (payload.soup and payload.soup.version) or -1), 1, #soupQueue, ms))
        local s = strategy.getStats and strategy.getStats() or nil
        if s then
            print(string.format("[Boundary/Renderer/Stats] requested=%s pooled=%s dots=%s starved=%s", tostring(s.requested or "?"), tostring(s.pool or 0), tostring(s.dots or 0), tostring(s.starved or 0)))
        end
    end
end

local function processQueue()
    if processing then return end
    processing = true
    local budget = BoundaryConfig.max_redraws_per_frame or 1
    local processed = 0
    while processed < budget and #soupQueue > 0 do
        local payload = table.remove(soupQueue, 1)
        drawSoup(payload)
        processed += 1
    end
    if processed < 1 and #soupQueue > 0 then
        print(string.format("[Boundary/Renderer] throttle redrawn=%d queued=%d", processed, #soupQueue))
    end
    processing = false
end

if RE_Delta then
RE_Delta.OnClientEvent:Connect(function(payload)
    if payload then
        -- Handle full replace payload
        if payload.replace or payload.full then
            enqueueSoup(payload)
            if BoundaryMask and BoundaryMask.setSoup and payload.soup then
                pcall(BoundaryMask.setSoup, payload.soup)
            end
            -- log batches count if present
            local b = (payload.full and payload.full.batches) or {}
            print(string.format("[Boundary/Renderer] RE_Delta pub_id=%s batches=%d queue=%d", 
                tostring(payload.pub_id or payload.version or -1), 
                #b, 
                #soupQueue))
            if payload.canvasY and State and State.setPlaneY then 
                pcall(State.setPlaneY, payload.canvasY) 
            end
        -- Handle delta payload
        elseif payload.delta then
            enqueueSoup(payload)
            local adds = payload.delta.adds or {}
            print(string.format("[Boundary/Renderer] RE_Delta delta pub_id=%s adds=%d queue=%d", 
                tostring(payload.pub_id or -1), 
                #adds, 
                #soupQueue))
        end
    end
end)
end

task.defer(function()
    -- Wait a bit for server to be ready with default pond
    task.wait(1.0)  -- Give server time to create default pond and boundary graph
    
    if RF_Get then
        local ok, resp = pcall(function() return RF_Get:InvokeServer() end)
        if ok and resp then
            print(string.format("[Boundary/Renderer] Got initial soup version=%s batches=%d", 
                tostring(resp.version), 
                resp.full and #(resp.full.batches or {}) or 0))
            
            -- Handle both old and new format
            if resp.full and resp.full.batches and #resp.full.batches > 0 then
                -- New format with batches - this is what we need!
                enqueueSoup(resp)
            elseif resp.soup then
                -- Old format - try to use it anyway
                enqueueSoup({ replace = true, soup = resp.soup or resp, version = resp.version or 0 })
            else
                warn("[Boundary/Renderer] Initial soup has no batches, waiting for delta")
            end
            
            gotSoupAt = os.clock()
            if BoundaryMask and BoundaryMask.setSoup and resp.soup then
                pcall(BoundaryMask.setSoup, resp.soup)
            end
        else
            warn("[Boundary/Renderer] Failed to get initial soup:", tostring(resp))
        end
    else
        warn("[Boundary/Renderer] RF_BoundaryGetSoup missing; will rely on events")
    end
end)

game:GetService("RunService").Heartbeat:Connect(processQueue)

-- ADDED: Boundary markers toggle (M key)
-- Auto-enable markers only while placement tools are equipped
local markersEnabled = false
local lastBuildToolSeenAt: number? = nil
local OFF_GRACE_SECONDS = 0.35 -- avoid flicker/re-render when swapping build tools
local function autoUpdateMarkers()
    local want = toolEquipped()
    local now = os.clock()
    if want then
        lastBuildToolSeenAt = now
    end
    -- Hysteresis: keep markers on briefly after losing tool to absorb quick swaps
    local effectiveWant = want or ((lastBuildToolSeenAt ~= nil) and ((now - (lastBuildToolSeenAt :: number)) < OFF_GRACE_SECONDS))
    if effectiveWant ~= markersEnabled then
        markersEnabled = effectiveWant
        local strat = requireDotted()
        strat.setEnabled(markersEnabled)
        if markersEnabled then
            print("[Boundary/Renderer] markers_visible=true (placement tool equipped)")
        else
            print("[Boundary/Renderer] markers_visible=false (no placement tool)")
        end
    end
end
game:GetService("RunService").Heartbeat:Connect(function()
    autoUpdateMarkers()
end)

-- Dev commands
Players.LocalPlayer.Chatted:Connect(function(msg)
    local lower = msg:lower()
    -- Dots renderer controls
    local dotsCmd = lower:match("^boundary%.dots%s+(%a+)")
    if dotsCmd then
        local strat = requireDotted()
        strat.setEnabled(dotsCmd == "on")
        print(string.format("[Boundary/Renderer] dots=%s", dotsCmd))
        return
    end
    local which, val = lower:match("^boundary%.lod%s+(%a+)%s+(%d+)")
    if which and val then
        local v = tonumber(val) or 0
        if which == "near" then BoundaryConfig.lod_near_distance = v; print("[Boundary/LOD] near=", v)
        elseif which == "far" then BoundaryConfig.lod_far_distance = v; print("[Boundary/LOD] far=", v) end
        return
    end
    local halo = lower:match("^boundary%.halo%s+(%a+)")
    if halo then BoundaryConfig.halo_enabled = (halo == "on"); print("[Boundary/Halo] enabled=", BoundaryConfig.halo_enabled) return end
    local hints = lower:match("^boundary%.hints%s+(%a+)")
    if hints then BoundaryConfig.hints_enabled = (hints == "on"); print("[Boundary/Hints] enabled=", BoundaryConfig.hints_enabled) return end
    if lower:match("^boundary%.stats") then
        local strat = requireDotted()
        local s = strat.getStats and strat.getStats() or { batches = 0, dots = 0, pool = 0 }
        print(string.format("[Boundary/Renderer] stats pool=%d batches=%d dots=%d", s.pool or 0, s.batches or 0, s.dots or 0))
        return
    end
end)

-- Init log and watchdogs
print(string.format("[Boundary/Renderer] strategy=%s enabled=%s", "DottedMarkers", tostring(BoundaryConfig.boundary_renderer_enabled)))
task.delay(5.0, function()
    if not gotSoupAt then
        print(string.format("[Boundary/Renderer] warn=no_soup_5s flag=%s", tostring(BoundaryConfig.boundary_renderer_enabled)))
    end
end)
local lastQueueNonEmpty: number? = nil
game:GetService("RunService").Heartbeat:Connect(function()
    if #soupQueue > 0 then
        if not lastQueueNonEmpty then lastQueueNonEmpty = os.clock() end
        if os.clock() - (lastQueueNonEmpty or 0) > 2.0 then
            print(string.format("[Boundary/Renderer] warn=queue_stall len=%d", #soupQueue))
            lastQueueNonEmpty = os.clock()
        end
    else
        lastQueueNonEmpty = nil
    end
end)
