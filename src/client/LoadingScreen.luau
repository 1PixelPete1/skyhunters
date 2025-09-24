-- LoadingScreen.client.luau
-- Professional loading screen with progress bar and animations

local Players = Players or game:GetService("Players")
local TweenService = TweenService or game:GetService("TweenService")
local RunService = RunService or game:GetService("RunService")
local ReplicatedStorage = ReplicatedStorage or game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Progress remote discovery with late-binding (handles remotes created after client start)
local progressRemote: any = nil
local progressConn: RBXScriptConnection? = nil
local readySent = false
local function findProgressRemote(): any
    local net = ReplicatedStorage:FindFirstChild("Net")
    local remotes = net and net:FindFirstChild("Remotes")
    local re = remotes and remotes:FindFirstChild("RE_LoadingProgress")
    if re then return re end
    local legacy = ReplicatedStorage:FindFirstChild("Remotes")
    local legacyRe = legacy and legacy:FindFirstChild("LoadingProgressRemote")
    return legacyRe
end

local LoadingScreen = {}

-- UI Configuration
local UI_CONFIG = {
    backgroundColor = Color3.fromRGB(15, 15, 20),
    accentColor = Color3.fromRGB(70, 130, 180),
    textColor = Color3.new(1, 1, 1),
    progressBarHeight = 8,
    animationSpeed = 0.5,
    pulseSpeed = 2,
}

-- Create loading UI
local function createLoadingUI()
    -- Main screen GUI
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LoadingScreen"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset = true
    screenGui.ResetOnSpawn = false
    screenGui.DisplayOrder = 1000
    screenGui.Parent = playerGui
    
    -- Background overlay
    local background = Instance.new("Frame")
    background.Name = "Background"
    background.Size = UDim2.new(1, 0, 1, 0)
    background.BackgroundColor3 = UI_CONFIG.backgroundColor
    background.BorderSizePixel = 0
    background.Parent = screenGui
    
    -- Main container
    local container = Instance.new("Frame")
    container.Name = "Container"
    container.Size = UDim2.new(0, 400, 0, 200)
    container.Position = UDim2.new(0.5, -200, 0.5, -100)
    container.BackgroundTransparency = 1
    container.Parent = background
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "QuietWinds"
    title.TextColor3 = UI_CONFIG.textColor
    title.TextScaled = true
    title.Font = Enum.Font.SourceSansBold
    title.Parent = container
    
    -- Subtitle
    local subtitle = Instance.new("TextLabel")
    subtitle.Name = "Subtitle"
    subtitle.Size = UDim2.new(1, 0, 0, 25)
    subtitle.Position = UDim2.new(0, 0, 0, 45)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Loading your world..."
    subtitle.TextColor3 = Color3.fromRGB(200, 200, 200)
    subtitle.TextScaled = true
    subtitle.Font = Enum.Font.SourceSans
    subtitle.Parent = container
    
    -- Progress bar background
    local progressBg = Instance.new("Frame")
    progressBg.Name = "ProgressBackground"
    progressBg.Size = UDim2.new(1, 0, 0, UI_CONFIG.progressBarHeight)
    progressBg.Position = UDim2.new(0, 0, 0, 90)
    progressBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    progressBg.BorderSizePixel = 0
    progressBg.Parent = container
    
    -- Progress bar corner
    local progressBgCorner = Instance.new("UICorner")
    progressBgCorner.CornerRadius = UDim.new(0, 4)
    progressBgCorner.Parent = progressBg
    
    -- Progress bar fill
    local progressFill = Instance.new("Frame")
    progressFill.Name = "ProgressFill"
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.BackgroundColor3 = UI_CONFIG.accentColor
    progressFill.BorderSizePixel = 0
    progressFill.Parent = progressBg
    
    -- Progress fill corner
    local progressFillCorner = Instance.new("UICorner")
    progressFillCorner.CornerRadius = UDim.new(0, 4)
    progressFillCorner.Parent = progressFill
    
    -- Progress text
    local progressText = Instance.new("TextLabel")
    progressText.Name = "ProgressText"
    progressText.Size = UDim2.new(1, 0, 0, 20)
    progressText.Position = UDim2.new(0, 0, 0, 110)
    progressText.BackgroundTransparency = 1
    progressText.Text = "0%"
    progressText.TextColor3 = UI_CONFIG.textColor
    progressText.TextScaled = true
    progressText.Font = Enum.Font.SourceSans
    progressText.Parent = container
    
    -- Status message
    local statusMessage = Instance.new("TextLabel")
    statusMessage.Name = "StatusMessage"
    statusMessage.Size = UDim2.new(1, 0, 0, 20)
    statusMessage.Position = UDim2.new(0, 0, 0, 135)
    statusMessage.BackgroundTransparency = 1
    statusMessage.Text = "Initializing..."
    statusMessage.TextColor3 = Color3.fromRGB(180, 180, 180)
    statusMessage.TextScaled = true
    statusMessage.Font = Enum.Font.SourceSans
    statusMessage.Parent = container
    
    -- Loading dots animation
    local dots = Instance.new("TextLabel")
    dots.Name = "Dots"
    dots.Size = UDim2.new(1, 0, 0, 20)
    dots.Position = UDim2.new(0, 0, 0, 160)
    dots.BackgroundTransparency = 1
    dots.Text = "..."
    dots.TextColor3 = UI_CONFIG.accentColor
    dots.TextScaled = true
    dots.Font = Enum.Font.SourceSans
    dots.Parent = container
    
    return screenGui
