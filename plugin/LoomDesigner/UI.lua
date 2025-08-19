--!strict
local RequireUtil = require(script.Parent.RequireUtil)
local LoomDesigner = require(script.Parent.Main)

local UI = {}

local function makeSection(parent: Instance, title: string): Frame
local sec = Instance.new("Frame")
sec.BackgroundTransparency = 1
sec.Size = UDim2.new(1, -20, 0, 0)
sec.AutomaticSize = Enum.AutomaticSize.Y
sec.Parent = parent

local header = Instance.new("TextLabel")
header.Text = title
header.Font = Enum.Font.SourceSansSemibold
header.TextSize = 18
header.TextColor3 = Color3.fromRGB(220,220,220)
header.BackgroundTransparency = 1
header.Size = UDim2.new(1, 0, 0, 28)
header.Parent = sec

local group = Instance.new("Frame")
group.BackgroundTransparency = 1
group.Size = UDim2.new(1, 0, 0, 0)
group.Position = UDim2.new(0,0,0,30)
group.AutomaticSize = Enum.AutomaticSize.Y
group.Parent = sec

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = group

return group
end

local function labeledTextBox(parent: Instance, label: string, defaultText: string, onCommit: (string)->())
local row = Instance.new("Frame")
row.Size = UDim2.new(1, 0, 0, 26)
row.BackgroundTransparency = 1
row.Parent = parent

local lab = Instance.new("TextLabel")
lab.Text = label
lab.BackgroundTransparency = 1
lab.TextColor3 = Color3.fromRGB(200,200,200)
lab.TextXAlignment = Enum.TextXAlignment.Left
lab.Size = UDim2.new(0, 150, 1, 0)
lab.Parent = row

local box = Instance.new("TextBox")
box.Text = defaultText
box.Size = UDim2.new(1, -160, 1, 0)
box.Position = UDim2.new(0, 155, 0, 0)
box.BackgroundColor3 = Color3.fromRGB(42,42,42)
box.TextColor3 = Color3.new(1,1,1)
box.Parent = row

box.FocusLost:Connect(function(enterPressed)
if enterPressed then onCommit(box.Text) end
end)
return box
end

local function checkbox(parent: Instance, label: string, defaultState: boolean, onToggle: (boolean)->())
local btn = Instance.new("TextButton")
btn.Size = UDim2.new(0,180,0,24)
btn.BackgroundColor3 = Color3.fromRGB(48,48,48)
btn.TextColor3 = Color3.new(1,1,1)
local state = defaultState
local function render()
    btn.Text = (state and "[x] " or "[ ] ") .. label
end
btn.MouseButton1Click:Connect(function()
    state = not state
    render()
    onToggle(state)
end)
render()
btn.Parent = parent
return btn
end

-- Overlay-safe dropdown: mounts popup to popupHost
local function dropdown(parent: Instance, popupHost: Frame, label: string, options: {string}, defaultIndex: number, onSelect: (string)->())
local row = Instance.new("Frame")
row.Size = UDim2.new(1, 0, 0, 26)
row.BackgroundTransparency = 1
row.Parent = parent

local lab = Instance.new("TextLabel")
lab.Text = label
lab.BackgroundTransparency = 1
lab.TextColor3 = Color3.fromRGB(200,200,200)
lab.TextXAlignment = Enum.TextXAlignment.Left
lab.Size = UDim2.new(0, 150, 1, 0)
lab.Parent = row

local btn = Instance.new("TextButton")
btn.Text = options[defaultIndex] or "Select…"
btn.Size = UDim2.new(1, -160, 1, 0)
btn.Position = UDim2.new(0, 155, 0, 0)
btn.BackgroundColor3 = Color3.fromRGB(42,42,42)
btn.TextColor3 = Color3.new(1,1,1)
btn.Parent = row

local open = false
local popup: Frame? = nil

local function closePopup()
open = false
if popup then popup:Destroy(); popup = nil end
end

