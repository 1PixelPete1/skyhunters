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

-- payload = { itemId: string, qty?: number (ignored/clamped to 1), txnId?: string }
function ShopService.Purchase(player, payload)
    -- Basic input validation
    if typeof(payload) ~= "table" then
        return { ok = false, code = "BAD_REQUEST" }
    end
    local itemId = payload.itemId
    if typeof(itemId) ~= "string" then
        return { ok = false, code = "BAD_REQUEST" }
    end

    -- Rate limit (small window)
    if not RateLimiter.Allow(player, "purchase", 6, 3.0) then
        return { ok = false, code = "RATE_LIMITED" }
    end

    local def = ServerItemConfig.items[itemId]
    if not def or def.class ~= "Producer" then
        return { ok = false, code = "NOT_FOR_SALE" }
    end
    if not def.obtainable or def.adminOnly then
        return { ok = false, code = "UNOBTAINABLE" }
    end
    local unitPrice = def.price or math.huge
    local qty = 1
    local total = unitPrice * qty

    return TxnLock.withLock(player, "purchase", function()
        if (player.crumbs or 0) < total then
            return { ok = false, code = "INSUFFICIENT_FUNDS" }
        end
        if not Economy.ApplyCrumbsDelta(player, -total, "purchase") then
            return { ok = false, code = "INSUFFICIENT_FUNDS" }
        end
        InventoryService.Add(player, itemId, qty)

        -- Persist
        if FORCE_DURABLE_SAVE then
            -- Minimal, blocking commit to avoid loss if the player leaves immediately.
            -- Prefer a targeted, fast-save path here.
            local okSave = SaveScheduler.flushImmediate(player)
            if not okSave then
                Economy.ApplyCrumbsDelta(player, total, "refund")
                InventoryService.Add(player, itemId, -qty)
                return { ok = false, code = "SAVE_FAILED" }
            end
        else
            -- Normal path: enqueue/batch
            SaveScheduler.enqueue(player.UserId, function()
                SaveScheduler.flushImmediate(player)
            end)
        end

        -- Return authoritative result
        return {
            ok = true,
            itemId = itemId,
            qtyGranted = qty,
            newBalance = player.crumbs,
            newCount = (player.inventory and player.inventory[itemId]) or 0,
        }
    end)
end

return ShopService
