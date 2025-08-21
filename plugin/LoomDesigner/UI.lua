--!strict
local RequireUtil = require(script.Parent.RequireUtil)
local LoomDesigner = require(script.Parent.Main)
local FlowTrace = require(script.Parent.FlowTrace)
local ModelResolver = require(script.Parent.ModelResolver)

local UI = {}

local function applyAuthoringAndPreview()
    local apply = LoomDesigner.ApplyAuthoring
    if type(apply) == "function" then
        apply()
    end
    local rebuild = LoomDesigner.RebuildPreview
    if type(rebuild) == "function" then
        rebuild(nil)
    end
end

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
end

-- Overlay-safe dropdown: mounts popup to popupHost
local function dropdown(parent: Instance, popupHost: Frame, label: string, options: {any}, defaultIndex: number, onSelect: (any)->())
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

local function toStr(opt: any): string
    if typeof(opt) == "Instance" then
        return opt.Name
    else
        return tostring(opt)
    end
end

local btn = Instance.new("TextButton")
btn.Text = options[defaultIndex] and toStr(options[defaultIndex]) or "Select…"
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
    item.Text = toStr(opt)
    item.Size = UDim2.new(1, -4, 0, 20)
    item.Position = UDim2.fromOffset(2, 0)
    item.BackgroundColor3 = Color3.fromRGB(50,50,50)
    item.TextColor3 = Color3.new(1,1,1)
    item.ZIndex = 1002
    item.Parent = popup

    item.MouseButton1Click:Connect(function()
    btn.Text = toStr(opt)
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
return btn
end

local function makeBtn(parent, text, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0,80,1,0)
    b.BackgroundColor3 = Color3.fromRGB(48,48,48)
    b.TextColor3 = Color3.new(1,1,1)
    b.Text = text
    b.ZIndex = (parent.ZIndex or 0) + 1
    b.Parent = parent
    b.MouseButton1Click:Connect(cb)
    return b
end

local function bindNumberField(parent: Instance, label: string, get: ()->number?, setDraft: (number)->(), commit: ()->())
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,0,0,24)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local lab = Instance.new("TextLabel")
    lab.Text = label
    lab.BackgroundTransparency = 1
    lab.TextColor3 = Color3.fromRGB(200,200,200)
    lab.Size = UDim2.new(0,120,1,0)
    lab.TextXAlignment = Enum.TextXAlignment.Left
    lab.Parent = row

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1,-130,1,0)
    box.Position = UDim2.new(0,130,0,0)
    box.Text = tostring(get() or "")
    box.Parent = row

    local tkn
    local function push()
        local v = tonumber(box.Text)
        if v ~= nil then setDraft(v); commit() end
    end

    box:GetPropertyChangedSignal("Text"):Connect(function()
        if tkn then task.cancel(tkn) end
        tkn = task.delay(0.12, push)
    end)
    box.FocusLost:Connect(function(_)
        if tkn then task.cancel(tkn); tkn = nil end
        push()
    end)
end

local function addTooltip(target: GuiObject, text: string)
    local tip = Instance.new("TextLabel")
    tip.Text = text
    tip.Visible = false
    tip.BackgroundColor3 = Color3.fromRGB(25,25,25)
    tip.TextColor3 = Color3.fromRGB(220,220,220)
    tip.BorderSizePixel = 0
    tip.AutomaticSize = Enum.AutomaticSize.XY
    tip.Parent = target
    target.MouseEnter:Connect(function() tip.Visible = true end)
    target.MouseLeave:Connect(function() tip.Visible = false end)
end

function UI.Build(widget: PluginGui, plugin: Plugin, where)
local controlsHost: Frame = where.controlsHost
local popupHost: Frame = where.popupHost

-- Ensure LoomDesigner has a state/profile on first open
LoomDesigner.Start(plugin)

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
local status = Instance.new("TextLabel")
status.TextColor3 = Color3.fromRGB(160,200,255)
status.BackgroundTransparency = 1
status.Size = UDim2.new(1,0,0,18)
status.Font = Enum.Font.SourceSansSemibold
status.Parent = scroll

local function updateStatus()
    local assign = LoomDesigner.GetAssignments and LoomDesigner.GetAssignments() or {trunk = ""}
    local trunk = assign.trunk or "-"
    local seed = LoomDesigner.GetSeed and LoomDesigner.GetSeed() or "?"
    status.Text = string.format("Trunk: %s   Seed: %s", trunk, tostring(seed))
