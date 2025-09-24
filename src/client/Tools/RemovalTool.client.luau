--!strict
-- RemovalTool.client.luau: Client-side removal tool with highlighting and confirmation
-- Provides hover highlighting and safe removal confirmation for ponds and lanterns
-- Activated by Delete key, no longer requires Tool instance

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Net = RS:WaitForChild("Net", 5)
local Remotes = Net and Net:FindFirstChild("Remotes")
local RF_RemovePond: RemoteFunction? = Remotes and Remotes:FindFirstChild("RF_RemovePond")
local RF_CanRemovePond: RemoteFunction? = Remotes and Remotes:FindFirstChild("RF_CanRemovePond")
local RF_RemoveLantern: RemoteFunction? = Remotes and Remotes:FindFirstChild("RF_RemoveLantern")

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

-- Tool state
local RemovalTool = {}
local isActive = false
local currentMode = "pond"  -- "pond" or "lantern"
local hoveredObject: Instance? = nil
local hoveredId: string? = nil
local hoveredType: string? = nil
local highlightObjects: { Instance } = {}  -- Multiple highlights for model highlighting
local isMouse1Down = false

-- Track plot center and default pond id to avoid highlighting default pond
local plotCenter: Vector3? = nil
local defaultPondId: string? = nil

local function tryUpdatePlotCenter()
    local ok, NetApi = pcall(function() return require(RS.Shared.Net) end)
    if not ok then return end
    local ev = NetApi:GetEvent("RE_BaseAssigned")
    ev.OnClientEvent:Connect(function(assignment)
        if assignment and typeof(assignment) == "table" and typeof(assignment.origin) == "CFrame" then
            plotCenter = assignment.origin.Position
        end
    end)
end

task.spawn(tryUpdatePlotCenter)

local function computeDefaultPondIdIfNeeded()
    if defaultPondId then return end
    local center = plotCenter or Vector3.new(0,0,0)
    local cfg = require(RS.Config.WorldConfig)
    local expectedR = (cfg.ISLANDS and cfg.ISLANDS.Pond and cfg.ISLANDS.Pond.Radius) or 15
    local NetClient = _G.PondNetworkClient or { snapshot = { ponds = {} } }
    local bestId: string? = nil
    local bestDist = math.huge
    for id, pond in pairs(NetClient.snapshot.ponds or {}) do
        local d = (pond.pos - Vector2.new(center.X, center.Z)).Magnitude
        if math.abs((pond.radius or 0) - expectedR) <= (expectedR * 0.2) and d < bestDist then
            bestDist = d; bestId = id
        end
    end
    defaultPondId = bestId
end

-- Confirmation UI state
local confirmationGui: ScreenGui? = nil
local confirmationTarget: { id: string, type: string }? = nil
local confirmationStartTime = 0
local CONFIRMATION_HOLD_TIME = 1.0  -- Hold time in seconds

-- Connection storage for cleanup
local inputConnections: { RBXScriptConnection } = {}
local heartbeatConnection: RBXScriptConnection? = nil

-- Create highlight effect for hovered objects
local function createHighlight(target: Instance): Instance?
    if not target or not target:IsA("BasePart") then return nil end
    
    -- Create a highlight object
    local highlight = Instance.new("Highlight")
    highlight.Adornee = target
    highlight.FillColor = Color3.fromRGB(255, 100, 100)  -- Red tint
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)  -- White outline
    highlight.FillTransparency = 0.3
    highlight.OutlineTransparency = 0.1
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = target
    
    -- Add a pulsing animation
    local tween = TweenService:Create(highlight, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
        FillTransparency = 0.6,
        OutlineTransparency = 0.3
    })
    tween:Play()
    
    return highlight
end

-- Create flat red material overlay (alternative highlighting method)
local function createFlatOverlay(target: Instance): Instance?
    if not target or not target:IsA("BasePart") then return nil end
    
    -- Store original properties
    local originalMaterial = target.Material
    local originalColor = target.Color
    local originalTransparency = target.Transparency
    
    -- Apply red flat overlay
    target.Material = Enum.Material.Neon
    target.Color = Color3.fromRGB(255, 50, 50)
    target.Transparency = 0.2
    
    -- Create a cleanup function stored in the target
    target:SetAttribute("OverlayCleanup", true)
    target:SetAttribute("OriginalMaterial", originalMaterial.Name)
    target:SetAttribute("OriginalColor", string.format("%.3f,%.3f,%.3f", originalColor.R, originalColor.G, originalColor.B))
    target:SetAttribute("OriginalTransparency", originalTransparency)
    
    return target
