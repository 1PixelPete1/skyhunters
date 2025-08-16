local ModelUtils = {}

function ModelUtils.ensurePrimaryPart(m)
    if m.PrimaryPart then return end
    local root = m:FindFirstChild("Root") or m:FindFirstChildWhichIsA("BasePart")
    if root then m.PrimaryPart = root end
end

function ModelUtils.stripExternalConstraints(m)
    for _, d in ipairs(m:GetDescendants()) do
        local isJoint = d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Motor6D")
            or d:IsA("HingeConstraint") or d:IsA("BallSocketConstraint") or d:IsA("RodConstraint")
        if isJoint then
            local a = d.Part0 or d.Attachment0
            local b = d.Part1 or d.Attachment1
            local aInside = not a or a:IsDescendantOf(m)
            local bInside = not b or b:IsDescendantOf(m)
            if not aInside or not bInside then d:Destroy() end
        end
    end
end

function ModelUtils.weldModelRigid(m)
    local root = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
    if not root then return end
    for _, p in ipairs(m:GetDescendants()) do
        if p:IsA("BasePart") and p ~= root then
            local w = Instance.new("WeldConstraint")
            w.Part0 = root
            w.Part1 = p
            w.Parent = root
        end
    end
end

function ModelUtils.insideHorizontalBounds(pos, bounds)
    return pos.X >= bounds.min.X and pos.X <= bounds.max.X
        and pos.Z >= bounds.min.Z and pos.Z <= bounds.max.Z
end

return ModelUtils

