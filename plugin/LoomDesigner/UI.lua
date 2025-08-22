--!strict
local LoomDesigner = require(script.Parent.Main)
local GrowthStylesCore = require(script.Parent.GrowthStylesCore)

local UI = {}

local FALLBACK_KINDS = {"straight","curved","zigzag","sigmoid","chaotic"}

local KIND_FIELDS = {
    curved = {
        {key = "amplitudeDeg", label = "Amplitude Deg"},
        {key = "frequency", label = "Frequency"},
    },
    zigzag = {
        {key = "zigzagEvery", label = "Zigzag Every"},
        {key = "zigzagStep", label = "Zigzag Step"},
    },
    sigmoid = {
        {key = "curvature", label = "Curvature"},
    },
    chaotic = {
        {key = "rollBias", label = "Roll Bias"},
        {key = "amplitudeDeg", label = "Amplitude Deg"},
        {key = "frequency", label = "Frequency"},
    },
}

local function makeList(parent: Instance): Frame
    local frame = Instance.new("Frame")
    frame.BackgroundTransparency = 1
    frame.Size = UDim2.new(1,0,0,0)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.Parent = parent

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0,6)
    layout.Parent = frame

    return frame
end

local function labeledDropdown(parent: Instance, popupHost: Frame, label: string, options: {string}, defaultIndex: number, onSelect: (string)->())
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1,0,0,26)
    row.Parent = parent

    local lab = Instance.new("TextLabel")
    lab.Text = label
    lab.BackgroundTransparency = 1
    lab.TextColor3 = Color3.fromRGB(200,200,200)
    lab.Size = UDim2.new(0,150,1,0)
    lab.TextXAlignment = Enum.TextXAlignment.Left
    lab.Parent = row

    local btn = Instance.new("TextButton")
    btn.Text = options[defaultIndex] or "Select"
    btn.Size = UDim2.new(1,-160,1,0)
    btn.Position = UDim2.new(0,155,0,0)
    btn.BackgroundColor3 = Color3.fromRGB(42,42,42)
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Parent = row

    local open = false
    local popup: Frame? = nil

    local function closePopup()
        open = false
        if popup then popup:Destroy(); popup=nil end
    end

    btn.MouseButton1Click:Connect(function()
        if open then closePopup(); return end
        open = true
        popup = Instance.new("Frame")
        popup.BackgroundColor3 = Color3.fromRGB(36,36,36)
        popup.BorderSizePixel = 1
        popup.ZIndex = 1001
        popup.Parent = popupHost

        local btnAbs = btn.AbsolutePosition
        local rootAbs = popupHost.AbsolutePosition
        popup.Position = UDim2.fromOffset(btnAbs.X - rootAbs.X, btnAbs.Y - rootAbs.Y + btn.AbsoluteSize.Y)
        popup.Size = UDim2.fromOffset(btn.AbsoluteSize.X, math.min(#options,10)*22 + 4)

        local list = Instance.new("UIListLayout")
        list.Parent = popup
        list.Padding = UDim.new(0,2)
        list.SortOrder = Enum.SortOrder.LayoutOrder

        for _,opt in ipairs(options) do
            local item = Instance.new("TextButton")
            item.Text = tostring(opt)
            item.Size = UDim2.new(1,-4,0,20)
            item.Position = UDim2.fromOffset(2,0)
            item.BackgroundColor3 = Color3.fromRGB(50,50,50)
            item.TextColor3 = Color3.new(1,1,1)
            item.ZIndex = 1002
            item.Parent = popup
            item.MouseButton1Click:Connect(function()
                btn.Text = tostring(opt)
                onSelect(tostring(opt))
                closePopup()
            end)
        end
    end)

    popupHost.InputBegan:Connect(function(input)
        if open and popup and input.UserInputType == Enum.UserInputType.MouseButton1 then
            local pos = input.Position
            local p0 = popup.AbsolutePosition
            local p1 = p0 + popup.AbsoluteSize
            if not (pos.X >= p0.X and pos.X <= p1.X and pos.Y >= p0.Y and pos.Y <= p1.Y) then
                closePopup()
            end
        end
    end)

    return btn
end

local function numberField(parent: Instance, label: string, value: number?, onCommit: (number)->())
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1,0,0,26)
    row.Parent = parent

    local lab = Instance.new("TextLabel")
    lab.Text = label
    lab.BackgroundTransparency = 1
    lab.TextColor3 = Color3.fromRGB(200,200,200)
    lab.Size = UDim2.new(0,150,1,0)
    lab.TextXAlignment = Enum.TextXAlignment.Left
    lab.Parent = row

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1,-160,1,0)
    box.Position = UDim2.new(0,155,0,0)
    box.BackgroundColor3 = Color3.fromRGB(42,42,42)
    box.TextColor3 = Color3.new(1,1,1)
    box.Text = value and tostring(value) or ""
    box.Parent = row

    box.FocusLost:Connect(function(_)
        local v = tonumber(box.Text)
        if v then onCommit(v) end
    end)
