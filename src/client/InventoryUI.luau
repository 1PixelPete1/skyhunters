local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local InventoryConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("InventoryConfig"))
local ItemsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemsConfig"))
local CountChangedEvent = ReplicatedStorage:FindFirstChild("InventoryCountChanged")
if not CountChangedEvent then
    CountChangedEvent = Instance.new("BindableEvent")
    CountChangedEvent.Name = "InventoryCountChanged"
    CountChangedEvent.Parent = ReplicatedStorage
end
local HeldItemController = require(script.Parent:WaitForChild("HeldItemController"))

local RF_Fetch = ReplicatedStorage:WaitForChild("Inventory_FetchPage")

local localPlayer = Players.LocalPlayer

local InventoryUI = {}

local debounceMs = InventoryConfig.UI.DebounceMs
local pageSize = InventoryConfig.UI.PageSize

local currentCategory = InventoryConfig.Categories[1].id
local currentSearch = ""
local nextCursor
local items = {}
local itemLookup = {}
local cells = {}
local cellPool = {}
local gridContainer

local function createCell()
    local frame = Instance.new("ImageButton")
    frame.Size = UDim2.new(0, InventoryConfig.UI.GridCellMinPx, 0, InventoryConfig.UI.GridCellMinPx)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    frame.BorderSizePixel = 0
    local stroke = Instance.new("UIStroke")
    stroke.Parent = frame
    frame.MouseButton1Click:Connect(function()
        local uid = frame:GetAttribute("uid")
        if not uid then
            return
        end
        local item = itemLookup[uid]
        if item then
            local cfg = ItemsConfig.Types[item.typeId]
            if cfg then
                HeldItemController.Start({
                    id = item.uid,
                    model = cfg.model,
                    type = "Build",
                    weldTo = "Head",
                    carryOffset = nil,
                    count = item.count,
                    icon = cfg.icon,
                    name = cfg.displayName,
                    cameraBehavior = cfg.cameraBehavior,
                }, "build")
            end
        end
    end)
    return frame
end

local function getCell()
    local cell = table.remove(cellPool)
    if cell then
        return cell
    end
    return createCell()
end

local function clearCells()
    for _, cell in pairs(cells) do
        cell.Parent = nil
        cell:SetAttribute("uid", nil)
        table.insert(cellPool, cell)
    end
    table.clear(cells)
end

local function renderGrid()
    clearCells()
    for _, item in ipairs(items) do
        local cell = getCell()
        cell.Image = item.icon
        cell:SetAttribute("uid", item.uid)
        cell.Parent = gridContainer
        table.insert(cells, cell)
    end
end

CountChangedEvent.Event:Connect(function(uid, newCount)
    local item = itemLookup[uid]
    if item then
        item.count = newCount
        if newCount <= 0 then
            for i, existing in ipairs(items) do
                if existing.uid == uid then
                    table.remove(items, i)
                    break
                end
            end
            itemLookup[uid] = nil
        end
    end
    renderGrid()
end)

local function fetchPage(reset)
    if reset then
        nextCursor = nil
        items = {}
        itemLookup = {}
    end
    local page, newCursor = RF_Fetch:InvokeServer(currentCategory, currentSearch, nextCursor)
    for _, item in ipairs(page) do
        table.insert(items, item)
        itemLookup[item.uid] = item
    end
    nextCursor = newCursor
end

local function refresh()
    fetchPage(true)
    renderGrid()
end

