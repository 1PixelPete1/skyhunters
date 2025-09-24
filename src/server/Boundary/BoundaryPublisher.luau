--!strict
local RS = game:GetService("ReplicatedStorage")
local BoundaryConfig = require(RS:WaitForChild("Shared"):WaitForChild("Boundary"):WaitForChild("BoundaryConfig"))
local WorldConfig = require(RS:WaitForChild("Config"):WaitForChild("WorldConfig"))

-- Ensure remote tree exists unconditionally at boot
local Net = RS:FindFirstChild("Net") or Instance.new("Folder")
Net.Name = "Net"; Net.Parent = RS
local Remotes = Net:FindFirstChild("Remotes") or Instance.new("Folder")
Remotes.Name = "Remotes"; Remotes.Parent = Net
local RF_Get = Remotes:FindFirstChild("RF_BoundaryGetSoup") or Instance.new("RemoteFunction")
RF_Get.Name = "RF_BoundaryGetSoup"; RF_Get.Parent = Remotes
local RE_Delta = Remotes:FindFirstChild("RE_BoundaryDelta") or Instance.new("RemoteEvent")
RE_Delta.Name = "RE_BoundaryDelta"; RE_Delta.Parent = Remotes

-- Require after remotes are available so clients can wait even if modules fail later
local BoundaryGraph = require(script.Parent:WaitForChild("BoundaryGraph"))
local BoundaryGeometry = require(script.Parent:WaitForChild("BoundaryGeometry"))
local BoundaryHeightUtil = require(RS.Shared:WaitForChild("BoundaryHeightUtil"))

local lastPublishedVersion = -1
local lastGoodSoup: any = nil
local soupVer = 3
local junctionsVer = 1
print(string.format("[Boundary/Publisher] init soupVer=%d junctionsVer=%d", soupVer, junctionsVer))

local function rateGate(tag: string)
    local cfg = BoundaryConfig
    if not cfg.debug_enabled then return true end
    local bucket = script:GetAttribute("__rate_"..tag)
    local now = os.clock()
    if not bucket then
        script:SetAttribute("__rate_"..tag, now)
        script:SetAttribute("__rate_count_"..tag, 1)
        return true
    end
    local count = script:GetAttribute("__rate_count_"..tag) or 0
    if now - bucket >= 1.0 then
        script:SetAttribute("__rate_"..tag, now)
        script:SetAttribute("__rate_count_"..tag, 1)
        return true
    end
    if count < (cfg.debug_rate_limit_per_s or 20) then
        script:SetAttribute("__rate_count_"..tag, count + 1)
        return true
    end
    return false
end

local lastDotBatchesById: { [string]: any } = {}
local lastPubId = 0
local pending = false
local pendingAffected: { [string]: boolean } = {}
local lastPublishAt = 0.0

local function countDots(batches: { any }): number
    local n = 0
    for _, b in ipairs(batches) do n += #(b.points or {}) end
    return n
end

-- Centralized height calculation using BoundaryHeightUtil
-- Removed local raycastToTerrain function to use centralized version