end

-- Find the entire model that should be highlighted for a given target
local function findModelToHighlight(target: Instance, targetType: string): Instance?
    if not target then return nil end
    
    if targetType == "pond" then
        -- For ponds, try to find the entire rim folder or model
        local parent = target.Parent
        while parent and parent ~= workspace do
            if parent.Parent and parent.Parent.Name == "PondRims" then
                return parent  -- Return the pond folder containing all rim parts
            end
            parent = parent.Parent
        end
        return target  -- Fallback to the individual part
    elseif targetType == "lantern" then
        -- For lanterns, find the Model that contains this part
        if CS:HasTag(target, "Lantern") then
            return target  -- Target is the main lantern
        end
        
        local parent = target.Parent
        if parent and CS:HasTag(parent, "Lantern") then
            return parent  -- Parent is the lantern model
        end
        
        -- Search upward for a Model with lantern characteristics
        while parent and parent ~= workspace do
            if parent:IsA("Model") and (parent.Name:find("Lantern") or CS:HasTag(parent, "Lantern")) then
                return parent
            end
            parent = parent.Parent
        end
        
        return target  -- Fallback to individual part
    end
    
    return target
end

-- Create simple red highlight for pond removal
local function createPondHighlight(pondId: string): { Instance }
    local highlights = {}
    -- Find and highlight rim parts with Highlight adorners (no color mutation)
    local pondRims = workspace:FindFirstChild("PondRims")
    if pondRims then
        local rimFolder = pondRims:FindFirstChild(pondId)
        if rimFolder then
            for _, child in ipairs(rimFolder:GetDescendants()) do
                if child:IsA("BasePart") then
                    local hl = Instance.new("Highlight")
                    hl.Adornee = child
                    hl.FillColor = Color3.fromRGB(255, 0, 0)
                    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                    hl.FillTransparency = 0.6
                    hl.OutlineTransparency = 0.1
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.Parent = child
                    table.insert(highlights, hl)
                end
            end
        end
    end
    return highlights
end

-- Remove pond highlight adorners and restore any previous tints (defensive)
local function removePondHighlight(highlights: { Instance })
    for _, inst in ipairs(highlights) do
        if inst and inst.Parent then
            inst:Destroy()
        end
    end
    -- Defensive cleanup in case any parts were tinted by older code
    local pondRims = workspace:FindFirstChild("PondRims")
    if pondRims then
        for _, part in ipairs(pondRims:GetDescendants()) do
            if part:IsA("BasePart") and part:GetAttribute("OriginalColor_Removal") then
                local colorStr = part:GetAttribute("OriginalColor_Removal")
                local r, g, b = colorStr:match("([%d%.]+),([%d%.]+),([%d%.]+)")
                if r and g and b then
                    part.Color = Color3.new(tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0)
                end
                part:SetAttribute("OriginalColor_Removal", nil)
            end
        end
    end
end

-- Remove highlight/overlay (DEFINED BEFORE removeModelHighlights!)
local function removeHighlight(target: Instance?)
    if not target then return end
    
    -- If it's a Highlight object itself, destroy it
    if target:IsA("Highlight") then
        target:Destroy()
        return
    end
    
    -- Remove any Highlight children
    for _, child in ipairs(target:GetChildren()) do
        if child:IsA("Highlight") then
            child:Destroy()
        end
    end
    
    -- Restore flat overlay if it was applied
    if target:IsA("BasePart") and target:GetAttribute("OverlayCleanup") then
        local matName = target:GetAttribute("OriginalMaterial")
        local colorStr = target:GetAttribute("OriginalColor")
        local transparency = target:GetAttribute("OriginalTransparency")
        
        if matName then
            local ok, mat = pcall(function() return Enum.Material[matName] end)
            if ok and mat then target.Material = mat end
        end
        
        if colorStr then
            local r, g, b = colorStr:match("([%d%.]+),([%d%.]+),([%d%.]+)")
            if r and g and b then
                target.Color = Color3.new(tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0)
            end
        end
        
        if transparency then
            target.Transparency = transparency
        end
        
        -- Clear attributes
        target:SetAttribute("OverlayCleanup", nil)
        target:SetAttribute("OriginalMaterial", nil)
        target:SetAttribute("OriginalColor", nil)
        target:SetAttribute("OriginalTransparency", nil)
    end