function InventoryUI.Init()
    local playerGui = localPlayer:WaitForChild("PlayerGui")
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "InventoryGUI"
    screenGui.Parent = playerGui

    local toggleButton = Instance.new("ImageButton")
    toggleButton.Name = "InventoryToggle"
    toggleButton.Size = UDim2.new(0, 40, 0, 40)
    toggleButton.Position = UDim2.new(1, -45, 0.5, -20)
    toggleButton.AnchorPoint = Vector2.new(1, 0.5)
    toggleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    toggleButton.Image = "rbxassetid://0"
    toggleButton.ZIndex = 2
    toggleButton.Parent = screenGui

    local root = Instance.new("Frame")
    root.Size = UDim2.new(1, 0, 1, 0)
    root.BackgroundTransparency = 1
    root.AnchorPoint = Vector2.new(1, 0)
    root.Position = UDim2.fromScale(2, 0)
    root.Visible = false
    root.ZIndex = 0
    root.Parent = screenGui

    local categoriesColumn = Instance.new("Frame")
    categoriesColumn.Name = "CategoriesColumn"
    categoriesColumn.Size = UDim2.new(0, InventoryConfig.UI.CategoryButtonMinPx + InventoryConfig.UI.CategoryButtonPaddingPx * 2, 1, 0)
    categoriesColumn.BackgroundTransparency = 1
    categoriesColumn.Parent = root

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, InventoryConfig.UI.CategoryButtonPaddingPx)
    layout.Parent = categoriesColumn

    for _, cat in ipairs(InventoryConfig.Categories) do
        local button = Instance.new("TextButton")
        button.Text = cat.label
        button.Size = UDim2.new(1, 0, 0, InventoryConfig.UI.CategoryButtonMinPx)
        button.BackgroundColor3 = cat.color
        button.MouseButton1Click:Connect(function()
            currentCategory = cat.id
            refresh()
        end)
        button.Parent = categoriesColumn
    end

    local listPanel = Instance.new("Frame")
    listPanel.Name = "ListPanel"
    listPanel.Position = UDim2.new(0, categoriesColumn.Size.X.Offset, 0, 0)
    listPanel.Size = UDim2.new(1, -categoriesColumn.Size.X.Offset, 1, 0)
    listPanel.BackgroundTransparency = 1
    listPanel.Parent = root

    local search = Instance.new("TextBox")
    search.PlaceholderText = "Search"
    search.Size = UDim2.new(1, -InventoryConfig.UI.GridPaddingPx * 2, 0, 24)
    search.Position = UDim2.new(0, InventoryConfig.UI.GridPaddingPx, 0, InventoryConfig.UI.GridPaddingPx)
    search.Parent = listPanel

    local grid = Instance.new("ScrollingFrame")
    grid.Name = "Grid"
    grid.Position = UDim2.new(0, InventoryConfig.UI.GridPaddingPx, 0, 32 + InventoryConfig.UI.GridPaddingPx)
    grid.Size = UDim2.new(1, -InventoryConfig.UI.GridPaddingPx * 2, 1, -40)
    grid.BackgroundTransparency = 1
    grid.CanvasSize = UDim2.new()
    grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
    grid.Parent = listPanel

    gridContainer = Instance.new("Frame")
    gridContainer.Name = "Container"
    gridContainer.BackgroundTransparency = 1
    gridContainer.Size = UDim2.new(1, 0, 0, 0)
    gridContainer.AutomaticSize = Enum.AutomaticSize.Y
    gridContainer.Parent = grid

    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, InventoryConfig.UI.GridCellMinPx, 0, InventoryConfig.UI.GridCellMinPx)
    gridLayout.CellPadding = UDim2.new(0, InventoryConfig.UI.GridPaddingPx, 0, InventoryConfig.UI.GridPaddingPx)
    gridLayout.Parent = gridContainer

    local lastText
    search:GetPropertyChangedSignal("Text"):Connect(function()
        if lastText == search.Text then
            return
        end
        lastText = search.Text
        task.delay(debounceMs / 1000, function()
            if search.Text == lastText then
                currentSearch = search.Text
                refresh()
            end
        end)
    end)


    local open = false
    local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    toggleButton.MouseButton1Click:Connect(function()
        open = not open
        if open then
            root.Visible = true
            TweenService:Create(root, tweenInfo, {Position = UDim2.fromScale(1, 0)}):Play()
        else
            local tween = TweenService:Create(root, tweenInfo, {Position = UDim2.fromScale(2, 0)})
            tween.Completed:Connect(function()
                root.Visible = false
            end)
            tween:Play()
        end
    end)

    refresh(grid)

end

return InventoryUI
