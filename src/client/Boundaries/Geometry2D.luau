--!strict
-- Geometry2D: pure 2D helpers on XZ plane (Vector2)

local Geometry2D = {}

local function clamp(n: number, a: number, b: number): number
    if n < a then return a end
    if n > b then return b end
    return n
end

function Geometry2D.circleSample(center: Vector2, R: number, pxPerStud: number, minSeg: number, maxSeg: number, chordPx: number?): { Vector2 }
    local circ = 2 * math.pi * math.max(0.01, R)
    local pxCirc = circ * math.max(1, pxPerStud)
    local chord = math.max(1, chordPx or 10)
    -- Aim chordPx per segment; clamp between min/max
    local targetSeg = math.floor(pxCirc / chord + 0.5)
    local segs = clamp(targetSeg, math.max(3, minSeg), math.max(minSeg, maxSeg))
    local pts = table.create(segs)
    for i = 0, segs - 1 do
        local t = (i / segs) * 2 * math.pi
        pts[i + 1] = center + Vector2.new(math.cos(t) * R, math.sin(t) * R)
    end
    return pts
end

function Geometry2D.simplifyNearDuplicates(points: { Vector2 }, epsilon: number): { Vector2 }
    if #points <= 1 then return points end
    local out = {}
    local prev = points[1]
    table.insert(out, prev)
    for i = 2, #points do
        local p = points[i]
        if (p - prev).Magnitude >= (epsilon or 0) then
            table.insert(out, p)
            prev = p
        end
    end
    return out
end

function Geometry2D.resampleByArcLength(points: { Vector2 }, step: number): { Vector2 }
    local out = {}
    if #points == 0 then return out end
    local accum = 0.0
    table.insert(out, points[1])
    for i = 1, #points - 1 do
        local a = points[i]
        local b = points[i + 1]
        local seg = b - a
        local len = seg.Magnitude
        if len > 0 then
            local dir = seg / len
            local t = step - accum
            while t <= len do
                table.insert(out, a + dir * t)
                t += step
            end
            accum = (len - ((len - accum) % step)) % step
        end
    end
    if (out[#out] - points[#points]).Magnitude > (step * 0.25) then
        table.insert(out, points[#points])
    end
    return out
end

-- side: +1 (left) or -1 (right)
function Geometry2D.offsetPolylineBevel(points: { Vector2 }, offset: number, side: number): { Vector2 }
    local npts = #points
    if npts == 0 then return {} end
    if npts == 1 then return { points[1] } end
    local out = table.create(npts)
    for i = 1, npts do
        local prev = points[math.max(1, i - 1)]
        local curr = points[i]
        local nextp = points[math.min(npts, i + 1)]
        local d1 = curr - prev
        local d2 = nextp - curr
        local n1 = d1.Magnitude > 0 and Vector2.new(-d1.Y, d1.X).Unit or Vector2.new(0, 1)
        local n2 = d2.Magnitude > 0 and Vector2.new(-d2.Y, d2.X).Unit or Vector2.new(0, 1)
        local n = (n1 + n2)
        if n.Magnitude < 1e-6 then n = n1 end
        n = n.Unit * (offset * (side >= 0 and 1 or -1))
        out[i] = curr + n
    end
    return out
end

function Geometry2D.aabbOfPoints(points: { Vector2 }, pad: number): (number, number, number, number)
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    for _, p in ipairs(points) do
        if p.X < minX then minX = p.X end
        if p.Y < minY then minY = p.Y end
        if p.X > maxX then maxX = p.X end
        if p.Y > maxY then maxY = p.Y end
    end
    minX -= pad; minY -= pad; maxX += pad; maxY += pad
    return minX, minY, maxX, maxY
end

return Geometry2D