end
updateStatus()

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
local secConfig   = makeSection(scroll, "Branch Config")
local secSeed     = makeSection(scroll, "Seed / Randomness")
local secGrowth   = makeSection(scroll, "Growth Progression")
local secSeg      = makeSection(scroll, "Segment Overrides")
local secGeo      = makeSection(scroll, "Segment Geometry")
local secScale    = makeSection(scroll, "Size Profile")
local secRot      = makeSection(scroll, "Rotation Rules")
local secDeco     = makeSection(scroll, "Decorations")
-- Branch authoring panels
local secBranchLib = makeSection(scroll, "Branch Library")
local secBranchTree = makeSection(scroll, "Branch Tree")
local secModels    = makeSection(scroll, "Models (Authoring)")
local secDecoAuth  = makeSection(scroll, "Decorations (Authoring)")
local secIO        = makeSection(scroll, "Export / Import")

-- Forward decls for branch authoring
local selectedBranch: string? = nil
local renderBranchLibrary
local renderBranchTree

-- Config dropdown (list from LoomConfigs keys)
local LoomConfigs = require(game.ReplicatedStorage.looms.LoomConfigs)
local LoomConfigUtil = require(game.ReplicatedStorage.looms.LoomConfigUtil)

local function listConfigIds()
    local ids = {}
    for k, v in pairs(LoomConfigs) do
        if type(v) == "table" then table.insert(ids, k) end
    end
    table.sort(ids)
    return ids
end

local configIds = listConfigIds()

