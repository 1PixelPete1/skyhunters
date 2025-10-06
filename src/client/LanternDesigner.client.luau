--!strict
-- LanternDesigner.client.luau
-- Studio-only designer UI exposing tree structure and lantern parameters

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not RunService:IsStudio() then
    return
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FeatureFlags = require(Shared:WaitForChild("FeatureFlags"))
local Types = require(Shared:WaitForChild("LanternTypes"))

if not FeatureFlags.get("Lanterns.DesignerEnabled") then
    return
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local spawnRemote = ReplicatedStorage:FindFirstChild("SpawnDesignerLantern")
if not spawnRemote then
    spawnRemote = Instance.new("RemoteEvent")
    spawnRemote.Name = "SpawnDesignerLantern"
    spawnRemote.Parent = ReplicatedStorage
end

local DEFAULT_STYLE_OPTIONS = {
    straight = {},
    scurve = {minLateral = 1.25, tipDrop = 0.2},
    planar_spiral = {radiusFactor = 0.12, minRadius = 1.5},
    helix = {radius = 2.0, pitch = 1.0},
}

local function cloneStyleOptions()
    local result = {}
    for style, data in pairs(DEFAULT_STYLE_OPTIONS) do
        local copy = {}
        for key, value in pairs(data) do
            copy[key] = value
        end
        result[style] = copy
    end
    return result
end

local function deepCopy(value: any): any
    if typeof(value) == "table" then
        local clone = {}
        for key, entry in pairs(value) do
            clone[key] = deepCopy(entry)
        end
        return clone
    end
    return value
end

local function makeCurve(mu: number, sigma: number, lo: number, hi: number, multiplier: number?): {[string]: number}
    if multiplier == nil then
        multiplier = 1
    end
    return {
        mu = mu,
        sigma = sigma,
        lo = lo,
        hi = hi,
        multiplier = multiplier,
    }
end

local designerState = {
    activeTab = "tree",
    visible = true,
    previewModel = nil :: Model?,
    tree = {
        masterSeed = math.random(1, 1_000_000),
        channelSeeds = {
            shape = math.random(1, 1_000_000),
            pose = math.random(1, 1_000_000),
            look = math.random(1, 1_000_000),
        },
        distribution = {
            maxTotal = 5,
            maxPerSocket = 2,
            pattern = "uniform",
        },
        angles = {
            pitch = makeCurve(30, 15.0, -45, 90, 1.0),
            yaw = makeCurve(180, 90.0, 0, 360, 1.0),
        },
        branchLength = {
            fraction = makeCurve(0.55, 0.08, 0.3, 0.8, 1.0),
        },
        jitter = {
            enabled = true,
            range = 15,
        },
    },
    lantern = {
        params = {
            height = {value = 12, min = 8, max = 20, rngEnabled = true},
            bend = {value = 15, min = 0, max = 60, rngEnabled = true},
            twist = {value = 0, min = 0, max = 360, rngEnabled = false},
            armLength = {value = 1.8, min = 1, max = 4, rngEnabled = false},
            lanternTilt = {value = 5, min = -45, max = 45, rngEnabled = true},
            lanternYaw = {value = 0, min = -90, max = 90, rngEnabled = true},
        },
        style = "scurve",
        styleOptions = cloneStyleOptions(),
        orientation = {
            mode = "tangent",
            autoRefresh = true,
        },
        branchProfile = {
            mode = "taper",
            radiusStart = 0.08,
            radiusEnd = 0.06,
            midScale = 1.15,
        },
        models = {
            head = {selection = "HeadA"},
            base = {selection = "StoneDisk"},
            segment = {selection = "Cylinder"},
            headScale = {value = 1.0, min = 0.5, max = 10.0, rngEnabled = false},
            baseScale = {value = 1.0, min = 0.5, max = 10.0, rngEnabled = false},
        },
        decorations = {},
    },
}

