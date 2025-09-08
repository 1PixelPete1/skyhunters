--!strict
local RS = game:GetService("ReplicatedStorage")
local Graph = require(game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Boundary"):WaitForChild("BoundaryGraph"))

return function()
    local pass, fail = 0, 0
    local function ok(cond: boolean, label: string)
        if cond then pass += 1 else fail += 1; print("[FAIL] " .. label) end
    end

    local v0 = Graph.getVersion()
    local n1 = Graph.addNode({ id = "A", posXZ = Vector2.new(0,0), radius = 10 })
    ok(n1 ~= nil, "addNode A")
    local v1 = Graph.getVersion(); ok(v1 > v0, "version++ addNode")
    local n2 = Graph.addNode({ id = "B", posXZ = Vector2.new(20,0), radius = 12 })
    ok(n2 ~= nil, "addNode B")
    local e1 = Graph.addEdge({ id = "E", a = "A", b = "B", path = { Vector2.new(0,0), Vector2.new(20,0) }, width = 8 })
    ok(e1 ~= nil, "addEdge E")
    local v2 = Graph.getVersion(); ok(v2 > v1, "version++ addEdge")

    -- snapshot isolation
    local snap = Graph.snapshot()
    local before = snap.nodes["A"].radius
    snap.nodes["A"].radius = 999 -- attempt to mutate
    local snap2 = Graph.snapshot()
    ok(snap2.nodes["A"].radius == before, "snapshot immutable copy")

    print(("BoundaryGraph tests: %d pass, %d fail"):format(pass, fail))
    return fail == 0
end

