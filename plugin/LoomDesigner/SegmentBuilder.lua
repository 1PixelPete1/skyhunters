--!strict
local SegmentBuilder = {}

-- Builds a single segment Instance according to materialization mode.
-- params = {
--   mode = "Model" | "Part",
--   depth = number,
--   isTerminal = boolean,
--   modelConfig = table?,
--   partConfig = table?,
--   resolver = any,
--   configModels = table?,
--   lengthScale = number?,
--   thicknessScale = number?,
-- }

local function getRefList(params)
    local modelCfg = params.modelConfig or {}
    local configModels = params.configModels or {}
    local depth = params.depth
    if params.isTerminal then
        if modelCfg.terminal then return modelCfg.terminal end
        if configModels.byDepth and configModels.byDepth.terminal then
            return configModels.byDepth.terminal
        end
    end
    if modelCfg.byDepth and modelCfg.byDepth[depth] then
        return modelCfg.byDepth[depth]
    end
    if configModels.byDepth and configModels.byDepth[depth] then
        return configModels.byDepth[depth]
    end
    return nil
end

local function parsePartType(s: any)
    s = tostring(s):lower()
    local map = {
        sphere = "Ball",
        ball = "Ball",
        round = "Ball",
        block = "Block",
        cube = "Block",
        cylinder = "Cylinder",
        tube = "Cylinder",
    }
    local name = map[s]
    if name then
        return Enum.PartType[name]
    end
    return Enum.PartType.Block
end

function SegmentBuilder.Build(params)
    if params.mode == "Part" then
        local cfg = params.partConfig or {}
        local pType = cfg.partType
        if typeof(pType) ~= "EnumItem" then
            pType = parsePartType(pType)
        end
        local part
        if pType == Enum.PartType.Ball then
            part = Instance.new("Part")
            part.Shape = Enum.PartType.Ball
        elseif pType == Enum.PartType.Cylinder then
            part = Instance.new("Part")
            part.Shape = Enum.PartType.Cylinder
        elseif pType == Enum.PartType.Wedge then
            part = Instance.new("WedgePart")
        elseif pType == Enum.PartType.CornerWedge then
            part = Instance.new("CornerWedgePart")
        else
            part = Instance.new("Part")
            part.Shape = Enum.PartType.Block
        end
        part.Material = cfg.material or Enum.Material.Plastic
        part.Color = cfg.color or Color3.new(1,1,1)
        part.Anchored = cfg.anchored ~= false
        part.CanCollide = cfg.canCollide or false
        part.CastShadow = cfg.castShadow ~= false

        local lengthScale = params.lengthScale or 1
        local thicknessScale = params.thicknessScale or 1
        local baseLength = cfg.baseLength or 2
        local baseThickness = cfg.baseThickness or 1
        local length = baseLength * lengthScale
        local thick = baseThickness * thicknessScale

        if pType == Enum.PartType.Ball then
            part.Size = Vector3.new(thick, thick, thick)
        elseif pType == Enum.PartType.Cylinder then
            part.Size = Vector3.new(thick, length, thick)
        else
            part.Size = Vector3.new(thick, length, thick)
        end
        return part
    else
        local resolver = params.resolver
        local refList = getRefList(params)
        local model
        if resolver and resolver.ResolveFromList then
            model = resolver.ResolveFromList(refList)
        elseif type(resolver) == "function" then
            model = resolver(refList)
        end
        if not model then return nil end

        local cfg = params.modelConfig or {}
        local uniform = cfg.uniformScale
        local scaleVec = cfg.scale
        if model:IsA("Model") then
            for _, part in ipairs(model:GetDescendants()) do
                if part:IsA("BasePart") then
                    local s = part.Size
                    if scaleVec then
                        part.Size = Vector3.new(s.X * (scaleVec.X), s.Y * (scaleVec.Y), s.Z * (scaleVec.Z))
                    elseif uniform then
                        part.Size = s * uniform
                    end
                end
            end
            local pivot = cfg.pivot or "AutoPrimary"
            if pivot == "AutoPrimary" or pivot == "FirstPart" then
                if not model.PrimaryPart then
                    local pp = model:FindFirstChildWhichIsA("BasePart", true)
                    if pp then model.PrimaryPart = pp end
                end
            end
            if cfg.alignAxis == "Z" then
                local cf = model:GetPivot()
                model:PivotTo(cf * CFrame.Angles(0, math.rad(90), 0))
            end
        elseif model:IsA("BasePart") then
            local s = model.Size
            if scaleVec then
                model.Size = Vector3.new(s.X * scaleVec.X, s.Y * scaleVec.Y, s.Z * scaleVec.Z)
            elseif uniform then
                model.Size = s * uniform
            end
            if cfg.alignAxis == "Z" then
                model.CFrame = model.CFrame * CFrame.Angles(0, math.rad(90), 0)
            end
        end
        return model
    end
end

return SegmentBuilder
