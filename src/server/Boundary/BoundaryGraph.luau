--!strict
-- BoundaryGraph: single authoritative in-memory boundary graph (server-only)

local RS = game:GetService("ReplicatedStorage")
local BoundaryTypes = require(RS.Shared.Boundary.BoundaryTypes)

export type BoundaryNode = BoundaryTypes.BoundaryNode
export type BoundaryEdge = BoundaryTypes.BoundaryEdge
export type BoundaryGraph = BoundaryTypes.BoundaryGraph

local Graph = {}
print("[Boundary/Graph] init")

local _state: BoundaryGraph = { version = 0, nodes = {}, edges = {} }

local Changed = Instance.new("BindableEvent")
Graph.Changed = Changed.Event

local function v2(x: number, y: number): Vector2
    return Vector2.new(x, y)
end

local function deepCopyGraph(src: BoundaryGraph): BoundaryGraph
    local nodes = {}
    for id, n in pairs(src.nodes) do
        nodes[id] = { id = n.id, posXZ = v2(n.posXZ.X, n.posXZ.Y), radius = n.radius }
    end
    local edges = {}
    for id, e in pairs(src.edges) do
        local path = table.create(#(e.path or {}))
        for i = 1, #(e.path or {}) do
            local p = e.path[i]
            path[i] = v2(p.X, p.Y)
        end
        edges[id] = { id = e.id, a = e.a, b = e.b, path = path, width = e.width }
    end
    return { version = src.version, nodes = nodes, edges = edges }
end

local function bump(op: string, id: string?, delta: any?)
    _state.version += 1
    print(string.format("[Boundary/Graph] op=%s id=%s version=%d", op, tostring(id), _state.version))
    Changed:Fire(_state.version, op, id, delta)
end

local function nodeExists(id: string): boolean
    return _state.nodes[id] ~= nil
end

local function validateNode(n: BoundaryNode): (boolean, string?)
    if type(n) ~= "table" or type(n.id) ~= "string" then return false, "bad_node" end
    if typeof(n.posXZ) ~= "Vector2" then return false, "bad_pos" end
    if type(n.radius) ~= "number" or n.radius <= 0 then return false, "bad_radius" end
    return true, nil
end

local function validateEdge(e: BoundaryEdge): (boolean, string?)
    if type(e) ~= "table" or type(e.id) ~= "string" then return false, "bad_edge" end
    if type(e.a) ~= "string" or type(e.b) ~= "string" then return false, "bad_endpoints" end
    if e.a == e.b then return false, "same_endpoint" end
    if not nodeExists(e.a) or not nodeExists(e.b) then return false, "missing_endpoint" end
    if type(e.width) ~= "number" or e.width <= 0 then return false, "bad_width" end
    if type(e.path) ~= "table" or #e.path < 2 then return false, "bad_path" end
    for i = 1, #e.path do
        if typeof(e.path[i]) ~= "Vector2" then return false, "bad_path_point" end
    end
    return true, nil
end

function Graph.snapshot(): BoundaryGraph
    return deepCopyGraph(_state)
end

function Graph.replace(g: BoundaryGraph): BoundaryGraph
    if type(g) ~= "table" or type(g.nodes) ~= "table" or type(g.edges) ~= "table" then
        warn("[Boundary/GraphError] reason=bad_graph_input")
        return Graph.snapshot()
    end
    local new: BoundaryGraph = { version = _state.version, nodes = {}, edges = {} }
    for id, n in pairs(g.nodes) do
        local ok, reason = validateNode(n)
        if not ok then warn("[Boundary/GraphError] reason=", reason, " id=", id); return Graph.snapshot() end
        new.nodes[id] = { id = n.id, posXZ = v2(n.posXZ.X, n.posXZ.Y), radius = n.radius }
    end
    for id, e in pairs(g.edges) do
        local ok, reason
        do _state.nodes = new.nodes; ok, reason = validateEdge(e) end
        if not ok then warn("[Boundary/GraphError] reason=", reason, " id=", id); _state.nodes = new.nodes; return Graph.snapshot() end
        local path = table.create(#(e.path or {}))
        for i = 1, #(e.path or {}) do local p = e.path[i]; path[i] = v2(p.X, p.Y) end
        new.edges[id] = { id = e.id, a = e.a, b = e.b, path = path, width = e.width }
    end
    _state = new
    bump("replace", "*")
    return Graph.snapshot()
end

function Graph.applyDelta(delta: any): BoundaryGraph
    if type(delta) ~= "table" then warn("[Boundary/GraphError] reason=bad_delta") return Graph.snapshot() end
    if delta.nodes then
        for _, n in ipairs(delta.nodes.created or {}) do Graph.addNode(n) end
        for _, upd in ipairs(delta.nodes.updated or {}) do Graph.updateNode(upd.id, upd) end
        for _, id in ipairs(delta.nodes.removed or {}) do Graph.removeNode(id) end
    end
    if delta.edges then
        for _, e in ipairs(delta.edges.created or {}) do Graph.addEdge(e) end
        for _, upd in ipairs(delta.edges.updated or {}) do Graph.updateEdge(upd.id, upd) end
        for _, id in ipairs(delta.edges.removed or {}) do Graph.removeEdge(id) end
    end
    return Graph.snapshot()
end

function Graph.addNode(n: BoundaryNode): BoundaryNode?
    local ok, reason = validateNode(n)
    if not ok then warn("[Boundary/GraphError] reason=", reason); return nil end
    local copy = { id = n.id, posXZ = v2(n.posXZ.X, n.posXZ.Y), radius = n.radius }
    _state.nodes[n.id] = copy
    bump("addNode", n.id, copy)
    return { id = copy.id, posXZ = v2(copy.posXZ.X, copy.posXZ.Y), radius = copy.radius }
end

function Graph.updateNode(id: string, partial: any): BoundaryNode?
    local cur = _state.nodes[id]
    if not cur then warn("[Boundary/GraphError] reason=missing_node id=", id); return nil end
    local radius = partial.radius ~= nil and tonumber(partial.radius) or cur.radius
    local pos = partial.posXZ and typeof(partial.posXZ) == "Vector2" and partial.posXZ or cur.posXZ
    if radius <= 0 then warn("[Boundary/GraphError] reason=bad_radius id=", id); return nil end
    _state.nodes[id] = { id = id, posXZ = v2(pos.X, pos.Y), radius = radius }
    bump("updateNode", id, _state.nodes[id])
    local c = _state.nodes[id]
    return { id = c.id, posXZ = v2(c.posXZ.X, c.posXZ.Y), radius = c.radius }
end

function Graph.removeNode(id: string)
    if not _state.nodes[id] then warn("[Boundary/GraphError] reason=missing_node id=", id); return end
    for eid, e in pairs(_state.edges) do
        if e.a == id or e.b == id then _state.edges[eid] = nil end
    end
    _state.nodes[id] = nil
    bump("removeNode", id)
end

function Graph.addEdge(e: BoundaryEdge): BoundaryEdge?
    local ok, reason = validateEdge(e)
    if not ok then warn("[Boundary/GraphError] reason=", reason); return nil end
    local path = table.create(#(e.path or {}))
    for i = 1, #(e.path or {}) do local p = e.path[i]; path[i] = v2(p.X, p.Y) end
    local copy = { id = e.id, a = e.a, b = e.b, path = path, width = e.width }
    _state.edges[e.id] = copy
    bump("addEdge", e.id, copy)
    return { id = copy.id, a = copy.a, b = copy.b, path = deepCopyGraph({version=0,nodes={},edges={["e"]=copy}}).edges["e"].path, width = copy.width }
end

function Graph.updateEdge(id: string, partial: any): BoundaryEdge?
    local cur = _state.edges[id]
    if not cur then warn("[Boundary/GraphError] reason=missing_edge id=", id); return nil end
    local width = partial.width ~= nil and tonumber(partial.width) or cur.width
    local path = cur.path
    if partial.path and type(partial.path) == "table" and #partial.path >= 2 then
        local tmp = {}
        for i = 1, #partial.path do
            local p = partial.path[i]
            if typeof(p) ~= "Vector2" then warn("[Boundary/GraphError] reason=bad_path_point id=", id); return nil end
            tmp[i] = v2(p.X, p.Y)
        end
        path = tmp
    end
    if width <= 0 then warn("[Boundary/GraphError] reason=bad_width id=", id); return nil end
    _state.edges[id] = { id = id, a = cur.a, b = cur.b, path = path, width = width }
    bump("updateEdge", id, _state.edges[id])
    local e = _state.edges[id]
    return { id = e.id, a = e.a, b = e.b, path = deepCopyGraph({version=0,nodes={},edges={["e"]=e}}).edges["e"].path, width = e.width }
end

function Graph.removeEdge(id: string)
    if not _state.edges[id] then warn("[Boundary/GraphError] reason=missing_edge id=", id); return end
    _state.edges[id] = nil
    bump("removeEdge", id)
end

function Graph.getVersion(): number
    return _state.version
end

return Graph

