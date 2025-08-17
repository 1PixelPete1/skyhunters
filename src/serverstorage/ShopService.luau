-- ServerStorage/ShopService.luau
-- Server-authoritative purchase of BASIC PRODUCER items (debug-producer clones).
-- Differences allowed: name, rarity, price. Everything else identical.

local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local serverModules = ServerScriptService:WaitForChild("Server")
local Economy = require(serverModules:WaitForChild("Economy"))
local InventoryService = require(serverModules:WaitForChild("InventoryService"))
local SaveScheduler = require(serverModules:WaitForChild("SaveScheduler"))
local PlayerManager = require(serverModules:WaitForChild("PlayerManager"))
local ServerItemConfig = require(ServerStorage:WaitForChild("ServerItemConfig"))
local RateLimiter = require(ServerStorage.RateLimiter)
local TxnLock = require(ServerStorage.TxnLock)

local ShopService = {}

-- Toggle to control durability: if true, commit a synchronous save for each purchase
local FORCE_DURABLE_SAVE = true -- TODO: wire to your environment/flag system

-- Returns a client-safe catalog (mapped elsewhere; don’t leak server flags here)
function ShopService.FetchCatalog(player)
    return require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PublicItemCatalog"))
end

function ShopService.FetchShopSnapshot(player)
    local catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PublicItemCatalog"))
    local data = PlayerManager.GetPlayerData(player)
    local balance = data.crumbs or 0
    return { catalog = catalog, balance = balance }
end

-- payload = { itemId: string, qty?: number (ignored/clamped to 1), txnId?: string }
function ShopService.Purchase(player, payload)
    local function deny(code)
        print("[SHOP] PURCHASE_DENY", player.UserId, code)
        return { ok = false, code = code }
    end

    -- Basic input validation
    if typeof(payload) ~= "table" then
        return deny("BAD_REQUEST")
    end
    local itemId = payload.itemId
    if typeof(itemId) ~= "string" then
        return deny("BAD_REQUEST")
    end

    -- Rate limit (small window)
    if not RateLimiter.Allow(player, "purchase", 6, 3.0) then
        return deny("RATE_LIMITED")
    end

    local def = ServerItemConfig.items[itemId]
    if not def or def.class ~= "Producer" then
        return deny("NOT_FOR_SALE")
    end
    if not def.obtainable or def.adminOnly then
        return deny("UNOBTAINABLE")
    end
    local unitPrice = def.price or math.huge
    local qty = 1
    local total = unitPrice * qty

    return TxnLock.withLock(player, "purchase", function()
        local data = PlayerManager.GetPlayerData(player)
        local balance = data.crumbs or 0
        if balance < total then
            return deny("INSUFFICIENT_FUNDS")
        end
        if not Economy.ApplyCrumbsDelta(data, -total, "purchase") then
            return deny("INSUFFICIENT_FUNDS")
        end
        InventoryService.Add(player, itemId, qty)
        local newCount = InventoryService.GetCount(player, itemId)

        -- Persist
        if FORCE_DURABLE_SAVE then
            -- Minimal, blocking commit to avoid loss if the player leaves immediately.
            -- Prefer a targeted, fast-save path here.
            local okSave = SaveScheduler.flushImmediate(player)
            if not okSave then
                Economy.ApplyCrumbsDelta(data, total, "rollback")
                InventoryService.Add(player, itemId, -qty)
                return deny("SAVE_FAILED")
            end
        else
            -- Normal path: enqueue/batch
            SaveScheduler.enqueue(player.UserId, function()
                SaveScheduler.flushImmediate(player)
            end)
        end

        print("[SHOP] PURCHASE_OK", player.UserId, itemId, total, "balance=" .. tostring(data.crumbs))

        -- Return authoritative result
        return {
            ok = true,
            itemId = itemId,
            qtyGranted = qty,
            newBalance = data.crumbs,
            newCount = newCount,
        }
    end)
end

return ShopService
