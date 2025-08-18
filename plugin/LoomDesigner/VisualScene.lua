--!strict
local RequireUtil = require(script.Parent.RequireUtil)
local VisualScene = {}

local previewModel: Model? = nil

function VisualScene.GetPreviewRoot()
    local ws = game:GetService("Workspace")
    local root = ws:FindFirstChild("LoomPreview")
    if not root then
        root = Instance.new("Folder")
        root.Name = "LoomPreview"
        root.Parent = ws
    end
    return root
end

function VisualScene.SetPreviewModel(model: Model)
    previewModel = model
end

function VisualScene.Clear()
    if previewModel then
        for _, c in ipairs(previewModel:GetChildren()) do
            c:Destroy()
        end
    end
end

function VisualScene.Spawn(instance, cf)
    local root = previewModel or VisualScene.GetPreviewRoot()
    if cf then
        -- Apply CFrame to Models or Parts
        if instance:IsA("Model") then
            if not instance.PrimaryPart then
                -- Try to set a primary part automatically
                local pp = instance:FindFirstChildWhichIsA("BasePart", true)
                if pp then instance.PrimaryPart = pp end
            end
            if instance.PrimaryPart then
                instance:PivotTo(cf)
            end
        elseif instance:IsA("BasePart") then
            instance.CFrame = cf
            instance.Anchored = true
        end
    end
    instance.Parent = root
end

return VisualScene
