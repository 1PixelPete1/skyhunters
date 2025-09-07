--!strict

-- CrowdController: client-only deterministic minion rendering per pond
-- Consumes RE_OnCrowdDescriptor(pondId, descriptor) from server
-- Descriptor (contract, keep fields symbolic):
-- {
--   crowdSeed: uint32,
--   numAgents: number,
--   epochT0: number,          -- server time when current phase started
--   phase: "Calm"|"Scatter"|"Return",
--   litDiscs: { {cx,cy,cz,r}, ... },   -- optional hint; may be nil
--   avoidDiscs: { {cx,cy,cz,r}, ... }, -- funnel avoidance
--   wave: { size:number, dt:number }   -- optional
-- }

local CrowdController = {}

-- Dependencies (stubs)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)

-- Config (symbolic)
CrowdController.Config = {
    StepHz = 10,              -- updates/sec for pose recomputation
    MaxAgentsClient = 60,     -- LOD cap; impostors beyond this (later)
    AnchorOccupancyCap = 2,   -- per anchor
}

-- Deterministic PRNG/hash stubs (replace with SeedUtil/XorShift later)
local function hash32(a: number, b: number, c: number): number
    return 0 -- TODO
end

local function rand01(seed: number): number
    return 0 -- TODO
end

-- State:
-- CrowdController._ponds[pondId] = {
--   descriptor = <last>,
--   timeOffset = 0,          -- smoothed server - client seconds
--   anchors = {},            -- anchor list (client-derived; TODO: fetch/build)
--   assignments = {},        -- agentId -> anchorId (computed deterministically)
-- }

CrowdController._ponds = {}

-- Event handler: descriptor update
function CrowdController._OnDescriptor(pondId: string, d: table)
    -- TODO: store descriptor; recompute anchors if needed; rebuild deterministic assignments
    -- Ensure stable sort order of agents and anchors before greedy assignment
    local p = CrowdController._ponds[pondId] or {}
    p.descriptor = d
    CrowdController._ponds[pondId] = p
end

-- Pose evaluation at absolute time
function CrowdController._EvaluateAgentPose(pondId: string, agentId: number, t: number): Vector3
    -- TODO: pure function of (anchors[assignment], agent seed, t, phase, epochT0)
    return Vector3.zero
end

-- Public API
function CrowdController.Start()
    Net:GetEvent(Net.Events.RE_OnCrowdDescriptor).OnClientEvent:Connect(CrowdController._OnDescriptor)
    Net:GetEvent(Net.Events.RE_OnMinionScatter).OnClientEvent:Connect(function(pondId, reason)
        -- optional: could trigger a momentary UI pulse or change pose mapping
    end)

    -- Start stepped loop: recompute poses at StepHz for visible ponds
    local step = 1 / (CrowdController.Config.StepHz > 0 and CrowdController.Config.StepHz or 10)
    task.spawn(function()
        while true do
            -- TODO: iterate visible ponds and recompute poses for up to MaxAgentsClient
            task.wait(step)
        end
    end)
end

return CrowdController

