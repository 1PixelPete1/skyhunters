local ValidationService = {}

function ValidationService.Init(services)
    ValidationService._services = services
end

function ValidationService.ValidatePlacement(player: Player, partId: string, cframe: CFrame)
    return true
end

return ValidationService

