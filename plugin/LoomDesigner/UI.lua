--!strict
local RequireUtil = require(script.Parent.RequireUtil)
local LoomDesigner = require(script.Parent.Main)
local FlowTrace = require(script.Parent.FlowTrace)
local ModelResolver = require(script.Parent.ModelResolver)

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

local st = LoomDesigner.GetState()
local status = Instance.new("TextLabel")
status.Text = string.format("Seed: %s   Trunk: %s", tostring(st.baseSeed), st.branchAssignments and st.branchAssignments.trunkProfile or "-")
status.TextColor3 = Color3.fromRGB(160,200,255)
status.BackgroundTransparency = 1
status.Size = UDim2.new(1,0,0,18)
status.Parent = scroll

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
local secProfile  = makeSection(scroll, "Profile")
local secGeo      = makeSection(scroll, "Segment Geometry")
local secScale    = makeSection(scroll, "Size Profile")
local secRot      = makeSection(scroll, "Rotation Rules")
local secDeco     = makeSection(scroll, "Decorations")
-- Stage D authoring panels
local secProfilesLib = makeSection(scroll, "Profiles (Authoring)")
local secAssign    = makeSection(scroll, "Assignments (Authoring)")
local secModels    = makeSection(scroll, "Models (Authoring)")
local secDecoAuth  = makeSection(scroll, "Decorations (Authoring)")
local secIO        = makeSection(scroll, "Export / Import")

-- Forward decls shared across profile authoring
local selectedProfile: string? = nil
local renderProfiles
local renderProfileEditor
local renderAssignments
local commitAndRebuild

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