local widgets = {
    tree = {
        masterSeed = nil :: TextBox?,
        channelSeeds = {} :: {[string]: TextBox},
        pitch = {} :: {[string]: TextBox},
        yaw = {} :: {[string]: TextBox},
        fraction = {} :: {[string]: TextBox},
        distribution = {
            patternButton = nil :: TextButton?,
            maxTotal = nil :: TextBox?,
            maxPerSocket = nil :: TextBox?,
        },
        jitterToggle = nil :: TextButton?,
        jitterRange = nil :: TextBox?,
    },
    lantern = {
        params = {} :: {[string]: {valueBox: TextBox, minBox: TextBox, maxBox: TextBox, toggle: TextButton}},
        styleButton = nil :: TextButton?,
        styleSections = {} :: {[string]: Frame},
        orientationButton = nil :: TextButton?,
        autoRefreshButton = nil :: TextButton?,
        branchModeButton = nil :: TextButton?,
        radiusEndRow = nil :: Frame?,
        midScaleRow = nil :: Frame?,
        headModel = nil :: TextBox?,
        baseModel = nil :: TextBox?,
        segmentModel = nil :: TextBox?,
        headScale = nil :: TextBox?,
        baseScale = nil :: TextBox?,
    },
}

local function formatNumber(value: number, format: string?): string
    return string.format(format or "%.3f", value)
end

local pendingPreview = false

local function computePreviewPosition(distance: number): Vector3?
    local character = player.Character
    if not character then
        return nil
    end
    local root = character:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then
        return root.Position + root.CFrame.LookVector * distance
    end
    return nil
end

local function fireDesignerRemote(mode: string, position: Vector3?)
    local payload = {
        mode = mode,
        position = position,
        tree = deepCopy(designerState.tree),
        lantern = deepCopy(designerState.lantern),
    }
    spawnRemote:FireServer(payload)
end

local function schedulePreview()
    if not designerState.lantern.orientation.autoRefresh then
        return
    end
    if pendingPreview then
        return
    end
    pendingPreview = true
    task.delay(0.2, function()
        pendingPreview = false
        fireDesignerRemote("preview", computePreviewPosition(8))
    end)
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LanternDesigner"
screenGui.DisplayOrder = 10
screenGui.ResetOnSpawn = false
screenGui.Enabled = designerState.visible
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.fromOffset(520, 720)
mainFrame.Position = UDim2.new(1, -540, 0.5, -360)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local round = Instance.new("UICorner")
round.CornerRadius = UDim.new(0, 8)
round.Parent = mainFrame

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 46)
titleBar.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.BackgroundTransparency = 1
titleLabel.Position = UDim2.fromOffset(12, 0)
titleLabel.Size = UDim2.new(1, -140, 1, 0)
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.TextSize = 20
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.TextColor3 = Color3.fromRGB(235, 235, 240)
titleLabel.Text = "Lantern Designer"
titleLabel.Parent = titleBar

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.fromOffset(40, 26)
closeButton.Position = UDim2.new(1, -52, 0.5, -13)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 70, 70)
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.SourceSansBold
closeButton.TextSize = 18
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.Text = "X"
closeButton.Parent = titleBar

closeButton.MouseButton1Click:Connect(function()
    designerState.visible = false
    screenGui.Enabled = designerState.visible
end)

local tabBar = Instance.new("Frame")
tabBar.Position = UDim2.new(0, 0, 0, 46)
tabBar.Size = UDim2.new(1, 0, 0, 38)
tabBar.BackgroundColor3 = Color3.fromRGB(38, 38, 46)
tabBar.BorderSizePixel = 0
tabBar.Parent = mainFrame

local function makeTabButton(text: string, position: UDim2): TextButton
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0.5, 0, 1, 0)
    button.Position = position
    button.BackgroundColor3 = Color3.fromRGB(48, 48, 58)
    button.BorderSizePixel = 0
    button.Font = Enum.Font.SourceSansBold
    button.TextSize = 16
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Text = text
    button.Parent = tabBar
    return button
end

local treeTabButton = makeTabButton("Main Lantern", UDim2.new(0, 0, 0, 0))
local lanternTabButton = makeTabButton("Branch Arms", UDim2.new(0.5, 0, 0, 0))
treeTabButton.BackgroundColor3 = Color3.fromRGB(58, 58, 72)

local contentHeight = mainFrame.Size.Y.Offset - 180

local treeContent = Instance.new("ScrollingFrame")
treeContent.Name = "TreeContent"
treeContent.Position = UDim2.new(0, 12, 0, 92)
treeContent.Size = UDim2.new(1, -24, 0, contentHeight)
treeContent.BackgroundTransparency = 1
treeContent.ScrollBarThickness = 8
treeContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
treeContent.CanvasSize = UDim2.new(0, 0, 0, 0)
treeContent.Visible = true
treeContent.Parent = mainFrame

