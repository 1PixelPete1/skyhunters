-- HeadLanternController.lua
-- Client-side head lantern visuals and flashlight cone

local HeadLanternController = {}
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Head lantern state
local headLanternModel = nil
local flashlightCone = nil
local curseUI = nil
local isEquipped = false

function HeadLanternController:Initialize()
    -- Create curse UI overlay
    self:CreateCurseUI()
    
    -- Update loop for flashlight
    RunService.RenderStepped:Connect(function()
        if isEquipped and flashlightCone then
            self:UpdateFlashlight()
        end
    end)
end

function HeadLanternController:CreateCurseUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CurseUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player:WaitForChild("PlayerGui")
    
    -- Curse indicator frame
    curseUI = Instance.new("Frame")
    curseUI.Size = UDim2.new(0, 250, 0, 80)
    curseUI.Position = UDim2.new(0, 10, 0, 10)
    curseUI.BackgroundColor3 = Color3.new(0.1, 0.05, 0.15)
    curseUI.BorderSizePixel = 0
    curseUI.Visible = false
    curseUI.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = curseUI
    
    -- Curse name
    self.curseName = Instance.new("TextLabel")
    self.curseName.Size = UDim2.new(1, -10, 0, 25)
    self.curseName.Position = UDim2.new(0, 5, 0, 5)
    self.curseName.BackgroundTransparency = 1
    self.curseName.Text = "No Curse"
    self.curseName.TextColor3 = Color3.fromRGB(200, 150, 255)
    self.curseName.TextScaled = true
    self.curseName.Font = Enum.Font.Fantasy
    self.curseName.Parent = curseUI
    
    -- Curse description
    self.curseDesc = Instance.new("TextLabel")
    self.curseDesc.Size = UDim2.new(1, -10, 0, 30)
    self.curseDesc.Position = UDim2.new(0, 5, 0, 30)
    self.curseDesc.BackgroundTransparency = 1
    self.curseDesc.Text = ""
    self.curseDesc.TextColor3 = Color3.new(0.8, 0.8, 0.8)
    self.curseDesc.TextScaled = true
    self.curseDesc.Font = Enum.Font.SourceSans
    self.curseDesc.Parent = curseUI
    
    -- Durability indicator
    self.durabilityBar = Instance.new("Frame")
    self.durabilityBar.Size = UDim2.new(1, -10, 0, 8)
    self.durabilityBar.Position = UDim2.new(0, 5, 1, -13)
    self.durabilityBar.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
    self.durabilityBar.BorderSizePixel = 0
    self.durabilityBar.Parent = curseUI
    
    self.durabilityFill = Instance.new("Frame")
    self.durabilityFill.Size = UDim2.new(1, 0, 1, 0)
    self.durabilityFill.BackgroundColor3 = Color3.fromRGB(255, 200, 100)
    self.durabilityFill.BorderSizePixel = 0
    self.durabilityFill.Parent = self.durabilityBar
end

function HeadLanternController:EquipHeadLantern(lanternData, curseData)
    isEquipped = true
    
    -- Create flashlight cone
    self:CreateFlashlight(lanternData)
    
    -- Update UI
    self.curseName.Text = curseData.Name
    self.curseDesc.Text = curseData.Description
    self:UpdateDurability(lanternData.durability, lanternData.deathsRemaining)
    
    curseUI.Visible = true
    
    -- Animate in
    curseUI.Position = UDim2.new(-0.2, 0, 0, 10)
    TweenService:Create(curseUI, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
        Position = UDim2.new(0, 10, 0, 10)
    }):Play()
    
    -- Visual effect on character
    self:CreateHeadLanternModel()
end

function HeadLanternController:CreateFlashlight(lanternData)
    -- Create spotlight for flashlight cone
    flashlightCone = Instance.new("SpotLight")
    flashlightCone.Brightness = lanternData.stats.lightBrightness or 2
    flashlightCone.Range = lanternData.stats.lightRadius or 30
    flashlightCone.Angle = 60
    flashlightCone.Face = Enum.NormalId.Front
    flashlightCone.Color = Color3.fromHSV(0.1, 0.3, 1)
    flashlightCone.Shadows = true
    
    -- Parent to camera for first-person effect
    local attachment = Instance.new("Attachment")
    attachment.Name = "FlashlightAttachment"
    attachment.Parent = camera
    
    flashlightCone.Parent = attachment
end

function HeadLanternController:UpdateFlashlight()
    if not flashlightCone or not camera then return end
    
    local character = player.Character
    if character and character:FindFirstChild("Head") then
        -- Position at head, aim where camera looks
        local head = character.Head
        local attachment = flashlightCone.Parent
        
        if attachment then
            attachment.WorldCFrame = CFrame.lookAt(
                head.Position + camera.CFrame.LookVector * 0.5,
                head.Position + camera.CFrame.LookVector * 10
            )
        end
    end
end

function HeadLanternController:CreateHeadLanternModel()
    local character = player.Character
    if not character or not character:FindFirstChild("Head") then return end
    
    -- Create glowing lantern on head
    headLanternModel = Instance.new("Part")
    headLanternModel.Name = "HeadLantern"
    headLanternModel.Size = Vector3.new(0.8, 0.8, 0.8)
    headLanternModel.Shape = Enum.PartType.Ball
    headLanternModel.Material = Enum.Material.Neon
    headLanternModel.Color = Color3.fromHSV(0.1, 0.4, 1)
    headLanternModel.CanCollide = false
    headLanternModel.Parent = character
    
    -- Weld to head
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = character.Head
    weld.Part1 = headLanternModel
    weld.Parent = headLanternModel
    
    -- Position above head
    headLanternModel.CFrame = character.Head.CFrame * CFrame.new(0, 1.5, 0)
    
    -- Add glow
    local pointLight = Instance.new("PointLight")
    pointLight.Brightness = 1
    pointLight.Range = 10
    pointLight.Color = Color3.fromHSV(0.1, 0.4, 1)
    pointLight.Parent = headLanternModel
    
    -- Floating animation
    local floatConnection
    floatConnection = RunService.Heartbeat:Connect(function()
        if headLanternModel and headLanternModel.Parent then
            local time = tick()
            local offset = math.sin(time * 2) * 0.1
            -- Update position relative to head
            if character.Head then
                headLanternModel.CFrame = character.Head.CFrame * CFrame.new(0, 1.5 + offset, 0)
            end
        else
            floatConnection:Disconnect()
        end
    end)
end

function HeadLanternController:UpdateDurability(maxDurability, remaining)
    local percentage = remaining / maxDurability
    self.durabilityFill.Size = UDim2.new(percentage, 0, 1, 0)
    
    -- Color based on remaining
    if percentage > 0.6 then
        self.durabilityFill.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
    elseif percentage > 0.3 then
        self.durabilityFill.BackgroundColor3 = Color3.fromRGB(255, 200, 100)
    else
        self.durabilityFill.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    end
end

function HeadLanternController:RemoveHeadLantern()
    isEquipped = false
    
    -- Clean up flashlight
    if flashlightCone then
        flashlightCone.Parent:Destroy()
        flashlightCone = nil
    end
    
    -- Clean up model
    if headLanternModel then
        headLanternModel:Destroy()
        headLanternModel = nil
    end
    
    -- Hide UI
    TweenService:Create(curseUI, TweenInfo.new(0.3), {
        Position = UDim2.new(-0.3, 0, 0, 10)
    }):Play()
    
    task.wait(0.3)
    curseUI.Visible = false
end

return HeadLanternController