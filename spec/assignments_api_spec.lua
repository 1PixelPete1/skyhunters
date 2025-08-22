package.path = "plugin/?.lua;plugin/?/init.lua;src/server/?.luau;src/server/?/init.luau;src/shared/?.luau;src/shared/?/init.luau;src/client/?.luau;src/client/?/init.luau;" .. package.path

local ok, LoomDesigner = pcall(require, "LoomDesigner/Main")
if not ok then
    print("assignments_api_spec.lua skipped: " .. tostring(LoomDesigner))
    return
end
if LoomDesigner.Start then LoomDesigner.Start(nil) end

-- ensure branches exist for assignments
LoomDesigner.CreateBranch("trunkBranch", {kind = "straight"})
LoomDesigner.CreateBranch("childBranch", {kind = "straight"})

-- trunk assignment
LoomDesigner.SetTrunk("trunkBranch")

-- add child assignment
LoomDesigner.AddChild("trunkBranch", "childBranch", "side", 2)

local a = LoomDesigner.GetAssignments()
assert(a.trunk == "trunkBranch", "trunk not set")
assert(#a.children == 1, "child not added")
assert(a.children[1].parent == "trunkBranch", "parent mismatch")
assert(a.children[1].child == "childBranch", "child mismatch")
assert(a.children[1].placement == "side", "placement mismatch")
assert(a.children[1].count == 2, "count mismatch")

-- remove child
LoomDesigner.RemoveChild(1)
local b = LoomDesigner.GetAssignments()
assert(#b.children == 0, "child not removed")

print("assignments_api_spec.lua ok")
