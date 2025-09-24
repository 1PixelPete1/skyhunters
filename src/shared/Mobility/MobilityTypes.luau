--[[
	MobilityTypes.luau
	Shared type definitions for the mobility system
	Handles leap (double jump) and thrust dash mechanics
]]

export type AbilityType = "Leap" | "Dash"

export type MobilityConfig = {
	-- Leap configuration
	LeapPower: number,
	LeapCooldown: number,
	LeapMaxCharges: number,
	LeapRechargeRate: number,
	LeapVerticalBoost: number,
	LeapHorizontalBoost: number,
	
	-- Dash configuration
	DashPower: number,
	DashCooldown: number,
	DashDistance: number,
	DashDuration: number,
	DashMaxCharges: number,
	
	-- Visual effects
	GustParticleCount: number,
	GustSpreadAngle: number,
	ZoomOutAmount: number,
	ZoomOutDuration: number,
	
	-- Server validation
	MaxPositionDelta: number,
	ValidationTimeout: number,
	TeleportBackThreshold: number,
	
	-- Equipment requirements (for future inventory integration)
	RequiresEquipment: boolean,
	RequiredLeapItem: string?,
	RequiredDashItem: string?
}

export type AbilityState = {
	LastUsed: number,
	ChargesRemaining: number,
	IsOnCooldown: boolean,
	NextChargeTime: number,
	IsEquipped: boolean
}

export type MobilityState = {
	Leap: AbilityState,
	Dash: AbilityState,
	LastValidPosition: Vector3,
	LastValidVelocity: Vector3,
	ValidationPending: boolean,
	LastAbilityUse: number? -- Made optional for backward compatibility
}

export type MobilityRequest = {
	Type: AbilityType | string, -- Allow string for flexibility
	StartPosition: Vector3,
	Direction: Vector3,
	Timestamp: number,
	SequenceNumber: number
}

export type MobilityResponse = {
	Success: boolean,
	SequenceNumber: number,
	CorrectedPosition: Vector3?,
	Reason: string?
}

export type PackVisuals = {
	MainPack: BasePart,
	LeapIndicator: BasePart,
	DashIndicator: BasePart,
	AttachmentWeld: WeldConstraint
}

export type EffectData = {
	Type: "Gust" | "Trail" | "Impact",
	Position: Vector3,
	Direction: Vector3,
	Power: number,
	Color: Color3?
}

-- Module table to ensure proper loading
local MobilityTypes = {}

return MobilityTypes
