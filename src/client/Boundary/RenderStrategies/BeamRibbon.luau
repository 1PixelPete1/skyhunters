--!strict
-- BeamRibbon strategy: smooth ribbons rendered with Beams slightly above terrain

local RS = game:GetService("ReplicatedStorage")
local BoundaryConfig = require(RS.Shared.Boundary.BoundaryConfig)

local ROOT = workspace:FindFirstChild("BoundaryBeams") or Instance.new("Folder")
ROOT.Name = "BoundaryBeams"; ROOT.Parent = workspace

local guide = workspace:FindFirstChild("BoundaryBeamGuide")
if not guide then
    guide = Instance.new("Part")
    guide.Name = "BoundaryBeamGuide"
    guide.Anchored = true
    guide.CanCollide = false
    guide.CanQuery = false
    guide.CanTouch = false
    guide.Transparency = 1
    guide.Size = Vector3.new(1,1,1)
    guide.Parent = ROOT
end

local beams: { Beam } = {}
local attachments: { Attachment } = {}

local function ensureAttachment(idx: number): Attachment
    local a = attachments[idx]
    if a and a.Parent then return a end
    a = Instance.new("Attachment")
    a.Name = string.format("A_%05d", idx)
    a.Parent = guide
    attachments[idx] = a
    return a
end

local function ensureBeam(idx: number): Beam
    local b = beams[idx]
    if b and b.Parent then return b end
    b = Instance.new("Beam")
    b.Name = string.format("B_%05d", idx)
    b.FaceCamera = false
    b.Color = ColorSequence.new(Color3.fromRGB(60, 255, 120))
    b.Transparency = NumberSequence.new(0.2)
    b.Width0 = 0.35; b.Width1 = 0.35
    b.Segments = 2
    b.LightEmission = 0.2
    b.Parent = ROOT
    beams[idx] = b
    return b
end

local function rimPeakY(): number
    local peak = -math.huge
    local rims = workspace:FindFirstChild("PondRims")
    if rims then
        for _, d in ipairs(rims:GetDescendants()) do
            if d:IsA("BasePart") and d.Name == "RimStone" then
                local top = d.Position.Y + d.Size.Y * 0.5
                if top > peak then peak = top end
            end
        end
    end
    if peak == -math.huge then return workspace.FallenPartsDestroyHeight + 100 end
    return peak
end

local Strategy = {}

function Strategy.clearAll()
    for _, b in ipairs(beams) do b.Enabled = false end
end

function Strategy.renderSoup(payload): number
    local soup = payload.soup
    local used = 0
    local maxBeams = BoundaryConfig.max_beams_total or 2000
    local y = rimPeakY() + 0.15
    guide.CFrame = CFrame.new(0, y, 0)
    for _, pl in ipairs(soup.polylines or {}) do
        local pts = pl.pts or {}
        for i = 1, #pts - 1 do
            if used >= maxBeams then break end
            used += 1
            local a0 = ensureAttachment(used*2-1)
            local a1 = ensureAttachment(used*2)
            a0.WorldPosition = Vector3.new(pts[i].X, y, pts[i].Y)
            a1.WorldPosition = Vector3.new(pts[i+1].X, y, pts[i+1].Y)
            local b = ensureBeam(used)
            b.Attachment0 = a0
            b.Attachment1 = a1
            b.Enabled = true
        end
        if used >= maxBeams then break end
    end
    -- disable remaining beams
    local idx = used + 1
    while idx <= #beams do
        local b = beams[idx]
        if b then b.Enabled = false end
        idx += 1
    end
    return used
end

return Strategy

