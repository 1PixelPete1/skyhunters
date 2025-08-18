--!strict
local VisualScene = {}
local _previewModel: Model? = nil
local _firstBasePart: BasePart? = nil

function VisualScene.SetPreviewModel(m: Model)
    _previewModel = m
    _firstBasePart = nil
end

local function ensurePrimary(part: BasePart)
    if _previewModel and not _previewModel.PrimaryPart then
        _previewModel.PrimaryPart = part
    end
end

function VisualScene.Clear()
    if not _previewModel then return end
    for _, ch in ipairs(_previewModel:GetChildren()) do
        if ch:IsA("BasePart") or ch:IsA("Model") then ch:Destroy() end
    end
end

-- Accepts either:
--   - an Instance (BasePart/Model) to parent
--   - a spec table:
--       { class="Part", shape="Ball"/Enum.PartType.Ball, size=Vector3, cframe=CFrame,
--         material=Enum.Material.SmoothPlastic, color=Color3, anchored=true, canCollide=false, name="Segment" }
function VisualScene.Spawn(spec)
    if not _previewModel then return nil end

    if typeof(spec) == "Instance" then
        spec.Parent = _previewModel
        if spec:IsA("BasePart") then ensurePrimary(spec) end
        return spec
    end
    if type(spec) ~= "table" then return nil end

    local part = Instance.new("Part")
    part.Name = spec.name or "Segment"
    part.Anchored = (spec.anchored ~= false)
    part.CanCollide = (spec.canCollide == true)
    part.Material = (typeof(spec.material) == "EnumItem" and spec.material) or Enum.Material.SmoothPlastic
    if spec.color then
        local c = spec.color
        if typeof(c) == "Color3" then part.Color = c end
    end

    -- Shape + Size
    local shape = spec.shape
    if typeof(shape) == "EnumItem" then
        part.Shape = shape
    elseif type(shape) == "string" then
        local s = shape:lower()
        if s == "ball" or s == "sphere" or s == "round" then
            part.Shape = Enum.PartType.Ball
        elseif s == "cylinder" or s == "tube" then
            part.Shape = Enum.PartType.Cylinder
        else
            part.Shape = Enum.PartType.Block
        end
    end
    if typeof(spec.size) == "Vector3" then
        part.Size = spec.size
    end
    if typeof(spec.cframe) == "CFrame" then
        part.CFrame = spec.cframe
    end

    part.Parent = _previewModel
    ensurePrimary(part)
    return part
end

return VisualScene
