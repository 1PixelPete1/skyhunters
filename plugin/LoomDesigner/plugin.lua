--!strict
-- LoomDesigner Studio Plugin entry point with full dock UI

local LoomDesigner = require(script.Parent.Main)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LoomConfigs = require(ReplicatedStorage.looms.LoomConfigs)

local toolbar = plugin:CreateToolbar("LoomDesigner")
local button = toolbar:CreateButton("Open", "Open LoomDesigner window", "")

local DockWidgetPluginGuiInfo = DockWidgetPluginGuiInfo.new(
        Enum.InitialDockState.Left,
        true, false,
        420, 600,
        300, 400
)

local widget = plugin:CreateDockWidgetPluginGui("LoomDesignerWidget", DockWidgetPluginGuiInfo)
widget.Title = "Loom Designer"

-- Root UI container
local root = Instance.new("Frame")
root.Size = UDim2.fromScale(1,1)
root.BackgroundColor3 = Color3.fromRGB(30,30,30)
root.Parent = widget

-- Preview area
local previewFrame = Instance.new("Frame")
previewFrame.Size = UDim2.new(1, -20, 0, 200)
previewFrame.Position = UDim2.new(0,10,1,-210)
previewFrame.BackgroundColor3 = Color3.fromRGB(45,45,45)
previewFrame.BorderSizePixel = 0
previewFrame.Parent = root

-- Scrolling controls container
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -220)
scroll.Position = UDim2.new(0,10,0,10)
scroll.BackgroundTransparency = 1
scroll.CanvasSize = UDim2.new(0,0,0,0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ScrollBarThickness = 6
scroll.Parent = root

local scrollLayout = Instance.new("UIListLayout")
scrollLayout.FillDirection = Enum.FillDirection.Vertical
scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
scrollLayout.Padding = UDim.new(0,10)
scrollLayout.Parent = scroll

-- helpers
local function rebuild()
        LoomDesigner.RebuildPreview(previewFrame)
end

local function createSection(title: string)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1,0,0,0)
        container.AutomaticSize = Enum.AutomaticSize.Y
        container.BackgroundColor3 = Color3.fromRGB(40,40,40)
        container.Parent = scroll

        local header = Instance.new("TextButton")
        header.Size = UDim2.new(1,0,0,28)
        header.Text = title
        header.BackgroundColor3 = Color3.fromRGB(60,60,60)
        header.TextColor3 = Color3.new(1,1,1)
        header.Parent = container

        local contents = Instance.new("Frame")
        contents.Size = UDim2.new(1,0,0,0)
        contents.AutomaticSize = Enum.AutomaticSize.Y
        contents.Position = UDim2.fromOffset(0,28)
        contents.BackgroundTransparency = 1
        contents.Parent = container

        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Vertical
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0,6)
        layout.Parent = contents

        header.MouseButton1Click:Connect(function()
                contents.Visible = not contents.Visible
        end)

        return contents
end

local function createTextInput(section: Instance, label: string, default: string, cb)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1,-10,0,24)
        frame.BackgroundTransparency = 1
        frame.Parent = section

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.5,0,1,0)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = Color3.new(1,1,1)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = frame

        local box = Instance.new("TextBox")
        box.Size = UDim2.new(0.5,-5,1,0)
        box.Position = UDim2.new(0.5,5,0,0)
        box.Text = default
        box.BackgroundColor3 = Color3.fromRGB(70,70,70)
        box.TextColor3 = Color3.new(1,1,1)
        box.ClearTextOnFocus = false
        box.Parent = frame

        box.FocusLost:Connect(function(enter)
                if enter and cb then
                        cb(box.Text)
                end
        end)

        return box
end

local function createButton(section: Instance, label: string, cb)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1,-10,0,24)
        btn.Text = label
        btn.BackgroundColor3 = Color3.fromRGB(70,130,180)
        btn.TextColor3 = Color3.new(1,1,1)
        btn.Parent = section

        btn.MouseButton1Click:Connect(function()
                if cb then cb() end
        end)

        return btn
end

local function createToggle(section: Instance, label: string, default: boolean, cb)
        local state = default
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1,-10,0,24)
        btn.BackgroundColor3 = Color3.fromRGB(80,80,80)
        btn.TextColor3 = Color3.new(1,1,1)
        btn.Text = label .. ": " .. (state and "ON" or "OFF")
        btn.Parent = section

        btn.MouseButton1Click:Connect(function()
                state = not state
                btn.Text = label .. ": " .. (state and "ON" or "OFF")
                if cb then cb(state) end
        end)

        return btn
end

