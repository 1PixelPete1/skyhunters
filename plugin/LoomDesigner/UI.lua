--!strict
local LoomDesigner = require(script.Parent.Main)
local GrowthStylesCore = require(script.Parent.GrowthStylesCore)

local UI = {}

local FALLBACK_KINDS = {"straight","curved","zigzag","sigmoid","chaotic","spiral","noise","random"}

local KIND_FIELDS = {
curved = {
{key = "amplitudeDeg", label = "Amplitude Deg", default = 12},
{key = "frequency", label = "Frequency", default = 1},
    {key = "curvature", label = "Curvature", default = 0.35},
},
zigzag = {
{key = "zigzagEvery", label = "Zigzag Every", default = 1},
    {key = "zigzagStep", label = "Zigzag Step", default = 12},
    {key = "pitchBias", label = "Pitch Bias", default = 0},
{key = "rollBias", label = "Roll Bias", default = 0},
},
sigmoid = {
{key = "amplitudeDeg", label = "Amplitude Deg", default = 10},
{key = "sigmoidK", label = "Sigmoid K", default = 6},
{key = "sigmoidMid", label = "Sigmoid Mid", default = 0.5},
},
    chaotic = {
            {key = "amplitudeDeg", label = "Amplitude Deg", default = 12},
            {key = "chaoticR", label = "Chaotic R", default = 3.9},
            {key = "rollBias", label = "Roll Bias", default = 0},
        },
        spiral = {
            {key = "amplitudeDeg", label = "Amplitude Deg", default = 10},
            {key = "yawStep", label = "Yaw Step", default = 10},
            {key = "yawVar", label = "Yaw Variance", default = 0},
            {key = "pitchBias", label = "Pitch Bias", default = 0},
            {key = "pitchVar", label = "Pitch Variance", default = 0},
            {key = "rollBias", label = "Roll Bias", default = 0},
            {key = "rollVar", label = "Roll Variance", default = 0},
        },
        noise = {
            {key = "noiseAmp", label = "Noise Amplitude", default = 10},
            {key = "rollBias", label = "Roll Bias", default = 0},
        },
        random = {
            {key = "amplitudeDeg", label = "Amplitude Deg", default = 180},
        },
    }