local treeLayout = Instance.new("UIListLayout")
treeLayout.Padding = UDim.new(0, 8)
treeLayout.SortOrder = Enum.SortOrder.LayoutOrder
treeLayout.Parent = treeContent

local lanternContent = treeContent:Clone()
lanternContent.Name = "LanternContent"
lanternContent.Visible = false
lanternContent.Parent = mainFrame

local function addSection(container: Instance, orderCounter: () -> number, title: string)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 30)
    frame.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
    frame.BorderSizePixel = 0
    frame.LayoutOrder = orderCounter()
    frame.Parent = container

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -10, 1, 0)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 15
    label.TextColor3 = Color3.fromRGB(190, 200, 255)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = title
    label.Parent = frame
end

local function addNumberRow(container: Instance, orderCounter: () -> number, label: string, format: string, initialValue: number, onCommit: (number) -> (number?), minValue: number?, maxValue: number?): TextBox
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 32)
    frame.BackgroundTransparency = 1
    frame.LayoutOrder = orderCounter()
    frame.Parent = container

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(0.55, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.SourceSans
    nameLabel.TextSize = 14
    nameLabel.TextColor3 = Color3.fromRGB(225, 225, 228)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Text = label
    nameLabel.Parent = frame

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.45, 0, 1, -4)
    box.Position = UDim2.new(0.55, 0, 0, 2)
    box.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = false
    box.Font = Enum.Font.SourceSans
    box.TextSize = 14
    box.TextColor3 = Color3.new(1, 1, 1)
    box.Text = formatNumber(initialValue, format)
    box.Parent = frame

    box.Focused:Connect(function()
        box.TextScaled = false
    end)

    box.FocusLost:Connect(function()
        local rawValue = tonumber(box.Text)
        if rawValue == nil then
            box.Text = formatNumber(initialValue, format)
            return
        end
        if minValue then rawValue = math.max(rawValue, minValue) end
        if maxValue then rawValue = math.min(rawValue, maxValue) end
        local adjusted = onCommit(rawValue)
        if adjusted ~= nil then
            rawValue = adjusted
        end
        box.Text = formatNumber(rawValue, format)
        schedulePreview()
    end)

    return box
end

local function addToggleRow(container: Instance, orderCounter: () -> number, label: string, initialState: boolean, callback: (boolean, TextButton) -> ())
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 32)
    frame.BackgroundTransparency = 1
    frame.LayoutOrder = orderCounter()
    frame.Parent = container

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 100, 1, -4)
    button.Position = UDim2.new(0, 0, 0, 2)
    button.BackgroundColor3 = initialState and Color3.fromRGB(70, 130, 180) or Color3.fromRGB(55, 55, 55)
    button.BorderSizePixel = 0
    button.Font = Enum.Font.SourceSansBold
    button.TextSize = 14
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Text = initialState and "On" or "Off"
    button.Parent = frame

    local labelObj = Instance.new("TextLabel")
    labelObj.Size = UDim2.new(1, -110, 1, 0)
    labelObj.Position = UDim2.new(0, 110, 0, 0)
    labelObj.BackgroundTransparency = 1
    labelObj.Font = Enum.Font.SourceSans
    labelObj.TextSize = 14
    labelObj.TextColor3 = Color3.fromRGB(225, 225, 228)
    labelObj.TextXAlignment = Enum.TextXAlignment.Left
    labelObj.Text = label
    labelObj.Parent = frame

    local state = initialState
    button.MouseButton1Click:Connect(function()
        state = not state
        button.BackgroundColor3 = state and Color3.fromRGB(70, 130, 180) or Color3.fromRGB(55, 55, 55)
        button.Text = state and "On" or "Off"
        callback(state, button)
        schedulePreview()
    end)

    return button
end