local function renderProfileSection()
    for _, c in ipairs(secProfile:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
    local st = LoomDesigner.GetState()
    local active = st.activeProfileName
    if not active then
        local banner = Instance.new("TextLabel")
        banner.Text = "Select or create a Profile in Authoring to edit."
        banner.TextColor3 = Color3.fromRGB(255,180,80)
        banner.BackgroundTransparency = 1
        banner.Size = UDim2.new(1,0,0,20)
        banner.Parent = secProfile
    else
        local KINDS = LoomDesigner.SUPPORTED_KIND_LIST or {"straight","curved","zigzag","sigmoid","chaotic"}
        local draft = st.profileDrafts[active]
        dropdown(secProfile, popupHost, "Kind", KINDS,
            table.find(KINDS, (draft and draft.kind) or "curved") or 2,
            function(opt)
                draft.kind = string.lower(opt)
                LoomDesigner.CommitProfileEdit(active, draft)
                LoomDesigner.ApplyAuthoring()
                LoomDesigner.RebuildPreview(nil)
            end
        )
    end
end
renderProfileSection()

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
-- Profiles list and editor --------------------------------------------------
local listFrame = Instance.new("ScrollingFrame")
listFrame.BackgroundTransparency = 1
listFrame.BorderSizePixel = 0
listFrame.Size = UDim2.new(1,0,0,150)
listFrame.CanvasSize = UDim2.new(0,0,0,0)
listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
listFrame.ScrollBarThickness = 8
listFrame.LayoutOrder = 1
listFrame.Parent = secProfilesLib
listFrame.ZIndex = 2
listFrame.ClipsDescendants = false
-- ensure the list is mounted correctly and not clipped by ancestors
task.defer(function()
    if not listFrame:IsDescendantOf(controlsHost) then
        listFrame.Parent = secProfilesLib
    end
    local ancestor = listFrame.Parent
    while ancestor do
        if ancestor:IsA("GuiObject") then
            ancestor.ClipsDescendants = false
        end
        ancestor = ancestor.Parent
    end
end)

local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop = UDim.new(0,4)
listPadding.PaddingBottom = UDim.new(0,4)
listPadding.PaddingLeft = UDim.new(0,4)
listPadding.PaddingRight = UDim.new(0,4)
listPadding.Parent = listFrame

local profileLayout = Instance.new("UIListLayout")
profileLayout.SortOrder = Enum.SortOrder.LayoutOrder
profileLayout.Parent = listFrame

local buttonsRow = Instance.new("Frame")
buttonsRow.Size = UDim2.new(1,0,0,26)
buttonsRow.BackgroundTransparency = 1
buttonsRow.LayoutOrder = 2
buttonsRow.Parent = secProfilesLib
buttonsRow.ZIndex = 2

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

local renameBox = labeledTextBox(secProfilesLib, "New Name", "", function(txt)
    if selectedProfile and txt ~= "" then
        local st = LoomDesigner.GetState()
        LoomDesigner.RenameProfile(selectedProfile, txt)
        if st.profileDrafts[selectedProfile] then
            st.profileDrafts[txt] = st.profileDrafts[selectedProfile]
            st.profileDrafts[selectedProfile] = nil
        end
        if st.activeProfileName == selectedProfile then
            st.activeProfileName = txt
        end
        selectedProfile = txt
        commitAndRebuild()
    end
    renameBox.Parent.Visible = false
end)
renameBox.Parent.Visible = false
renameBox.Parent.LayoutOrder = 3

local pendingProfileName = ""
local newProfileBox: TextBox? = nil
newProfileBox = labeledTextBox(secProfilesLib, "Profile Name", "", function(txt)
    local st = LoomDesigner.GetState()
    local name = (txt ~= "" and txt) or pendingProfileName
    LoomDesigner.CreateProfile(name)
    st.profileDrafts[name] = LoomConfigUtil.deepCopy(st.savedProfiles[name])
    st.activeProfileName = name
    selectedProfile = name
    if newProfileBox and newProfileBox.Parent then newProfileBox.Parent.Visible = false end
    pendingProfileName = ""
    commitAndRebuild()
    renderProfiles()
    renderProfileEditor()
    task.defer(function()
        local btn = listFrame:FindFirstChild(name)
        if btn then
            local abs = btn.AbsolutePosition
            local rootAbs = listFrame.AbsolutePosition
            listFrame.CanvasPosition = Vector2.new(0, abs.Y - rootAbs.Y)
        end
    end)
end)
if newProfileBox and newProfileBox.Parent then
    newProfileBox.Parent.Visible = false
    newProfileBox.Parent.LayoutOrder = 3
end

local function newProfile()
    local st = LoomDesigner.GetState()
    local i = 1
    while st.savedProfiles["profile"..i] do i += 1 end
    pendingProfileName = "profile"..i
    if newProfileBox then
        newProfileBox.Text = pendingProfileName
        if newProfileBox.Parent then
            newProfileBox.Parent.Visible = true
        end
        newProfileBox:CaptureFocus()
    end
end

local function duplicateProfile()
    if not selectedProfile then return end
    local st = LoomDesigner.GetState()
    local base = selectedProfile .. "Copy"
    local i = 1
    while st.savedProfiles[base..i] do i += 1 end
    local src = LoomConfigUtil.deepCopy(st.savedProfiles[selectedProfile])
    local name = base..i
    LoomDesigner.CreateProfile(name, LoomConfigUtil.deepCopy(src))
    st.profileDrafts[name] = LoomConfigUtil.deepCopy(src)
    st.activeProfileName = name
    selectedProfile = name
    commitAndRebuild()
end

local function renameProfile()
    if not selectedProfile then return end
    renameBox.Text = selectedProfile
    renameBox.Parent.Visible = true
end

local function deleteProfile()
    if not selectedProfile then return end
    local st = LoomDesigner.GetState()
    LoomDesigner.DeleteProfile(selectedProfile)
    st.profileDrafts[selectedProfile] = nil
    if st.activeProfileName == selectedProfile then
        st.activeProfileName = nil
    end
    selectedProfile = nil
    commitAndRebuild()
end

makeBtn(buttonsRow, "New", newProfile)
makeBtn(buttonsRow, "Duplicate", duplicateProfile)
makeBtn(buttonsRow, "Rename", renameProfile)
makeBtn(buttonsRow, "Delete", deleteProfile)

local profileEditor = Instance.new("Frame")
profileEditor.BackgroundTransparency = 1
profileEditor.Size = UDim2.new(1,0,0,0)
profileEditor.AutomaticSize = Enum.AutomaticSize.Y
profileEditor.Parent = secProfilesLib
profileEditor.LayoutOrder = 4

-- Child authoring helpers ---------------------------------------------------
local CHILD_PLACEMENTS = {"tip","junction","along","radial","spiral"}
local CHILD_ROTATIONS = {"upright","inherit","custom"}

local function createChildRow(parent: Instance, popupHost: Frame, child: table,
        profileNames: {string}, commit: ()->(), remove: ()->(), rerender: ()->())
    local frame = Instance.new("Frame")
    frame.BackgroundTransparency = 1
    frame.Size = UDim2.new(1,0,0,0)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.Parent = parent

    dropdown(frame, popupHost, "Profile", profileNames,
        table.find(profileNames, child.name) or 1, function(opt)
            child.name = opt
            commit()
        end)

    labeledTextBox(frame, "Count", tostring(child.count or 1), function(txt)
        child.count = tonumber(txt) or 1
        commit()
    end)

    dropdown(frame, popupHost, "Placement", CHILD_PLACEMENTS,
        table.find(CHILD_PLACEMENTS, child.placement) or 1, function(opt)
            child.placement = opt
            commit()
        end)

    local rotIndex
    if type(child.rotation) == "table" then
        rotIndex = table.find(CHILD_ROTATIONS, "custom")
    else
        rotIndex = table.find(CHILD_ROTATIONS, child.rotation)
    end
    dropdown(frame, popupHost, "Rotation", CHILD_ROTATIONS, rotIndex or 1,
        function(opt)
            if opt == "custom" then
                child.rotation = type(child.rotation) == "table" and child.rotation or {pitch = 0, yaw = 0, roll = 0}
            else
                child.rotation = opt
            end
            commit()
            rerender()
        end)

    if type(child.rotation) == "table" then
        labeledTextBox(frame, "Pitch", tostring(child.rotation.pitch or 0), function(txt)
            child.rotation.pitch = tonumber(txt) or 0
            commit()
        end)
        labeledTextBox(frame, "Yaw", tostring(child.rotation.yaw or 0), function(txt)
            child.rotation.yaw = tonumber(txt) or 0
            commit()
        end)
        labeledTextBox(frame, "Roll", tostring(child.rotation.roll or 0), function(txt)
            child.rotation.roll = tonumber(txt) or 0
            commit()
        end)
    end

    local delBtn = makeBtn(frame, "Remove", function()
        remove()
    end)
    delBtn.Size = UDim2.new(0,80,0,24)
end

local function renderChildrenSection(parent: Instance, popupHost: Frame, draft: table, commit: ()->())
    local section = makeSection(parent, "Children")

    local function render()
        for _, c in ipairs(section:GetChildren()) do
            if c:IsA("GuiObject") then c:Destroy() end
        end

        local names = {}
        for name in pairs(LoomDesigner.GetState().savedProfiles) do
            table.insert(names, name)
        end
        table.sort(names)

        draft.children = draft.children or {}
        for i, child in ipairs(draft.children) do
            createChildRow(section, popupHost, child, names, commit, function()
                table.remove(draft.children, i)
                render()
                commit()
            end, render)
        end

        local addBtn = makeBtn(section, "Add Child", function()
            local name = names[1]
            if name then
                table.insert(draft.children, {name = name, count = 1, placement = "tip", rotation = "upright"})
                render()
                commit()
            end
        end)
        addBtn.Size = UDim2.new(0,100,0,24)
    end

    render()
    return section
end

-- render functions ---------------------------------------------------------
commitAndRebuild = function()
    local st = LoomDesigner.GetState()
    local active = st.activeProfileName
    local draft = active and st.profileDrafts and st.profileDrafts[active]
    if active and draft then
        st.profileDrafts[active] = draft
        LoomDesigner.CommitProfileEdit(active, draft)
    end
    LoomDesigner.ApplyAuthoring()
    LoomDesigner.RebuildPreview(nil)
end

renderProfileEditor = function()
    for _, c in ipairs(profileEditor:GetChildren()) do c:Destroy() end
    if not selectedProfile then return end
    local st = LoomDesigner.GetState()
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0,6)
    layout.Parent = profileEditor
    st.activeProfileName = selectedProfile
    st.profileDrafts = st.profileDrafts or {}
    local draft = st.profileDrafts[selectedProfile]
    if not draft then
        draft = LoomConfigUtil.deepCopy(st.savedProfiles[selectedProfile] or {})
        st.profileDrafts[selectedProfile] = draft
    end

    local function commit()
        commitAndRebuild()
    end

    local kinds = LoomDesigner.SUPPORTED_KIND_LIST or {"straight","curved","zigzag","sigmoid","chaotic"}
    dropdown(profileEditor, popupHost, "Kind", kinds, table.find(kinds, draft.kind) or 1, function(opt)
        draft.kind = string.lower(opt)
        commit()
        renderProfileEditor()
    end)

    local function numBox(label, field)
        bindNumberField(profileEditor, label,
            function() return draft[field] end,
            function(v) draft[field] = v end,
            commit)
    end

    numBox("Amplitude", "amplitudeDeg")
    numBox("Frequency", "frequency")
    numBox("Curvature", "curvature")
    numBox("Roll Bias", "rollBias")
    numBox("Child Inherit", "childInherit")
    if draft.kind == "zigzag" then numBox("Zigzag Every", "zigzagEvery") end
    if draft.kind == "sigmoid" then numBox("Sigmoid K", "sigmoidK"); numBox("Sigmoid Mid", "sigmoidMid") end
    if draft.kind == "chaotic" then numBox("Chaotic R", "chaoticR") end

    local modes = {"uniform","triangular","normal","biased"}
    dropdown(profileEditor, popupHost, "SegMode", modes, table.find(modes, draft.segmentCountMode) or 1, function(opt)
        draft.segmentCountMode = opt
        commit()
        renderProfileEditor()
    end)

    local errLabel = Instance.new("TextLabel")
    errLabel.BackgroundTransparency = 1
    errLabel.TextColor3 = Color3.fromRGB(255,120,120)
    errLabel.TextXAlignment = Enum.TextXAlignment.Left
    errLabel.Size = UDim2.new(1,0,0,20)
    errLabel.Parent = profileEditor

    local function validate()
        errLabel.Text = ""
        if draft.segmentCountMin and draft.segmentCountMax and draft.segmentCountMin > draft.segmentCountMax then
            errLabel.Text = "min>max"
        end
        if draft.segmentCountMode == "normal" and draft.segmentCountSd and draft.segmentCountSd < 0 then
            errLabel.Text = "sd<0"
        end
        if draft.segmentCountMode == "biased" and draft.segmentCountBias and draft.segmentCountBias <= 0 then
            errLabel.Text = "bias<=0"
        end
    end

    local function segNum(label, field)
        bindNumberField(profileEditor, label,
            function() return draft[field] end,
            function(v) draft[field] = v; validate() end,
            commit)
    end

    segNum("Segment Count", "segmentCount")
    segNum("SegCount Min", "segmentCountMin")
    segNum("SegCount Max", "segmentCountMax")
    if draft.segmentCountMode == "triangular" then segNum("Mode N", "segmentCountModeN") end
    if draft.segmentCountMode == "normal" then segNum("Mean", "segmentCountMean"); segNum("Sd", "segmentCountSd") end
    if draft.segmentCountMode == "biased" then segNum("Bias", "segmentCountBias") end

    renderChildrenSection(profileEditor, popupHost, draft, commit)
    validate()