local BRANCH_FIELDS = {
    {
        kind = "number",
        label = "Segment Count",
        key = "segmentCount",
        default = 12,
        get = function()
            if not selectedBranch then return 12 end
            local branches = (LoomDesigner.GetBranches and LoomDesigner.GetBranches()) or {}
            local branch = branches[selectedBranch]
            return branch and branch.segmentCount or 12
        end,
        set = function(v)
            if selectedBranch and LoomDesigner.EditBranch then
                LoomDesigner.EditBranch(selectedBranch, {segmentCount = v})
            end
        end,
    },
    {
        kind = "number",
        label = "Segment Count Min",
        key = "segmentCountMin",
        default = 8,
        get = function()
            if not selectedBranch then return 8 end
            local branches = (LoomDesigner.GetBranches and LoomDesigner.GetBranches()) or {}
            local branch = branches[selectedBranch]
            return branch and branch.segmentCountMin or 8
        end,
        set = function(v)
            if selectedBranch and LoomDesigner.EditBranch then
                LoomDesigner.EditBranch(selectedBranch, {segmentCountMin = v})
            end
        end,
    },
    {
        kind = "number",
        label = "Segment Count Max",
        key = "segmentCountMax",
        default = 16,
        get = function()
            if not selectedBranch then return 16 end
            local branches = (LoomDesigner.GetBranches and LoomDesigner.GetBranches()) or {}
            local branch = branches[selectedBranch]
            return branch and branch.segmentCountMax or 16
        end,
        set = function(v)
            if selectedBranch and LoomDesigner.EditBranch then
                LoomDesigner.EditBranch(selectedBranch, {segmentCountMax = v})
            end
        end,
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
    return box
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
    branchControls.Visible = true  -- Always show branch controls

    local kinds = LoomDesigner and LoomDesigner.SUPPORTED_KIND_LIST
    if type(kinds) ~= "table" or #kinds == 0 then
        kinds = FALLBACK_KINDS
    end

    local paramsFrame = makeList(branchControls)

    local function renderFields()
        for _,c in ipairs(paramsFrame:GetChildren()) do
            if c:IsA("GuiObject") then c:Destroy() end
        end
        
        -- Add branch-specific fields first
        for _,entry in ipairs(BRANCH_FIELDS) do
            if entry.kind == "number" then
                numberField(paramsFrame, entry.label, entry.get(), function(v)
                    entry.set(v)
                    LoomDesigner.RebuildPreview()
                end)
            elseif entry.kind == "dropdown" then
                labeledDropdown(paramsFrame, popupHost, entry.label, entry.options, entry.get(), function(opt)
                    entry.set(opt)
                    LoomDesigner.RebuildPreview()
                end)
            end
        end
        
        -- Add kind-specific parameters
        local prof = GrowthStylesCore.GetProfile()
        local defs = KIND_FIELDS[prof.kind]
        if defs then
            for _,entry in ipairs(defs) do
                local currentValue = GrowthStylesCore.GetParam(entry.key) or entry.default or 0
                numberField(paramsFrame, entry.label, currentValue, function(v)
                    GrowthStylesCore.SetParam(entry.key, v)
                    -- Also save to the selected branch
                    if selectedBranch and LoomDesigner.EditBranch then
                        LoomDesigner.EditBranch(selectedBranch, {[entry.key] = v})
                    end
                    GrowthStylesCore.ApplyPreview()
                end)
            end
        end
        
        -- Add global fields
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

    local addChildBtn = Instance.new("TextButton")
    addChildBtn.Text = "Add Sub-Branch"
    addChildBtn.Size = UDim2.new(0,160,0,24)
    addChildBtn.BackgroundColor3 = Color3.fromRGB(48,48,48)
    addChildBtn.TextColor3 = Color3.new(1,1,1)
    addChildBtn.Parent = branchControls
    
    local navBtn = Instance.new("TextButton")
    navBtn.Text = "Navigate Hierarchy"
    navBtn.Size = UDim2.new(0,160,0,24)
    navBtn.BackgroundColor3 = Color3.fromRGB(48,48,48)
    navBtn.TextColor3 = Color3.new(1,1,1)
    navBtn.Parent = branchControls

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

    -- ensure default branch exists before building branch controls
    ensureStart()

    local selectedBranch: string? = nil
    local branchDropdownBtn: TextButton? = nil
    local kindDropdownBtn = nil
    
    -- Forward declare functions that reference each other
    local updateBranchUI
    local createKindDropdown
    
    createKindDropdown = function()
        if kindDropdownBtn then kindDropdownBtn.Parent:Destroy() end
        
        local currentKind = "straight"
        if selectedBranch then
            local branches = (LoomDesigner.GetBranches and LoomDesigner.GetBranches()) or {}
            local branch = branches[selectedBranch]
            if branch then
                currentKind = branch.kind or "straight"
            end
        end
        
        local kindIndex = 1
        for i, kind in ipairs(kinds) do
            if kind == currentKind then
                kindIndex = i
                break
            end
        end
        
        kindDropdownBtn = labeledDropdown(branchControls, popupHost, "Kind", kinds, kindIndex, function(opt)
            GrowthStylesCore.SetKind(opt)
            -- Also save to the selected branch
            if selectedBranch and LoomDesigner.EditBranch then
                LoomDesigner.EditBranch(selectedBranch, {kind = opt})
            end
            renderFields()
            GrowthStylesCore.ApplyPreview()
        end)
    end
    
    updateBranchUI = function()
        local branches = (LoomDesigner.GetBranches and LoomDesigner.GetBranches()) or {}
        
        if not selectedBranch or not branches[selectedBranch] then
            helperLabel.Text = "Create or select a branch to edit."
            return
        end
        
        local branch = branches[selectedBranch]
        
        -- Show branch hierarchy info
        local assignments = (LoomDesigner.GetAssignments and LoomDesigner.GetAssignments()) or {}
        local isTrunk = (assignments.trunk == selectedBranch)
        local children = {}
        for _, child in ipairs(assignments.children) do
            if child.parent == selectedBranch then
                table.insert(children, child.child)
            end
        end
        
        local hierarchyText = string.format("Editing: %s", selectedBranch)
        if isTrunk then
            hierarchyText = hierarchyText .. " (TRUNK)"
        end
        if #children > 0 then
            hierarchyText = hierarchyText .. string.format(" | Children: %s", table.concat(children, ", "))
        end
        helperLabel.Text = hierarchyText
        
        -- Sync the branch data to GrowthStylesCore
        GrowthStylesCore.SetKind(branch.kind or "straight")
        for k, v in pairs(branch) do
            if k ~= "kind" and type(v) == "number" then
                GrowthStylesCore.SetParam(k, v)
            end
        end
        
        -- Refresh the parameter fields and kind dropdown
        createKindDropdown()
        renderFields()
        GrowthStylesCore.ApplyPreview()
    end
    local function refreshBranchDropdown(selectName)
        ensureStart()
        if branchDropdownBtn then branchDropdownBtn.Parent:Destroy() end
        local branches = (LoomDesigner.GetBranches and LoomDesigner.GetBranches()) or {}
        local names = {}
        for name in pairs(branches) do
            table.insert(names, name)
        end
        table.sort(names)
        
        -- If no branches exist, create a default one
        if #names == 0 then
            print("[UI] No branches found, creating default branch")
            if LoomDesigner.CreateBranch then
                LoomDesigner.CreateBranch("branch1", { kind = "straight" })
            end
            if LoomDesigner.SetTrunk then
                LoomDesigner.SetTrunk("branch1")
            end
            names = {"branch1"}
        end
        
        local defaultIndex = 1
        if selectName then
            for i,n in ipairs(names) do
                if n == selectName then
                    defaultIndex = i
                    break
                end
            end
        end
        branchDropdownBtn = labeledDropdown(container, popupHost, "Branch", names, defaultIndex, function(opt)
            selectedBranch = opt
            updateBranchUI()
        end)
        branchDropdownBtn.LayoutOrder = 2  -- Position after mode button
        selectedBranch = names[defaultIndex]
        if selectedBranch then
            updateBranchUI()
        end
    end

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
            print("[UI] SetTrunk", selectedBranch)
            LoomDesigner.SetTrunk(selectedBranch)
            LoomDesigner.RebuildPreview()
        else
            warn("[UI] SetTrunk: no branch selected")
        end
    end)

    addChildBtn.MouseButton1Click:Connect(function()
        ensureStart()
        if not selectedBranch then
            warn("[UI] AddSubBranch: no branch selected")
            return
        end
        
        -- Create a new child branch
        local branches = (LoomDesigner.GetBranches and LoomDesigner.GetBranches()) or {}
        local i = 1
        local childName = selectedBranch .. "_child" .. i
        while branches[childName] do
            i += 1
            childName = selectedBranch .. "_child" .. i
        end
        
        -- Create the child branch with default settings
        if LoomDesigner.CreateBranch then
            LoomDesigner.CreateBranch(childName, { kind = "curved" })
        end
        
        -- Attach it to the selected branch
        if LoomDesigner.AddChild then
            print("[UI] AddSubBranch: attaching", childName, "to", selectedBranch)
            LoomDesigner.AddChild(selectedBranch, childName, "tip", 1)
            LoomDesigner.RebuildPreview()
            refreshBranchDropdown(childName)  -- Select the new child
        end
    end)
    
    navBtn.MouseButton1Click:Connect(function()
        if not selectedBranch then return end
        
        local assignments = (LoomDesigner.GetAssignments and LoomDesigner.GetAssignments()) or {}
        local options = {}
        
        -- Add parent option
        local parent = nil
        for _, child in ipairs(assignments.children) do
            if child.child == selectedBranch then
                parent = child.parent
                break
            end
        end
        if parent then
            table.insert(options, "↑ Parent: " .. parent)
        end
        
        -- Add children options
        local children = {}
        for _, child in ipairs(assignments.children) do
            if child.parent == selectedBranch then
                table.insert(children, child.child)
            end
        end
        for _, childName in ipairs(children) do
            table.insert(options, "↓ Child: " .. childName)
        end
        
        -- Add trunk option if not already trunk
        if assignments.trunk ~= selectedBranch then
            table.insert(options, "🌳 Trunk: " .. (assignments.trunk or "none"))
        end
        
        if #options > 0 then
            -- Create a simple navigation popup (using the existing dropdown system)
            local navFrame = Instance.new("Frame")
            navFrame.BackgroundColor3 = Color3.fromRGB(36,36,36)
            navFrame.BorderSizePixel = 1
            navFrame.Size = UDim2.new(0, 200, 0, math.min(#options * 25 + 10, 200))
            navFrame.Position = UDim2.new(0.5, -100, 0.5, -50)
            navFrame.ZIndex = 1000
            navFrame.Parent = popupHost
            
            local list = Instance.new("UIListLayout")
            list.Parent = navFrame
            list.Padding = UDim.new(0,2)
            
            for _, option in ipairs(options) do
                local btn = Instance.new("TextButton")
                btn.Text = option
                btn.Size = UDim2.new(1, -4, 0, 20)
                btn.BackgroundColor3 = Color3.fromRGB(50,50,50)
                btn.TextColor3 = Color3.new(1,1,1)
                btn.TextXAlignment = Enum.TextXAlignment.Left
                btn.Parent = navFrame
                btn.MouseButton1Click:Connect(function()
                    local targetName = option:match(": (.+)$")
                    if targetName then
                        refreshBranchDropdown(targetName)
                    end
                    navFrame:Destroy()
                end)
            end
            
            -- Auto-close after 5 seconds
            task.delay(5, function()
                if navFrame.Parent then
                    navFrame:Destroy()
                end
            end)
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

        print("[UI] ApplyToTrunk", trunk)

        if LoomDesigner.EditBranch then
            LoomDesigner.EditBranch(trunk, design)
        end

        if LoomDesigner.ApplyAuthoringAndPreview then
            LoomDesigner.ApplyAuthoringAndPreview(nil)
        end
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

    -- seed controls
    local seedBox
    seedBox = numberField(container, "Base Seed", LoomDesigner.GetSeed and LoomDesigner.GetSeed(), function(v)
        ensureStart()
        if LoomDesigner.SetSeed then
            LoomDesigner.SetSeed(v)
            LoomDesigner.RebuildPreview()
        end
    end)

    local reseedBtn = Instance.new("TextButton")
    reseedBtn.Text = "Randomize Seed"
    reseedBtn.Size = UDim2.new(0,160,0,24)
    reseedBtn.BackgroundColor3 = Color3.fromRGB(48,48,48)
    reseedBtn.TextColor3 = Color3.new(1,1,1)
    reseedBtn.Parent = container
    reseedBtn.MouseButton1Click:Connect(function()
        ensureStart()
        if LoomDesigner.Reseed then
            local s = LoomDesigner.Reseed()
            if seedBox then seedBox.Text = tostring(s) end
        end
    end)

    -- Advanced Rotation Controls Section
    local rotationSection = Instance.new("Frame")
    rotationSection.BackgroundTransparency = 1
    rotationSection.Size = UDim2.new(1,0,0,0)
    rotationSection.AutomaticSize = Enum.AutomaticSize.Y
    rotationSection.Parent = container
    
    local rotationHeader = Instance.new("TextLabel")
    rotationHeader.Text = "--- Rotation Rules ---"
    rotationHeader.BackgroundTransparency = 1
    rotationHeader.TextColor3 = Color3.fromRGB(255,255,0)
    rotationHeader.Size = UDim2.new(1,0,0,24)
    rotationHeader.TextXAlignment = Enum.TextXAlignment.Center
    rotationHeader.Parent = rotationSection
    
    local rotFrame = makeList(rotationSection)
    
    local state = LoomDesigner.GetState and LoomDesigner.GetState() or {}
    local rot = state.overrides and state.overrides.rotationRules or {}
    
    local contOpts = {"auto","accumulate","absolute"}
    local contIndex = 1
    if rot.continuity == "accumulate" then contIndex = 2
    elseif rot.continuity == "absolute" then contIndex = 3 end
    
    labeledDropdown(rotFrame, popupHost, "Continuity", contOpts, contIndex, function(opt)
        ensureStart()
        local mode = opt == "auto" and nil or opt
        LoomDesigner.SetOverrides({rotationRules = {continuity = mode}})
        LoomDesigner.RebuildPreview()
    end)
    
    numberField(rotFrame, "Yaw Clamp Deg", rot.yawClampDeg or 22, function(v)
        ensureStart()
        LoomDesigner.SetOverrides({rotationRules = {yawClampDeg = v}})
        LoomDesigner.RebuildPreview()
    end)
    
    numberField(rotFrame, "Pitch Clamp Deg", rot.pitchClampDeg or 10, function(v)
        ensureStart()
        LoomDesigner.SetOverrides({rotationRules = {pitchClampDeg = v}})
        LoomDesigner.RebuildPreview()
    end)
    
    -- Micro-jitter controls
    local jitterEnabled = rot.enableMicroJitter == true
    labeledDropdown(rotFrame, popupHost, "Enable Micro Jitter", {"No", "Yes"}, jitterEnabled and 2 or 1, function(opt)
        ensureStart()
        LoomDesigner.SetOverrides({rotationRules = {enableMicroJitter = opt == "Yes"}})
        LoomDesigner.RebuildPreview()
    end)
    
    numberField(rotFrame, "Micro Jitter Deg", rot.microJitterDeg or 0, function(v)
        ensureStart()
        LoomDesigner.SetOverrides({rotationRules = {microJitterDeg = v}})
        LoomDesigner.RebuildPreview()
    end)
    
    -- Twist controls
    local twistEnabled = rot.enableTwist ~= false
    labeledDropdown(rotFrame, popupHost, "Enable Twist", {"No", "Yes"}, twistEnabled and 2 or 1, function(opt)
        ensureStart()
        LoomDesigner.SetOverrides({rotationRules = {enableTwist = opt == "Yes"}})
        LoomDesigner.RebuildPreview()
    end)
    
    numberField(rotFrame, "Twist Strength Deg/Seg", rot.twistStrengthDegPerSeg or 0, function(v)
        ensureStart()
        LoomDesigner.SetOverrides({rotationRules = {twistStrengthDegPerSeg = v}})
        LoomDesigner.RebuildPreview()
    end)
    
    numberField(rotFrame, "Twist RNG Range Deg", rot.twistRngRangeDeg or 0, function(v)
        ensureStart()
        LoomDesigner.SetOverrides({rotationRules = {twistRngRangeDeg = v}})
        LoomDesigner.RebuildPreview()
    end)

    -- Model Management Section
    local modelSection = Instance.new("Frame")
    modelSection.BackgroundTransparency = 1
    modelSection.Size = UDim2.new(1,0,0,0)
    modelSection.AutomaticSize = Enum.AutomaticSize.Y
    modelSection.Parent = container
    
    local modelHeader = Instance.new("TextLabel")
    modelHeader.Text = "--- Model Library ---"
    modelHeader.BackgroundTransparency = 1
    modelHeader.TextColor3 = Color3.fromRGB(0,255,255)
    modelHeader.Size = UDim2.new(1,0,0,24)
    modelHeader.TextXAlignment = Enum.TextXAlignment.Center
    modelHeader.Parent = modelSection

    local modelFrame = makeList(modelSection)
    
    -- Available models in ReplicatedStorage
    local availableModels = {"BasicBranch", "LeafyBranch", "BarkSegment", "TwigSegment"}  -- Default examples
    
    local function getAvailableModels()
        local models = {}
        local RS = game:GetService("ReplicatedStorage")
        local modelsFolder = RS:FindFirstChild("models") or RS:FindFirstChild("Models")
        if modelsFolder then
            for _, model in ipairs(modelsFolder:GetChildren()) do
                table.insert(models, model.Name)
            end
        end
        return #models > 0 and models or availableModels
    end
    
    local depthInput = numberField(modelFrame, "Model Depth", 0, function() end)
    
    local modelDropdown = nil
    local function refreshModelDropdown()
        if modelDropdown then modelDropdown.Parent:Destroy() end
        local models = getAvailableModels()
        modelDropdown = labeledDropdown(modelFrame, popupHost, "Model Name", models, 1, function(opt)
            -- Model selected
        end)
    end
    refreshModelDropdown()
    
    local modelBtn = Instance.new("TextButton")
    modelBtn.Text = "Add Model to Depth"
    modelBtn.Size = UDim2.new(0,180,0,24)
    modelBtn.BackgroundColor3 = Color3.fromRGB(48,48,48)
    modelBtn.TextColor3 = Color3.new(1,1,1)
    modelBtn.Parent = modelFrame

    local modelList = Instance.new("TextLabel")
    modelList.BackgroundTransparency = 1
    modelList.TextColor3 = Color3.fromRGB(200,200,200)
    modelList.Size = UDim2.new(1,0,0,0)
    modelList.AutomaticSize = Enum.AutomaticSize.Y
    modelList.TextXAlignment = Enum.TextXAlignment.Left
    modelList.TextYAlignment = Enum.TextYAlignment.Top
    modelList.Text = "Model assignments:\n[0] Default segments\n[1] Secondary branches\n[terminal] End caps"
    modelList.Parent = modelFrame

    local function refreshModels()
        local models = LoomDesigner.GetModels and LoomDesigner.GetModels() or {}
        local lines = {"Model assignments:"}
        if next(models) then
            for depth, list in pairs(models) do
                lines[#lines+1] = string.format("[%s] %s", tostring(depth), table.concat(list, ", "))
            end
        else
            lines[#lines+1] = "[0] Default segments"
            lines[#lines+1] = "[1] Secondary branches" 
            lines[#lines+1] = "[terminal] End caps"
        end
        modelList.Text = table.concat(lines, "\n")
    end
    refreshModels()

    modelBtn.MouseButton1Click:Connect(function()
        ensureStart()
        local depth = tonumber(depthInput.Text) or 0
        local models = getAvailableModels()
        local selectedModel = models[1]  -- Default to first model
        if modelDropdown and modelDropdown.Text and modelDropdown.Text ~= "Select" then
            selectedModel = modelDropdown.Text
        end
        if LoomDesigner.AddModel and selectedModel then
            LoomDesigner.AddModel(depth, selectedModel)
            refreshModels()
            LoomDesigner.RebuildPreview()
        end
    end)

    -- Initial setup after all functions are defined
    createKindDropdown()
    refreshBranchDropdown()
    renderFields()
    GrowthStylesCore.ApplyPreview()

end

return UI