local function addDropdownRow(container: Instance, orderCounter: () -> number, label: string, options: {string}, initial: string, callback: (string, TextButton) -> ()): TextButton
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 32)
    frame.BackgroundTransparency = 1
    frame.LayoutOrder = orderCounter()
    frame.Parent = container

    local labelObj = Instance.new("TextLabel")
    labelObj.Size = UDim2.new(0.5, 0, 1, 0)
    labelObj.BackgroundTransparency = 1
    labelObj.Font = Enum.Font.SourceSans
    labelObj.TextSize = 14
    labelObj.TextColor3 = Color3.fromRGB(225, 225, 228)
    labelObj.TextXAlignment = Enum.TextXAlignment.Left
    labelObj.Text = label
    labelObj.Parent = frame

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0.5, 0, 1, -4)
    button.Position = UDim2.new(0.5, 0, 0, 2)
    button.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
    button.BorderSizePixel = 0
    button.Font = Enum.Font.SourceSans
    button.TextSize = 14
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Text = initial
    button.Parent = frame

    button.MouseButton1Click:Connect(function()
        local index = table.find(options, button.Text) or 1
        index += 1
        if index > #options then
            index = 1
        end
        local selection = options[index]
        button.Text = selection
        callback(selection, button)
        schedulePreview()
    end)

    return button
end

local doTree
local doLantern

doTree = function()
    local order = 0
    local function nextOrder()
        order += 1
        return order
    end

    addSection(treeContent, nextOrder, "RNG Seeds")
    widgets.tree.masterSeed = addNumberRow(treeContent, nextOrder, "Master seed", "%.0f", designerState.tree.masterSeed, function(value)
        value = math.clamp(math.floor(value + 0.5), 1, 1_000_000)
        designerState.tree.masterSeed = value
        return value
    end, 1, 1_000_000)

    for key, label in pairs({shape = "Shape channel", pose = "Pose channel", look = "Look channel"}) do
        widgets.tree.channelSeeds[key] = addNumberRow(treeContent, nextOrder, label .. " seed", "%.0f", designerState.tree.channelSeeds[key], function(value)
            value = math.clamp(math.floor(value + 0.5), 1, 1_000_000)
            designerState.tree.channelSeeds[key] = value
            return value
        end, 1, 1_000_000)
    end

    addSection(treeContent, nextOrder, "Branch Spawning")
    widgets.tree.distribution.patternButton = addDropdownRow(treeContent, nextOrder, "Pattern", {"uniform", "staggered", "spiral"}, designerState.tree.distribution.pattern, function(selection)
        designerState.tree.distribution.pattern = selection
    end)
    widgets.tree.distribution.maxTotal = addNumberRow(treeContent, nextOrder, "Max total branches", "%.0f", designerState.tree.distribution.maxTotal, function(value)
        value = math.max(0, math.floor(value + 0.5))
        designerState.tree.distribution.maxTotal = value
        return value
    end, 0, 32)
    widgets.tree.distribution.maxPerSocket = addNumberRow(treeContent, nextOrder, "Max per socket", "%.0f", designerState.tree.distribution.maxPerSocket, function(value)
        value = math.max(0, math.floor(value + 0.5))
        designerState.tree.distribution.maxPerSocket = value
        return value
    end, 0, 8)

    local function curveSection(title: string, data: {[string]: number}, store: {[string]: TextBox})
        addSection(treeContent, nextOrder, title)
        store.mu = addNumberRow(treeContent, nextOrder, "Mean", "%.3f", data.mu, function(value)
            data.mu = value
            return value
        end, nil, nil)
        store.sigma = addNumberRow(treeContent, nextOrder, "Spread", "%.3f", data.sigma, function(value)
            data.sigma = math.max(0, value)
            return data.sigma
        end, 0, nil)
        store.lo = addNumberRow(treeContent, nextOrder, "Min", "%.3f", data.lo, function(value)
            data.lo = value
            if data.hi < data.lo then
                data.hi = data.lo
                store.hi.Text = formatNumber(data.hi)
            end
            if data.mu < data.lo then
                data.mu = data.lo
                store.mu.Text = formatNumber(data.mu)
            end
            return data.lo
        end, nil, nil)
        store.hi = addNumberRow(treeContent, nextOrder, "Max", "%.3f", data.hi, function(value)
            data.hi = value
            if data.hi < data.lo then
                data.hi = data.lo
            end
            if data.mu > data.hi then
                data.mu = data.hi
                store.mu.Text = formatNumber(data.mu)
            end
            return data.hi
        end, nil, nil)
    end

    curveSection("Branch pitch (up/down)", designerState.tree.angles.pitch, widgets.tree.pitch)
    curveSection("Branch rotation (around parent)", designerState.tree.angles.yaw, widgets.tree.yaw)
    curveSection("Branch length (fraction)", designerState.tree.branchLength.fraction, widgets.tree.fraction)

    addSection(treeContent, nextOrder, "Jitter")
    widgets.tree.jitterToggle = addToggleRow(treeContent, nextOrder, "Angular jitter", designerState.tree.jitter.enabled, function(state)
        designerState.tree.jitter.enabled = state
    end)
    widgets.tree.jitterRange = addNumberRow(treeContent, nextOrder, "Jitter range (deg)", "%.1f", designerState.tree.jitter.range, function(value)
        value = math.max(0, value)
        designerState.tree.jitter.range = value
        return value
    end, 0, 90)
