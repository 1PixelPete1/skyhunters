-- ServerStorage/ShopService.luau
-- Server-authoritative purchase of BASIC PRODUCER items (debug-producer clones).
-- Differences allowed: name, rarity, price. Everything else identical.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- TODO: require your real services:
-- local EconomyService = require(ServerStorage.EconomyService)
-- local InventoryService = require(ServerStorage.InventoryService)
-- local SaveScheduler = require(ServerStorage.SaveScheduler)
-- local ServerItemConfig = require(ServerStorage.ServerItemConfig) -- server-only truth
local RateLimiter = require(ServerStorage.RateLimiter)
local TxnLock = require(ServerStorage.TxnLock)

local ShopService = {}

-- Toggle to control durability: if true, commit a synchronous save for each purchase
local FORCE_DURABLE_SAVE = true -- TODO: wire to your environment/flag system

-- Returns a client-safe catalog (mapped elsewhere; don’t leak server flags here)
function ShopService.FetchCatalog(player)
    -- TODO: return require(ReplicatedStorage.Shared.PublicItemCatalog)
    return {}
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

    -- TODO: lookup server-only item def
    -- local def = ServerItemConfig.items[itemId]
    local def = nil -- replace
    if not def then
        return { ok = false, code = "NOT_FOR_SALE" }
    end

    -- Must be a BASIC PRODUCER variant (same model/behavior as debug producer)
    -- if def.class ~= "Producer" then return { ok=false, code="NOT_FOR_SALE" } end

    -- Enforce obtainability/adminOnly on the server
    -- if not def.obtainable or def.adminOnly then return { ok=false, code="UNOBTAINABLE" } end

    -- Price is server truth
    -- local unitPrice = def.price or math.huge
    local unitPrice = math.huge -- replace
    local qty = 1 -- clamp to 1 for now
    local total = unitPrice * qty

    return TxnLock.withLock(player, "purchase", function()
        -- Funds check and debit
        -- if EconomyService.GetBalance(player, "crumbs") < total then
        -- return { ok=false, code="INSUFFICIENT_FUNDS" }
        -- end
        -- EconomyService.Add(player, "crumbs", -total)

        -- Grant item(s)
        -- InventoryService.AddItem(player, itemId, qty)

        -- Persist
        if FORCE_DURABLE_SAVE then
            -- Minimal, blocking commit to avoid loss if the player leaves immediately.
            -- Prefer a targeted, fast-save path here.
            -- local okSave = SaveScheduler.flushImmediate(player)
            local okSave = true -- replace with your real call
            if not okSave then
                -- Roll back if desired:
                -- EconomyService.Add(player, "crumbs", total)
                -- InventoryService.AddItem(player, itemId, -qty)
                return { ok = false, code = "SAVE_FAILED" }
            end
        else
            -- Normal path: enqueue/batch
            -- SaveScheduler.enqueue(player.UserId, ...)
        end

        -- Return authoritative result
        return {
            ok = true,
            itemId = itemId,
            qtyGranted = qty,
            -- newBalance = EconomyService.GetBalance(player, "crumbs"),
            -- newCount = InventoryService.GetCount(player, itemId),
        }
    end)
end

return ShopService
