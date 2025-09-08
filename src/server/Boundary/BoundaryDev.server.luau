--!strict
-- Studio-only dev commands for Boundary system

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
    return
end

local BoundaryGraph = require(script.Parent:WaitForChild("BoundaryGraph"))
local BoundaryGeometry = require(script.Parent:WaitForChild("BoundaryGeometry"))
local BoundaryPublisher = require(script.Parent:WaitForChild("BoundaryPublisher"))
local PondNetworkService = require(game:GetService("ServerScriptService"):WaitForChild("Systems"):WaitForChild("PondNetworkService"))
local RS = game:GetService("ReplicatedStorage")
local BoundaryConfig = require(RS:WaitForChild("Shared"):WaitForChild("Boundary"):WaitForChild("BoundaryConfig"))

local function stats()
    local soup = (function()
        local s = BoundaryGraph.snapshot(); local soup = select(1, BoundaryGeometry.buildSoup(s)); return soup
    end)()
    local pc = #(soup.polylines or {})
    local segs = 0
    for _, pl in ipairs(soup.polylines or {}) do segs += math.max(0, #(pl.pts or {}) - 1) end
    print(string.format("[Boundary/Stats] version=%d polylines=%d segments=%d", soup.version or -1, pc, segs))
end

local function validate()
    local snap = BoundaryGraph.snapshot()
    local soup = select(1, BoundaryGeometry.buildSoup(snap))
    local ok, reason = BoundaryGeometry.validateSoup(soup, snap)
    print(string.format("[Boundary/Validate] ok=%s reason=%s", tostring(ok), tostring(reason)))
end

local function addPond(args: { string })
    local x = tonumber(args[3]); local z = tonumber(args[4]); local r = tonumber(args[5]) or 10
    if not x or not z then print("usage: /boundary addpond x z r"); return end
    PondNetworkService.addPond(Vector2.new(x, z), r)
end

local function connect(args: { string })
    local a = args[3]; local b = args[4]; local w = tonumber(args[5])
    if not a or not b then print("usage: /boundary connect a b [width]"); return end
    PondNetworkService.connectPonds(a, b, w)
end

local function timing(args: { string })
    local onoff = (args[3] or ""):lower()
    if onoff == "on" then BoundaryConfig.telemetry_enabled = true elseif onoff == "off" then BoundaryConfig.telemetry_enabled = false else print("usage: /boundary timing on|off") end
    print("[Boundary/Timing] telemetry_enabled=", BoundaryConfig.telemetry_enabled)
end

local function toggleDebug(args: { string })
    local onoff = (args[3] or ""):lower()
    if onoff == "on" then BoundaryConfig.debug_enabled = true elseif onoff == "off" then BoundaryConfig.debug_enabled = false else print("[Boundary/Dev] usage=/boundary on|off") return end
    print("[Boundary/Graph] debug_enabled=", BoundaryConfig.debug_enabled)
end

local function ceiling(args: { string })
    local v = tonumber(args[3])
    if not v then print("usage: /boundary ceiling <int>"); return end
    BoundaryConfig.validate_segments_ceiling = math.max(1000, math.floor(v))
    print(string.format("[Boundary/Ceiling] validate_segments_ceiling=%d", BoundaryConfig.validate_segments_ceiling))
end

local function dumpPond(args: { string })
    local id = args[3]
    if not id then print("usage: /boundary dump pond <id>"); return end
    local snap = BoundaryGraph.snapshot()
    local n = snap.nodes[id]
    if not n then print("[Boundary/ArcDump] pondId=", id, " reason=not_found"); return end
    local R = n.radius * (1 + BoundaryConfig.pond_scale) + BoundaryConfig.pad
    local gaps = {}
    for _, e in pairs(snap.edges) do
        local function dirAt(isA: boolean): Vector2
            if isA then return ( #e.path >= 2 and (e.path[2] - e.path[1]) or Vector2.new(1,0) ).Unit else return ( #e.path >= 2 and (e.path[#e.path] - e.path[#e.path-1]) or Vector2.new(-1,0) ).Unit end
        end
        local half = (e.width * 0.5) + BoundaryConfig.pad
        if e.a == id or e.b == id then
            local theta = math.atan2((e.a == id and dirAt(true) or dirAt(false)).Y, (e.a == id and dirAt(true) or dirAt(false)).X)
            local u = math.clamp(half / math.max(1e-5, R), 0, 1)
            local a = math.asin(u)
            local a0 = (theta - a) % (2*math.pi)
            local a1 = (theta + a) % (2*math.pi)
            if a1 < a0 then a1 += 2*math.pi end
            table.insert(gaps, { a0, a1 })
        end
    end
    table.sort(gaps, function(A,B) return A[1] < B[1] end)
    print(string.format("[Boundary/ArcDump] pondId=%s gaps=%d", id, #gaps))
    for i, g in ipairs(gaps) do print(string.format("[Boundary/ArcDump] i=%d a0=%.3f a1=%.3f len=%.3f", i, g[1], g[2], g[2]-g[1])) end
end

local function selfcheck()
    local RS = game:GetService("ReplicatedStorage")
    local Net = RS:FindFirstChild("Net")
    local Remotes = Net and Net:FindFirstChild("Remotes")
    local rf = Remotes and Remotes:FindFirstChild("RF_BoundaryGetSoup")
    local re = Remotes and Remotes:FindFirstChild("RE_BoundaryDelta")
    local ok = (Net and Remotes and rf and re) and true or false
    if ok then
        print("[Boundary/Dev] selfcheck ok=true")
    else
        print(string.format("[Boundary/Dev] selfcheck ok=false hasNet=%s hasRemotes=%s hasRF=%s hasRE=%s",
            tostring(Net~=nil), tostring(Remotes~=nil), tostring(rf~=nil), tostring(re~=nil)))
    end
end

local function onChat(player: Player, msg: string)
    if not msg:lower():match("^/boundary") then return end
    local tokens = {}
    for t in string.gmatch(msg, "%S+") do table.insert(tokens, t) end
    local sub = (tokens[2] or ""):lower()
    if sub == "soup" then
        stats()
    elseif sub == "validate" then
        validate()
    elseif sub == "on" or sub == "off" then
        toggleDebug(tokens)
    elseif sub == "timing" then
        timing(tokens)
    elseif sub == "ceiling" then
        ceiling(tokens)
    elseif sub == "capture" then
        capture(tokens)
    elseif sub == "selfcheck" then
        selfcheck()
    elseif sub == "dump" and (tokens[3] or ""):lower() == "pond" then
        dumpPond(tokens)
    elseif sub == "addpond" then
        addPond(tokens)
    elseif sub == "connect" then
        connect(tokens)
    else
        print("/boundary commands: soup | validate | timing on|off | ceiling <int> | dump pond <id> | addpond x z r | connect a b [width]")
    end
end

Players.PlayerAdded:Connect(function(plr)
    plr.Chatted:Connect(function(msg) onChat(plr, msg) end)
end)
local function capture(args: { string })
    local versionStr = args[3]
    local snap = BoundaryGraph.snapshot()
    local soup = select(1, BoundaryGeometry.buildSoup(snap))
    local v = soup.version or -1
    if versionStr and tonumber(versionStr) and tonumber(versionStr) ~= v then
        print(string.format("[Boundary/Dev] usage=/boundary capture [latest] (requested %s, have %d)", versionStr, v))
        return
    end
    local maxPts = BoundaryConfig.capture_max_points_per_poly or 5
    local excerpt = {}
    for i, pl in ipairs(soup.polylines or {}) do
        if i > 50 then break end -- keep short
        local pts = pl.pts or {}
        local sample = {}
        local n = #pts
        if n > 0 then
            local step = math.max(1, math.floor(n / math.max(1, maxPts)))
            for j=1,n,step do
                local p = pts[j]
                table.insert(sample, { x = math.floor(p.X*100)/100, y = math.floor(p.Y*100)/100 })
                if #sample >= maxPts then break end
            end
        end
        table.insert(excerpt, { id = pl.id, pts = sample })
    end
    local ponds = 0; local lakes = 0
    for _, pl in ipairs(soup.polylines or {}) do local id = pl.id or ""; if id:match("^pond:") then ponds+=1 elseif id:match("^edge:") then lakes+=1 end end
    print(string.format("[Boundary/Capture] pub_id=%d ponds=%d lakes=%d soup_excerpt=%s", v, ponds, lakes, game:GetService("HttpService"):JSONEncode(excerpt)))
end


for _, plr in ipairs(Players:GetPlayers()) do
    plr.Chatted:Connect(function(msg) onChat(plr, msg) end)
end