end

function UI.Build(_widget: PluginGui, plugin: Plugin, where)
    local controlsHost: Frame = where.controlsHost
    local popupHost: Frame = where.popupHost

    local container = makeList(controlsHost)

    local authoring = false

    local modeBtn = Instance.new("TextButton")
    modeBtn.Text = "Mode: Preview"
    modeBtn.Size = UDim2.new(0,160,0,24)
    modeBtn.BackgroundColor3 = Color3.fromRGB(48,48,48)
    modeBtn.TextColor3 = Color3.new(1,1,1)
    modeBtn.Parent = container

    local kinds = LoomDesigner and LoomDesigner.SUPPORTED_KIND_LIST
    if type(kinds) ~= "table" or #kinds == 0 then
        kinds = FALLBACK_KINDS
    end

    local paramsFrame = makeList(container)

    local function renderFields()
        for _,c in ipairs(paramsFrame:GetChildren()) do
            if c:IsA("GuiObject") then c:Destroy() end
        end
        local prof = GrowthStylesCore.GetProfile()
        local defs = KIND_FIELDS[prof.kind]
        if defs then
            for _,entry in ipairs(defs) do
                numberField(paramsFrame, entry.label, GrowthStylesCore.GetParam(entry.key), function(v)
                    GrowthStylesCore.SetParam(entry.key, v)
                    GrowthStylesCore.ApplyPreview()
                end)
            end
        end
    end

    labeledDropdown(container, popupHost, "Kind", kinds, 1, function(opt)
        GrowthStylesCore.SetKind(opt)
        renderFields()
        GrowthStylesCore.ApplyPreview()
    end)

    renderFields()
    GrowthStylesCore.ApplyPreview()

    local applyBtn = Instance.new("TextButton")
    applyBtn.Text = "Apply to Trunk"
    applyBtn.Size = UDim2.new(0,160,0,24)
    applyBtn.BackgroundColor3 = Color3.fromRGB(48,48,48)
    applyBtn.TextColor3 = Color3.new(1,1,1)
    applyBtn.Visible = false
    applyBtn.Parent = container

    local started = false
    local function ensureStart()
        if not started then
            local ok, _ = pcall(function()
                return LoomDesigner.Start(plugin)
            end)
            started = ok
        end
    end

    applyBtn.MouseButton1Click:Connect(function()
        ensureStart()
        local prof = GrowthStylesCore.GetProfile()
        local design = { kind = prof.kind }
        for k, v in pairs(prof.params) do design[k] = v end

        local branches = (LoomDesigner.GetBranches and LoomDesigner.GetBranches()) or {}
        if not next(branches) then
            if LoomDesigner.CreateBranch then
                LoomDesigner.CreateBranch("branch1", { kind = "straight" })
            end
            branches = (LoomDesigner.GetBranches and LoomDesigner.GetBranches()) or { branch1 = { kind = "straight" } }
        end

        local assignments = (LoomDesigner.GetAssignments and LoomDesigner.GetAssignments()) or { trunk = "" }
        local trunk = assignments.trunk
        if not trunk or trunk == "" or not branches[trunk] then
            for name in pairs(branches) do trunk = name break end
            if LoomDesigner.SetTrunk then LoomDesigner.SetTrunk(trunk) end
        end

        if LoomDesigner.EditBranch then
            LoomDesigner.EditBranch(trunk, design)
        end

        if LoomDesigner.ApplyAuthoringAndPreview then
            LoomDesigner.ApplyAuthoringAndPreview(nil)
        end
    end)

    modeBtn.MouseButton1Click:Connect(function()
        authoring = not authoring
        modeBtn.Text = authoring and "Mode: Authoring" or "Mode: Preview"
        applyBtn.Visible = authoring
    end)
end

return UI
