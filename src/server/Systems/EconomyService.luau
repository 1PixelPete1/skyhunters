--!strict

local EconomyService = {}

function EconomyService.Init(services)
    EconomyService._services = services
end

function EconomyService.GetBalances(player: Player)
    local profile = EconomyService._services.SaveService.GetProfile(player)
    return profile.balances
end

-- req: Types.SellRequest
function EconomyService.Sell(player: Player, req)
    local profile = EconomyService._services.SaveService.GetProfile(player)
    local amount = req.amount or profile.balances.aether
    local sellAmount = math.clamp(amount, 0, profile.balances.aether)
    profile.balances.aether -= sellAmount
    profile.balances.crumbs += sellAmount
    local Net = EconomyService._services.Net
    if Net then
        Net:GetEvent("RE_Balances"):FireClient(player, profile.balances)
    end
    return { ok = true, crumbsDelta = sellAmount }
end

-- Optional quote helper
function EconomyService.Quote(player: Player, amount: number?)
    local profile = EconomyService._services.SaveService.GetProfile(player)
    local maxSell = profile and profile.balances.aether or 0
    local sellAmount = math.clamp(amount or maxSell, 0, maxSell)
    return { ok = true, crumbs = sellAmount }
end

return EconomyService
