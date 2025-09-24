-- ToolHandler.client.luau
-- Handles all tool functionality on the client side

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local backpack = player:WaitForChild("Backpack")
local character = player.Character or player.CharacterAdded:Wait()

print("[ToolHandler] Client tool handler initialized")

-- Track authoritative player state from server
local currentPlayerState = "Neutral"
do
    local ok, ev = pcall(function() return ReplicatedStorage:WaitForChild("PlayerStateRemote", 5) end)
    if ok and ev and ev:IsA("RemoteEvent") then
        ev.OnClientEvent:Connect(function(eventType, data)
            if eventType == "StateChanged" and data and data.state then
                currentPlayerState = data.state
                print("[ToolHandler] Player state changed to:", currentPlayerState)
            end
        end)
        -- Request current state
        pcall(function() ev:FireServer("RequestState") end)
    end
end

-- Get remotes
local Net = ReplicatedStorage:WaitForChild("Net", 10)
local remotes = Net and Net:FindFirstChild("Remotes")

-- Create use item remote if needed
local useItemRemote
if remotes then
    useItemRemote = remotes:FindFirstChild("RE_UseItem")
    if not useItemRemote then
        useItemRemote = Instance.new("RemoteEvent")
        useItemRemote.Name = "RE_UseItem"
        useItemRemote.Parent = remotes
    end
end

-- Handle tool activation
local function setupTool(tool: Tool)
    if not tool:IsA("Tool") then return end
    
    local itemId = tool:GetAttribute("ItemId")
    local quantity = tool:GetAttribute("Quantity")
    
    if not itemId then
        -- Attempt to infer ItemId from legacy tool names to avoid spammy warnings
        local lname = string.lower(tool.Name or "")
        local inferredId: string? = nil
        if string.find(lname, "removal") then
            inferredId = "removal_tool"
            tool:SetAttribute("ItemType", "removal")
        elseif string.find(lname, "pond") then
            inferredId = "pond_basic"
            tool:SetAttribute("ItemType", "pond")
        elseif string.find(lname, "lantern") then
            -- Distinguish run/toggle tools from placement tools by name if possible
            if string.find(lname, "run") or string.find(lname, "toggle") then
                inferredId = "lantern_control"
                tool:SetAttribute("ItemType", "control")
            else
                inferredId = "lantern_basic"
                tool:SetAttribute("ItemType", "lantern")
            end
        end
        if inferredId then
            tool:SetAttribute("ItemId", inferredId)
            itemId = inferredId
        else
            warn("[ToolHandler] Tool has no ItemId:", tool.Name)
            return
        end
    end
    
    print("[ToolHandler] Setting up tool:", tool.Name, "ItemId:", itemId, "Quantity:", quantity or 1)
    
    -- Handle tool activation
    local activatedConnection
    activatedConnection = tool.Activated:Connect(function()
        print("[ToolHandler] Activated:", tool.Name, "ItemId:", itemId)
        
        -- CRITICAL: Check if placement tools are allowed based on state
        local itemType = tool:GetAttribute("ItemType")
        local isPlacementTool = (itemType == "lantern" or itemType == "pond" or itemType == "oil" or itemType == "canal" or itemType == "removal")
        
        if isPlacementTool and currentPlayerState ~= "Build" then
            warn(string.format("[ToolHandler] Cannot use %s - current state is '%s', must be in 'Build' state", tool.Name, currentPlayerState))
            return  -- Block tool usage
        end
        
        -- Visual feedback
        local handle = tool:FindFirstChild("Handle")
        if handle and handle:IsA("BasePart") then
            -- Quick flash effect
            local originalColor = handle.Color
            handle.Color = Color3.new(1, 1, 1)
            wait(0.1)
            handle.Color = originalColor
        end
        
        -- Send to server
        if useItemRemote then
            useItemRemote:FireServer(itemId, quantity)
        else
            warn("[ToolHandler] No UseItem remote found")
        end
        
        -- Tool-specific client effects
        local itemType = tool:GetAttribute("ItemType")
        if itemType == "lantern" then
            print("[ToolHandler] Placing lantern...")
            -- Could add ghost preview here
        elseif itemType == "pond" then
            print("[ToolHandler] Creating pond...")
            -- Could add pond preview here
        elseif itemType == "oil" then
            print("[ToolHandler] Using oil canister...")
            -- Could add oil effect here
        elseif itemType == "canal" then
            print("[ToolHandler] Canal tool activated...")
            -- Could add canal preview here
        end
    end)
    
    -- Handle tool equipped
    local equippedConnection
    equippedConnection = tool.Equipped:Connect(function()
        print("[ToolHandler] Equipped:", tool.Name)
        
        -- Show tooltip or UI
        local handle = tool:FindFirstChild("Handle")
        if handle and handle:IsA("BasePart") then
            -- Make it glow when equipped
            handle.Material = Enum.Material.ForceField
        end
    end)
    
    -- Handle tool unequipped
    local unequippedConnection
    unequippedConnection = tool.Unequipped:Connect(function()
        print("[ToolHandler] Unequipped:", tool.Name)
        
        -- Hide tooltip or UI
        local handle = tool:FindFirstChild("Handle")
        if handle and handle:IsA("BasePart") then
            -- Remove glow
            handle.Material = Enum.Material.Neon
        end
    end)
    
    -- Clean up connections when tool is removed
    tool.AncestryChanged:Connect(function()
        if not tool.Parent then
            if activatedConnection then activatedConnection:Disconnect() end
            if equippedConnection then equippedConnection:Disconnect() end
            if unequippedConnection then unequippedConnection:Disconnect() end
        end
    end)
end

-- Watch for new tools in backpack
backpack.ChildAdded:Connect(function(child)
    if child:IsA("Tool") then
        setupTool(child)
    end
end)

-- Setup existing tools
for _, tool in pairs(backpack:GetChildren()) do
    if tool:IsA("Tool") then
        setupTool(tool)
    end
end

-- Also watch character for equipped tools
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    
    -- Watch for tools being added to character (when equipped)
    character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            setupTool(child)
        end
    end)
    
    -- Setup any already equipped tools
    for _, tool in pairs(character:GetChildren()) do
        if tool:IsA("Tool") then
            setupTool(tool)
        end
    end
end)

-- Setup tools in current character
if character then
    character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            setupTool(child)
        end
    end)
    
    for _, tool in pairs(character:GetChildren()) do
        if tool:IsA("Tool") then
            setupTool(tool)
        end
    end
end

print("[ToolHandler] Ready to handle tools")