end

doTree()

doLantern = function()
    local order = 0
    local function nextOrder()
        order += 1
        return order
    end

    addSection(lanternContent, nextOrder, "Core parameters")
    for name, param in pairs(designerState.lantern.params) do
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -10, 0, 84)
        frame.BackgroundTransparency = 1
        frame.LayoutOrder = nextOrder()
        frame.Parent = lanternContent

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 0, 20)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.SourceSansBold
        title.TextSize = 14
        title.TextColor3 = Color3.fromRGB(225, 225, 228)
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Text = name
        title.Parent = frame

        local function makeBox(offset: number, text: string): TextBox
            local box = Instance.new("TextBox")
            box.Size = UDim2.new(0.32, -4, 0, 28)
            box.Position = UDim2.new(offset, 0, 0, 26)
            box.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
            box.BorderSizePixel = 0
            box.ClearTextOnFocus = false
            box.Font = Enum.Font.SourceSans
            box.TextSize = 14
            box.TextColor3 = Color3.new(1, 1, 1)
            box.Text = text
            box.Parent = frame
            box.Focused:Connect(function()
                box.TextScaled = false
            end)
            return box
        end

        local valueBox = makeBox(0, formatNumber(param.value))
        local minBox = makeBox(0.34, formatNumber(param.min))
        local maxBox = makeBox(0.68, formatNumber(param.max))

        local toggle = Instance.new("TextButton")
        toggle.Size = UDim2.new(0, 120, 0, 28)
        toggle.Position = UDim2.new(0, 0, 0, 56)
        toggle.BackgroundColor3 = param.rngEnabled and Color3.fromRGB(70, 130, 180) or Color3.fromRGB(55, 55, 55)
        toggle.BorderSizePixel = 0
        toggle.Font = Enum.Font.SourceSansBold
        toggle.TextSize = 14
        toggle.TextColor3 = Color3.new(1, 1, 1)
        toggle.Text = param.rngEnabled and "RNG enabled" or "Locked"
        toggle.Parent = frame

        local function commit()
            local val = tonumber(valueBox.Text)
            local minVal = tonumber(minBox.Text)
            local maxVal = tonumber(maxBox.Text)
            if minVal then param.min = minVal end
            if maxVal then param.max = maxVal end
            if param.max < param.min then
                param.max = param.min
            end
            if val then
                param.value = math.clamp(val, param.min, param.max)
            else
                param.value = math.clamp(param.value, param.min, param.max)
            end
            valueBox.Text = formatNumber(param.value)
            minBox.Text = formatNumber(param.min)
            maxBox.Text = formatNumber(param.max)
            schedulePreview()
        end

        valueBox.FocusLost:Connect(commit)
        minBox.FocusLost:Connect(commit)
        maxBox.FocusLost:Connect(commit)

        toggle.MouseButton1Click:Connect(function()
            param.rngEnabled = not param.rngEnabled
            toggle.BackgroundColor3 = param.rngEnabled and Color3.fromRGB(70, 130, 180) or Color3.fromRGB(55, 55, 55)
            toggle.Text = param.rngEnabled and "RNG enabled" or "Locked"
        end)

        widgets.lantern.params[name] = {valueBox = valueBox, minBox = minBox, maxBox = maxBox, toggle = toggle}
    end

    addSection(lanternContent, nextOrder, "Style")
    widgets.lantern.styleButton = addDropdownRow(lanternContent, nextOrder, "Curve style", {"straight", "scurve", "planar_spiral", "helix"}, designerState.lantern.style, function(selection)
        designerState.lantern.style = selection
        for name, frame in pairs(widgets.lantern.styleSections) do
            frame.Visible = (name == selection)
        end
    end)

    addSection(lanternContent, nextOrder, "Style overrides")
    for styleName, override in pairs(designerState.lantern.styleOptions) do
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, -10, 0, 90)
        container.BackgroundTransparency = 1
        container.LayoutOrder = nextOrder()
        container.Visible = (styleName == designerState.lantern.style)
        container.Parent = lanternContent
        widgets.lantern.styleSections[styleName] = container

        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 6)
        layout.Parent = container

        local innerOrder = 0
        local function nextInner()
            innerOrder += 1
            return innerOrder
        end

        local function addOverride(label: string, key: string, minValue: number?, maxValue: number?)
            addNumberRow(container, nextInner, label, "%.3f", override[key] or 0, function(value)
                if minValue then value = math.max(value, minValue) end
                if maxValue then value = math.min(value, maxValue) end
                override[key] = value
                return value
            end, minValue, maxValue)
        end

        if styleName == "scurve" then
            addOverride("Minimum lateral", "minLateral", 0.1, nil)
            addOverride("Tip drop", "tipDrop", 0, nil)
        elseif styleName == "planar_spiral" then
            addOverride("Radius factor", "radiusFactor", 0.01, nil)
            addOverride("Minimum radius", "minRadius", 0.1, nil)
        elseif styleName == "helix" then
            addOverride("Radius", "radius", 0.1, nil)
            addOverride("Pitch", "pitch", 0.1, nil)
        end
    end

    addSection(lanternContent, nextOrder, "Orientation")
    widgets.lantern.orientationButton = addDropdownRow(lanternContent, nextOrder, "Pole orientation", {"tangent", "chord"}, designerState.lantern.orientation.mode, function(selection)
        designerState.lantern.orientation.mode = selection
    end)
    widgets.lantern.autoRefreshButton = addToggleRow(lanternContent, nextOrder, "Auto preview", designerState.lantern.orientation.autoRefresh, function(state)
        designerState.lantern.orientation.autoRefresh = state
        pendingPreview = false
        if state then
            schedulePreview()
        end
    end)

    addSection(lanternContent, nextOrder, "Branch profile")
    widgets.lantern.branchModeButton = addDropdownRow(lanternContent, nextOrder, "Mode", {"uniform", "taper", "bell"}, designerState.lantern.branchProfile.mode, function(selection)
        designerState.lantern.branchProfile.mode = selection
        if widgets.lantern.radiusEndRow then
            widgets.lantern.radiusEndRow.Visible = selection ~= "uniform"
        end
        if widgets.lantern.midScaleRow then
            widgets.lantern.midScaleRow.Visible = selection == "bell"
        end
    end)
    
    addNumberRow(lanternContent, nextOrder, "Radius start", "%.3f", designerState.lantern.branchProfile.radiusStart, function(value)
        value = math.max(0.005, value)
        designerState.lantern.branchProfile.radiusStart = value
        if designerState.lantern.branchProfile.mode == "uniform" then
            designerState.lantern.branchProfile.radiusEnd = value
            if widgets.lantern.radiusEndRow then
                local box = widgets.lantern.radiusEndRow:FindFirstChildWhichIsA("TextBox", true)
                if box then
                    box.Text = formatNumber(value)
                end
            end
        end
        return value
    end, 0.005, nil)

    do
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -10, 0, 32)
        frame.BackgroundTransparency = 1
        frame.LayoutOrder = nextOrder()
        frame.Parent = lanternContent
        widgets.lantern.radiusEndRow = frame
        frame.Visible = designerState.lantern.branchProfile.mode ~= "uniform"

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.55, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.SourceSans
        label.TextSize = 14
        label.TextColor3 = Color3.fromRGB(225, 225, 228)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = "Radius end"
        label.Parent = frame

        local box = Instance.new("TextBox")
        box.Size = UDim2.new(0.45, 0, 1, -4)
        box.Position = UDim2.new(0.55, 0, 0, 2)
        box.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
        box.BorderSizePixel = 0
        box.ClearTextOnFocus = false
        box.Font = Enum.Font.SourceSans
        box.TextSize = 14
        box.TextColor3 = Color3.new(1, 1, 1)
        box.Text = formatNumber(designerState.lantern.branchProfile.radiusEnd)
        box.Parent = frame

        box.Focused:Connect(function()
            box.TextScaled = false
        end)

        box.FocusLost:Connect(function()
            local value = tonumber(box.Text) or designerState.lantern.branchProfile.radiusEnd
            value = math.max(0.005, value)
            designerState.lantern.branchProfile.radiusEnd = value
            box.Text = formatNumber(value)
            schedulePreview()
        end)
    end

    do
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -10, 0, 32)
        frame.BackgroundTransparency = 1
        frame.LayoutOrder = nextOrder()
        frame.Parent = lanternContent
        widgets.lantern.midScaleRow = frame
        frame.Visible = designerState.lantern.branchProfile.mode == "bell"

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.55, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.SourceSans
        label.TextSize = 14
        label.TextColor3 = Color3.fromRGB(225, 225, 228)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = "Mid scale"
        label.Parent = frame

        local box = Instance.new("TextBox")
        box.Size = UDim2.new(0.45, 0, 1, -4)
        box.Position = UDim2.new(0.55, 0, 0, 2)
        box.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
        box.BorderSizePixel = 0
        box.ClearTextOnFocus = false
        box.Font = Enum.Font.SourceSans
        box.TextSize = 14
        box.TextColor3 = Color3.new(1, 1, 1)
        box.Text = formatNumber(designerState.lantern.branchProfile.midScale)
        box.Parent = frame

        box.FocusLost:Connect(function()
            local value = tonumber(box.Text) or designerState.lantern.branchProfile.midScale
            value = math.max(0.1, value)
            designerState.lantern.branchProfile.midScale = value
            box.Text = formatNumber(value)
            schedulePreview()
        end)
    end

    addSection(lanternContent, nextOrder, "Models (Main Lantern)")
    local function addTextRow(label: string, initial: string, setter: (string) -> ())
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -10, 0, 32)
        frame.BackgroundTransparency = 1
        frame.LayoutOrder = nextOrder()
        frame.Parent = lanternContent

        local labelObj = Instance.new("TextLabel")
        labelObj.Size = UDim2.new(0.55, 0, 1, 0)
        labelObj.BackgroundTransparency = 1
        labelObj.Font = Enum.Font.SourceSans
        labelObj.TextSize = 14
        labelObj.TextColor3 = Color3.fromRGB(225, 225, 228)
        labelObj.TextXAlignment = Enum.TextXAlignment.Left
        labelObj.Text = label
        labelObj.Parent = frame

        local box = Instance.new("TextBox")
        box.Size = UDim2.new(0.45, 0, 1, -4)
        box.Position = UDim2.new(0.55, 0, 0, 2)
        box.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
        box.BorderSizePixel = 0
        box.Font = Enum.Font.SourceSans
        box.TextSize = 14
        box.TextColor3 = Color3.new(1, 1, 1)
        box.Text = initial
        box.ClearTextOnFocus = false
        box.Parent = frame

        box.FocusLost:Connect(function()
            setter(box.Text)
            schedulePreview()
        end)

        return box
    end

    widgets.lantern.headModel = addTextRow("Head model", designerState.lantern.models.head.selection, function(text)
        designerState.lantern.models.head.selection = text
    end)
    widgets.lantern.baseModel = addTextRow("Base model (foundation)", designerState.lantern.models.base.selection, function(text)
        designerState.lantern.models.base.selection = text
    end)
    
    addSection(lanternContent, nextOrder, "Branch Segment Model")
    widgets.lantern.segmentModel = addTextRow("Segment model", designerState.lantern.models.segment.selection, function(text)
        designerState.lantern.models.segment.selection = text
        print("[Designer] Branch segment model:", text)
    end)
    
    local headScaleParam = designerState.lantern.models.headScale
    widgets.lantern.headScale = addNumberRow(lanternContent, nextOrder, "Head scale", "%.2f", headScaleParam.value, function(value)
        value = math.clamp(value, headScaleParam.min, headScaleParam.max)
        headScaleParam.value = value
        return value
    end, headScaleParam.min, headScaleParam.max)

    local baseScaleParam = designerState.lantern.models.baseScale
    widgets.lantern.baseScale = addNumberRow(lanternContent, nextOrder, "Base scale", "%.2f", baseScaleParam.value, function(value)
        value = math.clamp(value, baseScaleParam.min, baseScaleParam.max)
        baseScaleParam.value = value
        return value
    end, baseScaleParam.min, baseScaleParam.max)
