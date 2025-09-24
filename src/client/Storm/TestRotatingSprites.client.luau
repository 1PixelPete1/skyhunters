--!strict
-- TestRotatingSprites.client.luau
-- Quick test script to verify rotating sprites are working

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- Wait for character
local player = Players.LocalPlayer
if not player then return end

print("[TestRotatingSprites] Starting rotating sprite test...")

-- Simple rotating sprite implementation for testing
local function createTestSprites()
    local container = Instance.new("Folder")
    container.Name = "TestRotatingSprites"
    container.Parent = Workspace
    
    local sprites = {}
    local config = {
        count = 12,
        radius = 20,
        spriteSize = Vector3.new(6, 10, 0.2),
        rotationSpeed = 0.5,
    }
    
    -- Create sprites in a ring
    for i = 1, config.count do
        local angle = (i - 1) / config.count * math.pi * 2
        
        local part = Instance.new("Part")
        part.Name = "TestSprite_" .. i
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.Size = config.spriteSize
        part.Material = Enum.Material.ForceField
        part.BrickColor = BrickColor.new("Light blue")
        part.Transparency = 0.3
        part.Parent = container
        
        -- Add a decal for visibility
        local decal = Instance.new("Decal")
        decal.Face = Enum.NormalId.Front
        decal.Texture = "rbxasset://textures/particles/smoke_main.dds"
        decal.Color3 = Color3.fromRGB(150, 180, 200)
        decal.Transparency = 0.2
        decal.Parent = part
        
        table.insert(sprites, {
            part = part,
            decal = decal,
            angle = angle,
            baseAngle = angle,
        })
    end
    
    -- Update loop
    local connection = RunService.Heartbeat:Connect(function(dt)
        local camera = Workspace.CurrentCamera
        if not camera then return end
        
        local cameraPos = camera.CFrame.Position
        
        for _, sprite in ipairs(sprites) do
            -- Rotate around camera
            sprite.angle += config.rotationSpeed * dt
            
            -- Calculate position
            local x = math.cos(sprite.angle) * config.radius
            local z = math.sin(sprite.angle) * config.radius
            local position = cameraPos + Vector3.new(x, 5, z) -- 5 studs above camera
            
            -- Orient tangentially (key for seeing sprites at an angle)
            local tangent = Vector3.new(-math.sin(sprite.angle), 0, math.cos(sprite.angle))
            local up = Vector3.new(0, 1, 0)
            
            sprite.part.CFrame = CFrame.lookAt(position, position + tangent, up)
            
            -- Pulse effect for visibility
            local pulse = 0.7 + 0.3 * math.sin(tick() * 2 + sprite.baseAngle)
            sprite.part.Transparency = 1 - pulse
            sprite.decal.Transparency = 1 - pulse * 0.8
        end
    end)
    
    -- Cleanup after 30 seconds
    task.wait(30)
    connection:Disconnect()
    container:Destroy()
    print("[TestRotatingSprites] Test complete - sprites cleaned up")
end

-- Run the test
task.spawn(createTestSprites)
print("[TestRotatingSprites] Sprites should now be rotating around your camera for 30 seconds")
print("[TestRotatingSprites] You should see them at an angle when they're at the sides of your screen")
