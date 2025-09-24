--[[
	MobilityConfig.luau
	Configuration values for the mobility system
	Centralizes all tuning parameters for easy adjustment
]]

-- Note: Types module returns an empty table, just use for type exports
local MobilityTypes = script.Parent:FindFirstChild("MobilityTypes")
local Types = if MobilityTypes then require(MobilityTypes) else {}

-- Define config with proper typing
local Config = {
	-- Leap (Jump Pack) configuration
	LeapPower = 50, -- Base jump power
	LeapCooldown = 2.5, -- Seconds between leaps
	LeapMaxCharges = 2, -- Double jump capability
	LeapRechargeRate = 1.5, -- Seconds to recharge one leap
	LeapVerticalBoost = 30, -- Additional vertical velocity
	LeapHorizontalBoost = 15, -- Forward momentum boost
	
	-- Dash (Q key thrust) configuration
	DashPower = 80, -- Thrust force
	DashCooldown = 3, -- Seconds between dashes
	DashDistance = 30, -- Studs to travel (increased from 20)
	DashDuration = 0.3, -- Seconds for dash animation
	DashMaxCharges = 1, -- Single dash charge
	
	-- Visual effects configuration
	GustParticleCount = 12, -- Number of gust particles
	GustSpreadAngle = 45, -- Degrees of particle spread
	ZoomOutAmount = 10, -- Additional FOV during abilities
	ZoomOutDuration = 0.5, -- Seconds for zoom transition
	
	-- Server validation thresholds (ADJUSTED FOR LESS AGGRESSIVE VALIDATION)
	MaxPositionDelta = 150, -- Maximum allowed position change (increased from 100)
	ValidationTimeout = 2, -- Seconds before validation expires (increased from 1)
	TeleportBackThreshold = 100, -- Studs before teleport correction (increased from 50)
	
	-- Equipment integration (for future inventory system)
	RequiresEquipment = false, -- Set to true when inventory is ready
	RequiredLeapItem = nil, -- Item ID for leap equipment
	RequiredDashItem = nil, -- Item ID for dash equipment
}

-- Development mode overrides
if game:GetService("RunService"):IsStudio() then
	Config.LeapCooldown = 0.5 -- Faster cooldowns in Studio
	Config.DashCooldown = 0.5
	Config.RequiresEquipment = false -- Always allow in Studio
	Config.MaxPositionDelta = 200 -- Even more lenient in Studio
	
	print("[MobilityConfig] Studio mode - using development settings")
	print("  LeapCooldown:", Config.LeapCooldown)
	print("  DashCooldown:", Config.DashCooldown)
end

return Config