end

-- Create comprehensive highlight for entire models (for lanterns)
local function createModelHighlight(modelOrFolder: Instance): { Instance }
    local highlights = {}
    
    if modelOrFolder:IsA("Model") then
        -- Highlight all parts in the model (lantern)
        for _, child in ipairs(modelOrFolder:GetDescendants()) do
            if child:IsA("BasePart") then
                local highlight = createHighlight(child)
                if highlight then
                    table.insert(highlights, highlight)
                end
            end
        end
    elseif modelOrFolder:IsA("BasePart") then
        -- Single part fallback
        local highlight = createFlatOverlay(modelOrFolder)
        if highlight then
            table.insert(highlights, highlight)
        end
    end
    
    return highlights
end

-- Remove highlights from multiple objects
local function removeModelHighlights(highlights: { Instance })
    for _, highlight in ipairs(highlights) do
        removeHighlight(highlight)
    end
end

-- Get pond ID from raycast target - more aggressive detection
local function getPondIdFromTarget(target: Instance): string?
    if not target then return nil end
    
    -- Check direct attribute
    local pondId = target:GetAttribute("pondId")
    if pondId then
        computeDefaultPondIdIfNeeded()
        if defaultPondId and pondId == defaultPondId then return nil end
        return pondId
    end
    
    -- Check if it's a pond rim stone
    if target.Name == "RimStone" then
        local parent = target.Parent
        while parent and parent ~= workspace do
            if parent.Parent and parent.Parent.Name == "PondRims" then
                computeDefaultPondIdIfNeeded()
                if defaultPondId and parent.Name == defaultPondId then return nil end
                return parent.Name  -- Folder name is pond ID
            end
            parent = parent.Parent
        end
    end
    
    -- Check parent structure (PondRims/pondId/parts)
    local parent = target.Parent
    while parent and parent ~= workspace do
        if parent.Parent and parent.Parent.Name == "PondRims" then
            computeDefaultPondIdIfNeeded()
            if defaultPondId and parent.Name == defaultPondId then return nil end
            return parent.Name  -- Folder name is pond ID
        end
        parent = parent.Parent
    end
    
    return nil
end

-- Get lantern ID from raycast target (IMPROVED detection)
local function getLanternIdFromTarget(target: Instance): string?
    if not target then return nil end
    
    -- Check if it's tagged as a lantern directly
    if CS:HasTag(target, "Lantern") then
        local id = target:GetAttribute("lanternId") or target:GetAttribute("LanternId") or target.Name
        if id and id ~= "Workspace" and id ~= "" then
            return id
        end
    end
    
    -- Check parent if target is part of a lantern model
    local parent = target.Parent
    if parent and CS:HasTag(parent, "Lantern") then
        local id = parent:GetAttribute("lanternId") or parent:GetAttribute("LanternId") or parent.Name
        if id and id ~= "Workspace" and id ~= "" then
            return id
        end
    end
    
    -- Check if it's a lantern part by walking up the hierarchy
    local current = target
    while current and current ~= workspace do
        if current:IsA("Model") and CS:HasTag(current, "Lantern") then
            local id = current:GetAttribute("lanternId") or current:GetAttribute("LanternId") or current.Name
            if id and id ~= "Workspace" and id ~= "" and id ~= "Model" then
                return id
            end
        end
        
        -- Check for lantern-like naming patterns
        if current:IsA("Model") and current.Name and current.Name:find("lan") then
            local id = current:GetAttribute("lanternId") or current:GetAttribute("LanternId") or current.Name
            if id and id ~= "Workspace" and id ~= "" then
                return id
            end
        end
        
        current = current.Parent
    end
    
    return nil
