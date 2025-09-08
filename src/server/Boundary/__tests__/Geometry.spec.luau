--!strict
local RS = game:GetService("ReplicatedStorage")
local BoundaryGeometry = require(game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Boundary"):WaitForChild("BoundaryGeometry"))

return function()
    local pass, fail = 0, 0
    local function ok(cond: boolean, label: string)
        if cond then pass += 1 else fail += 1; print("[FAIL] " .. label) end
    end

    local graph = {
        version = 1,
        nodes = {
            A = { id = "A", posXZ = Vector2.new(0,0), radius = 10 },
            B = { id = "B", posXZ = Vector2.new(30,0), radius = 10 },
        },
        edges = {
            E = { id = "E", a = "A", b = "B", path = { Vector2.new(0,0), Vector2.new(30,0) }, width = 8 },
        },
    }

    local soup = select(1, BoundaryGeometry.buildSoup(graph))
    ok(soup.version == graph.version, "soup version matches")
    local okv, reason = BoundaryGeometry.validateSoup(soup, graph)
    ok(okv, "soup validates: " .. tostring(reason))

    -- Expect two rims for E with equal vertex counts
    local counts = {}
    for _, pl in ipairs(soup.polylines) do
        local id = pl.id or ""
        local eid, side = id:match("edge:(.+):([LR])")
        if eid == "E" and side then counts[#counts+1] = #pl.pts end
    end
    ok(#counts == 2 and counts[1] == counts[2], "equal rim vertex counts")

    print(("BoundaryGeometry tests: %d pass, %d fail"):format(pass, fail))
    return fail == 0
end
