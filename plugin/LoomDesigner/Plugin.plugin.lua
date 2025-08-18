--!strict
local RequireUtil = require(script.Parent.RequireUtil)
local UI = require(script.Parent.UI)
local LoomDesigner = require(script.Parent.Main)

-- Toolbar + button
local toolbar = plugin:CreateToolbar("LoomDesigner")
local button = toolbar:CreateButton("Open", "Open LoomDesigner", "")

-- Dock
local info = DockWidgetPluginGuiInfo.new(
    Enum.InitialDockState.Left,
    true, false,
    600, 700,
    400, 350
)
local widget = plugin:CreateDockWidgetPluginGui("LoomDesignerWidget", info)
widget.Title = "Loom Designer"
widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Root layers
local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.fromScale(1,1)
root.BackgroundColor3 = Color3.fromRGB(28,28,28)
root.Parent = widget

local controlsHost = Instance.new("Frame")
controlsHost.Name = "ControlsHost"
controlsHost.Size = UDim2.fromScale(1,1)
controlsHost.BackgroundTransparency = 1
controlsHost.Parent = root

-- Overlay host for dropdowns/popups (stays last, high ZIndex)
local popupHost = Instance.new("Frame")
popupHost.Name = "PopupHost"
popupHost.Size = UDim2.fromScale(1,1)
popupHost.BackgroundTransparency = 1
popupHost.ZIndex = 1000
popupHost.Parent = root

-- Wire up UI
UI.Build(widget, plugin, {
    controlsHost = controlsHost,
    popupHost = popupHost,
})

button.Click:Connect(function()
    widget.Enabled = not widget.Enabled
    if widget.Enabled then
        LoomDesigner.Start(plugin)
    end
end)

widget.Enabled = true
