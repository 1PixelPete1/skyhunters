--!strict
-- SetupLanternKit.server.luau
-- Creates temporary test assets for the lantern system
-- Run this once in Studio to set up the kit

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function createAttachment(parent: Instance, name: string, position: Vector3?)
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = position or Vector3.zero
	attachment.Parent = parent
	return attachment
end

local function createSimplePart(name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	return part
end

local function setupLanternKit()
	-- Check if kit already exists
	if ReplicatedStorage:FindFirstChild("LanternKit") then
		print("LanternKit already exists. Removing old version...")
		ReplicatedStorage.LanternKit:Destroy()
	end
	
	-- Create main kit folder
	local kit = Instance.new("Folder")
	kit.Name = "LanternKit"
	
	-- Create category folders
	local baseFolder = Instance.new("Folder")
	baseFolder.Name = "Base"
	baseFolder.Parent = kit
	
	local poleFolder = Instance.new("Folder")
	poleFolder.Name = "Pole"
	poleFolder.Parent = kit
	
	local headFolder = Instance.new("Folder")
	headFolder.Name = "Head"
	headFolder.Parent = kit
	
	local decorFolder = Instance.new("Folder")
	decorFolder.Name = "Decor"
	decorFolder.Parent = kit
	
	-- Create Base prefabs
	
	-- StoneDisk
	local stoneDisk = Instance.new("Model")
	stoneDisk.Name = "StoneDisk"
	
	local diskPart = Instance.new("Part")
	diskPart.Name = "Base"
	diskPart.Shape = Enum.PartType.Cylinder
	diskPart.Size = Vector3.new(0.5, 3, 3)
	diskPart.Color = Color3.fromRGB(120, 120, 120)
	diskPart.Material = Enum.Material.Slate
	diskPart.Anchored = true
	diskPart.CanCollide = false
	diskPart.CFrame = CFrame.Angles(0, 0, math.pi/2)
	diskPart.Parent = stoneDisk
	
	createAttachment(diskPart, "TopSocket", Vector3.new(0.25, 0, 0))
	stoneDisk.PrimaryPart = diskPart
	stoneDisk.Parent = baseFolder
	
	-- SquareBlock
	local squareBlock = Instance.new("Model")
	squareBlock.Name = "SquareBlock"
	
	local blockPart = createSimplePart("Base", Vector3.new(2, 0.8, 2), Color3.fromRGB(100, 100, 100))
	blockPart.Material = Enum.Material.Concrete
	blockPart.Parent = squareBlock
	
	createAttachment(blockPart, "TopSocket", Vector3.new(0, 0.4, 0))
	squareBlock.PrimaryPart = blockPart
	squareBlock.Parent = baseFolder
	
	-- Tripod
	local tripod = Instance.new("Model")
	tripod.Name = "Tripod"
	
	local tripodCenter = createSimplePart("Center", Vector3.new(0.5, 0.3, 0.5), Color3.fromRGB(80, 60, 40))
	tripodCenter.Material = Enum.Material.Wood
	tripodCenter.Parent = tripod
	
	for i = 1, 3 do
		local angle = (i - 1) * (2 * math.pi / 3)
		local leg = createSimplePart("Leg" .. i, Vector3.new(0.2, 1.5, 0.2), Color3.fromRGB(80, 60, 40))
		leg.Material = Enum.Material.Wood
		
		local x = math.cos(angle) * 0.8
		local z = math.sin(angle) * 0.8
		leg.CFrame = CFrame.new(x, -0.5, z) * CFrame.Angles(math.rad(15), angle, 0)
		leg.Parent = tripod
	end
	
	createAttachment(tripodCenter, "TopSocket", Vector3.new(0, 0.15, 0))
	tripod.PrimaryPart = tripodCenter
	tripod.Parent = baseFolder
	
	-- Create Pole prefabs
	
	-- Cylinder (for pole segments)
	local cylinder = createSimplePart("Cylinder", Vector3.new(2, 0.3, 0.3), Color3.fromRGB(92, 64, 51))
	cylinder.Shape = Enum.PartType.Cylinder
	cylinder.Material = Enum.Material.Wood
	cylinder.Parent = poleFolder
	
	-- Arm (for branches)
	local arm = createSimplePart("Arm", Vector3.new(1.5, 0.2, 0.2), Color3.fromRGB(92, 64, 51))
	arm.Shape = Enum.PartType.Cylinder
	arm.Material = Enum.Material.Wood
	arm.Parent = poleFolder
	
	-- Create Head prefabs
	
	-- HeadA (simple lantern head)
	local headA = Instance.new("Model")
	headA.Name = "HeadA"
	
	-- Main lantern body
	local lanternBody = createSimplePart("Body", Vector3.new(1.2, 1.6, 1.2), Color3.fromRGB(200, 180, 140))
	lanternBody.Material = Enum.Material.Neon
	lanternBody.Transparency = 0.3
	lanternBody.Parent = headA
	
	-- Top cap
	local topCap = createSimplePart("TopCap", Vector3.new(1.4, 0.2, 1.4), Color3.fromRGB(60, 40, 30))
	topCap.Material = Enum.Material.Wood
	topCap.Position = Vector3.new(0, 0.9, 0)
	topCap.Parent = headA
	
	-- Bottom cap
	local bottomCap = createSimplePart("BottomCap", Vector3.new(1.4, 0.2, 1.4), Color3.fromRGB(60, 40, 30))
	bottomCap.Material = Enum.Material.Wood
	bottomCap.Position = Vector3.new(0, -0.9, 0)
	bottomCap.Parent = headA
	
	-- Add attachments
	createAttachment(topCap, "HangSocket", Vector3.new(0, 0.1, 0))
	createAttachment(lanternBody, "LightSocket", Vector3.new(0, 0, 0))
	
	headA.PrimaryPart = lanternBody
	headA.Parent = headFolder
	
	-- Create Decoration prefabs
	
	-- FlagSmall
	local flagSmall = Instance.new("Model")
	flagSmall.Name = "FlagSmall"
	
	local flagPole = createSimplePart("Pole", Vector3.new(0.05, 0.8, 0.05), Color3.fromRGB(100, 80, 60))
	flagPole.Parent = flagSmall
	
	local flagCloth = createSimplePart("Cloth", Vector3.new(0.01, 0.4, 0.6), Color3.fromRGB(200, 50, 50))
	flagCloth.Material = Enum.Material.Fabric
	flagCloth.Position = Vector3.new(0, 0.2, 0.3)
	flagCloth.Parent = flagSmall
	
	createAttachment(flagPole, "Mount", Vector3.new(0, -0.4, 0))
	flagSmall.PrimaryPart = flagPole
	flagSmall.Parent = decorFolder
	
	-- ChimeSmall
	local chimeSmall = Instance.new("Model")
	chimeSmall.Name = "ChimeSmall"
	
	local chimeTop = createSimplePart("Top", Vector3.new(0.3, 0.1, 0.3), Color3.fromRGB(180, 140, 100))
	chimeTop.Material = Enum.Material.Wood
	chimeTop.Parent = chimeSmall
	
	for i = 1, 3 do
		local tube = createSimplePart("Tube" .. i, Vector3.new(0.08, 0.6, 0.08), Color3.fromRGB(200, 170, 100))
		tube.Shape = Enum.PartType.Cylinder
		tube.Material = Enum.Material.Metal
		
		local offset = (i - 2) * 0.1
		tube.Position = Vector3.new(offset, -0.35, 0)
		tube.Parent = chimeSmall
	end
	
	createAttachment(chimeTop, "Mount", Vector3.new(0, 0.05, 0))
	chimeSmall.PrimaryPart = chimeTop
	chimeSmall.Parent = decorFolder
	
	-- CharmLeaf
	local charmLeaf = Instance.new("Model")
	charmLeaf.Name = "CharmLeaf"
	
	local leafString = createSimplePart("String", Vector3.new(0.02, 0.3, 0.02), Color3.fromRGB(150, 130, 100))
	leafString.Material = Enum.Material.Fabric
	leafString.Parent = charmLeaf
	
	local leaf = createSimplePart("Leaf", Vector3.new(0.3, 0.02, 0.2), Color3.fromRGB(100, 150, 80))
	leaf.Material = Enum.Material.Grass
	leaf.Position = Vector3.new(0, -0.2, 0)
	leaf.Parent = charmLeaf
	
	createAttachment(leafString, "Mount", Vector3.new(0, 0.15, 0))
	charmLeaf.PrimaryPart = leafString
	charmLeaf.Parent = decorFolder
	
	-- Parent kit to ReplicatedStorage
	kit.Parent = ReplicatedStorage
	
	print("✅ LanternKit setup complete!")
	print("Created:")
	print("  - 3 Base models (StoneDisk, SquareBlock, Tripod)")
	print("  - 2 Pole parts (Cylinder, Arm)")
	print("  - 1 Head model (HeadA)")
	print("  - 3 Decoration models (FlagSmall, ChimeSmall, CharmLeaf)")
end

-- Run setup
setupLanternKit()

return {}
