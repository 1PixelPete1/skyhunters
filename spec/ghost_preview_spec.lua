package.path = "src/shared/?.luau;src/shared/?/init.luau;" .. package.path

local ModelUtils = require("ModelUtils")

local model = {desc = {}}
function model:IsA(class) return class == "Model" end
function model:GetDescendants() return self.desc end

local function part(name)
    local p = {Name = name, class = "BasePart"}
    function p:IsA(c) return self.class == c end
    function p:IsDescendantOf(m) return m == model end
    table.insert(model.desc, p)
    return p
end

local root = part("Root")
model.PrimaryPart = root
local inside = part("Inside")
local outside = {Name = "Outside", class = "BasePart"}
function outside:IsA(c) return self.class == c end
function outside:IsDescendantOf(m) return false end

local weldInside = {class = "WeldConstraint", Part0 = root, Part1 = inside, destroyed = false}
function weldInside:IsA(c) return self.class == c or c == "Constraint" end
function weldInside:Destroy() self.destroyed = true end

local weldOutside = {class = "WeldConstraint", Part0 = root, Part1 = outside, destroyed = false}
function weldOutside:IsA(c) return self.class == c or c == "Constraint" end
function weldOutside:Destroy() self.destroyed = true end

model.desc[#model.desc+1] = weldInside
model.desc[#model.desc+1] = weldOutside

ModelUtils.stripExternalConstraints(model)
assert(weldInside.destroyed == false, "internal weld removed")
assert(weldOutside.destroyed == true, "external weld not removed")

print("ghost_preview_spec passed!")
