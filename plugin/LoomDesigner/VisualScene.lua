--!strict
local VisualScene = {}
local _previewModel: Model? = nil
local _firstBasePart: BasePart? = nil

local InsertService = game:GetService("InsertService")

local function spawnAsset(assetId: number, parent: Instance): Instance?
    local ok, model = pcall(function()
        return InsertService:LoadAsset(assetId)
    end)
    if not ok or not model then return nil end
    model.Parent = parent
    return model
end

-- helper to apply attributes to instances safely
local function applyAttributes(inst: Instance, attrs)
    if type(attrs) == "table" then
        for k, v in pairs(attrs) do
            pcall(function()
                inst:SetAttribute(k, v)
            end)
        end
    end
end

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
        applyAttributes(spec, nil)
        return spec
    end
    if type(spec) ~= "table" then return nil end

    if spec.instance then
        local inst = spec.instance
        inst.Parent = _previewModel
        if spec.scale then
            if inst:IsA("Model") then
                for _, p in ipairs(inst:GetDescendants()) do
                    if p:IsA("BasePart") then
                        p.Size = Vector3.new(
                            p.Size.X * spec.scale.X,
                            p.Size.Y * spec.scale.Y,
                            p.Size.Z * spec.scale.Z
                        )
                    end
                end
            elseif inst:IsA("BasePart") then
                inst.Size = Vector3.new(
                    inst.Size.X * spec.scale.X,
                    inst.Size.Y * spec.scale.Y,
                    inst.Size.Z * spec.scale.Z
                )
            end
        end
        if typeof(spec.cframe) == "CFrame" then
            if inst:IsA("Model") then
                inst:PivotTo(spec.cframe)
            else
                inst.CFrame = spec.cframe
            end
        end
        if inst:IsA("BasePart") then ensurePrimary(inst) end
        applyAttributes(inst, spec.attributes)
        return inst
    end

    if spec.assetId then
        local inst = spawnAsset(spec.assetId, _previewModel)
        if inst then
            if typeof(spec.cframe) == "CFrame" then
                local bp
                if inst:IsA("Model") then
                    bp = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
                elseif inst:IsA("BasePart") then
                    bp = inst
                end
                if bp then
                    local delta = spec.cframe:ToWorldSpace(CFrame.new())
                    inst:PivotTo(delta)
                end
            end
            if inst:IsA("BasePart") then ensurePrimary(inst) end
            applyAttributes(inst, spec.attributes)
            return inst
        end
        -- fall back to primitive part if asset failed
    end

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
    applyAttributes(part, spec.attributes)
    return part
end

return VisualScene