end

-- Create confirmation UI (IMPROVED with better hierarchy)
local function createConfirmationUI(): ScreenGui
    local gui = Instance.new("ScreenGui")
    gui.Name = "RemovalConfirmation"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = Player:WaitForChild("PlayerGui")
    
    -- Background frame
    local frame = Instance.new("Frame")
    frame.Name = "Frame"
    frame.Size = UDim2.new(0, 220, 0, 90)
    frame.Position = UDim2.new(0.5, -110, 0.5, -45)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 2
    frame.BorderColor3 = Color3.fromRGB(255, 100, 100)
    frame.Parent = gui
    
    -- Add UICorner for modern look
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    -- Label
    local label = Instance.new("TextLabel")
    label.Name = "TextLabel"
    label.Size = UDim2.new(1, -20, 0, 30)
    label.Position = UDim2.new(0, 10, 0, 5)
    label.BackgroundTransparency = 1
    label.Text = "Hold to Remove"
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = frame
    
    -- Progress bar background
    local progressBg = Instance.new("Frame")
    progressBg.Name = "Frame"  -- This is what the update function looks for
    progressBg.Size = UDim2.new(1, -20, 0, 10)
    progressBg.Position = UDim2.new(0, 10, 0, 45)
    progressBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    progressBg.BorderSizePixel = 1
    progressBg.BorderColor3 = Color3.fromRGB(80, 80, 80)
    progressBg.Parent = frame
    
    -- Progress bar corner
    local progressCorner = Instance.new("UICorner")
    progressCorner.CornerRadius = UDim.new(0, 4)
    progressCorner.Parent = progressBg
    
    -- Progress bar fill
    local progressFill = Instance.new("Frame")
    progressFill.Name = "ProgressFill"
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.Position = UDim2.new(0, 0, 0, 0)
    progressFill.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
    progressFill.BorderSizePixel = 0
    progressFill.Parent = progressBg
    
    -- Progress fill corner
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 4)
    fillCorner.Parent = progressFill
    
    -- Instruction label
    local instruction = Instance.new("TextLabel")
    instruction.Size = UDim2.new(1, -20, 0, 20)
    instruction.Position = UDim2.new(0, 10, 1, -30)
    instruction.BackgroundTransparency = 1
    instruction.Text = "Release to cancel"
    instruction.TextColor3 = Color3.fromRGB(180, 180, 180)
    instruction.TextScaled = true
    instruction.Font = Enum.Font.Gotham
    instruction.Parent = frame
    
    print("[RemovalTool] Created confirmation UI with improved hierarchy")
    return gui
end

-- Update confirmation progress (FIXED for better reliability and nil safety)
local function updateConfirmationProgress()
    if not confirmationGui or not confirmationTarget then 
        return
    end
    
    -- Verify confirmationTarget has required fields
    if type(confirmationTarget) ~= "table" or not confirmationTarget.id or not confirmationTarget.type then
        warn("[RemovalTool] Invalid confirmationTarget:", confirmationTarget)
        hideConfirmation()
        return
    end
    
    local frame = confirmationGui:FindFirstChild("Frame")
    if not frame then 
        warn("[RemovalTool] Frame not found in confirmation GUI")
        hideConfirmation()
        return 
    end
    
    local progressBg = frame:FindFirstChild("Frame")  -- Progress background
    local progressFill = progressBg and progressBg:FindFirstChild("ProgressFill")
    if not progressFill then 
        warn("[RemovalTool] ProgressFill not found in confirmation GUI")
        hideConfirmation()
        return 
    end
    
    local elapsed = os.clock() - confirmationStartTime
    local progress = math.clamp(elapsed / CONFIRMATION_HOLD_TIME, 0, 1)
    
    -- Update progress fill size immediately (no tween for smooth progress)
    progressFill.Size = UDim2.new(progress, 0, 1, 0)
    
    -- Update label to show progress percentage
    local label = frame:FindFirstChild("TextLabel")
    if label then
        label.Text = string.format("Removing %s... %.0f%%", confirmationTarget.type, progress * 100)
    end
    
    if progress >= 1 then
        -- Confirmation complete - execute removal
        RemovalTool.executeRemoval()
    end