btn.MouseButton1Click:Connect(function()
if open then closePopup(); return end
open = true

popup = Instance.new("Frame")
popup.BackgroundColor3 = Color3.fromRGB(36,36,36)
popup.BorderSizePixel = 1
popup.ZIndex = 1001
popup.Parent = popupHost

-- Position popup under the button in absolute space
local btnAbs = btn.AbsolutePosition
local rootAbs = popupHost.AbsolutePosition
popup.Position = UDim2.fromOffset(btnAbs.X - rootAbs.X, btnAbs.Y - rootAbs.Y + btn.AbsoluteSize.Y)
popup.Size = UDim2.fromOffset(btn.AbsoluteSize.X, math.min(#options, 10)*22 + 4)

local list = Instance.new("UIListLayout")
list.Parent = popup
list.Padding = UDim.new(0, 2)
list.SortOrder = Enum.SortOrder.LayoutOrder

for _, opt in ipairs(options) do
local item = Instance.new("TextButton")
item.Text = opt
item.Size = UDim2.new(1, -4, 0, 20)
item.Position = UDim2.fromOffset(2, 0)
item.BackgroundColor3 = Color3.fromRGB(50,50,50)
item.TextColor3 = Color3.new(1,1,1)
item.ZIndex = 1002
item.Parent = popup

item.MouseButton1Click:Connect(function()
btn.Text = opt
onSelect(opt)
closePopup()
end)
end
end)

-- click-away to close
popupHost.InputBegan:Connect(function(input)
if open and popup then
if input.UserInputType == Enum.UserInputType.MouseButton1 then
local pos = input.Position
local p0 = popup.AbsolutePosition
local p1 = p0 + popup.AbsoluteSize
if not (pos.X >= p0.X and pos.X <= p1.X and pos.Y >= p0.Y and pos.Y <= p1.Y) then
closePopup()
end
end
end
end)
end

function UI.Build(widget: PluginGui, plugin: Plugin, where)
local controlsHost: Frame = where.controlsHost
local popupHost: Frame = where.popupHost

-- Scrolling container
local scroll = Instance.new("ScrollingFrame")
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 8
scroll.Size = UDim2.fromScale(1,1)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new(0,0,0,0)
scroll.Parent = controlsHost

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 10)
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = scroll

local spawnBtn = Instance.new("TextButton")
spawnBtn.Size = UDim2.new(0,180,0,26)
spawnBtn.BackgroundColor3 = Color3.fromRGB(48,48,48)
spawnBtn.TextColor3 = Color3.new(1,1,1)
spawnBtn.Parent = scroll

local function updateSpawnLabel()
local folder = workspace:FindFirstChild("LoomPreview")
if folder and folder:FindFirstChild("PreviewBranch") then
spawnBtn.Text = "Rebuild Preview"
else
spawnBtn.Text = "Spawn Preview"
end
end

spawnBtn.MouseButton1Click:Connect(function()
LoomDesigner.RebuildPreview(nil)
updateSpawnLabel()
end)

updateSpawnLabel()

-- === Sections ===
local secConfig = makeSection(scroll, "Branch Config")
local secSeed   = makeSection(scroll, "Seed / Randomness")
local secGrowth = makeSection(scroll, "Growth Progression")
local secSeg    = makeSection(scroll, "Segment Overrides")
local secPath   = makeSection(scroll, "Path Style")
local secGeo    = makeSection(scroll, "Segment Geometry")
local secScale  = makeSection(scroll, "Size Profile")
local secRot    = makeSection(scroll, "Rotation Rules")
local secDeco   = makeSection(scroll, "Decorations")

-- Config dropdown (list from LoomConfigs keys)
local LoomConfigs = require(game.ReplicatedStorage.looms.LoomConfigs)
local configIds = {}
for id, _ in pairs(LoomConfigs) do table.insert(configIds, id) end
table.sort(configIds)

dropdown(secConfig, popupHost, "Config", configIds, 1, function(id)
LoomDesigner.SetConfigId(id)
LoomDesigner.RebuildPreview(nil)
end)

local seedLabel
local seedBox = labeledTextBox(secSeed, "Seed", tostring(LoomDesigner.GetSeed()), function(txt)
LoomDesigner.SetSeed(txt)
LoomDesigner.RebuildPreview(nil)
seedBox.Text = tostring(LoomDesigner.GetSeed())
seedLabel.Text = "Current Seed: " .. tostring(LoomDesigner.GetSeed())
end)
seedLabel = Instance.new("TextLabel")
seedLabel.BackgroundTransparency = 1
seedLabel.TextColor3 = Color3.fromRGB(200,200,200)
seedLabel.Size = UDim2.new(1,0,0,20)
seedLabel.TextXAlignment = Enum.TextXAlignment.Left
seedLabel.Text = "Current Seed: " .. tostring(LoomDesigner.GetSeed())
seedLabel.Parent = secSeed

local randBtn = Instance.new("TextButton")
randBtn.Text = "Reroll"
randBtn.Size = UDim2.new(0,180,0,26)
randBtn.BackgroundColor3 = Color3.fromRGB(48,48,48)
randBtn.TextColor3 = Color3.new(1,1,1)
randBtn.Parent = secSeed
randBtn.MouseButton1Click:Connect(function()
local newSeed = LoomDesigner.RandomizeSeed()
seedBox.Text = tostring(newSeed)
seedLabel.Text = "Current Seed: " .. tostring(newSeed)
LoomDesigner.RebuildPreview(nil)
end)

checkbox(secSeed, "Seed affects segmentCount", true, function(val)
    LoomDesigner.SetOverrides({seedAffects = {segmentCount = val}})
    LoomDesigner.RebuildPreview(nil)
end)
checkbox(secSeed, "Seed affects curvature", true, function(val)
    LoomDesigner.SetOverrides({seedAffects = {curvature = val}})
    LoomDesigner.RebuildPreview(nil)
end)
checkbox(secSeed, "Seed affects frequency", true, function(val)
    LoomDesigner.SetOverrides({seedAffects = {frequency = val}})
    LoomDesigner.RebuildPreview(nil)
end)
checkbox(secSeed, "Seed affects jitter", true, function(val)
    LoomDesigner.SetOverrides({seedAffects = {jitter = val}})
    LoomDesigner.RebuildPreview(nil)
end)

checkbox(secSeed, "Seed affects Twist", true, function(val)
    LoomDesigner.SetOverrides({seedAffects = {twist = val}})
    LoomDesigner.RebuildPreview(nil)
end)

labeledTextBox(secGrowth, "Growth % (0-100)", "50", function(txt)
local n = tonumber(txt)
if n then
LoomDesigner.SetGrowthPercent(math.clamp(n, 0, 100))
LoomDesigner.RebuildPreview(nil)
end
end)

labeledTextBox(secSeg, "Segment Count Override", "", function(txt)
local n = tonumber(txt)
local o = {}
if n then o.segmentCount = math.max(1, math.floor(n)) end
LoomDesigner.SetOverrides(o)
LoomDesigner.RebuildPreview(nil)
end)

labeledTextBox(secSeg, "SegmentCount Min", "", function(txt)
local n = tonumber(txt)
if n then
    LoomDesigner.SetOverrides({segmentCountMin = n})
    LoomDesigner.RebuildPreview(nil)
end
end)

labeledTextBox(secSeg, "SegmentCount Max", "", function(txt)
local n = tonumber(txt)
if n then
    LoomDesigner.SetOverrides({segmentCountMax = n})
    LoomDesigner.RebuildPreview(nil)
end
end)

local function setPath(field, value)
    LoomDesigner.SetOverrides({path = {[field] = value}})
    LoomDesigner.RebuildPreview(nil)
end

dropdown(secPath, popupHost, "Style", {"straight","curved","zigzag","noise","sigmoid","chaotic"}, 2, function(opt)
    setPath("style", opt)
end)

labeledTextBox(secPath, "Amplitude Deg", "10", function(txt)
local n = tonumber(txt)
if n then setPath("amplitudeDeg", n) end
end)

labeledTextBox(secPath, "Frequency", "0.35", function(txt)
local n = tonumber(txt)
if n then setPath("frequency", n) end
end)

labeledTextBox(secPath, "Curvature", "0.35", function(txt)
local n = tonumber(txt)
if n then setPath("curvature", n) end
end)

labeledTextBox(secPath, "Zigzag Every", "1", function(txt)
local n = tonumber(txt)
if n then setPath("zigzagEvery", n) end
end)

labeledTextBox(secPath, "Sigmoid K", "6", function(txt)
local n = tonumber(txt)
if n then setPath("sigmoidK", n) end
end)

labeledTextBox(secPath, "Sigmoid Mid", "0.5", function(txt)
local n = tonumber(txt)
if n then setPath("sigmoidMid", n) end
end)

labeledTextBox(secPath, "Chaotic R", "3.9", function(txt)
local n = tonumber(txt)
if n then setPath("chaoticR", n) end
end)

labeledTextBox(secPath, "Micro Jitter Deg", "2", function(txt)
    local n = tonumber(txt)
    if n then setPath("microJitterDeg", n) end
end)

checkbox(secPath, "Enable Heading Jitter", true, function(val)
    LoomDesigner.SetOverrides({enableMicroJitter = val})
    LoomDesigner.RebuildPreview(nil)
end)

-- === Segment Geometry ===
dropdown(secGeo, popupHost, "Mode", {"Model", "Part"}, 1, function(opt)
local o = {materialization = {mode = opt}}
LoomDesigner.SetOverrides(o)
LoomDesigner.RebuildPreview(nil)
end)

dropdown(secGeo, popupHost, "Part Type", {"Block","Ball","Cylinder","Wedge","CornerWedge"}, 1, function(opt)
local o = {materialization = {part = {partType = Enum.PartType[opt]}}}
LoomDesigner.SetOverrides(o)
LoomDesigner.RebuildPreview(nil)
end)

labeledTextBox(secGeo, "Base Length", "2", function(txt)
local n = tonumber(txt)
if n then
    LoomDesigner.SetOverrides({materialization = {part = {baseLength = n}}})
    LoomDesigner.RebuildPreview(nil)
end
end)

labeledTextBox(secGeo, "Base Thickness", "1", function(txt)
local n = tonumber(txt)
if n then
    LoomDesigner.SetOverrides({materialization = {part = {baseThickness = n}}})
    LoomDesigner.RebuildPreview(nil)
end
end)

local NamedColors = {
white=Color3.new(1,1,1), black=Color3.new(0,0,0), red=Color3.new(1,0,0),
lime=Color3.new(0,1,0), blue=Color3.new(0,0,1), yellow=Color3.new(1,1,0),
cyan=Color3.new(0,1,1), magenta=Color3.new(1,0,1), gray=Color3.fromRGB(128,128,128),
grey=Color3.fromRGB(128,128,128), brown=Color3.fromRGB(165,42,42)
}

local function parseColor3(s)
if typeof(s) == "Color3" then return s end
s = tostring(s):lower():gsub("%s+", "")
if NamedColors[s] then return NamedColors[s] end
local r,g,b = s:match("^rgb%((%d+),(%d+),(%d+)%)$")
if not r then
    r,g,b = s:match("^(%d+),(%d+),(%d+)$")
end
local function parseVector3(s)
    local x,y,z = tostring(s):match("^%s*([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)%s*$")
    if x then
        return Vector3.new(tonumber(x), tonumber(y), tonumber(z))
    end
    return Vector3.new()
end
if r and g and b then
    return Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b))
