local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryState = {}

local counts: { [string]: number } = {}
local crumbs = 0
local initialized = false

local countChanged = Instance.new("BindableEvent")
local crumbsChanged = Instance.new("BindableEvent")

local function showError(msg)
    warn("[InventoryState] " .. msg)
end

function InventoryState.InitOnce()
    if initialized then
        return
    end
    initialized = true
    local remotes = ReplicatedStorage:WaitForChild("Remotes")
    local folder = remotes:WaitForChild("Inventory")
    local rfSnapshot = folder:WaitForChild("RF_GetInventorySnapshot") :: RemoteFunction
    local rePush = folder:WaitForChild("RE_InventoryPush") :: RemoteEvent
    local snapshot = rfSnapshot:InvokeServer()
    if typeof(snapshot) == "table" then
        counts = snapshot.inventory or {}
        crumbs = snapshot.crumbs or 0
        crumbsChanged:Fire(crumbs)
    else
        showError("snapshot failed")
    end
    rePush.OnClientEvent:Connect(function(payload)
        if typeof(payload) ~= "table" then
            return
        end
        local id = payload.id
        local newCount = payload.newCount or 0
        counts[id] = newCount
        countChanged:Fire(id, newCount)
    end)
end

function InventoryState.GetCount(id: string): number
    return counts[id] or 0
end

function InventoryState.GetCrumbs(): number
    return crumbs
end

function InventoryState.SetCrumbs(newAmount: number)
    crumbs = newAmount
    crumbsChanged:Fire(crumbs)
end

InventoryState.OnItemCountChanged = countChanged.Event
InventoryState.OnCrumbsChanged = crumbsChanged.Event

return InventoryState
