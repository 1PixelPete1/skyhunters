--!strict
-- StrokeRenderer2D: draw polylines inside a SurfaceGui using Frame segments

local StrokeRenderer2D = {}

export type Canvas = {
    id: string,
    gui: SurfaceGui,
    container: Instance,
}

local function ensureContainer(cv: Canvas): Instance
    local c = cv.container
    if not c or not c.Parent then
        c = Instance.new("Folder")
        c.Name = "Segments"
        c.Parent = cv.gui
        cv.container = c
    end
    return c
end

local function getOrMake(c: Instance, index: number): Frame
    local name = string.format("Seg_%04d", index)
    local f = c:FindFirstChild(name)
    if f and f:IsA("Frame") then return f end
    f = Instance.new("Frame")
    f.Name = name
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.BorderSizePixel = 0
    f.BackgroundColor3 = Color3.new(0, 1, 0)
    f.Parent = c
    return f
end

local function snap(v: number): number
    return math.floor(v + 0.5)
end

function StrokeRenderer2D.drawPolyline(cv: Canvas, pointsPx: { Vector2 }, thicknessPx: number, color: Color3, maxSegments: number): number
    local c = ensureContainer(cv)
    local used = 0
    local n = #pointsPx
    for i = 1, n - 1 do
        if used >= maxSegments then break end
        local a = pointsPx[i]
        local b = pointsPx[i + 1]
        local d = b - a
        local len = d.Magnitude
        if len >= 1.0 then
            used += 1
            local f = getOrMake(c, used)
            f.Visible = true
            f.BackgroundColor3 = color
            local w = snap(len)
            local mid = (a + b) * 0.5
            f.Size = UDim2.fromOffset(w, thicknessPx)
            f.Position = UDim2.fromOffset(snap(mid.X), snap(mid.Y))
            f.Rotation = math.deg(math.atan2(d.Y, d.X))
        end
    end
    -- hide remaining
    local idx = used + 1
    while true do
        local name = string.format("Seg_%04d", idx)
        local f = c:FindFirstChild(name)
        if not f or not f:IsA("Frame") then break end
        f.Visible = false
        idx += 1
    end
    return used
end

function StrokeRenderer2D.clear(cv: Canvas)
    local c = ensureContainer(cv)
    for _, ch in ipairs(c:GetChildren()) do
        if ch:IsA("Frame") then ch.Visible = false end
    end
end

return StrokeRenderer2D