end
if s:sub(1,1) ~= "#" then s = "#" .. s end
local hex = s:match("^#(%x%x)(%x%x)(%x%x)$")
if hex then
    local rr,gg,bb = s:sub(2,3), s:sub(4,5), s:sub(6,7)
    return Color3.fromRGB(tonumber(rr,16), tonumber(gg,16), tonumber(bb,16))
end
return Color3.fromRGB(255,255,255)
end

labeledTextBox(secGeo, "Color", "#ffffff", function(txt)
local c = parseColor3(txt)
if c then
    LoomDesigner.SetOverrides({materialization = {part = {color = c}}})
    LoomDesigner.RebuildPreview(nil)
end
end)

-- === Size Profile ===
local currentProfile = {mode = "constant", value = 1, enableJitter = true}
local valueBox, startBox, finishBox, baseBox, ampBox, powerBox

local function commitProfile()
    LoomDesigner.SetOverrides({scaleProfile = currentProfile})
    LoomDesigner.RebuildPreview(nil)
end

local function updateProfileVis()
    local mode = currentProfile.mode
    if valueBox then valueBox.Parent.Visible = (mode == "constant") end
    local lin = (mode == "linear_down" or mode == "linear_up")
    if startBox then startBox.Parent.Visible = lin end
    if finishBox then finishBox.Parent.Visible = lin end
    local bell = (mode == "bell" or mode == "inverse_bell")
    if baseBox then baseBox.Parent.Visible = bell end
    if ampBox then ampBox.Parent.Visible = bell end
    if powerBox then powerBox.Parent.Visible = bell end
