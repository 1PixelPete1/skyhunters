-- ToolService.luau
-- Creates and manages tools for items granted to players

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToolService = {}

-- Tool definitions for different item types
local TOOL_DEFINITIONS = {
    -- Lantern types
    lantern_basic = {
        name = "Basic Lantern",
        description = "A simple lantern for lighting",
        color = Color3.fromRGB(255, 200, 100),
        toolTip = "Click to place a basic lantern",
    },
    lantern_advanced = {
        name = "Advanced Lantern",
        description = "An improved lantern with better range",
        color = Color3.fromRGB(200, 255, 150),
        toolTip = "Click to place an advanced lantern",
    },
    lantern_crystal = {
        name = "Crystal Lantern",
        description = "A magical crystal lantern",
        color = Color3.fromRGB(150, 200, 255),
        toolTip = "Click to place a crystal lantern",
    },
    
    -- Oil items
    oil_canister = {
        name = "Oil Canister",
        description = "Contains oil for lanterns",
        color = Color3.fromRGB(100, 80, 60),
        toolTip = "Use to refill oil",
    },
    
    -- Pond tools
    pond_basic = {
        name = "Basic Pond",
        description = "Creates a small pond",
        color = Color3.fromRGB(100, 150, 200),
        toolTip = "Click to place a pond",
    },
    pond_large = {
        name = "Large Pond",
        description = "Creates a large pond",
        color = Color3.fromRGB(80, 120, 180),
        toolTip = "Click to place a large pond",
    },
    canal_tool = {
        name = "Canal Tool",
        description = "Connects ponds with canals",
        color = Color3.fromRGB(120, 140, 160),
        toolTip = "Click two ponds to connect them",
    },
    
    -- Removal tool
    removal_tool = {
        name = "Removal Tool",
        description = "Remove ponds and lanterns",
        color = Color3.fromRGB(255, 50, 50),  -- Red for removal
        toolTip = "Click on items to remove them",
    },
}

-- Create a tool instance for an item
local function createTool(itemId: string, quantity: number?): Tool?
    local def = TOOL_DEFINITIONS[itemId]
    if not def then
        warn("[ToolService] No tool definition for:", itemId)
        return nil
    end
    
    -- Create the tool
    local tool = Instance.new("Tool")
    tool.Name = def.name
    tool.ToolTip = def.toolTip
    tool.RequiresHandle = false -- Most of our tools don't need handles
    tool.CanBeDropped = false -- Prevent accidental drops
    
    -- Add a visual part as the tool's appearance
    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(1, 1, 1)
    handle.Material = Enum.Material.Neon
    handle.BrickColor = BrickColor.new(def.color)
    handle.TopSurface = Enum.SurfaceType.Smooth
    handle.BottomSurface = Enum.SurfaceType.Smooth
    handle.CanCollide = false
    handle.Parent = tool
    
    -- Add a mesh to make it look nicer
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Sphere
    mesh.Scale = Vector3.new(0.8, 0.8, 0.8)
    mesh.Parent = handle
    
    -- Add attributes for identification
    tool:SetAttribute("ItemId", itemId)
    tool:SetAttribute("Quantity", quantity or 1)
    tool:SetAttribute("ItemType", string.match(itemId, "^(%w+)_") or "unknown")
    
    -- Add a StringValue for description
    local descValue = Instance.new("StringValue")
    descValue.Name = "Description"
    descValue.Value = def.description
    descValue.Parent = tool
    
    -- Add a server script to handle tool activation (no LocalScript needed)
    -- The tool will still work for basic equip/unequip
    -- For advanced functionality, we'd need a pre-existing LocalScript in StarterPlayer
    
    -- Add a ClickDetector alternative or use Tool.Activated on server
    local connection
    tool.AncestryChanged:Connect(function()
        if tool.Parent and tool.Parent:IsA("Model") then
            -- Tool was equipped
            local character = tool.Parent
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                print("[ToolService] Tool equipped:", tool.Name, "by", character.Name)
            end
        end
    end)
    
    return tool
end

-- Grant a tool to a player
function ToolService.GrantTool(player: Player, itemId: string, quantity: number?)
    local tool = createTool(itemId, quantity)
    if tool then
        -- Check if player already has this tool
        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            local existing = backpack:FindFirstChild(tool.Name)
            if existing then
                -- Update quantity if it already exists
                local currentQty = existing:GetAttribute("Quantity") or 1
                existing:SetAttribute("Quantity", currentQty + (quantity or 1))
                print("[ToolService] Updated existing tool quantity:", tool.Name, "new qty:", currentQty + (quantity or 1))
                tool:Destroy()
            else
                -- Add new tool to backpack
                tool.Parent = backpack
                print("[ToolService] Granted tool to", player.Name, ":", tool.Name)
            end
        else
            warn("[ToolService] Player has no backpack:", player.Name)
            tool:Destroy()
        end
    end
end

-- Remove a tool from a player
function ToolService.RemoveTool(player: Player, itemId: string)
    local def = TOOL_DEFINITIONS[itemId]
    if not def then return end
    
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        local tool = backpack:FindFirstChild(def.name)
        if tool then
            tool:Destroy()
            print("[ToolService] Removed tool from", player.Name, ":", def.name)
        end
    end
    
    -- Also check character (if equipped)
    local character = player.Character
    if character then
        local tool = character:FindFirstChild(def.name)
        if tool then
            tool:Destroy()
            print("[ToolService] Removed equipped tool from", player.Name, ":", def.name)
        end
    end
end

-- Clear all tools from a player
function ToolService.ClearTools(player: Player)
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, child in pairs(backpack:GetChildren()) do
            if child:IsA("Tool") then
                child:Destroy()
            end
        end
        print("[ToolService] Cleared all tools for", player.Name)
    end
end

-- Initialize service
function ToolService.Init(services)
    ToolService._services = services
    print("[ToolService] Initialized with", #TOOL_DEFINITIONS, "tool definitions")
end

return ToolService