end

-- Hide confirmation UI  
local function hideConfirmation()
    if confirmationGui then
        confirmationGui:Destroy()
        confirmationGui = nil
    end
    confirmationTarget = nil
end

-- Show confirmation UI (ENHANCED with better target validation)
local function showConfirmation(targetId: string, targetType: string)
    hideConfirmation()
    
    -- Validate inputs
    if not targetId or targetId == "" or targetId == "Workspace" then
        warn("[RemovalTool] Invalid targetId for confirmation:", targetId)
        return
    end
    
    if not targetType or targetType == "" then
        warn("[RemovalTool] Invalid targetType for confirmation:", targetType)
        return
    end
    
    confirmationTarget = { id = targetId, type = targetType }
    confirmationStartTime = os.clock()
    confirmationGui = createConfirmationUI()
    
    local label = confirmationGui:FindFirstChild("Frame", true) and 
                  confirmationGui.Frame:FindFirstChild("TextLabel")
    if label then
        label.Text = string.format("Remove %s?", targetType:gsub("^%l", string.upper))
    end
    
    print(string.format("[RemovalTool] Showing confirmation for %s: %s", targetType, targetId))
end

-- Handle mouse movement for highlighting
local function handleMouseMove()
    if not isActive then return end
    
    local target = Mouse.Target
    local hit = Mouse.Hit  -- Get mouse world position
    local newId: string? = nil
    local newType: string? = nil
    
    if currentMode == "pond" then
        newId = getPondIdFromTarget(target)
        
        -- If we didn't find a pond from the target, check if mouse is in pond area
        if not newId and hit then
            local mousePos = Vector2.new(hit.Position.X, hit.Position.Z)
            local NetClient = _G.PondNetworkClient or { snapshot = { ponds = {} } }
            if NetClient.snapshot and NetClient.snapshot.ponds then
                for pondId, pond in pairs(NetClient.snapshot.ponds) do
                    local dist = (mousePos - pond.pos).Magnitude
                    if dist <= pond.radius + 5 then  -- 5 stud buffer for easier targeting
                        computeDefaultPondIdIfNeeded()
                        if not (defaultPondId and pondId == defaultPondId) then
                            newId = pondId
                            break
                        end
                    end
                end
            end
        end
        newType = "pond"
    elseif currentMode == "lantern" then
        newId = getLanternIdFromTarget(target)
        newType = "lantern"
    end
    
    -- Update highlighting if target changed
    if newId ~= hoveredId or target ~= hoveredObject then
        -- Remove old highlights
        if #highlightObjects > 0 then
            if currentMode == "pond" then
                removePondHighlight(highlightObjects)
            else
                removeModelHighlights(highlightObjects)
            end
            highlightObjects = {}
        end
        
        -- Set new hover state
        hoveredObject = target
        hoveredId = newId
        hoveredType = newType
        
        -- Add new highlights
        if hoveredId then
            if currentMode == "pond" then
                highlightObjects = createPondHighlight(hoveredId)
            else
                -- For lanterns, find the model and highlight it
                local modelToHighlight = findModelToHighlight(hoveredObject, newType or "")
                if modelToHighlight then
                    highlightObjects = createModelHighlight(modelToHighlight)
                end
            end
            
            -- Update mouse cursor
            Mouse.Icon = "rbxasset://textures/Cursors/DragDetector/HoverCursor.png"
        else
            Mouse.Icon = ""
        end
    end
end

