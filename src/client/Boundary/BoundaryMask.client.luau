--!strict
-- BoundaryMask: client-side boundary inclusion check sourced from server soup

local RS = game:GetService("ReplicatedStorage")
local BoundaryConfig = require(RS.Shared.Boundary.BoundaryConfig)
local BoundarySDF = require(RS.Shared.Boundary.BoundarySDF)

local Net = RS:WaitForChild("Net", 3)
local Remotes = Net and Net:FindFirstChild("Remotes")
local RE_Delta: RemoteEvent = Remotes and Remotes:FindFirstChild("RE_BoundaryDelta")
local RF_Get: RemoteFunction = Remotes and Remotes:FindFirstChild("RF_BoundaryGetSoup")

local Mask = {
    soup = nil :: any,
}

local function setSoupInternal(soup: any)
    Mask.soup = soup
    print(string.format("[Boundary/Mask] update pub_id=%s polylines=%d", tostring(soup and soup.version or -1), #(soup and soup.polylines or {})))
end

function Mask.setSoup(soup: any)
    setSoupInternal(soup)
end

function Mask.isInsideBoundary(posXZ: Vector2): boolean
    -- For M0, defer to BoundarySDF (pure) until dots are authoritative
    -- If soup is missing, still evaluate against SDF using current Net snapshot assumptions
    -- In M1, replace with coarse mask built from dot batches
    return BoundarySDF.isInside(posXZ, { ponds = {}, lakes = {} })
end

-- Bootstrap: pull soup if remotes exist; subscribe to replace events
task.defer(function()
    print("[Boundary/Mask] init")
    if RF_Get then
        local ok, resp = pcall(function() return RF_Get:InvokeServer() end)
        if ok and resp then setSoupInternal(resp) end
    end
    if RE_Delta then
        RE_Delta.OnClientEvent:Connect(function(payload)
            if payload and payload.replace and payload.soup then
                setSoupInternal(payload.soup)
            end
        end)
    end
end)

return Mask