end

renderProfiles = function()
    for _, c in ipairs(listFrame:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
    local st = LoomDesigner.GetState()
    local hasProfiles = false
    for name, _ in pairs(st.savedProfiles) do
        hasProfiles = true
        local btn = Instance.new("TextButton")
        btn.Name = name
        btn.Size = UDim2.new(0,180,0,24)
        btn.BackgroundColor3 = Color3.fromRGB(48,48,48)
        btn.TextColor3 = Color3.new(1,1,1)
        btn.ZIndex = listFrame.ZIndex + 1
        btn.Text = name
        if name == st.activeProfileName then
            btn.Font = Enum.Font.SourceSansBold
            btn.BorderSizePixel = 2
            btn.BorderColor3 = Color3.fromRGB(80,120,200)
        else
            btn.Font = Enum.Font.SourceSans
            btn.BorderSizePixel = 0
        end
        btn.Parent = listFrame

        btn.MouseButton1Click:Connect(function()
            selectedProfile = name
            st.activeProfileName = name
            st.profileDrafts = st.profileDrafts or {}
            st.profileDrafts[name] = st.profileDrafts[name] or LoomConfigUtil.deepCopy(st.savedProfiles[name])
            renderProfiles()
            renderProfileEditor()
        end)
    end
    if not hasProfiles then
        profileLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        profileLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        selectedProfile = nil

        local help = Instance.new("TextLabel")
        help.Text = "No profiles yet. Create one to get started."
        help.BackgroundTransparency = 1
        help.TextColor3 = Color3.fromRGB(200,200,200)
        help.TextXAlignment = Enum.TextXAlignment.Center
        help.Size = UDim2.new(0,200,0,20)
        help.Parent = listFrame

        local createBtn = Instance.new("TextButton")
        createBtn.Text = "Create Profile"
        createBtn.Size = UDim2.new(0,180,0,24)
        createBtn.BackgroundColor3 = Color3.fromRGB(48,48,48)
        createBtn.TextColor3 = Color3.new(1,1,1)
        createBtn.ZIndex = listFrame.ZIndex + 1
        createBtn.Parent = listFrame
        createBtn.MouseButton1Click:Connect(function()
            newProfile()
        end)
    else
        profileLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
        profileLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    end
    renderProfileEditor()
end

renderProfiles()

-- re-render UI automatically when the saved profiles table changes
do
    local st = LoomDesigner.GetState()
    st.savedProfiles = select(1, FlowTrace.watchTable("ui.savedProfiles", st.savedProfiles, function()
        task.defer(function()
            renderProfiles()
            renderAssignments()
        end)
    end))
end

-- Assignments ---------------------------------------------------------------
local function renderAssignments()
    for _, c in ipairs(secAssign:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
    local st = LoomDesigner.GetState()
    local names = {}
    for n in pairs(st.savedProfiles) do table.insert(names, n) end
    table.sort(names)
    local trunkFrame = Instance.new("Frame")
    trunkFrame.BackgroundTransparency = 1
    trunkFrame.Size = UDim2.new(1,0,0,0)
    trunkFrame.AutomaticSize = Enum.AutomaticSize.Y
    trunkFrame.Parent = secAssign
    if #names == 0 then
        local btn = dropdown(trunkFrame, popupHost, "Trunk Profile", {"No profiles"}, 1, function() end)
        btn.Active = false
        btn.AutoButtonColor = false
        status.Text = string.format("Seed: %s   Trunk: -", tostring(st.baseSeed))
        local msg = Instance.new("TextLabel")
        msg.Text = "Create a profile first"
        msg.TextColor3 = Color3.fromRGB(200,200,200)
        msg.BackgroundTransparency = 1
        msg.Size = UDim2.new(1,0,0,18)
        msg.Parent = secAssign
        return
    end
    if not st.branchAssignments.trunkProfile or st.branchAssignments.trunkProfile == "" then
        st.branchAssignments.trunkProfile = names[1]
    end
    status.Text = string.format("Seed: %s   Trunk: %s", tostring(st.baseSeed), st.branchAssignments.trunkProfile or "-")
    local defaultIdx = table.find(names, st.branchAssignments.trunkProfile) or 1
    local btn = dropdown(trunkFrame, popupHost, "Trunk Profile", names, defaultIdx, function(opt)
        st.branchAssignments.trunkProfile = opt
        status.Text = string.format("Seed: %s   Trunk: %s", tostring(st.baseSeed), opt)
        pcall(function()
            plugin:SendNotification({Title = "Trunk set to " .. opt, Text = ""})
        end)
        LoomDesigner.ApplyAuthoring(); LoomDesigner.RebuildPreview(nil)
        renderAssignments()
    end)

    labeledTextBox(secAssign, "Branch Cap", tostring(st.branchAssignments.branchCap or 2), function(txt)
        local n = tonumber(txt)
        if n then
            st.branchAssignments.branchCap = math.max(0, math.floor(n))
            LoomDesigner.ApplyAuthoring(); LoomDesigner.RebuildPreview(nil)
        end
    end)

    local tree = Instance.new("Frame")
    tree.BackgroundTransparency = 1
    tree.Size = UDim2.new(1,0,0,0)
    tree.AutomaticSize = Enum.AutomaticSize.Y
    tree.Parent = secAssign
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = tree

    local visited = {}
    local function renderNode(name: string, depth: number)
        local row = Instance.new("TextButton")
        row.Name = name
        row.Size = UDim2.new(1,0,0,20)
        row.BackgroundColor3 = (name == selectedProfile) and Color3.fromRGB(70,70,110) or Color3.fromRGB(48,48,48)
        row.TextColor3 = Color3.new(1,1,1)
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.Text = string.rep("    ", depth) .. name
        row.Parent = tree
        row.MouseButton1Click:Connect(function()
            selectedProfile = name
            st.activeProfileName = name
            st.profileDrafts = st.profileDrafts or {}
            st.profileDrafts[name] = st.profileDrafts[name] or LoomConfigUtil.deepCopy(st.savedProfiles[name])
            renderProfiles()
            renderProfileEditor()
            renderAssignments()
            local btn = listFrame:FindFirstChild(name)
            if btn then
                local abs = btn.AbsolutePosition
                local rootAbs = scroll.AbsolutePosition
                scroll.CanvasPosition = Vector2.new(0, abs.Y - rootAbs.Y)
            end
        end)

        local prof = st.savedProfiles[name]
        if not prof then
            row.TextColor3 = Color3.fromRGB(255,120,120)
            return
        end

        if visited[name] then
            local cyc = Instance.new("TextLabel")
            cyc.BackgroundTransparency = 1
            cyc.TextColor3 = Color3.fromRGB(255,120,120)
            cyc.TextXAlignment = Enum.TextXAlignment.Left
            cyc.Size = UDim2.new(1,0,0,20)
            cyc.Text = string.rep("    ", depth+1) .. "(cycle)"
            cyc.Parent = tree
            return
        end
        visited[name] = true

        if prof.children then
            for _, child in ipairs(prof.children) do
                local childName = child.name
                if st.savedProfiles[childName] then
                    renderNode(childName, depth+1)
                else
                    local warn = Instance.new("TextLabel")
                    warn.Size = UDim2.new(1,0,0,20)
                    warn.BackgroundTransparency = 1
                    warn.TextXAlignment = Enum.TextXAlignment.Left
                    warn.TextColor3 = Color3.fromRGB(255,120,120)
                    warn.Text = string.rep("    ", depth+1) .. childName .. " (missing)"
                    warn.Parent = tree
                end
            end
        end
        visited[name] = nil
    end

    renderNode(st.branchAssignments.trunkProfile, 0)
end

renderAssignments()

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
        local inst, err = ModelResolver.ResolveOne(ref)
        if inst then
            table.insert(st.modelLibrary, ref)
            renderModels()
        else
            warnLabel.Text = err or "Asset not found"
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
        local inst, msg = ModelResolver.ResolveOne(ref)
        local refText = (typeof(ref) == "Instance") and ref.Name or tostring(ref)
        local nameText
        if inst then
            nameText = string.format("%s (%s)", refText, inst.Name)
        else
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
            if ModelResolver.ResolveOne(ref) then
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
                if ModelResolver.ResolveOne(cleaned) then
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
            if ModelResolver.ResolveOne(ref) then
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
                local inst2, err2 = ModelResolver.ResolveOne(opt)
                if inst2 then
                    deco.models[i] = opt
                    currentRef = opt
                    errLabel.Visible = false
                    LoomDesigner.ApplyAuthoring(); LoomDesigner.RebuildPreview(nil)
                else
                    errLabel.Text = err2 or "unresolved"
                    errLabel.Visible = true
                    btn.Text = (typeof(currentRef) == "Instance") and currentRef.Name or tostring(currentRef)
                end
            end)

            local inst, msg = ModelResolver.ResolveOne(ref)
            if not inst then
                errLabel.Text = msg or "unresolved"
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
            local inst, msg = ModelResolver.ResolveOne(ref)
            if inst then
                table.insert(deco.models, ref)
                renderDecorations(); LoomDesigner.ApplyAuthoring(); LoomDesigner.RebuildPreview(nil)
            else
                local warn = Instance.new("TextLabel")
                warn.Text = msg or "unresolved"
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
