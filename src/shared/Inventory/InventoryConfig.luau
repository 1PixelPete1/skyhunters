--!strict
-- InventoryConfig.luau
-- Configuration for the inventory system

local InventoryConfig = {}

-- UI Configuration
InventoryConfig.UI = {
	-- Colors
	Colors = {
		Background = Color3.fromRGB(28, 31, 36),
		SecondaryBackground = Color3.fromRGB(35, 39, 46),
		Accent = Color3.fromRGB(88, 101, 242),
		Border = Color3.fromRGB(45, 50, 58),
		Text = Color3.fromRGB(255, 255, 255),
		TextSecondary = Color3.fromRGB(180, 185, 195),
		
		-- Rarity colors
		Common = Color3.fromRGB(200, 200, 200),
		Uncommon = Color3.fromRGB(96, 211, 96),
		Rare = Color3.fromRGB(96, 164, 245),
		Epic = Color3.fromRGB(185, 96, 255),
		Legendary = Color3.fromRGB(255, 170, 0)
	},
	
	-- Sizes and positions
	BuildingInventory = {
		Position = UDim2.new(0.5, 0, 1, 60), -- Start below the screen
		Size = UDim2.new(0, 700, 0, 500),
		AnimatedPosition = UDim2.new(0.5, 0, 1, -120), -- Slides just above the hotbar
		CornerRadius = UDim.new(0, 12),
		CategoryWidth = 150,
		GridColumns = 8,
		GridRows = 6,
		ItemSize = 60,
		ItemSpacing = 5
	},
	
	EquipmentInventory = {
		Position = UDim2.new(0, 80, 0.5, 0), -- Left side
		Size = UDim2.new(0, 460, 0, 640),
		CornerRadius = UDim.new(0, 12),
		CategoryWidth = 350,
		SlotSize = 70,
		CurseSlotSize = 60
	},
	
	Hotbar = {
		Position = UDim2.new(0.5, 0, 1, -80),
		SlotSize = 60,
		Spacing = 5,
		MaxSlots = 10,
		CornerRadius = UDim.new(0, 8)
	},
	
	Buttons = {
		BuildingButton = {
			Position = UDim2.new(0.5, -80, 1, -140),
			Size = UDim2.new(0, 70, 0, 40),
			Icon = "rbxassetid://7734022107" -- Building icon
		},
		EquipmentButton = {
			Position = UDim2.new(0.5, 10, 1, -140),
			Size = UDim2.new(0, 70, 0, 40),
			Icon = "rbxassetid://7734053426" -- Equipment icon
		}
	},
	
	-- Animation settings
	Animations = {
		SlideSpeed = 0.3,
		FadeSpeed = 0.2,
		HoverScale = 1.05,
		ClickScale = 0.95,
		EasingStyle = Enum.EasingStyle.Quart,
		EasingDirection = Enum.EasingDirection.Out
	}
}

-- Gameplay Configuration
InventoryConfig.Gameplay = {
	-- Inventory limits
	MaxBuildingSlots = 48, -- 8x6 grid
	MaxCurseSlots = 3,
	MaxHotbarSlots = 10,
	
	-- Stack sizes
	DefaultMaxStack = 999,
	
	-- Categories
	BuildingCategories = {
		{id = "all", name = "All", icon = "rbxassetid://7734010488"},
		{id = "lantern", name = "Lanterns", icon = "rbxassetid://7734003107"},
		{id = "plotupgrade", name = "Plot Upgrades", icon = "rbxassetid://7734042139"},
		{id = "decoration", name = "Decoration", icon = "rbxassetid://7734000129"}
	},
	
	EquipmentCategories = {
		{id = "all", name = "All", icon = "rbxassetid://7734010488"},
		{id = "weapon", name = "Weapons", icon = "rbxassetid://7734022107"},
		{id = "lanternHead", name = "Lantern Head", icon = "rbxassetid://7734003107"},
		{id = "mobility", name = "Mobility", icon = "rbxassetid://7734053426"},
		{id = "curse", name = "Curses", icon = "rbxassetid://7733955511"}
	},
	
	-- Keybinds
	Keybinds = {
		OpenBuildingInventory = Enum.KeyCode.B,
		OpenEquipmentInventory = Enum.KeyCode.E,
		CloseInventory = Enum.KeyCode.Escape,
		Hotbar = {
			Enum.KeyCode.One,
			Enum.KeyCode.Two,
			Enum.KeyCode.Three,
			Enum.KeyCode.Four,
			Enum.KeyCode.Five,
			Enum.KeyCode.Six,
			Enum.KeyCode.Seven,
			Enum.KeyCode.Eight,
			Enum.KeyCode.Nine,
			Enum.KeyCode.Zero
		}
	}
}

-- Effects Configuration
InventoryConfig.Effects = {
	-- Glow gradient for compatible slots
	GlowGradient = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(88, 101, 242)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 140, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(88, 101, 242))
	}),
	
	-- Darkened color for incompatible slots
	IncompatibleAlpha = 0.3,
	
	-- Drag preview settings
	DragPreviewAlpha = 0.7,
	DragPreviewOffset = Vector2.new(10, 10)
}

-- Performance Configuration
InventoryConfig.Performance = {
	-- Rendering optimizations
	HideEffectsInMenu = true,
	DisableWeatherInMenu = true,
	UseObjectPooling = true,
	PoolSize = 100,
	
	-- Update rates
	UpdateDebounce = 0.1, -- seconds
	AnimationThrottle = 30, -- FPS
	
	-- Lazy loading
	LazyLoadDelay = 0.05, -- seconds between item loads
	BatchSize = 10 -- Items to load per batch
}

return InventoryConfig

