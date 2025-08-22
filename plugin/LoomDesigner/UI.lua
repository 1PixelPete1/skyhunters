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

local GLOBAL_FIELDS = {
    {
        kind = "number",
        label = "Base Seed",
        get = function()
            return LoomDesigner.GetSeed and LoomDesigner.GetSeed()
        end,
        set = function(v)
            if LoomDesigner.SetSeed then LoomDesigner.SetSeed(v) end
        end,
    },
    {
        kind = "number",
        label = "Segment Count",
        get = function()
            return GrowthStylesCore.GetParam("segmentCount")
        end,
        set = function(v)
            GrowthStylesCore.SetParam("segmentCount", v)
        end,
    },
    {
        kind = "dropdown",
        label = "Rotation Rules",
        options = {"auto","accumulate","absolute"},
        get = function()
            if LoomDesigner.GetRotationContinuity then
                local mode = LoomDesigner.GetRotationContinuity()
                if mode == "accumulate" then return 2 end
                if mode == "absolute" then return 3 end
            end
            return 1
        end,
        set = function(opt)
            if LoomDesigner.SetRotationContinuity then
                if opt == "auto" then
                    LoomDesigner.SetRotationContinuity(nil)
                else
                    LoomDesigner.SetRotationContinuity(opt)
                end
            end
        end,
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
    modeBtn.LayoutOrder = 1
    modeBtn.Parent = container

    local helperLabel = Instance.new("TextLabel")
    helperLabel.BackgroundTransparency = 1
    helperLabel.TextColor3 = Color3.fromRGB(200,200,200)
    helperLabel.Text = "Create or select a branch to edit."
    helperLabel.Size = UDim2.new(1,0,0,24)
    helperLabel.LayoutOrder = 5
    helperLabel.Parent = container

    local branchControls = makeList(container)
    branchControls.LayoutOrder = 6
    branchControls.Visible = false

    local kinds = LoomDesigner and LoomDesigner.SUPPORTED_KIND_LIST
    if type(kinds) ~= "table" or #kinds == 0 then
        kinds = FALLBACK_KINDS
    end

    local paramsFrame = makeList(branchControls)

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
        for _,entry in ipairs(GLOBAL_FIELDS) do
            if entry.kind == "number" then
                numberField(paramsFrame, entry.label, entry.get(), function(v)
                    entry.set(v)
                    GrowthStylesCore.ApplyPreview()
                end)
            elseif entry.kind == "dropdown" then
                labeledDropdown(paramsFrame, popupHost, entry.label, entry.options, entry.get(), function(opt)
                    entry.set(opt)
                    GrowthStylesCore.ApplyPreview()
                end)
            end
        end
    end

    labeledDropdown(branchControls, popupHost, "Kind", kinds, 1, function(opt)
        GrowthStylesCore.SetKind(opt)
        renderFields()
        GrowthStylesCore.ApplyPreview()
    end)

    renderFields()
    GrowthStylesCore.ApplyPreview()

    local delBtn = Instance.new("TextButton")
    delBtn.Text = "Delete Branch"
    delBtn.Size = UDim2.new(0,160,0,24)
    delBtn.BackgroundColor3 = Color3.fromRGB(48,48,48)
    delBtn.TextColor3 = Color3.new(1,1,1)
    delBtn.Parent = branchControls

    local trunkBtn = Instance.new("TextButton")
    trunkBtn.Text = "Set as Trunk"
    trunkBtn.Size = UDim2.new(0,160,0,24)
    trunkBtn.BackgroundColor3 = Color3.fromRGB(48,48,48)
    trunkBtn.TextColor3 = Color3.new(1,1,1)
    trunkBtn.Parent = branchControls

    local attachBtn = Instance.new("TextButton")
    attachBtn.Text = "Attach Child"
    attachBtn.Size = UDim2.new(0,160,0,24)
    attachBtn.BackgroundColor3 = Color3.fromRGB(48,48,48)
    attachBtn.TextColor3 = Color3.new(1,1,1)
    attachBtn.Parent = branchControls

    local applyBtn = Instance.new("TextButton")
    applyBtn.Text = "Apply to Trunk"
    applyBtn.Size = UDim2.new(0,160,0,24)
    applyBtn.BackgroundColor3 = Color3.fromRGB(48,48,48)
    applyBtn.TextColor3 = Color3.new(1,1,1)
    applyBtn.Visible = false
    applyBtn.Parent = branchControls

    local started = false
    local function ensureStart()
        if not started then
            local ok, err = pcall(function()
                return LoomDesigner.Start(plugin)
            end)
            if not ok then
                warn("LoomDesigner.Start failed:", err)
            end
            started = ok
        end
    end

    local selectedBranch: string? = nil
    local branchDropdownBtn: TextButton? = nil

    local function updateBranchUI()
        branchControls.Visible = selectedBranch ~= nil
        helperLabel.Visible = not selectedBranch
    end

    local function refreshBranchDropdown(selectName: string?)
        ensureStart()
        if branchDropdownBtn then branchDropdownBtn.Parent:Destroy() end
        local branches = (LoomDesigner.GetBranches and LoomDesigner.GetBranches()) or {}
        local names = {}
        for name in pairs(branches) do
            table.insert(names, name)
        end
        table.sort(names)
        local defaultIndex = 0
        if selectName then
            for i,n in ipairs(names) do
                if n == selectName then
                    defaultIndex = i
                    break
                end
            end
            selectedBranch = selectName
        elseif selectedBranch then
            for i,n in ipairs(names) do
                if n == selectedBranch then
                    defaultIndex = i
                    break
                end
            end
            if defaultIndex == 0 then selectedBranch = nil end
        end
        branchDropdownBtn = labeledDropdown(container, popupHost, "Branch", names, defaultIndex, function(opt)
            selectedBranch = opt
            updateBranchUI()
        end)
        branchDropdownBtn.Parent.LayoutOrder = 2
        updateBranchUI()
    end

    refreshBranchDropdown()

    delBtn.MouseButton1Click:Connect(function()
        ensureStart()
        if selectedBranch and LoomDesigner.DeleteBranch then
            LoomDesigner.DeleteBranch(selectedBranch)
            LoomDesigner.RebuildPreview()
            refreshBranchDropdown()
        end
    end)

    trunkBtn.MouseButton1Click:Connect(function()
        ensureStart()
        if selectedBranch and LoomDesigner.SetTrunk then
            LoomDesigner.SetTrunk(selectedBranch)
            LoomDesigner.RebuildPreview()
        end
    end)

    attachBtn.MouseButton1Click:Connect(function()
        ensureStart()
        if selectedBranch and LoomDesigner.AddChild then
            local assignments = (LoomDesigner.GetAssignments and LoomDesigner.GetAssignments()) or {}
            local trunk = assignments.trunk
            if trunk and trunk ~= "" and trunk ~= selectedBranch then
                LoomDesigner.AddChild(trunk, selectedBranch)
                LoomDesigner.RebuildPreview()
            end
        end
    end)

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

    local addBtn = Instance.new("TextButton")
    addBtn.Text = "Add Branch"
    addBtn.Size = UDim2.new(0,160,0,24)
    addBtn.BackgroundColor3 = Color3.fromRGB(48,48,48)
    addBtn.TextColor3 = Color3.new(1,1,1)
    addBtn.LayoutOrder = 3
    addBtn.Parent = container
    addBtn.MouseButton1Click:Connect(function()
        ensureStart()
        local branches = (LoomDesigner.GetBranches and LoomDesigner.GetBranches()) or {}
        local hadNone = not next(branches)
        local i = 1
        local name = "branch" .. i
        while branches[name] do
            i += 1
            name = "branch" .. i
        end
        if LoomDesigner.CreateBranch then
            LoomDesigner.CreateBranch(name, { kind = "straight" })
        end
        LoomDesigner.RebuildPreview()
        refreshBranchDropdown(hadNone and name or nil)
    end)

    local quickBtn = Instance.new("TextButton")
    quickBtn.Text = "New Branch + Author"
    quickBtn.Size = UDim2.new(0,160,0,24)
    quickBtn.BackgroundColor3 = Color3.fromRGB(48,48,48)
    quickBtn.TextColor3 = Color3.new(1,1,1)
    quickBtn.LayoutOrder = 4
    quickBtn.Parent = container
    quickBtn.MouseButton1Click:Connect(function()
        ensureStart()
        local branches = (LoomDesigner.GetBranches and LoomDesigner.GetBranches()) or {}
        local i = 1
        local name = "branch" .. i
        while branches[name] do
            i += 1
            name = "branch" .. i
        end
        if LoomDesigner.CreateBranch then
            LoomDesigner.CreateBranch(name, { kind = "straight" })
        end
        LoomDesigner.RebuildPreview()
        refreshBranchDropdown(name)
        authoring = true
        modeBtn.Text = "Mode: Authoring"
        applyBtn.Visible = true
    end)

    modeBtn.MouseButton1Click:Connect(function()
        authoring = not authoring
        modeBtn.Text = authoring and "Mode: Authoring" or "Mode: Preview"
        applyBtn.Visible = authoring
    end)
end

return UI