-- Execute the actual removal (ENHANCED with better error handling)
function RemovalTool.executeRemoval()
    if not confirmationTarget or type(confirmationTarget) ~= "table" then
        warn("[RemovalTool] executeRemoval called with invalid confirmationTarget:", confirmationTarget)
        hideConfirmation()
        return
    end
    
    local targetId = confirmationTarget.id
    local targetType = confirmationTarget.type
    
    -- Validate target data
    if not targetId or targetId == "" or not targetType or targetType == "" then
        warn("[RemovalTool] executeRemoval called with invalid target data:", targetId, targetType)
        hideConfirmation()
        return
    end
    
    print(string.format("[RemovalTool] Executing removal for %s: %s", targetType, targetId))
    
    hideConfirmation()
    
    -- Call appropriate removal remote
    if targetType == "pond" and RF_RemovePond then
        local ok, success, reason = pcall(function()
            return RF_RemovePond:InvokeServer(targetId)
        end)
        
        if ok and success then
            print(string.format("[RemovalTool] Successfully removed pond: %s", targetId))
        else
            warn(string.format("[RemovalTool] Failed to remove pond: %s (%s)", targetId, reason or "unknown"))
        end
    elseif targetType == "lantern" and RF_RemoveLantern then
        local ok, success, reason = pcall(function()
            return RF_RemoveLantern:InvokeServer(targetId)
        end)
        
        if ok and success then
            print(string.format("[RemovalTool] Successfully removed lantern: %s", targetId))
        else
            warn(string.format("[RemovalTool] Failed to remove lantern: %s (%s)", targetId, reason or "unknown"))
        end
    else
        warn(string.format("[RemovalTool] Unknown target type or missing remote: %s", targetType))
    end
    
    -- Clear highlighting
    if #highlightObjects > 0 then
        if targetType == "pond" then
            removePondHighlight(highlightObjects)
        else
            removeModelHighlights(highlightObjects)
        end
        highlightObjects = {}
    end
    hoveredObject = nil
    hoveredId = nil
    hoveredType = nil
end

-- Handle mouse input (ENHANCED with better state management)
local function handleInput(input: InputObject, gameProcessed: boolean)
    if gameProcessed or not isActive then return end
    
    -- Only handle input if we're actually hovering over a valid target
    -- This prevents interference with placement when removal tool is active but not targeting anything
    if not (hoveredId and hoveredType) then return end
    
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if input.UserInputState == Enum.UserInputState.Begin then
            -- Preflight check before showing confirmation (ponds only)
            if hoveredId and hoveredType then
                if hoveredType == "pond" and RF_CanRemovePond then
                    local ok, canRemove, reason = pcall(function()
                        return RF_CanRemovePond:InvokeServer(hoveredId)
                    end)
                    if not ok or not canRemove then
                        warn(string.format("[RemovalTool] Cannot remove pond %s: %s", hoveredId, reason or "blocked"))
                        return
                    end
                end
                print(string.format("[RemovalTool] Starting removal confirmation for %s: %s", hoveredType, hoveredId))
                showConfirmation(hoveredId, hoveredType)
            end
        elseif input.UserInputState == Enum.UserInputState.End then
            -- Cancel confirmation
            if confirmationGui then
                print("[RemovalTool] Canceling removal confirmation")
            end
            hideConfirmation()
        end
    end
end

-- Activate removal tool
function RemovalTool.activate(mode: string?)
    if isActive then return end
    
    isActive = true
    currentMode = mode or "pond"
    Mouse.Icon = ""
    
    -- Connect input handlers and store connections for cleanup
    table.insert(inputConnections, UIS.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isMouse1Down = true
        end
        handleInput(input, gpe)
    end))
    table.insert(inputConnections, UIS.InputEnded:Connect(function(input, gpe)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isMouse1Down = false
        end
        handleInput(input, gpe)
    end))
    table.insert(inputConnections, Mouse.Move:Connect(handleMouseMove))
    
    -- Start heartbeat connection for confirmation progress (IMPROVED with error handling)
    heartbeatConnection = RunService.Heartbeat:Connect(function()
        if confirmationGui and confirmationTarget then
            -- Cancel if cursor leaves the target or mouse is released
            if not isMouse1Down or not hoveredId or hoveredId ~= confirmationTarget.id then
                hideConfirmation()
                return
            end
            local ok, err = pcall(updateConfirmationProgress)
            if not ok then
                warn("[RemovalTool] Error updating confirmation progress:", err)
                hideConfirmation()  -- Clean up on error
            end
        end
    end)
    
    print(string.format("[RemovalTool] Activated in %s mode (R to toggle mode, Delete to deactivate)", currentMode))
end