end

checkbox(secScale, "Enable Size Jitter", true, function(val)
    LoomDesigner.SetOverrides({enableScaleJitter = val})
    LoomDesigner.RebuildPreview(nil)
end)

dropdown(secScale, popupHost, "Mode", {"constant","linear_down","linear_up","bell","inverse_bell"}, 1, function(opt)
    currentProfile.mode = opt
    commitProfile()
    updateProfileVis()
end)

valueBox = labeledTextBox(secScale, "Value", "1", function(txt)
    local n = tonumber(txt)
    if n then currentProfile.value = n; commitProfile() end
end)

startBox = labeledTextBox(secScale, "Start", "1", function(txt)
    local n = tonumber(txt)
    if n then currentProfile.start = n; commitProfile() end
end)

finishBox = labeledTextBox(secScale, "Finish", "0.6", function(txt)
    local n = tonumber(txt)
    if n then currentProfile.finish = n; commitProfile() end
end)

baseBox = labeledTextBox(secScale, "Base", "0.7", function(txt)
    local n = tonumber(txt)
    if n then currentProfile.base = n; commitProfile() end
end)

ampBox = labeledTextBox(secScale, "Amp", "0.5", function(txt)
    local n = tonumber(txt)
    if n then currentProfile.amp = n; commitProfile() end
end)