end

-- Animate dots
local function animateDots(dotsLabel)
    local dotStates = {"", ".", "..", "..."}
    local currentState = 1
    
    local connection
    connection = RunService.Heartbeat:Connect(function()
        if not dotsLabel.Parent then
            connection:Disconnect()
            return
        end
        
        currentState = currentState + 1
        if currentState > #dotStates then
            currentState = 1
        end
        
        dotsLabel.Text = dotStates[currentState]
        wait(0.5) -- Update every half second
    end)
    
    return connection
end

-- Update progress bar
local function updateProgress(gui, progressData)
    local container = gui.Background.Container
    local progressFill = container.ProgressBackground.ProgressFill
    local progressText = container.ProgressText
    local statusMessage = container.StatusMessage
    
    -- Update progress bar
    local targetSize = UDim2.new(progressData.percentage / 100, 0, 1, 0)
    local tween = TweenService:Create(
        progressFill,
        TweenInfo.new(UI_CONFIG.animationSpeed, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        {Size = targetSize}
    )
    tween:Play()
    
    -- Update text
    progressText.Text = progressData.percentage .. "%"
    statusMessage.Text = progressData.message or "Loading..."
    
    -- Pulse effect on progress bar
    local pulseIn = TweenService:Create(
        progressFill,
        TweenInfo.new(UI_CONFIG.pulseSpeed / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        {BackgroundColor3 = Color3.fromRGB(90, 150, 200)}
    )
    local pulseOut = TweenService:Create(
        progressFill,
        TweenInfo.new(UI_CONFIG.pulseSpeed / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
        {BackgroundColor3 = UI_CONFIG.accentColor}
    )
    
    pulseIn:Play()
    pulseIn.Completed:Connect(function()
        pulseOut:Play()
    end)
end

-- Internal: bind progress remote if available (idempotent)
local function bindProgress()
    if progressConn and progressRemote then return end
    progressRemote = findProgressRemote()
    if not progressRemote then return end
    progressConn = progressRemote.OnClientEvent:Connect(function(payload)
        if type(payload) == "table" then
            if payload.completed then
                LoadingScreen:Complete()
                return
            end
            local pct = 0
            if typeof(payload.progress) == "number" then
                pct = math.clamp(math.floor((payload.progress or 0) * 100 + 0.5), 0, 100)
            elseif typeof(payload.percentage) == "number" then
                pct = math.clamp(payload.percentage, 0, 100)
            end
            local message = "Loading..."
            if typeof(payload.status) == "string" and typeof(payload.detail) == "string" then
                message = (payload.status .. " - " .. payload.detail)
            elseif typeof(payload.message) == "string" then
                message = payload.message
            end
            LoadingScreen:UpdateProgress({ percentage = pct, message = message })
            if (typeof(payload.progress) == "number" and payload.progress >= 1) or payload.status == "Complete" then
                LoadingScreen:Complete()
            end
        end
    end)
    -- Notify server that client is ready to receive progress updates
    local net = ReplicatedStorage:FindFirstChild("Net")
    local remotes = net and net:FindFirstChild("Remotes")
    local ready = remotes and remotes:FindFirstChild("RE_LoadingReady")
    if ready and ready:IsA("RemoteEvent") and not readySent then
        readySent = true
        ready:FireServer()
    end
end

-- Show loading screen
function LoadingScreen:Show()
    if self.gui then
        self:Hide()
    end
    
    self.gui = createLoadingUI()
    self.dotsConnection = animateDots(self.gui.Background.Container.Dots)
    print("[LoadingScreen] Show()")
    -- Attempt to bind progress immediately and retry a few times for late-created remotes
    bindProgress()
    task.spawn(function()
        local tries = 0
        while not progressConn and tries < 16 do
            tries += 1
            bindProgress()
            task.wait(0.5)
        end
        if not progressConn then
            warn("[LoadingScreen] Progress remote not found after retries; UI will rely on client bootstrap milestones")
        end
    end)
    
    -- Fade in animation
    local background = self.gui.Background
    background.BackgroundTransparency = 1
    
    local fadeIn = TweenService:Create(
        background,
        TweenInfo.new(UI_CONFIG.animationSpeed, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        {BackgroundTransparency = 0}
    )
    fadeIn:Play()
end

-- Hide loading screen
function LoadingScreen:Hide()
    if not self.gui then
        return
    end
    
    print("[LoadingScreen] Hide()")
    if progressConn then progressConn:Disconnect(); progressConn = nil end
    -- Disconnect dots animation
    if self.dotsConnection then
        self.dotsConnection:Disconnect()
        self.dotsConnection = nil
    end
    
    -- Fade out animation
    local background = self.gui.Background
    local fadeOut = TweenService:Create(
        background,
        TweenInfo.new(UI_CONFIG.animationSpeed, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
        {BackgroundTransparency = 1}
    )
    
    fadeOut:Play()
    fadeOut.Completed:Connect(function()
        if self.gui then
            self.gui:Destroy()
            self.gui = nil
        end
    end)
end

-- Handle progress updates
function LoadingScreen:UpdateProgress(progressData)
    if not self.gui then
        self:Show()
    end
    
    updateProgress(self.gui, progressData)
end

-- Handle completion
function LoadingScreen:Complete()
    self:Hide()
end

-- Connect to remote events (if available)
if progressRemote then
    progressRemote.OnClientEvent:Connect(function(payload)
        -- Map server payload to UI structure
        -- Expected fields from server: progress (0..1), status (string), detail (string), isLoading (bool?)
        if type(payload) == "table" then
            -- Only treat AsyncPondLoader as authoritative for completion
            local isAsync = (payload.source == "AsyncPondLoader")
            if payload.completed and isAsync then
                LoadingScreen:Complete()
                return
            end
            local pct = 0
            if typeof(payload.progress) == "number" then
                pct = math.clamp(math.floor((payload.progress or 0) * 100 + 0.5), 0, 100)
            elseif typeof(payload.percentage) == "number" then
                pct = math.clamp(payload.percentage, 0, 100)
            end
            local message = "Loading..."
            if typeof(payload.status) == "string" and typeof(payload.detail) == "string" then
                message = (payload.status .. " - " .. payload.detail)
            elseif typeof(payload.message) == "string" then
                message = payload.message
            end
            -- Always show progress, but only auto-complete for AsyncPondLoader
            LoadingScreen:UpdateProgress({ percentage = pct, message = message })
            if isAsync and ((typeof(payload.progress) == "number" and payload.progress >= 1) or payload.status == "Complete") then
                LoadingScreen:Complete()
            end
        end
    end)
else
    warn("[LoadingScreen] Progress remote not found (Net/Remotes.RE_LoadingProgress or Remotes.LoadingProgressRemote)")
end

-- Auto-show on significant loading operations
local function detectLoadingOperation()
    -- You can hook this into your existing systems
    -- For now, it will respond to remote events
end

return LoadingScreen
