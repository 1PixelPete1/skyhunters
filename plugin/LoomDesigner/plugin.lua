--!strict
-- LoomDesigner Studio Plugin entry point

local LoomDesigner = require(script.Parent.Main)

local toolbar = plugin:CreateToolbar("LoomDesigner")
local button = toolbar:CreateButton("Open", "Open LoomDesigner window", "")

local DockWidgetPluginGuiInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Left,
	true, false,
	400, 500,
	200, 200
)

local widget = plugin:CreateDockWidgetPluginGui("LoomDesignerWidget", DockWidgetPluginGuiInfo)
widget.Title = "Loom Designer"

-- Root UI container
local root = Instance.new("Frame")
root.Size = UDim2.fromScale(1,1)
root.BackgroundColor3 = Color3.fromRGB(30,30,30)
root.Parent = widget

-- Preview area
local previewFrame = Instance.new("Frame")
previewFrame.Size = UDim2.new(1, -20, 1, -100)
previewFrame.Position = UDim2.new(0,10,0,90)
previewFrame.BackgroundColor3 = Color3.fromRGB(45,45,45)
previewFrame.Parent = root

-- "Generate Branch" button
local genButton = Instance.new("TextButton")
genButton.Size = UDim2.new(0,150,0,30)
genButton.Position = UDim2.new(0,10,0,10)
genButton.Text = "Generate Branch"
genButton.BackgroundColor3 = Color3.fromRGB(70,130,180)
genButton.TextColor3 = Color3.new(1,1,1)
genButton.Parent = root

-- "Randomize Seed" button
local seedButton = Instance.new("TextButton")
seedButton.Size = UDim2.new(0,150,0,30)
seedButton.Position = UDim2.new(0,10,0,50)
seedButton.Text = "Randomize Seed"
seedButton.BackgroundColor3 = Color3.fromRGB(70,130,180)
seedButton.TextColor3 = Color3.new(1,1,1)
seedButton.Parent = root

-- Growth % slider (super simple: click to set %)
local growthSlider = Instance.new("TextButton")
growthSlider.Size = UDim2.new(0,150,0,30)
growthSlider.Position = UDim2.new(0,10,0,90)
growthSlider.Text = "Growth: 50%"
growthSlider.BackgroundColor3 = Color3.fromRGB(70,130,180)
growthSlider.TextColor3 = Color3.new(1,1,1)
growthSlider.Parent = root

-- Hook up actions
genButton.MouseButton1Click:Connect(function()
	LoomDesigner.SetConfigId("oak_branch") -- hardcode for now
	LoomDesigner.RebuildPreview(previewFrame)
end)

seedButton.MouseButton1Click:Connect(function()
	LoomDesigner.RandomizeSeed()
	LoomDesigner.RebuildPreview(previewFrame)
end)

growthSlider.MouseButton1Click:Connect(function()
	-- toggle between 0, 50, 100% for demo
	if growthSlider.Text == "Growth: 50%" then
		LoomDesigner.SetGrowthPercent(100)
		growthSlider.Text = "Growth: 100%"
	elseif growthSlider.Text == "Growth: 100%" then
		LoomDesigner.SetGrowthPercent(0)
		growthSlider.Text = "Growth: 0%"
	else
		LoomDesigner.SetGrowthPercent(50)
		growthSlider.Text = "Growth: 50%"
	end
	LoomDesigner.RebuildPreview(previewFrame)
end)

button.Click:Connect(function()
	widget.Enabled = not widget.Enabled
	if widget.Enabled then
		LoomDesigner.Start(plugin)
	end
end)

widget.Enabled = false
