--!strict
local RS = game:GetService("ReplicatedStorage")
local BoundaryTypes = require(RS.Shared.Boundary.BoundaryTypes)
local BoundaryConfig = require(RS.Shared.Boundary.BoundaryConfig)

export type BoundaryGraph = BoundaryTypes.BoundaryGraph
export type PolylineSoup = BoundaryTypes.PolylineSoup

local Geometry = {}

local function rateGate(tag: string)
    local cfg = BoundaryConfig
    if not cfg.debug_enabled then return true end
    local key = "__rate_"..tag
    local now = os.clock()
    local store = (Geometry :: any)
    local last = store[key]
    local countKey = key.."_count"
    local count = store[countKey] or 0
    if not last or (now - last) >= 1.0 then
        store[key] = now
        store[countKey] = 1
        return true
    end
    if count < (cfg.debug_rate_limit_per_s or 20) then
        store[countKey] = count + 1
        return true
    end
    return false
end

local function v2(x: number, y: number): Vector2 return Vector2.new(x,y) end
local function clamp(x: number, a: number, b: number): number if x<a then return a end if x>b then return b end return x end
local function segLen(a: Vector2, b: Vector2): number return (b-a).Magnitude end
local function unit(v: Vector2): Vector2 local m=v.Magnitude; if m<=1e-8 then return v2(0,0) end return v/m end
local function normalFor(a: Vector2, b: Vector2): Vector2 local d=unit(b-a); return v2(-d.Y,d.X) end

