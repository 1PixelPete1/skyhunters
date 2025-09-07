--!strict

-- CollectionService binder for placed base lanterns.
-- Keeps client/server tagging consistent; server is authority for state.

local CollectionService = game:GetService("CollectionService")

local TAG = "LanternBase"

local BaseLanternBinder = {}

function BaseLanternBinder.Tag(instance: Instance)
    if not CollectionService:HasTag(instance, TAG) then
        CollectionService:AddTag(instance, TAG)
    end
end

function BaseLanternBinder.Untag(instance: Instance)
    if CollectionService:HasTag(instance, TAG) then
        CollectionService:RemoveTag(instance, TAG)
    end
end

function BaseLanternBinder.GetTagged(): { Instance }
    return CollectionService:GetTagged(TAG)
end

return BaseLanternBinder