local function buildAllDotBatches(graph): { any }
    local cfg = BoundaryConfig
    local spacing = cfg.dotSpacing or 3.5
    local lift = (cfg.dotLiftY or 0.05)
    local half = cfg.canalHalfWidth or 2.0
    
    -- Use the configured island surface height as a base, but raycast for actual terrain
    local islandSurfaceY = (WorldConfig.ISLANDS and WorldConfig.ISLANDS.DefaultHeightY) or 1
    
    local function buildWith(sp)
        local tmp = {}
        -- Try to read PondNetworkService snapshot for per-feature Y baking
        local PNSsnap: any = nil
        do
            local okSnap, PNS = pcall(function()
                return require(game:GetService("ServerScriptService"):WaitForChild("Systems"):WaitForChild("PondNetworkService"))
            end)
            if okSnap and PNS and PNS.snapshot then PNSsnap = PNS.snapshot end
        end
        for pondId, n in pairs(graph.nodes or {}) do
            local R = n.radius * (1 + (cfg.pond_scale or 0)) + (cfg.pad or 0)
            local okG, gaps = pcall(function() return require(script.Parent.BoundaryGeometry).computePondGaps(graph, pondId, R, half) end)
            
            -- Use centralized height calculation for consistency
            local pondY = BoundaryHeightUtil.getBoundaryRenderY("pond_rim", n.posXZ, pondId)
            
            local okB, batch = pcall(function() return require(script.Parent.BoundaryGeometry).samplePondRim(graph, pondId, n.posXZ, R, okG and gaps or {}, sp, pondY) end)
            if okB and batch then
                batch.id = "pond_"..pondId; batch.kind = "pond_rim"
                table.insert(tmp, batch)
            else
                local id = "pond_"..pondId
                if lastDotBatchesById[id] then table.insert(tmp, lastDotBatchesById[id]) end
                if rateGate("Publish") then print(string.format("[Boundary/Publish] skip id=%s reason=build_error err=%s", id, tostring(batch))) end
            end
        end
        for lakeId, e in pairs(graph.edges or {}) do
            -- Use centralized height calculation for rails
            local pathMidpoint = #e.path > 0 and e.path[math.ceil(#e.path / 2)] or Vector2.new(0, 0)
            local railY = BoundaryHeightUtil.getCanalRailY(lakeId, pathMidpoint)
            
            -- Use denser spacing for canal rails but not too dense
            local railSpacing = math.min(sp * 0.7, 2.5)  -- Slightly denser than ponds but not excessive
            local okLR, L, Rr = pcall(function()
                local l, r = require(script.Parent.BoundaryGeometry).sampleCanalRails(graph, lakeId, e.path, half, railSpacing, railY)
                return l, r
            end)
            if okLR and L and Rr then
                L.id = "lake_"..lakeId.."_L"; Rr.id = "lake_"..lakeId.."_R"
                table.insert(tmp, L); table.insert(tmp, Rr)
            else
                local lidL = "lake_"..lakeId.."_L"
                local lidR = "lake_"..lakeId.."_R"
                if lastDotBatchesById[lidL] then table.insert(tmp, lastDotBatchesById[lidL]) end
                if lastDotBatchesById[lidR] then table.insert(tmp, lastDotBatchesById[lidR]) end
                if rateGate("Publish") then print(string.format("[Boundary/Publish] skip id=%s/%s reason=build_error", lidL, lidR)) end
            end
        end
        return tmp
    end
    local batches = buildWith(spacing)
    local maxDots = cfg.maxDotsPerPublish or 6000
    if countDots(batches) > maxDots then
        local mult = math.min(4.0, math.max(1.2, math.sqrt(countDots(batches)/maxDots)))
        spacing = spacing * mult
        if rateGate("Publish") then
            print(string.format("[Boundary/Publish] rebalance spacing_up=%.2f", spacing))
        end
        batches = buildWith(spacing)
    end
    return batches
end

local function diffDotBatches(newBatches: { any }): ({ any }, { string })
    local adds = {}
    local removes = {}
    local seen: { [string]: boolean } = {}
    for _, b in ipairs(newBatches) do
        local id = b.id
        seen[id] = true
        local prev = lastDotBatchesById[id]
        if not prev or #(prev.points or {}) ~= #(b.points or {}) then
            lastDotBatchesById[id] = b
            table.insert(adds, b)
        end
    end
    for id, _ in pairs(lastDotBatchesById) do
        if not seen[id] then table.insert(removes, id); lastDotBatchesById[id] = nil end
    end
    return adds, removes
end