dropdown(secConfig, popupHost, "Config", configIds, 1, function(id)
    if type(LoomConfigs[id]) ~= "table" then
        warn("[LoomDesigner] Ignoring non-table config key: " .. tostring(id))
    else
        LoomDesigner.SetConfigId(id)
        LoomDesigner.RebuildPreview(nil)
    end
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
randBtn.Text = "Reseed"
randBtn.Size = UDim2.new(0,180,0,26)
randBtn.BackgroundColor3 = Color3.fromRGB(48,48,48)
randBtn.TextColor3 = Color3.new(1,1,1)
randBtn.Parent = secSeed
randBtn.MouseButton1Click:Connect(function()
    local newSeed = LoomDesigner.Reseed()
seedBox.Text = tostring(newSeed)
seedLabel.Text = "Current Seed: " .. tostring(newSeed)
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

checkbox(secGrowth, "Render Full", true, function(val)
    LoomDesigner.SetOverrides({designFull = val})
    LoomDesigner.RebuildPreview(nil)
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

local function parseVector3(s: any): Vector3
    local x,y,z = tostring(s):match("^%s*([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)%s*$")
    if x then
        return Vector3.new(tonumber(x), tonumber(y), tonumber(z))
    end
    return Vector3.new()
end

local function parseColor3(s)
    if typeof(s) == "Color3" then return s end
    s = tostring(s):lower():gsub("%s+", "")
    if NamedColors[s] then return NamedColors[s] end
    local r, g, b = s:match("^rgb%((%d+),(%d+),(%d+)%)$")
    if not r then
        r, g, b = s:match("^(%d+),(%d+),(%d+)$")
    end
    if r and g and b then
        return Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b))
    end
    if s:sub(1, 1) ~= "#" then
        s = "#" .. s
    end
    local rr, gg, bb = s:match("^#(%x%x)(%x%x)(%x%x)$")
    if rr then
        return Color3.fromRGB(tonumber(rr, 16), tonumber(gg, 16), tonumber(bb, 16))
    end
    return Color3.fromRGB(255, 255, 255)
end

labeledTextBox(secGeo, "Color", "#ffffff", function(txt)
local c = parseColor3(txt)
if c then
    LoomDesigner.SetOverrides({materialization = {part = {color = c}}})
    LoomDesigner.RebuildPreview(nil)
end
end)

-- === Size Profile ===
local currentProfile = {mode = "constant", value = 1, enableJitter = false}
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

checkbox(secScale, "Enable Size Jitter", false, function(val)
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

labeledTextBox(secRot, "Pitch Clamp Deg", "", function(txt)
local n = tonumber(txt)
LoomDesigner.SetOverrides({rotationRules = {pitchClampDeg = n}})
LoomDesigner.RebuildPreview(nil)
end)

labeledTextBox(secRot, "Twist Strength Deg/Seg", "", function(txt)
local n = tonumber(txt)
LoomDesigner.SetOverrides({twistStrengthDegPerSeg = n})
LoomDesigner.RebuildPreview(nil)
end)

labeledTextBox(secRot, "Twist RNG \194\177 (deg)", "", function(txt)
local n = tonumber(txt)
LoomDesigner.SetOverrides({twistRngRangeDeg = n})
LoomDesigner.RebuildPreview(nil)
end)

checkbox(secRot, "Enable Heading Jitter", false, function(val)
    LoomDesigner.SetOverrides({enableMicroJitter = val})
    LoomDesigner.RebuildPreview(nil)
end)

labeledTextBox(secRot, "Heading Jitter \194\177 (deg)", "", function(txt)
local n = tonumber(txt)
LoomDesigner.SetOverrides({microJitterDeg = n})
LoomDesigner.RebuildPreview(nil)
end)

labeledTextBox(secRot, "FaceForward Bias", "", function(txt)
    local n = tonumber(txt)
    LoomDesigner.SetOverrides({rotationRules = {faceForwardBias = n}})
    LoomDesigner.RebuildPreview(nil)
end)

-- === Authoring Panels ======================================================
-- Branch Library -------------------------------------------------------------
local branchList = Instance.new("Frame")
branchList.BackgroundTransparency = 1
branchList.Size = UDim2.new(1,0,0,0)
branchList.AutomaticSize = Enum.AutomaticSize.Y
branchList.Parent = secBranchLib

local branchLayout = Instance.new("UIListLayout")
branchLayout.SortOrder = Enum.SortOrder.LayoutOrder
branchLayout.Parent = branchList

local branchButtonsRow = Instance.new("Frame")
branchButtonsRow.Size = UDim2.new(1,0,0,26)
branchButtonsRow.BackgroundTransparency = 1
branchButtonsRow.Parent = secBranchLib

local renameBox = labeledTextBox(secBranchLib, "New Name", "", function(txt)
    if selectedBranch and txt ~= "" then
        LoomDesigner.RenameBranch(selectedBranch, txt)
        selectedBranch = txt
        applyAuthoringAndPreview()
        renderBranchLibrary()
        renderBranchTree()
    end
    renameBox.Parent.Visible = false
end)
renameBox.Parent.Visible = false

local function newBranch()
    local branches = LoomDesigner.GetBranches()
    local i = 1
    while branches["branch"..i] do i += 1 end
    local name = "branch"..i
    LoomDesigner.CreateBranch(name, {kind = "straight"})
    selectedBranch = name
    applyAuthoringAndPreview()
    updateStatus()
    renderBranchLibrary()
end

local function duplicateBranch()
    if not selectedBranch then return end
    local branches = LoomDesigner.GetBranches()
    local base = selectedBranch .. "Copy"
    local i = 1
    while branches[base..i] do i += 1 end
    local name = base..i
    LoomDesigner.CreateBranch(name, branches[selectedBranch])
    selectedBranch = name
    applyAuthoringAndPreview()
    renderBranchLibrary()
end

local function renameBranch()
    if not selectedBranch then return end
    renameBox.Text = selectedBranch
    renameBox.Parent.Visible = true
end

local function deleteBranch()
    if not selectedBranch then return end
    LoomDesigner.DeleteBranch(selectedBranch)
    selectedBranch = nil
    applyAuthoringAndPreview()
    updateStatus()
    renderBranchLibrary()
    renderBranchTree()
end

makeBtn(branchButtonsRow, "New", newBranch)
makeBtn(branchButtonsRow, "Duplicate", duplicateBranch)
makeBtn(branchButtonsRow, "Rename", renameBranch)
makeBtn(branchButtonsRow, "Delete", deleteBranch)

renderBranchLibrary = function()
    for _, c in ipairs(branchList:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
    local branches = LoomDesigner.GetBranches()
    local names = {}
    for n in pairs(branches) do table.insert(names, n) end
    table.sort(names)
    for _, name in ipairs(names) do
        local btn = Instance.new("TextButton")
        btn.Name = name
        btn.Size = UDim2.new(1,0,0,20)
        btn.BackgroundColor3 = (name == selectedBranch) and Color3.fromRGB(70,70,110) or Color3.fromRGB(48,48,48)
        btn.TextColor3 = Color3.new(1,1,1)
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Text = name
        btn.Parent = branchList
        btn.MouseButton1Click:Connect(function()
            selectedBranch = name
            LoomDesigner.EditBranch(name, {})
            applyAuthoringAndPreview()
            renderBranchLibrary()
            renderBranchTree()
        end)
    end
end

-- Branch Tree ----------------------------------------------------------------
renderBranchTree = function()
    for _, c in ipairs(secBranchTree:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
    local branches = LoomDesigner.GetBranches()
    local names = {}
    for n in pairs(branches) do table.insert(names, n) end
    table.sort(names)

    local assignments = LoomDesigner.GetAssignments()
    local trunkIdx = table.find(names, assignments.trunk) or 1
    dropdown(secBranchTree, popupHost, "Trunk", names, trunkIdx, function(opt)
        LoomDesigner.SetTrunk(opt)
        applyAuthoringAndPreview()
        updateStatus()
        renderBranchTree()
    end)

    for i, child in ipairs(assignments.children) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1,0,0,20)
        row.BackgroundTransparency = 1
        row.Parent = secBranchTree
        local lab = Instance.new("TextLabel")
        lab.Size = UDim2.new(1,-80,1,0)
        lab.BackgroundTransparency = 1
        lab.TextColor3 = Color3.fromRGB(200,200,200)
        lab.TextXAlignment = Enum.TextXAlignment.Left
        lab.Text = string.format("%s -> %s (%s x%d)", child.parent, child.child, child.placement, child.count)
        lab.Parent = row
        local del = makeBtn(row, "Remove", function()
            LoomDesigner.RemoveChild(i)
            applyAuthoringAndPreview()
            renderBranchTree()
        end)
        del.Position = UDim2.new(1,-80,0,0)
    end

    local parentBox = labeledTextBox(secBranchTree, "Parent", "", function() end)
    local childBox = labeledTextBox(secBranchTree, "Child", "", function() end)
    local addBtn = makeBtn(secBranchTree, "Add Child", function()
        if parentBox.Text ~= "" and childBox.Text ~= "" then
            LoomDesigner.AddChild(parentBox.Text, childBox.Text, "tip", 1)
            applyAuthoringAndPreview()
            renderBranchTree()
        end
    end)
    addBtn.Size = UDim2.new(0,100,0,24)
end

renderBranchLibrary()
renderBranchTree()
-- Models -------------------------------------------------------------------
local function renderModels()
    for _, c in ipairs(secModels:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0,6)
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = secModels
    local st = LoomDesigner.GetState()

    local libLabel = Instance.new("TextLabel")
    libLabel.Text = "Library"
    libLabel.TextColor3 = Color3.fromRGB(200,200,200)
    libLabel.BackgroundTransparency = 1
    libLabel.Size = UDim2.new(1,0,0,20)
    libLabel.TextXAlignment = Enum.TextXAlignment.Left
    libLabel.Parent = secModels

    local warnLabel = Instance.new("TextLabel")
    warnLabel.Text = "Asset not found"
    warnLabel.TextColor3 = Color3.fromRGB(255,100,100)
    warnLabel.BackgroundTransparency = 1
    warnLabel.Size = UDim2.new(1,0,0,20)
    warnLabel.TextXAlignment = Enum.TextXAlignment.Left
    warnLabel.Visible = false
    warnLabel.Parent = secModels

    local accessoryRow: Frame? = nil

    local function tryAdd(ref)
        local resolved = ModelResolver.ResolveOne(ref)
        if typeof(resolved) == "Instance" then
            table.insert(st.modelLibrary, ref)
            renderModels()
        else
            warnLabel.Text = resolved or "Asset not found"
            warnLabel.Visible = true

            if accessoryRow then accessoryRow:Destroy(); accessoryRow = nil end
            local plr = game:GetService("Players").LocalPlayer
            local opts = {}
            if plr and plr.Character then
                for _, ch in ipairs(plr.Character:GetChildren()) do
                    if ch:IsA("Accessory") then table.insert(opts, ch.Name) end
                end
            end
            if #opts > 0 then
                accessoryRow = Instance.new("Frame")
                accessoryRow.Size = UDim2.new(1,0,0,26)
                accessoryRow.BackgroundTransparency = 1
                accessoryRow.Parent = secModels
                dropdown(accessoryRow, popupHost, "Use Accessory", opts, 1, function(opt)
                    if plr and plr.Character then
                        local acc = plr.Character:FindFirstChild(opt)
                        if acc and acc:IsA("Accessory") then
                            tryAdd(acc)
                        end
                    end
                end)
            end
        end
    end

    labeledTextBox(secModels, "Add by Name", "", function(txt)
        if txt ~= "" then
            local cleaned = (tostring(txt):gsub("^%s*(.-)%s*$","%1"))
            tryAdd(cleaned)
        end
    end)
    labeledTextBox(secModels, "Add AssetId", "", function(txt)
        local n = tonumber(txt)
        if n then
            tryAdd(n)
        end
    end)

    if #st.modelLibrary == 0 then
        local empty = Instance.new("TextLabel")
        empty.Text = "Model Library is empty. Use 'Add by Name' or 'Add AssetId' to seed it."
        empty.TextColor3 = Color3.fromRGB(180,180,180)
        empty.BackgroundTransparency = 1
        empty.Size = UDim2.new(1,0,0,22)
        empty.Parent = secModels
    end

    for i, ref in ipairs(st.modelLibrary) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1,0,0,24)
        row.BackgroundTransparency = 1
        row.Parent = secModels
        local resolved = ModelResolver.ResolveOne(ref)
        local refText = (typeof(ref) == "Instance") and ref.Name or tostring(ref)
        local nameText
        local inst = nil
        if typeof(resolved) == "Instance" then
            inst = resolved
            nameText = string.format("%s (%s)", refText, inst.Name)
        else
            local msg = resolved
            nameText = string.format("%s (%s)", refText, msg or "unresolved")
        end
        if inst then
            local preview = Instance.new("ViewportFrame")
            preview.Size = UDim2.new(0,24,1,0)
            preview.BackgroundTransparency = 1
            preview.Parent = row
            local cam = Instance.new("Camera")
            cam.Parent = preview
            preview.CurrentCamera = cam
            local model
            if inst:IsA("Model") then
                model = inst
            else
                model = Instance.new("Model")
                inst.Parent = model
            end
            model:PivotTo(CFrame.new())
            local _, size = model:GetBoundingBox()
            local s = math.max(size.X, size.Y, size.Z)
            cam.CFrame = CFrame.new(Vector3.new(s, s, s), Vector3.new())
            model.Parent = preview
        end
        local lab = Instance.new("TextLabel")
        lab.Text = nameText
        lab.BackgroundTransparency = 1
        lab.TextColor3 = Color3.fromRGB(200,200,200)
        lab.TextXAlignment = Enum.TextXAlignment.Left
        if inst then
            lab.Size = UDim2.new(1,-54,1,0)
            lab.Position = UDim2.new(0,30,0,0)
        else
            lab.Size = UDim2.new(1,-30,1,0)
        end
        lab.Parent = row
        local del = Instance.new("TextButton")
        del.Text = "X"
        del.Size = UDim2.new(0,24,1,0)
        del.Position = UDim2.new(1,-24,0,0)
        del.BackgroundColor3 = Color3.fromRGB(80,40,40)
        del.TextColor3 = Color3.new(1,1,1)
        del.Parent = row
        del.MouseButton1Click:Connect(function()
            table.remove(st.modelLibrary, i)
            renderModels(); LoomDesigner.ApplyAuthoring(); LoomDesigner.RebuildPreview(nil)
        end)
    end

    local mapLabel = Instance.new("TextLabel")
    mapLabel.Text = "Mapping"
    mapLabel.TextColor3 = Color3.fromRGB(200,200,200)
    mapLabel.BackgroundTransparency = 1
    mapLabel.Size = UDim2.new(1,0,0,20)
    mapLabel.TextXAlignment = Enum.TextXAlignment.Left
    mapLabel.Parent = secModels

    local mapContainer = Instance.new("Frame")
    mapContainer.BackgroundTransparency = 1
    mapContainer.Size = UDim2.new(1,0,0,0)
    mapContainer.AutomaticSize = Enum.AutomaticSize.Y
    mapContainer.Parent = secModels
    local mapLayout = Instance.new("UIListLayout")
    mapLayout.Padding = UDim.new(0,6)
    mapLayout.FillDirection = Enum.FillDirection.Vertical
    mapLayout.SortOrder = Enum.SortOrder.LayoutOrder
    mapLayout.Parent = mapContainer

    local depths = {}
    for k in pairs(st.modelsByDepth) do table.insert(depths, k) end
    table.insert(depths, "terminal")
    local function depthLess(a, b)
        if a == "terminal" then return false end
        if b == "terminal" then return true end
        return (tonumber(a) or math.huge) < (tonumber(b) or math.huge)
    end
    table.sort(depths, depthLess)
    for _, depth in ipairs(depths) do
        local list = st.modelsByDepth[depth] or {}
        local filtered = {}
        for _, ref in ipairs(list) do
            local r = ModelResolver.ResolveOne(ref)
            if typeof(r) == "Instance" then
                table.insert(filtered, ref)
            end
        end
        list = filtered
        st.modelsByDepth[depth] = list
        local df = Instance.new("Frame")
        df.BackgroundTransparency = 1
        df.Size = UDim2.new(1,0,0,0)
        df.AutomaticSize = Enum.AutomaticSize.Y
        df.Parent = mapContainer
        local dfLayout = Instance.new("UIListLayout")
        dfLayout.Padding = UDim.new(0,6)
        dfLayout.FillDirection = Enum.FillDirection.Vertical
        dfLayout.SortOrder = Enum.SortOrder.LayoutOrder
        dfLayout.Parent = df
        local header = Instance.new("TextLabel")
        header.Text = depth=="terminal" and "Terminal" or ("Depth "..depth)
        header.BackgroundTransparency = 1
        header.TextColor3 = Color3.fromRGB(200,200,200)
        header.Size = UDim2.new(1,0,0,20)
        header.TextXAlignment = Enum.TextXAlignment.Left
        header.Parent = df
        for i, ref in ipairs(list) do
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1,-160,0,26)
            row.Position = UDim2.new(0,160,0,0)
            row.BackgroundTransparency = 1
            row.Parent = df
            dropdown(row, popupHost, "", st.modelLibrary, table.find(st.modelLibrary, ref) or 1, function(opt)
                local cleaned = tostring(opt):gsub("^%s*(.-)%s*$","%1")
                local r = ModelResolver.ResolveOne(cleaned)
                if typeof(r) == "Instance" then
                    list[i] = cleaned
                    LoomDesigner.ApplyAuthoring(); LoomDesigner.RebuildPreview(nil)
                end
            end)
            local up = makeBtn(row, "^", function()
                if i>1 then list[i],list[i-1]=list[i-1],list[i]; renderModels(); LoomDesigner.ApplyAuthoring(); LoomDesigner.RebuildPreview(nil) end
            end)
            up.Size = UDim2.new(0,24,0,24); up.Position = UDim2.new(1,-48,0,0)
            local down = makeBtn(row, "v", function()
                if i<#list then list[i],list[i+1]=list[i+1],list[i]; renderModels(); LoomDesigner.ApplyAuthoring(); LoomDesigner.RebuildPreview(nil) end
            end)
            down.Size = UDim2.new(0,24,0,24); down.Position = UDim2.new(1,-24,0,0)
            local del = Instance.new("TextButton")
            del.Text = "X"
            del.Size = UDim2.new(0,24,0,24)
            del.Position = UDim2.new(1,-72,0,0)
            del.BackgroundColor3 = Color3.fromRGB(80,40,40)
            del.TextColor3 = Color3.new(1,1,1)
            del.Parent = row
            del.MouseButton1Click:Connect(function()
                table.remove(list, i)
                st.modelsByDepth[depth] = list
                renderModels(); LoomDesigner.ApplyAuthoring(); LoomDesigner.RebuildPreview(nil)
            end)
        end
        local addBtn = makeBtn(df, "Add", function()
            local ref = st.modelLibrary[1]
            if ref == nil then return end
            local r = ModelResolver.ResolveOne(ref)
            if typeof(r) == "Instance" then
                st.modelsByDepth[depth] = list
                table.insert(list, ref)
                renderModels(); LoomDesigner.ApplyAuthoring(); LoomDesigner.RebuildPreview(nil)
            end
        end)
        addBtn.Size = UDim2.new(0,60,0,24)
        local hasLib = (#st.modelLibrary > 0)
        addBtn.Active = hasLib
        addBtn.AutoButtonColor = hasLib
        addBtn.BackgroundTransparency = hasLib and 0 or 0.5
        addTooltip(addBtn, "Add the first model from the library to this depth.")
    end
end

renderModels()

-- Decorations ---------------------------------------------------------------
local function renderDecorations()
    for _, c in ipairs(secDecoAuth:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0,6)
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = secDecoAuth
    local st = LoomDesigner.GetState()

    checkbox(secDecoAuth, "Enable", st.overrides.decorations.enabled, function(val)
        st.overrides.decorations.enabled = val
        LoomDesigner.ApplyAuthoring(); LoomDesigner.RebuildPreview(nil)
    end)

    local function decoEditor(deco, idx)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1,0,0,0)
        frame.BackgroundTransparency = 1
        frame.AutomaticSize = Enum.AutomaticSize.Y
        frame.Parent = secDecoAuth
        local frameLayout = Instance.new("UIListLayout")
        frameLayout.Padding = UDim.new(0,6)
        frameLayout.FillDirection = Enum.FillDirection.Vertical
        frameLayout.SortOrder = Enum.SortOrder.LayoutOrder
        frameLayout.Parent = frame

        local header = Instance.new("TextLabel")
        header.Text = "Decoration "..idx
        header.BackgroundTransparency = 1
        header.TextColor3 = Color3.fromRGB(200,200,200)
        header.Size = UDim2.new(1,0,0,20)
        header.TextXAlignment = Enum.TextXAlignment.Left
        header.Parent = frame

        local modelsFrame = Instance.new("Frame")
        modelsFrame.Size = UDim2.new(1,0,0,0)
        modelsFrame.AutomaticSize = Enum.AutomaticSize.Y
        modelsFrame.BackgroundTransparency = 1
        modelsFrame.Parent = frame
        local modelsLayout = Instance.new("UIListLayout")
        modelsLayout.Padding = UDim.new(0,6)
        modelsLayout.FillDirection = Enum.FillDirection.Vertical
        modelsLayout.SortOrder = Enum.SortOrder.LayoutOrder
        modelsLayout.Parent = modelsFrame
        for i, ref in ipairs(deco.models or {}) do
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1,0,0,26)
            row.BackgroundTransparency = 1
            row.Parent = modelsFrame

            local currentRef = ref
            local errLabel = Instance.new("TextLabel")
            errLabel.TextColor3 = Color3.fromRGB(255,100,100)
            errLabel.BackgroundTransparency = 1
            errLabel.Size = UDim2.new(1,0,0,20)
            errLabel.TextXAlignment = Enum.TextXAlignment.Left
            errLabel.Visible = false

            local btn = dropdown(row, popupHost, "", st.modelLibrary, table.find(st.modelLibrary, ref) or 1, function(opt)
                local res2 = ModelResolver.ResolveOne(opt)
                if typeof(res2) == "Instance" then
                    deco.models[i] = opt
                    currentRef = opt
                    errLabel.Visible = false
                    LoomDesigner.ApplyAuthoring(); LoomDesigner.RebuildPreview(nil)
                else
                    errLabel.Text = res2 or "unresolved"
                    errLabel.Visible = true
                    btn.Text = (typeof(currentRef) == "Instance") and currentRef.Name or tostring(currentRef)
                end
            end)

            local res = ModelResolver.ResolveOne(ref)
            if typeof(res) ~= "Instance" then
                errLabel.Text = res or "unresolved"
                errLabel.Visible = true
            end
            errLabel.Parent = modelsFrame

            local del = Instance.new("TextButton")
            del.Text = "X"
            del.Size = UDim2.new(0,24,0,24)
            del.Position = UDim2.new(1,-24,0,0)
            del.BackgroundColor3 = Color3.fromRGB(80,40,40)
            del.TextColor3 = Color3.new(1,1,1)
            del.Parent = row
            del.MouseButton1Click:Connect(function()
                table.remove(deco.models, i)
                renderDecorations()
                LoomDesigner.ApplyAuthoring(); LoomDesigner.RebuildPreview(nil)
            end)
        end
        local addModelBtn = makeBtn(modelsFrame, "Add Model", function()
            deco.models = deco.models or {}
            local ref = st.modelLibrary[1]
            if ref == nil then return end
            local res3 = ModelResolver.ResolveOne(ref)
            if typeof(res3) == "Instance" then
                table.insert(deco.models, ref)
                renderDecorations(); LoomDesigner.ApplyAuthoring(); LoomDesigner.RebuildPreview(nil)
            else
                local warn = Instance.new("TextLabel")
                warn.Text = res3 or "unresolved"
                warn.TextColor3 = Color3.fromRGB(255,100,100)
                warn.BackgroundTransparency = 1
                warn.Size = UDim2.new(1,0,0,20)
                warn.TextXAlignment = Enum.TextXAlignment.Left
                warn.Parent = modelsFrame
            end
        end)
        addModelBtn.Size = UDim2.new(0,100,0,24)
        local hasLib = (#st.modelLibrary > 0)
        addModelBtn.Active = hasLib
        addModelBtn.AutoButtonColor = hasLib
        addModelBtn.BackgroundTransparency = hasLib and 0 or 0.5

        dropdown(frame, popupHost, "Placement", {"tip","junction","along","radial","spiral"}, 1, function(opt)
            deco.placement = opt
            LoomDesigner.ApplyAuthoring(); LoomDesigner.RebuildPreview(nil)
        end)
        dropdown(frame, popupHost, "Rotation", {"upright","inherit"}, 1, function(opt)
            deco.rotation = opt
            LoomDesigner.ApplyAuthoring(); LoomDesigner.RebuildPreview(nil)
        end)
        labeledTextBox(frame, "Density", tostring(deco.density or 1), function(txt)
            deco.density = tonumber(txt) or 1
            LoomDesigner.ApplyAuthoring(); LoomDesigner.RebuildPreview(nil)
        end)
        checkbox(frame, "Per Length", deco.perLength or false, function(val)
            deco.perLength = val
            LoomDesigner.ApplyAuthoring(); LoomDesigner.RebuildPreview(nil)
        end)
        labeledTextBox(frame, "minDepth", tostring(deco.minDepth or 0), function(txt)
            deco.minDepth = tonumber(txt)
            LoomDesigner.ApplyAuthoring(); LoomDesigner.RebuildPreview(nil)
        end)
        labeledTextBox(frame, "maxDepth", tostring(deco.maxDepth or 0), function(txt)
            deco.maxDepth = tonumber(txt)
            LoomDesigner.ApplyAuthoring(); LoomDesigner.RebuildPreview(nil)
        end)
        labeledTextBox(frame, "maxPerChain", tostring(deco.maxPerChain or ""), function(txt)
            deco.maxPerChain = tonumber(txt)
            LoomDesigner.ApplyAuthoring(); LoomDesigner.RebuildPreview(nil)
        end)
        labeledTextBox(frame, "yaw", tostring(deco.yaw or 0), function(txt)
            deco.yaw = tonumber(txt)
            LoomDesigner.ApplyAuthoring(); LoomDesigner.RebuildPreview(nil)
        end)
        labeledTextBox(frame, "pitch", tostring(deco.pitch or 0), function(txt)
            deco.pitch = tonumber(txt)
            LoomDesigner.ApplyAuthoring(); LoomDesigner.RebuildPreview(nil)
        end)
        labeledTextBox(frame, "roll", tostring(deco.roll or 0), function(txt)
            deco.roll = tonumber(txt)
            LoomDesigner.ApplyAuthoring(); LoomDesigner.RebuildPreview(nil)
        end)
        labeledTextBox(frame, "scaleMin", tostring(deco.scaleMin or 1), function(txt)
            deco.scaleMin = tonumber(txt)
            LoomDesigner.ApplyAuthoring(); LoomDesigner.RebuildPreview(nil)
        end)
        labeledTextBox(frame, "scaleMax", tostring(deco.scaleMax or 1), function(txt)
            deco.scaleMax = tonumber(txt)
            LoomDesigner.ApplyAuthoring(); LoomDesigner.RebuildPreview(nil)
        end)

        local delBtn = makeBtn(frame, "Delete", function()
            table.remove(st.overrides.decorations.types, idx)
            renderDecorations(); LoomDesigner.ApplyAuthoring(); LoomDesigner.RebuildPreview(nil)
        end)
        delBtn.Size = UDim2.new(0,80,0,24)
    end

    if #st.overrides.decorations.types == 0 then
        local empty = Instance.new("TextLabel")
        empty.Text = "No decorations defined. Use 'Add Decoration' to begin."
        empty.TextColor3 = Color3.fromRGB(180,180,180)
        empty.BackgroundTransparency = 1
        empty.Size = UDim2.new(1,0,0,22)
        empty.Parent = secDecoAuth
    end

    for i, deco in ipairs(st.overrides.decorations.types) do
        decoEditor(deco, i)
    end

    local addDecoBtn = makeBtn(secDecoAuth, "Add Decoration", function()
        table.insert(st.overrides.decorations.types, {models = {st.modelLibrary[1] or nil}, placement="tip", rotation="upright", density=1, minDepth=0, maxDepth=0, scaleMin=1, scaleMax=1})
        renderDecorations(); LoomDesigner.ApplyAuthoring(); LoomDesigner.RebuildPreview(nil)
    end)
    addDecoBtn.Size = UDim2.new(0,120,0,24)
    local hasLib = (#st.modelLibrary > 0)
    addDecoBtn.Active = hasLib
    addDecoBtn.AutoButtonColor = hasLib
    addDecoBtn.BackgroundTransparency = hasLib and 0 or 0.5
end

renderDecorations()

-- Export / Import controls --------------------------------------------------
local expBtn = Instance.new("TextButton")
expBtn.Text = "Export Config"
expBtn.Size = UDim2.new(0,180,0,26)
expBtn.BackgroundColor3 = Color3.fromRGB(48,48,48)
expBtn.TextColor3 = Color3.new(1,1,1)
expBtn.Parent = secIO
expBtn.MouseButton1Click:Connect(function()
    LoomDesigner.ExportAuthoring()
end)

local impBtn = Instance.new("TextButton")
impBtn.Text = "Import Config"
impBtn.Size = UDim2.new(0,180,0,26)
impBtn.BackgroundColor3 = Color3.fromRGB(48,48,48)
impBtn.TextColor3 = Color3.new(1,1,1)
impBtn.Parent = secIO
impBtn.MouseButton1Click:Connect(function()
    LoomDesigner.ImportAuthoring()
    LoomDesigner.RebuildPreview(nil)
end)
end

return UI
