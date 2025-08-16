package.path = "src/shared/?.luau;src/shared/?/init.luau;" .. package.path

local ModelUtils = require("ModelUtils")

if not Instance then
    Instance = {}
    function Instance.new(class)
        local obj = {class = class}
        setmetatable(obj, {
            __index = {
                IsA = function(self, c)
                    return self.class == c or (self.class == "WeldConstraint" and c == "Constraint")
                end,
            },
            __newindex = function(self, key, value)
                rawset(self, key, value)
                if key == "Parent" and value and value._children then
                    table.insert(value._children, self)
                end
            end,
        })
        return obj
    end
end

local model = {desc = {}}
function model:IsA(c) return c == "Model" end
function model:GetDescendants() return self.desc end
function model:FindFirstChildWhichIsA(class)
    for _, d in ipairs(self.desc) do
        if d:IsA(class) then return d end
    end
end

local root = {class = "BasePart", _children = {}}
function root:IsA(c) return self.class == c end
function root:IsDescendantOf(m) return m == model end
local part = {class = "BasePart"}
function part:IsA(c) return self.class == c end
function part:IsDescendantOf(m) return m == model end

model.desc = {root, part}
model.PrimaryPart = root

ModelUtils.weldModelRigid(model)
assert(#root._children == 1, "weld not created")
local weld = root._children[1]
assert(weld.Part0 == root and weld.Part1 == part, "weld incorrect")

print("held_rigidity_spec passed!")