powerBox = labeledTextBox(secScale, "Power", "2", function(txt)
    local n = tonumber(txt)
    if n then currentProfile.power = n; commitProfile() end
end)

checkbox(secScale, "Profile Jitter", true, function(val)
    currentProfile.enableJitter = val
    commitProfile()
end)

updateProfileVis()

checkbox(secDeco, "Enable Decorations", false, function(val)
    LoomDesigner.SetOverrides({decorations = {enabled = val}})
    LoomDesigner.RebuildPreview(nil)
end)

labeledTextBox(secDeco, "Kind", "leaf", function(txt)
    LoomDesigner.SetOverrides({decorations = {types = {[1] = {kind = txt}}}})
    LoomDesigner.RebuildPreview(nil)
end)

labeledTextBox(secDeco, "AssetId", "", function(txt)
    local n = tonumber(txt)
    if n then
        LoomDesigner.SetOverrides({decorations = {types = {[1] = {assetId = n}}}})
        LoomDesigner.RebuildPreview(nil)
    end
end)

labeledTextBox(secDeco, "Density/Seg", "0.5", function(txt)
    local n = tonumber(txt)
    if n then
        LoomDesigner.SetOverrides({decorations = {types = {[1] = {densityPerSeg = n}}}})
        LoomDesigner.RebuildPreview(nil)
    end
end)

labeledTextBox(secDeco, "Scale Min", "0.6", function(txt)
    local n = tonumber(txt)
    if n then
        LoomDesigner.SetOverrides({decorations = {types = {[1] = {scaleMin = n}}}})
        LoomDesigner.RebuildPreview(nil)
    end
end)

