--!strict
-- RenderQueueSystem: processes lightweight render jobs (stones, etc.) at a steady rate

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = ReplicatedStorage:FindFirstChild("Net") or Instance.new("Folder")
Net.Name = "Net"; Net.Parent = ReplicatedStorage
local Remotes = Net:FindFirstChild("Remotes") or Instance.new("Folder")
Remotes.Name = "Remotes"; Remotes.Parent = Net

local RE_LoadingProgress = Remotes:FindFirstChild("RE_LoadingProgress") or Instance.new("RemoteEvent")
RE_LoadingProgress.Name = "RE_LoadingProgress"; RE_LoadingProgress.Parent = Remotes
local RE_LoadingReady = Remotes:FindFirstChild("RE_LoadingReady") or Instance.new("RemoteEvent")
RE_LoadingReady.Name = "RE_LoadingReady"; RE_LoadingReady.Parent = Remotes

type Job = { id: string, kind: string, doWork: () -> (), label: string? }

local Q = {}

local ITEMS_PER_FRAME = 1 -- tune for smoothing
local queue: { Job } = {}
local totalEnqueued = 0
local totalProcessed = 0
local running = false
local anyClientReady = false
local lastBroadcast = 0
local lastProgressPct = -1

-- Track readiness from clients to avoid queuing events before listeners exist
do
    local seen: { [number]: boolean } = {}
    RE_LoadingReady.OnServerEvent:Connect(function(player)
        if not seen[player.UserId] then
            seen[player.UserId] = true
            anyClientReady = true
        end
    end)
    Players.PlayerRemoving:Connect(function(player)
        seen[player.UserId] = nil
        -- Keep anyClientReady true if others are still ready; simplest is to leave as-is
    end)
end

local function broadcast(force: boolean?)
    if totalEnqueued <= 0 then return end
    if not anyClientReady then return end
    local progress = totalProcessed / math.max(1, totalEnqueued)
    local pct = math.floor(progress * 100)
    local now = os.clock()
    local changed = (pct ~= lastProgressPct)
    if not force then
        if not changed and (now - lastBroadcast) < 0.2 then return end
    end
    lastBroadcast = now
    lastProgressPct = pct
    RE_LoadingProgress:FireAllClients({
        source = "RenderQueue",
        progress = progress,
        status = "Rendering",
        detail = string.format("Rendering objects %d/%d", totalProcessed, totalEnqueued),
        isLoading = Q.IsBusy(),
        percentage = pct,
        message = string.format("Rendering objects... (%d/%d)", totalProcessed, totalEnqueued),
    })
end

local function step()
    if #queue == 0 then return end
    local processedThisFrame = 0
    while processedThisFrame < ITEMS_PER_FRAME do
        local job = table.remove(queue, 1)
        if not job then break end
        local ok, err = pcall(job.doWork)
        if not ok then
            warn("[RenderQueue] job_failed", job.kind, job.id, err)
        end
        totalProcessed += 1
        processedThisFrame += 1
    end
    broadcast(false)
end

local heartbeatConn: RBXScriptConnection? = nil
local function ensurePump()
    if running then return end
    running = true
    heartbeatConn = RunService.Heartbeat:Connect(step)
end

function Q.Init(_services)
    ensurePump()
end

function Q.IsBusy(): boolean
    return (#queue > 0) or (totalProcessed < totalEnqueued)
end

function Q.Stats()
    return { pending = #queue, done = totalProcessed, total = totalEnqueued }
end

local nextUid = 0
local function uid(): string
    nextUid += 1
    return tostring(nextUid)
end

function Q.Enqueue(kind: string, label: string?, fn: () -> ())
    table.insert(queue, { id = uid(), kind = kind, doWork = fn, label = label })
    totalEnqueued += 1
    ensurePump()
    broadcast(false)
end

-- Convenience helpers
function Q.EnqueueRimStone(parent: Instance, props: { Size: Vector3, CFrame: CFrame, Color: Color3, Material: Enum.Material, Attributes: { [string]: any }? })
    Q.Enqueue("RIM_STONE", "rim", function()
        local p = Instance.new("Part")
        p.Name = "RimStone"
        p.Anchored = true
        p.CanCollide = true
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        p.Size = props.Size
        p.CFrame = props.CFrame
        p.Material = props.Material
        p.Color = props.Color
        if props.Attributes then
            for k, v in pairs(props.Attributes) do
                p:SetAttribute(k, v)
            end
        end
        p.Parent = parent
    end)
end

function Q.EnqueueCanalStone(parent: Instance, props: { Size: Vector3, CFrame: CFrame, Color: Color3, Material: Enum.Material, Name: string?, Attributes: { [string]: any }? })
    Q.Enqueue("CANAL_STONE", "canal", function()
        local p = Instance.new("Part")
        p.Name = props.Name or "CanalStone"
        p.Anchored = true
        p.CanCollide = true
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        p.Size = props.Size
        p.CFrame = props.CFrame
        p.Material = props.Material
        p.Color = props.Color
        if props.Attributes then
            for k, v in pairs(props.Attributes) do
                p:SetAttribute(k, v)
            end
        end
        p.Parent = parent
    end)
end

return Q
