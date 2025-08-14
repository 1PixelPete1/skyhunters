local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local InventoryConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("InventoryConfig"))

local RF_Fetch = ReplicatedStorage:WaitForChild("Inventory_FetchPage")
local RF_Equip = ReplicatedStorage:WaitForChild("Inventory_Equip")

local localPlayer = Players.LocalPlayer

local InventoryUI = {}

local debounceMs = InventoryConfig.UI.DebounceMs
local pageSize = InventoryConfig.UI.PageSize

local currentCategory = InventoryConfig.Categories[1].id
local currentSearch = ""
local nextCursor
local items = {}
local cells = {}
local cellPool = {}

local function createCell()
    local frame = Instance.new("ImageButton")
    frame.Size = UDim2.new(0, InventoryConfig.UI.GridCellMinPx, 0, InventoryConfig.UI.GridCellMinPx)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    frame.BorderSizePixel = 0
    local stroke = Instance.new("UIStroke")
    stroke.Parent = frame
    return frame
end

local function getCell(index)
    if cellPool[index] then
        return cellPool[index]
    end
    local cell = createCell()
    cellPool[index] = cell
    return cell
end

local function clearCells(grid)
    for _, cell in pairs(cells) do
        cell.Parent = nil
    end
    table.clear(cells)
end

local function renderGrid(grid)
    clearCells(grid)
    for i, item in ipairs(items) do
        local cell = getCell(i)
        cell.Image = item.icon
        cell.Parent = grid
        cell.MouseButton1Click:Connect(function()
            local result = RF_Equip:InvokeServer(item.uid)
            if result and result.ok then
                -- preview stub
            end
        end)
        table.insert(cells, cell)
    end
end

local function fetchPage(reset)
    if reset then
        nextCursor = nil
        items = {}
    end
    local page, newCursor = RF_Fetch:InvokeServer(currentCategory, currentSearch, nextCursor)
    for _, item in ipairs(page) do
        table.insert(items, item)
    end
    nextCursor = newCursor
end

local function refresh(grid)
    fetchPage(true)
    renderGrid(grid)
end

function InventoryUI.Init()
    local playerGui = localPlayer:WaitForChild("PlayerGui")
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "InventoryGUI"
    screenGui.Parent = playerGui

    local root = Instance.new("Frame")
    root.Size = UDim2.new(1, 0, 1, 0)
    root.BackgroundTransparency = 1
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
            refresh(grid)
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
    grid.Parent = listPanel

    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, InventoryConfig.UI.GridCellMinPx, 0, InventoryConfig.UI.GridCellMinPx)
    gridLayout.CellPadding = UDim2.new(0, InventoryConfig.UI.GridPaddingPx, 0, InventoryConfig.UI.GridPaddingPx)
    gridLayout.Parent = grid

    local lastText
    search:GetPropertyChangedSignal("Text"):Connect(function()
        if lastText == search.Text then
            return
        end
        lastText = search.Text
        task.delay(debounceMs / 1000, function()
            if search.Text == lastText then
                currentSearch = search.Text
                refresh(grid)
            end
        end)
    end)

    refresh(grid)
end

return InventoryUI