local function publishReplace(soup, buildTiming, validateTiming)
    local polyCount = #(soup.polylines or {}); local segs = 0
    for _, pl in ipairs(soup.polylines or {}) do segs += math.max(0, #(pl.pts or {}) - 1) end
    local ponds = 0; local lakes = 0
    -- note: graph context not here; estimate by id prefix
    for _, pl in ipairs(soup.polylines or {}) do
        local id = pl.id or ""
        if id:match("^pond:") then ponds += 1 elseif id:match("^edge:") then lakes += 1 end
    end
    if rateGate("Publish") then
        print(string.format("[Boundary/Publish] pub_id=%d polylines=%d segments=%d ponds=%d lakes=%d ms_build=%.2f ms_validate=%.2f",
            soup.version or -1, polyCount, segs, ponds, lakes,
            (buildTiming and buildTiming.ms_total) or 0, (validateTiming and validateTiming.ms_total) or 0))
    end
    if BoundaryConfig.telemetry_enabled and rateGate("Geometry") then
        print(string.format("[Boundary/Geometry] stage=build version=%d pub_id=%d ms_total=%.2f ms_gap=%.2f ms_offset=%.2f ms_collapse=%.2f",
            soup.version or -1, soup.version or -1, (buildTiming and buildTiming.ms_total) or 0, (buildTiming and buildTiming.ms_gap) or 0, (buildTiming and buildTiming.ms_offset) or 0, (buildTiming and buildTiming.ms_collapse) or 0))
    end
    if BoundaryConfig.telemetry_enabled and rateGate("Validate") then
        print(string.format("[Boundary/Validate] stage=validate version=%d pub_id=%d ms_total=%.2f ms_intersect=%.2f ms_arccover=%.2f",
            soup.version or -1, soup.version or -1, (validateTiming and validateTiming.ms_total) or 0, (validateTiming and validateTiming.ms_intersect) or 0, (validateTiming and validateTiming.ms_arccover) or 0))
    end
    -- Build dot soup full
    local snap = BoundaryGraph.snapshot()
    local dotBatches = buildAllDotBatches(snap)
    lastDotBatchesById = {}
    for _, b in ipairs(dotBatches) do lastDotBatchesById[b.id] = b end
    if #dotBatches == 0 then
        warn("[Boundary/Publish] FATAL no_batches_on_first_publish")
        return
    end
    lastPubId += 1
    local tSend0 = os.clock()
    local canvasY = ((WorldConfig.ISLANDS and WorldConfig.ISLANDS.DefaultHeightY) or 0) + (BoundaryConfig.dotLiftY or 0.05)
    local payload = { replace = true, version = soup.version, soup = soup, full = { batches = dotBatches }, pub_id = lastPubId, stats = { build = buildTiming, validate = validateTiming }, soupVer = soupVer, junctionsVer = junctionsVer, canvasY = canvasY }
    
    -- Cache the full payload for RF_Get requests
    lastGoodSoup = payload
    lastPublishedVersion = soup.version or lastPublishedVersion
    
    RE_Delta:FireAllClients(payload)
    local msSend = (os.clock()-tSend0)*1000
    if rateGate("Publish") then
        print(string.format("[Boundary/Publish] pub_id=%d batches=%d dots=%d ponds=%d lakes=%d ms_build=%.2f ms_validate=%.2f ms_send=%.2f",
            lastPubId, #dotBatches, countDots(dotBatches), ponds, lakes,
            (buildTiming and buildTiming.ms_total) or 0, (validateTiming and validateTiming.ms_total) or 0, msSend))
    end
end

local function onGraphChanged(version: number, op: string?, id: string?)
    task.defer(function()
        -- throttle coalescing
        pending = true
        if id then pendingAffected[id] = true end
        local now = os.clock()
        if (now - lastPublishAt) * 1000 < (BoundaryConfig.publishMinIntervalMs or 120) and lastPublishedVersion >= 0 then
            return
        end
        lastPublishAt = now
        local snap = BoundaryGraph.snapshot()
        local soup, bTiming = BoundaryGeometry.buildSoup(snap)
        local ok, reason, vTiming = BoundaryGeometry.validateSoup(soup, snap)
        if not ok then
            if rateGate("Publish") then
                print(string.format("[Boundary/Publish] pub_id=%d status=blocked reason=%s", snap.version or -1, tostring(reason)))
            end
            return
        end
        if lastPublishedVersion < 0 or soup.version ~= lastPublishedVersion then
            publishReplace(soup, bTiming, vTiming)
            pending = false; pendingAffected = {}
            return
        end
        -- Delta path
        local spacing = BoundaryConfig.dotSpacing or 3.5
        local lift = BoundaryConfig.dotLiftY or 0.05
        local half = BoundaryConfig.canalHalfWidth or 2.0
        local islandSurfaceY = (WorldConfig.ISLANDS and WorldConfig.ISLANDS.DefaultHeightY) or 1
        
        local function buildFor(idKey: string): { any }
            local batches = {}
            local e = snap.edges[idKey]
            local n = snap.nodes[idKey]
            if e then
                -- Use centralized height calculation for rails
                local pathMidpoint = #e.path > 0 and e.path[math.ceil(#e.path / 2)] or Vector2.new(0, 0)
                local railY = BoundaryHeightUtil.getCanalRailY(idKey, pathMidpoint)
                local okLR, L, Rr = pcall(function() return BoundaryGeometry.sampleCanalRails(snap, idKey, e.path, half, spacing, railY) end)
                if okLR and L and Rr then
                    L.id = "lake_"..idKey.."_L"; Rr.id = "lake_"..idKey.."_R"
                    table.insert(batches, L); table.insert(batches, Rr)
                else
                    local lidL = "lake_"..idKey.."_L"
                    local lidR = "lake_"..idKey.."_R"
                    if lastDotBatchesById[lidL] then table.insert(batches, lastDotBatchesById[lidL]) end
                    if lastDotBatchesById[lidR] then table.insert(batches, lastDotBatchesById[lidR]) end
                    if rateGate("Publish") then print(string.format("[Boundary/Publish] skip id=%s/%s reason=build_error", lidL, lidR)) end
                end
                -- neighbor ponds
                local na = snap.nodes[e.a]; local nb = snap.nodes[e.b]
                if na then
                    local R = na.radius * (1 + (BoundaryConfig.pond_scale or 0)) + (BoundaryConfig.pad or 0)
                    local okG, gaps = pcall(function() return BoundaryGeometry.computePondGaps(snap, e.a, R, half) end)
                    
                    -- Use centralized height calculation for pond A
                    local pondYa = BoundaryHeightUtil.getBoundaryRenderY("pond_rim", na.posXZ, e.a)
                    local okB, bA = pcall(function() return BoundaryGeometry.samplePondRim(snap, e.a, na.posXZ, R, okG and gaps or {}, spacing, pondYa) end)
                    if okB and bA then
                        bA.id = "pond_"..e.a
                        table.insert(batches, bA)
                    elseif lastDotBatchesById["pond_"..e.a] then
                        table.insert(batches, lastDotBatchesById["pond_"..e.a])
                    end
                end
                if nb then
                    local R = nb.radius * (1 + (BoundaryConfig.pond_scale or 0)) + (BoundaryConfig.pad or 0)
                    local okG2, gaps2 = pcall(function() return BoundaryGeometry.computePondGaps(snap, e.b, R, half) end)
                    
                    -- Use centralized height calculation for pond B
                    local pondYb = BoundaryHeightUtil.getBoundaryRenderY("pond_rim", nb.posXZ, e.b)
                    local okB2, bB = pcall(function() return BoundaryGeometry.samplePondRim(snap, e.b, nb.posXZ, R, okG2 and gaps2 or {}, spacing, pondYb) end)
                    if okB2 and bB then
                        bB.id = "pond_"..e.b
                        table.insert(batches, bB)
                    elseif lastDotBatchesById["pond_"..e.b] then
                        table.insert(batches, lastDotBatchesById["pond_"..e.b])
                    end
                end
            elseif n then
                local R = n.radius * (1 + (BoundaryConfig.pond_scale or 0)) + (BoundaryConfig.pad or 0)
                local okG, gaps = pcall(function() return BoundaryGeometry.computePondGaps(snap, idKey, R, half) end)
                
                -- Use centralized height calculation for standalone pond
                local pondY = BoundaryHeightUtil.getBoundaryRenderY("pond_rim", n.posXZ, idKey)
                local okB, b = pcall(function() return BoundaryGeometry.samplePondRim(snap, idKey, n.posXZ, R, okG and gaps or {}, spacing, pondY) end)
                if okB and b then
                    b.id = "pond_"..idKey
                    table.insert(batches, b)
                elseif lastDotBatchesById["pond_"..idKey] then
                    table.insert(batches, lastDotBatchesById["pond_"..idKey])
                end
            end
            return batches
        end
        local recompute: { any } = {}
        local touched = pendingAffected
        pending = false; pendingAffected = {}
        local seen = {}
        for key,_ in pairs(touched) do
            for _, b in ipairs(buildFor(key)) do
                if not seen[b.id] then table.insert(recompute, b); seen[b.id] = true end
            end
        end
        if #recompute == 0 then return end
        local adds, removes = diffDotBatches(recompute)
        -- Junction deltas: if edges touched, attach junctions for those lakes
        local junctionsAdd = {}
        local junctionsRemove = {}
        for key,_ in pairs(touched) do
            local e = snap.edges[key]
            if e then
                -- fetch junctions from PondNetwork snapshot if present
                local okSnap, PNS = pcall(function()
                    return require(game:GetService("ServerScriptService"):WaitForChild("Systems"):WaitForChild("PondNetworkService"))
                end)
                if okSnap and PNS and PNS.snapshot and PNS.snapshot.lakes and PNS.snapshot.lakes[key] then
                    local lake = PNS.snapshot.lakes[key]
                    local j = lake.junctions or {}
                    for _, jc in ipairs(j) do table.insert(junctionsAdd, jc) end
                end
            end
        end
        if (#adds + #removes + #junctionsAdd + #junctionsRemove) == 0 then return end
        lastPubId += 1
        local tSend0 = os.clock()
        local canvasY = ((WorldConfig.ISLANDS and WorldConfig.ISLANDS.DefaultHeightY) or 0) + (BoundaryConfig.dotLiftY or 0.05)
        RE_Delta:FireAllClients({ version = soup.version, delta = { junctionsRemove = junctionsRemove, junctionsAdd = junctionsAdd, adds = adds, removes = removes }, pub_id = lastPubId, soupVer = soupVer, junctionsVer = junctionsVer, canvasY = canvasY })
        local msSend = (os.clock()-tSend0)*1000
        if rateGate("Publish") then
            print(string.format("[Boundary/Publish] pub_id=%d batches=%d dots=%d ms_send=%.2f", lastPubId, (#adds)+(#removes), countDots(adds), msSend))
        end
    end)
end

BoundaryGraph.Changed:Connect(onGraphChanged)

RF_Get.OnServerInvoke = function(_player)
    -- If we have a cached good soup with batches, return it
    if lastGoodSoup and lastGoodSoup.full and lastGoodSoup.full.batches then 
        return lastGoodSoup 
    end
    
    -- Build fresh soup AND dot batches
    local snap = BoundaryGraph.snapshot()
    local soup, bTiming = BoundaryGeometry.buildSoup(snap)
    local ok, _, vTiming = BoundaryGeometry.validateSoup(soup, snap)
    
    if ok then
        -- Build dot batches (same as publishReplace does)
        local dotBatches = buildAllDotBatches(snap)
        local canvasY = ((WorldConfig.ISLANDS and WorldConfig.ISLANDS.DefaultHeightY) or 0) + (BoundaryConfig.dotLiftY or 0.05)
        
        -- Create full payload with batches
        local fullPayload = {
            replace = true,
            version = soup.version,
            soup = soup,
            full = { batches = dotBatches },
            pub_id = lastPubId + 1,
            soupVer = soupVer,
            junctionsVer = junctionsVer,
            canvasY = canvasY
        }
        
        lastGoodSoup = fullPayload
        lastPublishedVersion = soup.version
        
        print(string.format("[Boundary/Publisher] RF_Get built soup version=%d batches=%d", soup.version, #dotBatches))
        return fullPayload
    else
        warn("[Boundary/Publisher] RF_Get soup validation failed")
        -- Return minimal valid structure
        return {
            replace = true,
            version = 0,
            soup = { version = 0, polylines = {} },
            full = { batches = {} },
            soupVer = soupVer,
            junctionsVer = junctionsVer
        }
    end
end

-- Public API for forcing a publish (used by WorldBootstrap)
local Publisher = {}

function Publisher.forcePublish()
    print("[Boundary/Publisher] force_publish requested")
    local snap = BoundaryGraph.snapshot()
    local soup, bTiming = BoundaryGeometry.buildSoup(snap)
    local ok, reason, vTiming = BoundaryGeometry.validateSoup(soup, snap)
    if ok then
        publishReplace(soup, bTiming, vTiming)
    else
        warn("[Boundary/Publisher] force_publish failed validation:", reason)
    end
end

return Publisher
