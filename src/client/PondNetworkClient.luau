--!strict
-- Client mirror of PondNetworkService snapshot with delta subscription (ModuleScript)

local RS = game:GetService("ReplicatedStorage")

local Net = RS:WaitForChild("Net")
local Remotes = Net:WaitForChild("Remotes")
local RF_Get: RemoteFunction = Remotes:WaitForChild("RF_GetPondNetworkSnapshot")
local RE_Delta: RemoteEvent = Remotes:WaitForChild("RE_PondNetworkDelta")

local Types = require(RS.Shared.PondNetworkTypes)
local M: any = {}

M.snapshot = RF_Get:InvokeServer() :: Types.Snapshot
M.Changed = Instance.new("BindableEvent")

RE_Delta.OnClientEvent:Connect(function(packet)
    if packet.full then
        M.snapshot = RF_Get:InvokeServer()
    else
        local d = packet.delta or {}
        if d.ponds and d.ponds.created then
            for _, p in ipairs(d.ponds.created) do M.snapshot.ponds[p.id] = p end
        end
        if d.lakes and d.lakes.created then
            for _, l in ipairs(d.lakes.created) do M.snapshot.lakes[l.id] = l end
        end
        M.snapshot.version = packet.version or (M.snapshot.version + 1)
    end
    M.Changed:Fire(M.snapshot)
end)

return M