end

doLantern()

local buttonBar = Instance.new("Frame")
buttonBar.Position = UDim2.new(0, 12, 1, -60)
buttonBar.Size = UDim2.new(1, -24, 0, 48)
buttonBar.BackgroundTransparency = 1
buttonBar.Parent = mainFrame

local function addActionButton(text: string, xIndex: number, color: Color3): TextButton
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0.25, -6, 1, 0)
    button.Position = UDim2.new(xIndex * 0.25, xIndex * 6, 0, 0)
    button.BackgroundColor3 = color
    button.BorderSizePixel = 0
    button.Font = Enum.Font.SourceSansBold
    button.TextSize = 16
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Text = text
    button.Parent = buttonBar
    local rounder = Instance.new("UICorner")
    rounder.CornerRadius = UDim.new(0, 6)
    rounder.Parent = button
    return button
end

local rerollButton = addActionButton("Reroll", 0, Color3.fromRGB(90, 140, 200))
local previewButton = addActionButton("Preview", 1, Color3.fromRGB(80, 180, 130))
local spawnButton = addActionButton("Spawn", 2, Color3.fromRGB(200, 90, 80))
local copyButton = addActionButton("Copy JSON", 3, Color3.fromRGB(90, 90, 110))

local function rerollTreeSeeds()
    designerState.tree.masterSeed = math.random(1, 1_000_000)
    if widgets.tree.masterSeed then
        widgets.tree.masterSeed.Text = tostring(designerState.tree.masterSeed)
    end
    for key, box in pairs(widgets.tree.channelSeeds) do
        designerState.tree.channelSeeds[key] = math.random(1, 1_000_000)
        box.Text = tostring(designerState.tree.channelSeeds[key])
    end
