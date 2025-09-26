-- LightMergerController.lua
-- Greedy seed-and-absorb light clustering for performance

local LightMergerController = {}
local Lighting = game:GetService("Lighting")

-- Constants
local MERGE_RADIUS = 30 -- studs
local MAX_CLUSTER_DIAMETER = 80 -- optional constraint
local SUBLINEAR_EXPONENT = 0.7 -- for brightness/range combination

-- Active lights and proxies
local sourceLights = {} -- {id = {position, range, brightness, rarity}}
local proxyLights = {} -- actual Light instances
local clusters = {} -- clustering results

function LightMergerController:UpdateLights(lightData)
    sourceLights = {}
    for _, data in ipairs(lightData) do
        sourceLights[data.id] = data
    end
    
    self:RunMerger()
end

function LightMergerController:RunMerger()
    -- Clear existing proxies
    for _, light in pairs(proxyLights) do
        light:Destroy()
    end
    proxyLights = {}
    clusters = {}
    
    -- Create priority-sorted list
    local sortedLights = {}
    for id, data in pairs(sourceLights) do
        table.insert(sortedLights, {id = id, data = data})
    end
    
    -- Sort by rarity (higher first), then by id for deterministic tie-breaking
    table.sort(sortedLights, function(a, b)
        if a.data.rarity ~= b.data.rarity then
            return a.data.rarity > b.data.rarity
        end
        return a.id < b.id
    end)
    
    -- Track assignment
    local assigned = {}
    
    -- Greedy clustering
    for _, seed in ipairs(sortedLights) do
        if not assigned[seed.id] then
            local cluster = {seed.id}
            assigned[seed.id] = true
            
            local seedPos = seed.data.position
            
            -- Try to absorb unassigned lights within merge radius of seed
            for _, candidate in ipairs(sortedLights) do
                if not assigned[candidate.id] then
                    local dist = (candidate.data.position - seedPos).Magnitude
                    
                    if dist <= MERGE_RADIUS then
                        -- Optional: check cluster diameter constraint
                        if MAX_CLUSTER_DIAMETER then
                            local wouldExceed = false
                            for _, memberId in ipairs(cluster) do
                                local memberPos = sourceLights[memberId].position
                                if (candidate.data.position - memberPos).Magnitude > MAX_CLUSTER_DIAMETER then
                                    wouldExceed = true
                                    break
                                end
                            end
                            
                            if not wouldExceed then
                                table.insert(cluster, candidate.id)
                                assigned[candidate.id] = true
                            end
                        else
                            table.insert(cluster, candidate.id)
                            assigned[candidate.id] = true
                        end
                    end
                end
            end
            
            table.insert(clusters, cluster)
        end
    end
    
    -- Create proxy lights for each cluster
    for i, cluster in ipairs(clusters) do
        self:CreateProxyLight(cluster, i)
    end
end

function LightMergerController:CreateProxyLight(cluster, clusterId)
    -- Calculate weighted centroid and combined stats
    local totalWeight = 0
    local weightedPos = Vector3.new(0, 0, 0)
    local combinedBrightness = 0
    local combinedRange = 0
    local maxRarity = 1
    
    for _, lightId in ipairs(cluster) do
        local data = sourceLights[lightId]
        local weight = data.brightness
        
        totalWeight = totalWeight + weight
        weightedPos = weightedPos + (data.position * weight)
        
        -- Sublinear combination
        combinedBrightness = combinedBrightness + math.pow(data.brightness, SUBLINEAR_EXPONENT)
        combinedRange = combinedRange + math.pow(data.range, SUBLINEAR_EXPONENT)
        
        maxRarity = math.max(maxRarity, data.rarity)
    end
    
    if totalWeight > 0 then
        weightedPos = weightedPos / totalWeight
    else
        -- Fallback to simple average
        for _, lightId in ipairs(cluster) do
            weightedPos = weightedPos + sourceLights[lightId].position
        end
        weightedPos = weightedPos / #cluster
    end
    
    -- Normalize sublinear values
    combinedBrightness = math.pow(combinedBrightness, 1/SUBLINEAR_EXPONENT)
    combinedRange = math.pow(combinedRange, 1/SUBLINEAR_EXPONENT)
    
    -- Create proxy light
    local light = Instance.new("PointLight")
    light.Brightness = math.min(combinedBrightness, 10) -- cap for safety
    light.Range = math.min(combinedRange, 200) -- reasonable max
    light.Color = Color3.fromHSV(0.1, 0.3, 1) -- warm lantern color
    
    -- Parent to a part at the position
    local holder = Instance.new("Part")
    holder.Name = "LightProxy_" .. clusterId
    holder.Anchored = true
    holder.CanCollide = false
    holder.Transparency = 1
    holder.Size = Vector3.new(1, 1, 1)
    holder.Position = weightedPos
    holder.Parent = workspace.CurrentCamera -- or appropriate container
    
    light.Parent = holder
    proxyLights[clusterId] = holder
end

return LightMergerController