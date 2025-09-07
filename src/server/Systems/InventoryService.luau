local InventoryService = {}

function InventoryService.Init(services)
    InventoryService._services = services
end

function InventoryService.GrantItem(player: Player, itemId: string, count: number)
    local profile = InventoryService._services.SaveService.GetProfile(player)
    profile.inventory[itemId] = (profile.inventory[itemId] or 0) + (count or 1)
end

function InventoryService.ConsumeItem(player: Player, itemId: string, count: number)
    local profile = InventoryService._services.SaveService.GetProfile(player)
    local have = profile.inventory[itemId] or 0
    if have < count then
        return false
    end
    profile.inventory[itemId] = have - count
    return true
end

function InventoryService.HasUpgrade(player: Player, upgradeId: string): boolean
    local profile = InventoryService._services.SaveService.GetProfile(player)
    return profile.upgrades[upgradeId] == true
end

return InventoryService

