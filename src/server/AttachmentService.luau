local AttachmentService = {}

function AttachmentService.EquipAttachment(player, slot, itemId)
    -- TODO: equip attachment and persist
    return false, "NOT_IMPLEMENTED"
end

function AttachmentService.GetAttachments(player)
    -- TODO: return equipped attachment ids
    return { nil, nil }
end

function AttachmentService.ComputeAttachmentModifiers(player)
    -- TODO: compute movement and fire rate modifiers
    return {}
end

return AttachmentService