local function createDropdown(section: Instance, label: string, options: {string}, cb)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1,-10,0,24)
        frame.BackgroundTransparency = 1
        frame.Parent = section

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1,0,1,0)
        btn.BackgroundColor3 = Color3.fromRGB(80,80,80)
        btn.TextColor3 = Color3.new(1,1,1)
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Text = label .. ": " .. (options[1] or "")
        btn.Parent = frame

        local listFrame = Instance.new("Frame")
        listFrame.Size = UDim2.new(1,0,0,#options * 24)
        listFrame.Position = UDim2.new(0,0,1,2)
        listFrame.BackgroundColor3 = Color3.fromRGB(60,60,60)
        listFrame.Visible = false
        listFrame.Parent = frame

        local listLayout = Instance.new("UIListLayout")
        listLayout.Parent = listFrame

        for _, opt in ipairs(options) do
                local optBtn = Instance.new("TextButton")
                optBtn.Size = UDim2.new(1,0,0,24)
                optBtn.Text = opt
                optBtn.BackgroundColor3 = Color3.fromRGB(80,80,80)
                optBtn.TextColor3 = Color3.new(1,1,1)
                optBtn.Parent = listFrame
                optBtn.MouseButton1Click:Connect(function()
                        btn.Text = label .. ": " .. opt
                        listFrame.Visible = false
                        if cb then cb(opt) end
                end)
        end

        btn.MouseButton1Click:Connect(function()
                listFrame.Visible = not listFrame.Visible
        end)

        return btn
end

-- Build UI sections
local overrides = {}
local state

-- Branch Config
local branchSection = createSection("Branch Config")
local configIds = {}
for id,_ in pairs(LoomConfigs) do table.insert(configIds, id) end
table.sort(configIds)
createDropdown(branchSection, "Config", configIds, function(id)
        LoomDesigner.SetConfigId(id)
        rebuild()
end)

-- Seed + Randomness
local seedSection = createSection("Seed + Randomness")
local seedBox = createTextInput(seedSection, "Base Seed", "", function(text)
        local num = tonumber(text)
        if num then
                LoomDesigner.SetSeed(num)
                rebuild()
        end
end)
createButton(seedSection, "Randomize", function()
        local newSeed = LoomDesigner.RandomizeSeed()
        seedBox.Text = tostring(newSeed)
        rebuild()
end)
createButton(seedSection, "Reroll", function()
        rebuild()
end)

-- Growth Progression
local growthSection = createSection("Growth Progression")
createTextInput(growthSection, "Growth %", "50", function(text)
        local num = tonumber(text)
        if num then
                LoomDesigner.SetGrowthPercent(num)
                rebuild()
        end
end)
createToggle(growthSection, "Animate", false, function(enabled)
        overrides.animate = enabled
        LoomDesigner.SetOverrides(overrides)
end)

-- Segment Overrides
local segSection = createSection("Segment Overrides")
createTextInput(segSection, "Segment Count", "", function(text)
        local num = tonumber(text)
        if num then
                overrides.segmentCount = num
                LoomDesigner.SetOverrides(overrides)
                rebuild()
        end
end)
local profileOpts = {"spiral","curved","zigzag","random"}
createDropdown(segSection, "Profile", profileOpts, function(opt)
        overrides.profile = overrides.profile or {}
        overrides.profile.kind = opt
        LoomDesigner.SetOverrides(overrides)
        rebuild()
end)
createTextInput(segSection, "Length Jitter", "", function(text)
        local num = tonumber(text)
        overrides.segmentScaleJitter = overrides.segmentScaleJitter or {}
        if num then
                overrides.segmentScaleJitter.length = num
                LoomDesigner.SetOverrides(overrides)
                rebuild()
        end
end)
createTextInput(segSection, "Thickness Jitter", "", function(text)
        local num = tonumber(text)
        overrides.segmentScaleJitter = overrides.segmentScaleJitter or {}
        if num then
                overrides.segmentScaleJitter.thickness = num
                LoomDesigner.SetOverrides(overrides)
                rebuild()
        end
end)
createTextInput(segSection, "Relative Scale Tie", "", function(text)
        local num = tonumber(text)
        if num then
                overrides.relativeScaleTie = num
                LoomDesigner.SetOverrides(overrides)
                rebuild()
        end
end)

-- Decoration Controls
local decoSection = createSection("Decoration Controls")
local decoList = Instance.new("Frame")
decoList.Size = UDim2.new(1,0,0,0)
decoList.AutomaticSize = Enum.AutomaticSize.Y
decoList.BackgroundTransparency = 1
decoList.Parent = decoSection

local decoLayout = Instance.new("UIListLayout")
decoLayout.Parent = decoList
decoLayout.FillDirection = Enum.FillDirection.Vertical
decoLayout.SortOrder = Enum.SortOrder.LayoutOrder
decoLayout.Padding = UDim.new(0,6)

local decorations = {}

local function rebuildDecos()
        overrides.decorations = decorations
        LoomDesigner.SetOverrides(overrides)
        rebuild()
end

local function addDeco()
        local deco = {model = "", material = "Plastic", shape = "Block", rotation = {0,0,0}, scale = {1,1,1}, count = 1, distribution = "tip", singlePart = false}
        table.insert(decorations, deco)

        local entry = Instance.new("Frame")
        entry.Size = UDim2.new(1,0,0,0)
        entry.AutomaticSize = Enum.AutomaticSize.Y
        entry.BackgroundColor3 = Color3.fromRGB(50,50,50)
        entry.Parent = decoList

        local modelBox = createTextInput(entry, "Model", "", function(text)
                deco.model = text
                rebuildDecos()
        end)
        local materialOpts = {}
        for _,m in ipairs(Enum.Material:GetEnumItems()) do table.insert(materialOpts, m.Name) end
        createDropdown(entry, "Material", materialOpts, function(opt)
                deco.material = opt
                rebuildDecos()
        end)
        local shapeOpts = {"Block","Sphere","Cylinder","Mesh"}
        createDropdown(entry, "Shape", shapeOpts, function(opt)
                deco.shape = opt
                rebuildDecos()
        end)
        createTextInput(entry, "Rot X", "0", function(text)
                deco.rotation[1] = tonumber(text) or 0
                rebuildDecos()
        end)
        createTextInput(entry, "Rot Y", "0", function(text)
                deco.rotation[2] = tonumber(text) or 0
                rebuildDecos()
        end)
        createTextInput(entry, "Rot Z", "0", function(text)
                deco.rotation[3] = tonumber(text) or 0
                rebuildDecos()
        end)
        createTextInput(entry, "Scale X", "1", function(text)
                deco.scale[1] = tonumber(text) or 1
                rebuildDecos()
        end)
        createTextInput(entry, "Scale Y", "1", function(text)
                deco.scale[2] = tonumber(text) or 1
                rebuildDecos()
        end)
        createTextInput(entry, "Scale Z", "1", function(text)
                deco.scale[3] = tonumber(text) or 1
                rebuildDecos()
        end)
        createTextInput(entry, "Count", "1", function(text)
                deco.count = tonumber(text) or 1
                rebuildDecos()
        end)
        local distOpts = {"tip","random","clustered"}
        createDropdown(entry, "Distribution", distOpts, function(opt)
                deco.distribution = opt
                rebuildDecos()
        end)
        createToggle(entry, "Single Part", false, function(val)
                deco.singlePart = val
                rebuildDecos()
        end)
        createButton(entry, "Remove", function()
                for i,v in ipairs(decorations) do
                        if v == deco then
                                table.remove(decorations, i)
                                break
                        end
                end
                entry:Destroy()
                rebuildDecos()
        end)
end

createButton(decoSection, "Add Decoration", addDeco)

-- Export / Save
local exportSection = createSection("Export / Save")
local pathBox = createTextInput(exportSection, "File Path", "src/shared/looms/LoomConfigs.luau", function() end)
local saveAsBox = createTextInput(exportSection, "Save As ID", "", function() end)
createButton(exportSection, "Save Config", function()
        if not state then return end
        local cfg = LoomConfigs[state.configId]
        if saveAsBox.Text ~= "" then
                cfg = table.clone(cfg)
                cfg.id = saveAsBox.Text
        end
        LoomDesigner.ExportConfig(cfg, pathBox.Text)
end)

-- Developer Toggles
local devSection = createSection("Developer Toggles")
createToggle(devSection, "Show Axes", false, function(val)
        overrides.showAxes = val
        LoomDesigner.SetOverrides(overrides)
        rebuild()
end)
createToggle(devSection, "Show Overlay", false, function(val)
        overrides.showOverlay = val
        LoomDesigner.SetOverrides(overrides)
        rebuild()
end)
createToggle(devSection, "Show Colliders", false, function(val)
        overrides.showColliders = val
        LoomDesigner.SetOverrides(overrides)
        rebuild()
end)

button.Click:Connect(function()
        widget.Enabled = not widget.Enabled
        if widget.Enabled then
                state = LoomDesigner.Start(plugin)
                seedBox.Text = tostring(state.baseSeed)
        end
end)

widget.Enabled = false

