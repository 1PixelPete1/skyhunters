--!strict
-- LanternConeController.luau
-- Manages lantern cone calculations and forbidden wedge determination

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local StormTypes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("StormTypes"))
local StormConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("StormConfig"))

type ConePose = StormTypes.ConePose
type ForbiddenAzimuth = StormTypes.ForbiddenAzimuth

local coneConfig = StormConfig.Cone or {
    halfAngleDeg = 28,
    innerClear = 5,
    innerSoft = 9,
    outerSoft = 14,
    forbiddenPadDeg = 6,
}

local LanternConeController = {}
LanternConeController.Enabled = false  -- Default to disabled until we find lantern state

local function getLanternEnabled(): boolean
    local player = Players.LocalPlayer
    if not player then return false end

    local lanternEnabled = player:GetAttribute("LanternEnabled")
    if lanternEnabled ~= nil then
        return lanternEnabled
    end

    local character = player.Character
    if character then
        local lanternState = character:FindFirstChild("LanternState")
        if lanternState and lanternState:IsA("BoolValue") then
            return lanternState.Value
        end
    end

    local playerStates = game:GetService("ReplicatedStorage"):FindFirstChild("PlayerStates")
    if playerStates then
        local playerState = playerStates:FindFirstChild(player.Name)
        if playerState then
            local lanternValue = playerState:FindFirstChild("LanternEnabled")
            if lanternValue and lanternValue:IsA("BoolValue") then
                return lanternValue.Value
            end
        end
    end

    return true
end

local function buildPoseFromCamera(camera: Camera?): ConePose
    if not camera then
        return {
            origin = Vector3.new(),
            dir = Vector3.new(0, 0, -1),
            halfAngleDeg = coneConfig.halfAngleDeg,
            innerClear = coneConfig.innerClear,
            innerSoft = coneConfig.innerSoft,
            outerSoft = coneConfig.outerSoft,
        }
    end

    return {
        origin = camera.CFrame.Position,
        dir = camera.CFrame.LookVector,
        halfAngleDeg = coneConfig.halfAngleDeg,
        innerClear = coneConfig.innerClear,
        innerSoft = coneConfig.innerSoft,
        outerSoft = coneConfig.outerSoft,
    }
end

function LanternConeController:GetConePose(): ConePose
    return buildPoseFromCamera(Workspace.CurrentCamera)
end

function LanternConeController:GetForbiddenAzimuth(): ForbiddenAzimuth
    if not self.Enabled then
        return { minDeg = 0, maxDeg = 0 }
    end

    local camera = Workspace.CurrentCamera
    if not camera then
        return { minDeg = 0, maxDeg = 0 }
    end

    local lookDir = camera.CFrame.LookVector
    local yaw = math.atan2(lookDir.X, lookDir.Z)
    local yawDeg = math.deg(yaw)

    local halfAngle = coneConfig.halfAngleDeg
    local minDeg = (yawDeg - halfAngle - coneConfig.forbiddenPadDeg) % 360
    local maxDeg = (yawDeg + halfAngle + coneConfig.forbiddenPadDeg) % 360

    return {
        minDeg = minDeg,
        maxDeg = maxDeg,
    }
end

function LanternConeController:IsEnabled(): boolean
    return self.Enabled
end

function LanternConeController:UpdateLanternState()
    self.Enabled = getLanternEnabled()
end

function LanternConeController:Init()
    self:UpdateLanternState()

    task.spawn(function()
        while true do
            task.wait(0.5)
            self:UpdateLanternState()
        end
    end)

    local player = Players.LocalPlayer
    if player then
        player.AttributeChanged:Connect(function(attribute)
            if attribute == "LanternEnabled" then
                self:UpdateLanternState()
            end
        end)

        player.CharacterAdded:Connect(function()
            task.wait(1)
            self:UpdateLanternState()
        end)
    end
end

return LanternConeController