-- Deactivate removal tool
function RemovalTool.deactivate()
    if not isActive then return end
    
    isActive = false
    hideConfirmation()
    
    -- Clean up all connections
    for _, connection in ipairs(inputConnections) do
        if connection.Connected then
            connection:Disconnect()
        end
    end
    inputConnections = {}
    
    if heartbeatConnection and heartbeatConnection.Connected then
        heartbeatConnection:Disconnect()
        heartbeatConnection = nil
    end
    
    -- Clean up highlighting
    if #highlightObjects > 0 then
        if currentMode == "pond" then
            removePondHighlight(highlightObjects)
        else
            removeModelHighlights(highlightObjects)
        end
        highlightObjects = {}
    end
    
    hoveredObject = nil
    hoveredId = nil
    hoveredType = nil
    Mouse.Icon = ""
    
    print("[RemovalTool] Deactivated")
end

-- Toggle between pond and lantern modes
function RemovalTool.toggleMode()
    if not isActive then return end
    
    -- Clear current highlighting when switching modes (use old mode for cleanup)
    if #highlightObjects > 0 then
        if currentMode == "pond" then
            removePondHighlight(highlightObjects)
        else
            removeModelHighlights(highlightObjects)
        end
        highlightObjects = {}
    end
    
    -- Switch to new mode
    currentMode = (currentMode == "pond") and "lantern" or "pond"
    
    hoveredObject = nil
    hoveredId = nil
    hoveredType = nil
    
    print(string.format("[RemovalTool] Switched to %s mode", currentMode))
end

-- Tool-based activation: Watch for removal tool being equipped/unequipped
local function checkForRemovalTool()
    local char = Player and Player.Character
    if char then
        for _, inst in ipairs(char:GetChildren()) do
            if inst:IsA("Tool") then
                local itemId = inst:GetAttribute("ItemId")
                if itemId == "removal_tool" then
                    -- Removal tool equipped - activate removal mode
                    if not isActive then
                        RemovalTool.activate("pond")  -- Default to pond mode
                    end
                    return true
                end
            end
        end
    end
    
    -- No removal tool equipped - deactivate if active
    if isActive then
        RemovalTool.deactivate()
    end
    return false
end

-- Watch for tool changes
if Player.Character then
    Player.Character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") and child:GetAttribute("ItemId") == "removal_tool" then
            RemovalTool.activate("pond")
        end
    end)
    
    Player.Character.ChildRemoved:Connect(function(child)
        if child:IsA("Tool") and child:GetAttribute("ItemId") == "removal_tool" then
            RemovalTool.deactivate()
        end
    end)
end

Player.CharacterAdded:Connect(function(character)
    -- Re-setup tool watching for new character
    character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") and child:GetAttribute("ItemId") == "removal_tool" then
            RemovalTool.activate("pond")
        end
    end)
    
    character.ChildRemoved:Connect(function(child)
        if child:IsA("Tool") and child:GetAttribute("ItemId") == "removal_tool" then
            RemovalTool.deactivate()
        end
    end)
end)

-- Key bindings - Only for mode switching when removal tool is active
UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- R key to toggle between pond/lantern while removal tool is active
    if input.KeyCode == Enum.KeyCode.R and isActive then
        RemovalTool.toggleMode()
    end
    
    -- Dev fallback: Delete key ONLY works in Studio and when no tools are equipped
    if input.KeyCode == Enum.KeyCode.Delete and RunService:IsStudio() then
        local hasAnyTool = false
        local char = Player and Player.Character
        if char then
            for _, inst in ipairs(char:GetChildren()) do
                if inst:IsA("Tool") then
                    hasAnyTool = true
                    break
                end
            end
        end
        
        -- Only allow Delete key if no tools are equipped (pure dev mode)
        if not hasAnyTool then
            if isActive then
                RemovalTool.deactivate()
            else
                RemovalTool.activate("pond")
            end
        end
    end
end)

-- Handle character respawn cleanup
Player.CharacterAdded:Connect(function()
    if isActive then
        RemovalTool.deactivate()
    end
end)

print("[RemovalTool] Loaded - Delete key to toggle, R to switch mode while active")

return RemovalTool
