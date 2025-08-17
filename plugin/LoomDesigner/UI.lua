--!strict
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

-- === Sections ===
local secConfig = makeSection(scroll, "Branch Config")
local secSeed   = makeSection(scroll, "Seed / Randomness")
local secGrowth = makeSection(scroll, "Growth Progression")
local secSeg    = makeSection(scroll, "Segment Overrides")

-- Config dropdown (list from LoomConfigs keys)
local LoomConfigs = require(game.ReplicatedStorage.looms.LoomConfigs)
local configIds = {}
for id, _ in pairs(LoomConfigs) do table.insert(configIds, id) end
table.sort(configIds)

dropdown(secConfig, popupHost, "Config", configIds, 1, function(id)
LoomDesigner.SetConfigId(id)
LoomDesigner.RebuildPreview(nil)
end)

labeledTextBox(secSeed, "Seed", "12345", function(txt)
local n = tonumber(txt)
if n then
LoomDesigner.SetSeed(n)
LoomDesigner.RebuildPreview(nil)
end
end)

local randBtn = Instance.new("TextButton")
randBtn.Text = "Randomize Seed"
randBtn.Size = UDim2.new(0,180,0,26)
randBtn.BackgroundColor3 = Color3.fromRGB(48,48,48)
randBtn.TextColor3 = Color3.new(1,1,1)
randBtn.Parent = secSeed
randBtn.MouseButton1Click:Connect(function()
LoomDesigner.RandomizeSeed()
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
end

return UI