labeledTextBox(secDeco, "Scale Max", "1.2", function(txt)
    local n = tonumber(txt)
    if n then
        LoomDesigner.SetOverrides({decorations = {types = {[1] = {scaleMax = n}}}})
        LoomDesigner.RebuildPreview(nil)
    end
end)

labeledTextBox(secDeco, "Yaw", "45", function(txt)
    local n = tonumber(txt)
    if n then
        LoomDesigner.SetOverrides({decorations = {types = {[1] = {yaw = n}}}})
        LoomDesigner.RebuildPreview(nil)
    end
end)

labeledTextBox(secDeco, "Pitch", "20", function(txt)
    local n = tonumber(txt)
    if n then
        LoomDesigner.SetOverrides({decorations = {types = {[1] = {pitch = n}}}})
        LoomDesigner.RebuildPreview(nil)
    end
end)

labeledTextBox(secDeco, "Roll", "20", function(txt)
    local n = tonumber(txt)
    if n then
        LoomDesigner.SetOverrides({decorations = {types = {[1] = {roll = n}}}})
        LoomDesigner.RebuildPreview(nil)
    end
end)

labeledTextBox(secDeco, "Color", "auto", function(txt)
    LoomDesigner.SetOverrides({decorations = {types = {[1] = {color = txt}}}})
    LoomDesigner.RebuildPreview(nil)
end)

labeledTextBox(secDeco, "Attach", "along", function(txt)
    LoomDesigner.SetOverrides({decorations = {attach = txt}})
    LoomDesigner.RebuildPreview(nil)
end)

labeledTextBox(secDeco, "Offset (x,y,z)", "0,0.2,0", function(txt)
    local v = parseVector3(txt)
    LoomDesigner.SetOverrides({decorations = {offset = v}})
    LoomDesigner.RebuildPreview(nil)
end)

-- === Rotation Rules ===
dropdown(secRot, popupHost, "Continuity", {"Auto", "Accumulate", "Absolute"}, 1, function(opt)
    if opt == "Accumulate" then
        LoomDesigner.SetOverrides({rotationRules = {continuity = "accumulate"}})
    elseif opt == "Absolute" then
        LoomDesigner.SetOverrides({rotationRules = {continuity = "absolute"}})
    else
        LoomDesigner.ClearOverride({"rotationRules","continuity"})
    end
    LoomDesigner.RebuildPreview(nil)
end)

labeledTextBox(secRot, "Yaw Clamp Deg", "", function(txt)
local n = tonumber(txt)
LoomDesigner.SetOverrides({rotationRules = {yawClampDeg = n}})
LoomDesigner.RebuildPreview(nil)
end)

checkbox(secRot, "Enable Twist", true, function(val)
    LoomDesigner.SetOverrides({enableTwist = val})
    LoomDesigner.RebuildPreview(nil)
end)

labeledTextBox(secRot, "Pitch Clamp Deg", "", function(txt)
local n = tonumber(txt)
LoomDesigner.SetOverrides({rotationRules = {pitchClampDeg = n}})
LoomDesigner.RebuildPreview(nil)
end)

labeledTextBox(secRot, "Extra Roll/Seg", "", function(txt)
local n = tonumber(txt)
LoomDesigner.SetOverrides({rotationRules = {extraRollPerSegDeg = n}})
LoomDesigner.RebuildPreview(nil)
end)

labeledTextBox(secRot, "Random Roll Range", "", function(txt)
local n = tonumber(txt)
LoomDesigner.SetOverrides({rotationRules = {randomRollRangeDeg = n}})
LoomDesigner.RebuildPreview(nil)
end)

labeledTextBox(secRot, "FaceForward Bias", "", function(txt)
local n = tonumber(txt)
LoomDesigner.SetOverrides({rotationRules = {faceForwardBias = n}})
LoomDesigner.RebuildPreview(nil)
end)
end

return UI