local function resampleByStep(path: {Vector2}, step: number): {Vector2}
    if #path<2 then return {table.unpack(path)} end
    local out = {}; local acc=0; local prev = path[1]; table.insert(out, prev)
    for i=2,#path do
        local cur = path[i]; local d = cur - prev; local L = d.Magnitude; local dir = (L>0) and (d/L) or v2(0,0)
        local t = step - acc
        while t <= L do table.insert(out, prev + dir*t); t += step end
        acc = (L - (t - step)); prev = cur
    end
    if out[#out] ~= path[#path] then table.insert(out, path[#path]) end
    return out
end

local function mergeShortSegments(pts: {Vector2}, minLen: number): {Vector2}
    if #pts<2 then return pts end
    local out = { pts[1] }
    for i=2,#pts do local a=out[#out]; local b=pts[i]; if segLen(a,b) >= minLen then table.insert(out,b) end end
    if #out<2 then out={pts[1], pts[#pts]} end
    return out
end

local function computePerVertexNormals(path:{Vector2}):{Vector2}
    local n=#path; local norms = table.create(n)
    for i=1,n do
        local a=(i>1) and path[i-1] or path[i]; local b=path[i]; local c=(i<n) and path[i+1] or path[i]
        local n1=normalFor(a,b); local n2=normalFor(b,c); local avg=unit(n1+n2); if avg.Magnitude<1e-6 then avg=n1 end
        norms[i]=avg
    end
    return norms
end

local function offsetRimsFromCenterline(center:{Vector2}, halfWidth:number):({Vector2},{Vector2})
    local norms=computePerVertexNormals(center); local left=table.create(#center); local right=table.create(#center)
    for i=1,#center do left[i]=center[i]+norms[i]*halfWidth; right[i]=center[i]-norms[i]*halfWidth end
    return left,right
end

local function angleOf(p: Vector2): number return math.atan2(p.Y,p.X) end
local function wrapAngle(a:number):number local t=a%(2*math.pi); if t<0 then t+=2*math.pi end return t end

type Interval = { [number]: number }

local function mergeIntervals(intervals:{Interval}):{Interval}
    if #intervals == 0 then return {} end
    -- Normalize to [0,2pi) and sort by start angle
    for i=1,#intervals do
        local a0 = wrapAngle(intervals[i][1])
        local a1 = wrapAngle(intervals[i][2])
        if a1 < a0 then a1 += 2*math.pi end
        intervals[i][1], intervals[i][2] = a0, a1
    end
    table.sort(intervals,function(A,B) return A[1] < B[1] end)
    local out = {}
    local eps = BoundaryConfig.angle_epsilon or 1e-6
    for _,iv in ipairs(intervals) do
        if #out==0 then
            table.insert(out,{iv[1],iv[2]})
        else
            local last = out[#out]
            if iv[1] <= last[2] + eps then
                last[2] = math.max(last[2], iv[2])
            else
                table.insert(out,{iv[1],iv[2]})
            end
        end
    end
    -- Wrap-seam safety: if any interval exceeds 2pi, split into tail and head
    local splitOut = {}
    for _,iv in ipairs(out) do
        if iv[2] > 2*math.pi + eps then
            table.insert(splitOut, { iv[1], 2*math.pi })
            table.insert(splitOut, { 0.0, iv[2] - 2*math.pi })
        else
            table.insert(splitOut, iv)
        end
    end
    -- Re-merge after splitting in case of adjacency at seam
    if #splitOut > 0 then
        table.sort(splitOut,function(A,B) return A[1] < B[1] end)
        local merged = {}
        for _,iv in ipairs(splitOut) do
            if #merged==0 then table.insert(merged, {iv[1],iv[2]}) else
                local last = merged[#merged]
                if iv[1] <= last[2] + eps then last[2] = math.max(last[2], iv[2]) else table.insert(merged, {iv[1],iv[2]}) end
            end
        end
        return merged
    end
    return out
end

local function complementIntervals(intervals:{Interval}):{Interval}
    local out = {}; local start=0.0
    for _,iv in ipairs(intervals) do if iv[1] > start then table.insert(out,{start,iv[1]}) end; start=iv[2] end
    if start < 2*math.pi then table.insert(out,{start,2*math.pi}) end
    return out
end

local function sampleArc(center:Vector2, R:number, a0:number, a1:number, chordStuds:number):{Vector2}
    local dtheta = 2*math.asin(clamp(chordStuds/(2*R), 1e-5, 1)); local n = math.max(2, math.floor(math.abs(a1-a0)/math.max(1e-5,dtheta))+1)
    local pts = table.create(n)
    for i=0,n-1 do local t=i/(n-1); local a=a0+(a1-a0)*t; pts[i+1]=center+Vector2.new(math.cos(a),math.sin(a))*R end
    return pts
end

-- Helper functions for canal clipping (from CanalBuilder logic)
local function clipPathOutsideCircleStart(path: { Vector2 }, center: Vector2, R: number): { Vector2 }
    local function inside(p: Vector2) return (p - center).Magnitude < R end
    if #path < 2 then return path end
    local idx = 1
    while idx <= #path and inside(path[idx]) do idx += 1 end
    if idx == 1 then return path end -- already starts outside
    if idx > #path then return { } end -- entire path inside
    local a = path[idx - 1]
    local b = path[idx]
    -- bisection to find crossing
    local lo, hi = 0.0, 1.0
    for _ = 1, 16 do
        local mid = (lo + hi) * 0.5
        local p = a + (b - a) * mid
        if inside(p) then lo = mid else hi = mid end
    end
    local cross = a + (b - a) * hi
    local out = {}
    table.insert(out, cross)
    for i = idx, #path do table.insert(out, path[i]) end
    return out
end

local function clipPathOutsideCircleEnd(path: { Vector2 }, center: Vector2, R: number): { Vector2 }
    local function inside(p: Vector2) return (p - center).Magnitude < R end
    if #path < 2 then return path end
    local idx = #path
    while idx >= 1 and inside(path[idx]) do idx -= 1 end
    if idx == #path then return path end -- already ends outside
    if idx < 1 then return { } end -- entire path inside
    local a = path[idx]
    local b = path[idx + 1]
    local lo, hi = 0.0, 1.0
    for _ = 1, 16 do
        local mid = (lo + hi) * 0.5
        local p = a + (b - a) * mid
        if inside(p) then hi = mid else lo = mid end
    end
    local cross = a + (b - a) * lo
    local out = {}
    for i = 1, idx do table.insert(out, path[i]) end
    table.insert(out, cross)
    return out
end

-- M1: Dot soup helpers
local function deg(x:number):number return math.deg(x) end

local function unifyAndMergeGapIntervals(gaps:{Interval}):{Interval}
    -- Normalize angles to [-pi, pi) for stable wrap merging
    local function norm(a:number):number
        local t = ((a + math.pi) % (2*math.pi))
        if t < 0 then t += 2*math.pi end
        return t - math.pi
    end
    for i=1,#gaps do
        local a0 = norm(gaps[i][1])
        local a1 = norm(gaps[i][2])
        if a1 < a0 then a1 += 2*math.pi end
        gaps[i][1], gaps[i][2] = a0, a1
    end
    table.sort(gaps, function(A,B) return A[1] < B[1] end)
    local merged = {}
    local eps = (BoundaryConfig.angle_epsilon or 1e-6)
    for _, iv in ipairs(gaps) do
        if #merged == 0 then
            table.insert(merged, {iv[1], iv[2]})
        else
            local last = merged[#merged]
            if iv[1] <= last[2] + eps then
                last[2] = math.max(last[2], iv[2])
            else
                table.insert(merged, {iv[1], iv[2]})
            end
        end
    end
    -- Wrap seam: if first starts near -pi and last extends beyond +pi, merge across seam
    if #merged >= 2 then
        local first = merged[1]
        local last = merged[#merged]
        if first[1] <= -math.pi + 1e-6 and last[2] >= math.pi - 1e-6 then
            -- join them
            local joined = { last[1] - 2*math.pi, first[2] }
            local rest = {}
            for i=2,#merged-1 do table.insert(rest, merged[i]) end
            table.insert(rest, joined)
            merged = rest
        end
    end
    -- Map back to [0,2pi) for downstream consumers
    for i=1,#merged do
        merged[i][1] = wrapAngle(merged[i][1])
        merged[i][2] = wrapAngle(merged[i][2])
        if merged[i][2] < merged[i][1] then merged[i][2] += 2*math.pi end
    end
    table.sort(merged, function(A,B) return A[1] < B[1] end)
    return merged
end

function Geometry.computePondGaps(graph: BoundaryGraph, pondId: string, R: number, halfWidth: number): { Interval }
    local node = graph.nodes[pondId]
    if not node then return {} end
    local center = node.posXZ
    local dotSpacing = BoundaryConfig.dotSpacing or 3.5
    local rimPad = math.max(dotSpacing * 0.25, 0.25)
    local w = halfWidth + rimPad
    local epsRad = math.min((dotSpacing / math.max(1e-5, 3*R)), 0.035)
    -- Prefer junctions if enabled
    if BoundaryConfig.useJunctions then
        local arcs = {}
        local okSnap, PNS = pcall(function()
            return require(game:GetService("ServerScriptService"):WaitForChild("Systems"):WaitForChild("PondNetworkService"))
        end)
        if okSnap and PNS and PNS.snapshot and PNS.snapshot.lakes then
            for lakeId, lake in pairs(PNS.snapshot.lakes) do
                local juncs = lake.junctions or {}
                for _, jc in ipairs(juncs) do
                    if jc.pondId == pondId and jc.theta ~= nil and jc.arcHalfWidth ~= nil then
                        local a0 = jc.theta - jc.arcHalfWidth
                        local a1 = jc.theta + jc.arcHalfWidth
                        table.insert(arcs, { a0, a1 })
                    end
                end
            end
            if #arcs > 0 then
                local merged = unifyAndMergeGapIntervals(arcs)
                -- Degree cap and logs as usual
                local degree = 0
                for _, e in pairs(graph.edges or {}) do if e.a == pondId or e.b == pondId then degree += 1 end end
                if #merged > degree and degree > 0 then
                    table.sort(merged, function(A,B) return (A[2]-A[1]) > (B[2]-B[1]) end)
                    while #merged > degree do table.remove(merged) end
                    table.sort(merged, function(A,B) return A[1] < B[1] end)
                end
                if rateGate("Arc") then
                    local degTotal = 0; local maxW=0
                    for _, iv in ipairs(merged) do local w2=(iv[2]-iv[1]); degTotal += w2; if w2>maxW then maxW=w2 end end
                    print(string.format("[Boundary/Junction] pond=%s degree=%d juncs=%d arcs=%d totalsDeg=%.2f", tostring(pondId), degree, #arcs, #merged, deg(degTotal)))
                end
                return merged
            end
            -- useJunctions is on but no junctions found for this pond: no gaps
            return {}
        end
    end
    local function segCircleHits(a: Vector2, b: Vector2, c: Vector2, r: number): { { t: number, p: Vector2 } }
        local d = b - a
        local f = a - c
        local A = d:Dot(d)
        local B = 2 * f:Dot(d)
        local C = f:Dot(f) - r*r
        local disc = B*B - 4*A*C
        local out = {}
        if disc < 0 then return out end
        local s = math.sqrt(disc)
        local t1 = (-B - s)/(2*A)
        local t2 = (-B + s)/(2*A)
        if t1 >= 0 and t1 <= 1 then table.insert(out, { t = t1, p = a + d*t1 }) end
        if t2 >= 0 and t2 <= 1 and math.abs(t2 - t1) > 1e-6 then table.insert(out, { t = t2, p = a + d*t2 }) end
        return out
    end
    -- One gap per pond/lake; choose the entry/exit intersection nearest the respective endpoint
    local arcs = {}
    for lakeId, e in pairs(graph.edges or {}) do
        if e.a == pondId or e.b == pondId then
            local raw = e.path or {}
            local pts: {Vector2} = {}
            for i=1,#raw do
                local p = raw[i]
                if typeof(p) == "Vector3" then p = Vector2.new((p :: Vector3).X, (p :: Vector3).Z) end
                if typeof(p) == "Vector2" then table.insert(pts, p) end
            end
            if #pts < 2 then
                if rateGate("Arc") then print(string.format("[Boundary/Gaps] skip pond=%s lake=%s reason=short_path pts=%d", tostring(pondId), tostring(lakeId), #pts)) end
            else
                local chooseFromStart = (e.a == pondId)
                local chosen: Vector2? = nil
                local bestScore = math.huge
                for i=1,#pts-1 do
                    local a = pts[i]; local b = pts[i+1]
                    local hits = segCircleHits(a, b, center, R)
                    for _, h in ipairs(hits) do
                        local hitp = h.p
                        local score = chooseFromStart and (hitp - a).Magnitude or (hitp - b).Magnitude
                        if score < bestScore then bestScore = score; chosen = hitp end
                    end
                end
                if not chosen then
                    -- Fallback: nearest point on polyline to center
                    local bestD = math.huge
                    local bestP: Vector2? = nil
                    for i=1,#pts-1 do
                        local a = pts[i]; local b = pts[i+1]
                        local ab = b - a
                        local denom = ab:Dot(ab)
                        local t = 0
                        if denom > 0 then t = math.clamp((center - a):Dot(ab)/denom, 0, 1) end
                        local proj = a + ab * t
                        local d = (proj - center).Magnitude
                        if d < bestD then bestD = d; bestP = proj end
                    end
                    chosen = bestP
                    if rateGate("Arc") and chosen then
                        print(string.format("[Boundary/Gaps] fallback pond=%s lake=%s reason=no_hits", tostring(pondId), tostring(lakeId)))
                    end
                end
                if chosen then
                    local v = chosen - center
                    if v.Magnitude > 1e-6 then
                        local theta = angleOf(v)
                        local u = clamp(w/math.max(1e-5, R), 0, 1)
                        local h = math.asin(u)
                        local a0 = theta - (h + epsRad)
                        local a1 = theta + (h + epsRad)
                        table.insert(arcs, { a0, a1 })
                        if rateGate("Arc") then
                            print(string.format("[Boundary/Gaps] pond=%s lake=%s θdeg=%.2f R=%.2f hit=(%.2f,%.2f)", tostring(pondId), tostring(lakeId), deg(theta), R, chosen.X, chosen.Y))
                        end
                    end
                end
            end
        end
    end
    local merged = unifyAndMergeGapIntervals(arcs)
    -- Degree sanity: do not exceed attached canal count
    local degree = 0
    for _, e in pairs(graph.edges or {}) do if e.a == pondId or e.b == pondId then degree += 1 end end
    if #merged > degree and degree > 0 then
        table.sort(merged, function(A,B) return (A[2]-A[1]) > (B[2]-B[1]) end)
        if rateGate("Arc") then
            for i=degree+1,#merged do
                print(string.format("[Boundary/Gaps] dedupe pond=%s dropped_widthDeg=%.2f", tostring(pondId), deg(merged[i][2]-merged[i][1])))
            end
        end
        while #merged > degree do table.remove(merged) end
        table.sort(merged, function(A,B) return A[1] < B[1] end)
    end
    if rateGate("Arc") then
        local degTotal = 0; local maxW=0
        for _, iv in ipairs(merged) do local w2=(iv[2]-iv[1]); degTotal += w2; if w2>maxW then maxW=w2 end end
        print(string.format("[Boundary/Gaps] pond=%s arcs_merged=%d degree=%d totalsDeg=%.2f maxDeg=%.2f", tostring(pondId), #merged, degree, deg(degTotal), deg(maxW)))
    end
    return merged
end

function Geometry.samplePondRim(graph: BoundaryGraph, pondId: string, center: Vector2, R: number, gaps: { Interval }, spacing: number, y: number): any
    local eps = BoundaryConfig.angle_epsilon or 1e-6
    local keep = complementIntervals(gaps)
    if #gaps == 0 then
        -- With no lakes, keep must be full circle
        if not (#keep == 1 and math.abs((keep[1][2] - keep[1][1]) - (2*math.pi)) <= (2*eps)) then
            if rateGate("Arc") then
                print(string.format("[Boundary/Rim/Check] pond=%s keep_deg=%.2f gap_deg=%.2f EXPECT_FULL=YES", tostring(pondId), math.deg((keep[1] and (keep[1][2]-keep[1][1]) or 0)), 0.0))
            end
        end
    end
    local function sampleWith(sp:number): { any }
        local pts = {}
        local dtheta = sp / math.max(1e-5, R)
        for _, iv in ipairs(keep) do
            local a0, a1 = iv[1], iv[2]
            local a = a0
            while a <= a1 + eps do
                local p = center + Vector2.new(math.cos(a), math.sin(a))*R
                table.insert(pts, { x = p.X, y = y, z = p.Y })
                a += dtheta
            end
        end
        return pts
    end
    local pts = sampleWith(spacing)
    local minDots = 6
    local tries = 0
    while #pts > 0 and #pts < minDots and tries < 3 do
        spacing = spacing * 0.7
        pts = sampleWith(spacing)
        tries += 1
    end
    if #pts == 0 then
        print(string.format("[Boundary/Rim] skip_thin pond=%s dots=%d threshold=%d", tostring(pondId), #pts, minDots))
    end
    return { kind = "pond_rim", id = pondId, style = {}, points = pts }
end

local function resampleUniform(path:{Vector2}, step:number):{Vector2}
    return resampleByStep(path, step)
end

local function offsetPolyline(path:{Vector2}, half:number, side:number):{Vector2}
    local norms = computePerVertexNormals(path)
    local out = table.create(#path)
    for i=1,#path do out[i] = path[i] + norms[i]*(half*side) end
    return out
end

function Geometry.sampleCanalRails(graph: BoundaryGraph, lakeId: string, centerline:{Vector2}, halfWidth:number, spacing:number, y:number): (any, any)
    -- FIXED: Clip centerline to start/end at pond rims, not centers
    local clipped = centerline
    local edge = graph.edges and graph.edges[lakeId]
    if edge then
        local nodeA = edge.a and graph.nodes[edge.a]
        local nodeB = edge.b and graph.nodes[edge.b]
        
        -- Clip to ring circumferences like CanalBuilder does
        if nodeA then
            local ringR = nodeA.radius * (1 + (BoundaryConfig.pond_scale or 0.5)) + (BoundaryConfig.pad or 1.25)
            clipped = clipPathOutsideCircleStart(clipped, nodeA.posXZ, ringR)
        end
        if nodeB then
            local ringR = nodeB.radius * (1 + (BoundaryConfig.pond_scale or 0.5)) + (BoundaryConfig.pad or 1.25)
            clipped = clipPathOutsideCircleEnd(clipped, nodeB.posXZ, ringR)
        end
    end
    
    -- Use moderately denser sampling for continuous canal appearance
    local denseSpacing = math.min(spacing * 0.7, 2.5)  -- Slightly denser than pond dots
    local res = resampleUniform(clipped, denseSpacing)
    if #res < 2 then
        local pts = {}
        if #clipped >= 1 then
            local a = clipped[1]
            local b = clipped[#clipped]
            table.insert(pts, {x=a.X, y=y, z=a.Y})
            table.insert(pts, {x=b.X, y=y, z=b.Y})
        end
        return { kind = "canal_left", id = lakeId.."_L", style = {}, points = pts }, { kind = "canal_right", id = lakeId.."_R", style = {}, points = pts }
    end
    local left = offsetPolyline(res, halfWidth, 1)
    local right = offsetPolyline(res, halfWidth, -1)
    local function dotsFrom(path:{Vector2}):{any}
        local dots = {}
        for i=1,#path do
            local p = path[i]
            table.insert(dots, { x = p.X, y = y, z = p.Y })
        end
        return dots
    end
    local L = { kind = "canal_left", id = lakeId.."_L", style = {}, points = dotsFrom(left) }
    local Rr = { kind = "canal_right", id = lakeId.."_R", style = {}, points = dotsFrom(right) }
    if rateGate("Rim") then
        print(string.format("[Boundary/Rail] lake=%s L=%d R=%d clipped=%d->%d spacing=%.2f", lakeId, #L.points, #Rr.points, #centerline, #clipped, denseSpacing))
    end
    return L, Rr
end

function Geometry.buildSoup(graph: BoundaryGraph): (PolylineSoup, any)
    local t0=os.clock(); local soup:PolylineSoup={version=graph.version, polylines={}}; local minLen=1.0/math.max(1,BoundaryConfig.pps_global); local chordStuds=10/math.max(1,BoundaryConfig.pps_global)
    local timing={ms_total=0, ms_gap=0, ms_offset=0, ms_collapse=0}
    local pondGap = {}
    local tg0=os.clock()
    for _,e in pairs(graph.edges) do
        local function edgeDirAt(isA:boolean):Vector2 if isA then return unit((#e.path>=2 and (e.path[2]-e.path[1]) or v2(1,0))) else return unit((#e.path>=2 and (e.path[#e.path]-e.path[#e.path-1]) or v2(-1,0))) end end
        local half=(e.width*0.5)+BoundaryConfig.pad
        do local n=graph.nodes[e.a]; if n then local R=n.radius*(1+BoundaryConfig.pond_scale)+BoundaryConfig.pad; local theta=angleOf(edgeDirAt(true)); local u=clamp(half/math.max(1e-5,R),0,1); if u>=0.9999 then print(string.format("[Boundary/Geometry] gap_clamped pondId=%s edgeId=%s u=%.5f",tostring(n.id),tostring(e.id),u)) end; local alpha=math.asin(u); local a0=wrapAngle(theta-alpha); local a1=wrapAngle(theta+alpha); if a1<a0 then a1+=2*math.pi end; pondGap[n.id]=pondGap[n.id] or {}; table.insert(pondGap[n.id],{a0,a1}) end end
        do local n=graph.nodes[e.b]; if n then local R=n.radius*(1+BoundaryConfig.pond_scale)+BoundaryConfig.pad; local theta=angleOf(edgeDirAt(false)); local u=clamp(half/math.max(1e-5,R),0,1); if u>=0.9999 then print(string.format("[Boundary/Geometry] gap_clamped pondId=%s edgeId=%s u=%.5f",tostring(n.id),tostring(e.id),u)) end; local alpha=math.asin(u); local a0=wrapAngle(theta-alpha); local a1=wrapAngle(theta+alpha); if a1<a0 then a1+=2*math.pi end; pondGap[n.id]=pondGap[n.id] or {}; table.insert(pondGap[n.id],{a0,a1}) end end
    end
    timing.ms_gap=(os.clock()-tg0)*1000
    local tc0=os.clock()
    for id,n in pairs(graph.nodes) do
        local center=n.posXZ; local R=n.radius*(1+BoundaryConfig.pond_scale)+BoundaryConfig.pad; local gaps=pondGap[id] or {}
        for i=1,#gaps do gaps[i][1]=wrapAngle(gaps[i][1]); gaps[i][2]=wrapAngle(gaps[i][2]); if gaps[i][2] < gaps[i][1] then gaps[i][2]+=2*math.pi end end
        local merged=mergeIntervals(gaps)
        local keep=complementIntervals(merged)
        local prunedAny = false
        local prunedCount = 0
        local eps = BoundaryConfig.angle_epsilon or 1e-6
        -- Choose pixel step for ring sampling
        local pxStep = math.max(1, BoundaryConfig.ring_px_step or 6)
        chordStuds = pxStep / math.max(1, BoundaryConfig.pps_global)
        if rateGate("Arc") then
            local degTotal = 0
            for _, g in ipairs(gaps) do degTotal += (g[2]-g[1]) end
            print(string.format("[Boundary/Arc] version=%d pond=%s gaps=%d deg_total=%.2f eps=%.5f", graph.version or -1, tostring(id), #gaps, math.deg(degTotal), eps))
        end
        if #keep == 0 then
            -- No gaps: emit full ring as dense polyline; mark :full for validator
            local a0, a1 = 0.0, 2*math.pi - eps
            local pts=sampleArc(center,R,a0,a1, chordStuds); pts=mergeShortSegments(pts,minLen)
            table.insert(soup.polylines,{id="pond:"..id..":full", pts=pts})
            if rateGate("Arc") then
                print(string.format("[Boundary/Arc] version=%d pond=%s type=full px_step=%d", graph.version or -1, tostring(id), pxStep))
            end
        else
            -- Special case: single keep interval that effectively covers full circle
            if #keep == 1 and (keep[1][2] - keep[1][1]) >= (2*math.pi - 2*eps) then
                local a0, a1 = 0.0, 2*math.pi - eps
                local pts=sampleArc(center,R,a0,a1, chordStuds); pts=mergeShortSegments(pts,minLen)
                table.insert(soup.polylines,{id="pond:"..id..":full", pts=pts})
                if rateGate("Arc") then
                    print(string.format("[Boundary/Arc] version=%d pond=%s type=full px_step=%d", graph.version or -1, tostring(id), pxStep))
                end
            else
                for ai,iv in ipairs(keep) do
                -- Pixel guard: drop micro-arcs whose chord < 1px at current PPS
                local dtheta = math.max(0, iv[2]-iv[1])
                local chord = 2*R*math.sin(math.min(math.pi, dtheta*0.5))
                local px = chord * (BoundaryConfig.pps_global or 24)
                if px < 1.0 then
                    prunedAny = true; prunedCount += 1
                else
                    local pts=sampleArc(center,R,iv[1],iv[2],chordStuds); pts=mergeShortSegments(pts,minLen)
                    table.insert(soup.polylines,{id="pond:"..id..":"..tostring(ai), pts=pts})
                end
                end
            end
        end
        if prunedAny then
            if rateGate("Arc") then
                print(string.format("[Boundary/Arc] version=%d pond=%s reason=below_1px count=%d px_floor=%d", graph.version or -1, tostring(id), prunedCount, 1))
            end
        end
    end
    timing.ms_collapse=(os.clock()-tc0)*1000
    local to0=os.clock()
    for _,e in pairs(graph.edges) do
        local step=10/math.max(1,BoundaryConfig.pps_global); local center=resampleByStep(e.path, step); center=mergeShortSegments(center, minLen); local half=(e.width*0.5)+BoundaryConfig.pad
        local left,right=offsetRimsFromCenterline(center, half); left=mergeShortSegments(left,minLen); right=mergeShortSegments(right,minLen)
        -- Equalize counts to prevent rim_vertex_mismatch due to asymmetric collapse
        if #left ~= #right then
            local n = math.min(#left, #right)
            if n >= 2 then
                local l2 = table.create(n); for i=1,n do l2[i] = left[i] end; left = l2
                local r2 = table.create(n); for i=1,n do r2[i] = right[i] end; right = r2
                if rateGate("Rim") then
                    print(string.format("[Boundary/Rim] version=%d lake=%s L=%d R=%d equalized=%s collapse_sym=%s", graph.version or -1, tostring(e.id), #l2, #r2, tostring(true), tostring(false)))
                end
            end
        elseif rateGate("Rim") then
            print(string.format("[Boundary/Rim] version=%d lake=%s L=%d R=%d equalized=%s collapse_sym=%s", graph.version or -1, tostring(e.id), #left, #right, tostring(false), tostring(false)))
        end
        table.insert(soup.polylines,{id="edge:"..e.id..":L", pts=left}); table.insert(soup.polylines,{id="edge:"..e.id..":R", pts=right})
    end
    timing.ms_offset=(os.clock()-to0)*1000; timing.ms_total=(os.clock()-t0)*1000
    return soup, timing
end

local function segmentsIntersect(p1:Vector2,p2:Vector2,p3:Vector2,p4:Vector2):boolean
    local function orient(a:Vector2,b:Vector2,c:Vector2):number return (b.X-a.X)*(c.Y-a.Y)-(b.Y-a.Y)*(c.X-a.X) end
    local o1=orient(p1,p2,p3); local o2=orient(p1,p2,p4); local o3=orient(p3,p4,p1); local o4=orient(p3,p4,p2)
    if o1==0 and o2==0 and o3==0 and o4==0 then
        local function between(a:number,b:number,c:number):boolean return (b>=math.min(a,c)-1e-6) and (b<=math.max(a,c)+1e-6) end
        return between(p1.X,p3.X,p2.X) and between(p1.Y,p3.Y,p2.Y)
    end
    return (o1*o2<=0) and (o3*o4<=0)
end

function Geometry.validateSoup(soup: PolylineSoup, graph: BoundaryGraph?): (boolean, string?, any)
    local t0=os.clock(); local minLen=1.0/math.max(1,BoundaryConfig.pps_global); local timing={ms_total=0, ms_intersect=0, ms_arccover=0}
    local totalSegments=0; local ti0=os.clock()
    for _,pl in ipairs(soup.polylines) do
        local pts=pl.pts or {}
        for i=1,#pts-1 do if segLen(pts[i],pts[i+1])<minLen then return false, "short_segment", timing end end
        totalSegments += math.max(0,#pts-1)
        if totalSegments <= (BoundaryConfig.validate_segments_ceiling or 12000) then
            for i=1,#pts-2 do for j=i+2,#pts-1 do if segmentsIntersect(pts[i],pts[i+1],pts[j],pts[j+1]) then timing.ms_intersect=(os.clock()-ti0)*1000; if rateGate("Rim") then print(string.format("[Boundary/Rim] event=self_intersect retry=bevel success=%s","false")) end; return false, "self_intersection", timing end end end
        else
            if rateGate("Validate") then
                print(string.format("[Boundary/Validate] ceiling_hit segments=%d ceiling=%d action=%s", totalSegments, BoundaryConfig.validate_segments_ceiling or 12000, "skip_intersect"))
            end
        end
    end
    timing.ms_intersect=(os.clock()-ti0)*1000
    local rims={}
    for _,pl in ipairs(soup.polylines) do local id=pl.id or ""; local eid,side=id:match("edge:(.+):([LR])"); if eid and side then rims[eid]=rims[eid] or {}; table.insert(rims[eid], #pl.pts) end end
    for eid,counts in pairs(rims) do if #counts~=2 then return false, "rim_count_mismatch:"..eid end; if counts[1] ~= counts[2] then return false, "rim_vertex_mismatch:"..eid end end
    local ta0=os.clock()
    if graph then
        for pondId,n in pairs(graph.nodes) do
            local R=n.radius*(1+BoundaryConfig.pond_scale)+BoundaryConfig.pad
            local gaps={}
            for _,e in pairs(graph.edges) do
                local function dirAt(isA:boolean):Vector2 if isA then return unit((#e.path>=2 and (e.path[2]-e.path[1]) or v2(1,0))) else return unit((#e.path>=2 and (e.path[#e.path]-e.path[#e.path-1]) or v2(-1,0))) end end
                local half=(e.width*0.5)+BoundaryConfig.pad
                if e.a==pondId then local theta=angleOf(dirAt(true)); local u=clamp(half/math.max(1e-5,R),0,1); local alpha=math.asin(u); local a0=wrapAngle(theta-alpha); local a1=wrapAngle(theta+alpha); if a1<a0 then a1+=2*math.pi end; table.insert(gaps,{a0,a1})
                elseif e.b==pondId then local theta=angleOf(dirAt(false)); local u=clamp(half/math.max(1e-5,R),0,1); local alpha=math.asin(u); local a0=wrapAngle(theta-alpha); local a1=wrapAngle(theta+alpha); if a1<a0 then a1+=2*math.pi end; table.insert(gaps,{a0,a1}) end
            end
            local merged=mergeIntervals(gaps)
            -- If there are no gaps, totalKeep is full circle
            local totalKeep=2*math.pi; for _,iv in ipairs(merged) do totalKeep -= (iv[2]-iv[1]) end
            local totalArc=0
            for _,pl in ipairs(soup.polylines) do
                local id=pl.id or ""
                local pid, tag = id:match("pond:([^:]+):([^:]*)")
                if pid==pondId then
                    local pts=pl.pts or {}
                    if tag == "full" then
                        totalArc += 2*math.pi
                        -- Skip chord check for full arcs
                    elseif #pts>=2 then
                        local aFirst=angleOf(pts[1]-n.posXZ)
                        local aLast=angleOf(pts[#pts]-n.posXZ)
                        local da=wrapAngle(aLast-aFirst)
                        totalArc += da
                        local chord=segLen(pts[1], pts[#pts])
                        if chord < minLen then
                            if rateGate("Validate") then
                                print(string.format("[Boundary/Validate] version=%d pond=%s reason=%s", graph.version or -1, pondId, "arc_chord_tiny"))
                            end
                            return false, "arc_chord_tiny", timing
                        end
                    end
                end
            end
            local eps=(BoundaryConfig.area_epsilon or 0.05)
            if math.abs(totalArc-totalKeep) > eps then
                if rateGate("Validate") then
                    print(string.format("[Boundary/Validate] version=%d pond=%s reason=%s exp=%.3f got=%.3f", graph.version or -1, pondId, (totalArc<totalKeep) and "missing" or "overlap", totalKeep, totalArc))
                end
                return false, "arc_coverage_mismatch", timing
            end
        end
    end
    timing.ms_arccover=(os.clock()-ta0)*1000; timing.ms_total=(os.clock()-t0)*1000
    return true, nil, timing
end

return Geometry