end

local function rerollLanternParameters()
    for name, row in pairs(widgets.lantern.params) do
        local param = designerState.lantern.params[name]
        if param.rngEnabled then
            param.value = param.min + math.random() * (param.max - param.min)
            row.valueBox.Text = formatNumber(param.value)
        end
    end
end

rerollButton.MouseButton1Click:Connect(function()
    if designerState.activeTab == "tree" then
        rerollTreeSeeds()
    else
        rerollLanternParameters()
    end
    schedulePreview()
end)

previewButton.MouseButton1Click:Connect(function()
    fireDesignerRemote("preview", computePreviewPosition(8))
end)

spawnButton.MouseButton1Click:Connect(function()
    fireDesignerRemote("spawn", computePreviewPosition(10))
end)

copyButton.MouseButton1Click:Connect(function()
    local payload = {
        tree = deepCopy(designerState.tree),
        lantern = deepCopy(designerState.lantern),
    }
    local encoded = HttpService:JSONEncode(payload)
    local ok, err = pcall(setclipboard, encoded)
    if ok then
        print("[Designer] Copied configuration JSON to clipboard")
    else
        warn("[Designer] Clipboard copy failed:", err)
    end
end)

local function setTab(name: string)
    designerState.activeTab = name
    if name == "tree" then
        treeContent.Visible = true
        lanternContent.Visible = false
        treeTabButton.BackgroundColor3 = Color3.fromRGB(58, 58, 72)
        lanternTabButton.BackgroundColor3 = Color3.fromRGB(48, 48, 58)
    else
        treeContent.Visible = false
        lanternContent.Visible = true
        treeTabButton.BackgroundColor3 = Color3.fromRGB(48, 48, 58)
        lanternTabButton.BackgroundColor3 = Color3.fromRGB(58, 58, 72)
    end
end

treeTabButton.MouseButton1Click:Connect(function()
    setTab("tree")
end)

lanternTabButton.MouseButton1Click:Connect(function()
    setTab("lantern")
end)

setTab(designerState.activeTab)

if designerState.visible then
    screenGui.Enabled = true
    schedulePreview()
else
    screenGui.Enabled = false
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end
    local altDown = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)
    if altDown and input.KeyCode == Enum.KeyCode.D then
        designerState.visible = not designerState.visible
        screenGui.Enabled = designerState.visible
        if designerState.visible then
            schedulePreview()
        end
    end
end)

print("[Designer] Lantern Designer initialized (Alt+D)")
print("[Designer] Tree Structure tab controls branch spawning & angles")
print("[Designer] Lantern Branch tab controls individual branch properties")
