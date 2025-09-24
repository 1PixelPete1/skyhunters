--!strict
-- PondPersistence: Enhanced save and load system for dynamic ponds with full terrain and rim data

local PondPersistence = {}

local DataStoreService = game:GetService("DataStoreService")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local workspace = game:GetService("Workspace")

-- Use DataStore in production and in Studio if API Services are enabled
-- We'll handle DataStore errors gracefully instead of hard-coding Studio exclusions
local pondStore = DataStoreService:GetDataStore("DynamicPonds_v2") -- v2 for enhanced schema

if RunService:IsStudio() then
    print("[PondPersistence] Studio mode - DataStore will work if 'Allow Studio Access to API Services' is enabled in Game Settings > Security")
end

local function getPondNetworkService()
    local ok, PNS = pcall(function()
        return require(SSS:WaitForChild("Systems"):WaitForChild("PondNetworkService"))
    end)
return ok and PNS or nil
end

-- Clear all saved pond/lake data (Dev-only utility)
function PondPersistence.clearAll()
    local success, err = pcall(function()
        pondStore:SetAsync("WorldPonds", { version = 0, ponds = {}, lakes = {}, timestamp = os.time() })
    end)
    if not success then
        if RunService:IsStudio() then
            print("[PondPersistence] Clear failed - Enable 'Allow Studio Access to API Services' in Game Settings > Security. Error:", err)
        else
            warn("[PondPersistence] Clear failed:", err)
        end
    else
        print("[PondPersistence] Cleared all saved ponds/lakes")
    end
end

function PondPersistence.save()
    local PNS = getPondNetworkService()
    if not PNS then 
        warn("[PondPersistence] Cannot save - PondNetworkService not available")
        return false 
    end
    
    local snapshot = PNS.getSnapshot()
    local saveData = {
        version = snapshot.version,
        ponds = {},
        lakes = {},
        timestamp = os.time()
    }
    
    -- Convert ponds to enhanced saveable format with full reconstruction data
    for id, pond in pairs(snapshot.ponds) do
        -- Skip default ponds (they're created by world generation)
        if not string.find(id, "default") then
            -- Collect rim data for this pond
            local rimData = {}
            local pondRims = workspace:FindFirstChild("PondRims")
            if pondRims then
                local rimFolder = pondRims:FindFirstChild(id)
                if rimFolder then
                    for _, child in ipairs(rimFolder:GetDescendants()) do
                        if child:IsA("BasePart") and child.Name == "RimStone" then
                            table.insert(rimData, {
                                position = { X = child.Position.X, Y = child.Position.Y, Z = child.Position.Z },
                                rotation = { X = child.Rotation.X, Y = child.Rotation.Y, Z = child.Rotation.Z },
                                size = { X = child.Size.X, Y = child.Size.Y, Z = child.Size.Z },
                                color = { R = child.Color.R, G = child.Color.G, B = child.Color.B },
                                material = child.Material.Name
                            })
                        end
                    end
                end
            end
            
            -- Enhanced pond save data
            saveData.ponds[id] = {
                id = pond.id,
                pos = { X = pond.pos.X, Y = pond.pos.Y },
                radius = pond.radius,
                centerY = pond.centerY,
                -- Enhanced data for perfect reconstruction
                rimStones = rimData,
                createdAt = os.time(),
                schema = "v2"  -- Mark as enhanced save format
            }
        end
    end
    
    -- Convert lakes to enhanced saveable format with stone tile data
    for id, lake in pairs(snapshot.lakes) do
        -- Skip default lakes
        if not string.find(id, "default") then
            local pathData = {}
            for _, pt in ipairs(lake.path) do
                table.insert(pathData, { X = pt.X, Y = pt.Y })
            end
            
            -- Collect canal stone data
            local stoneData = {}
            local canalSegments = workspace:FindFirstChild("CanalSegments")
            if canalSegments then
                local canalFolder = canalSegments:FindFirstChild(id)
                if canalFolder then
                    for _, child in ipairs(canalFolder:GetChildren()) do
                        if child:IsA("BasePart") and child.Name == "CanalStone" then
                            table.insert(stoneData, {
                                position = { X = child.Position.X, Y = child.Position.Y, Z = child.Position.Z },
                                rotation = { X = child.Rotation.X, Y = child.Rotation.Y, Z = child.Rotation.Z },
                                size = { X = child.Size.X, Y = child.Size.Y, Z = child.Size.Z }
                            })
                        end
                    end
                end
            end
            
            saveData.lakes[id] = {
                id = lake.id,
                a = lake.a,
                b = lake.b,
                path = pathData,
                width = lake.width,
                junctions = lake.junctions,
                -- Enhanced data
                stoneData = stoneData,
                schema = "v2"
            }
        end
    end
    
    -- Save to DataStore
    local success, err = pcall(function()
        pondStore:SetAsync("WorldPonds", saveData)
    end)
    
    if success then
        print("[PondPersistence] Saved", table.getn(saveData.ponds), "dynamic ponds and", table.getn(saveData.lakes), "lakes")
    else
        if RunService:IsStudio() then
            print("[PondPersistence] Save failed - Enable 'Allow Studio Access to API Services' in Game Settings > Security. Error:", err)
        else
            warn("[PondPersistence] Save failed:", err)
        end
    end
    
    return success
end

function PondPersistence.load()
    local PNS = getPondNetworkService()
    if not PNS then 
        warn("[PondPersistence] Cannot load - PondNetworkService not available")
        return false 
    end
    
    local success, data = pcall(function()
        return pondStore:GetAsync("WorldPonds")
    end)
    
    if not success then
        if RunService:IsStudio() then
            print("[PondPersistence] Load failed - Enable 'Allow Studio Access to API Services' in Game Settings > Security. Error:", data)
        else
            warn("[PondPersistence] Load failed:", data)
        end
        return false
    end
    
    if not data then
        print("[PondPersistence] No saved pond data found")
        return false
    end
    
    local pondsLoaded = 0
    local lakesLoaded = 0
    
    -- Rebuild ponds with enhanced restoration
    for id, pondData in pairs(data.ponds or {}) do
        local pos = Vector2.new(pondData.pos.X, pondData.pos.Y)
        -- Pass skipValidation=true for restored ponds
        local pond = PNS.addPond(pos, pondData.radius, nil, true)
        if pond then
            pondsLoaded = pondsLoaded + 1
            
            -- If this is enhanced save data (v2), restore rim stones
            if pondData.schema == "v2" and pondData.rimStones then
                task.spawn(function()
                    task.wait(0.1) -- Small delay to let pond creation complete
                    
                    local pondRims = workspace:FindFirstChild("PondRims")
                    if pondRims then
                        local rimFolder = pondRims:FindFirstChild(pond.id)
                        if rimFolder then
                            -- Clear auto-generated rim stones
                            for _, child in ipairs(rimFolder:GetChildren()) do
                                if child.Name == "RimStone" then
                                    child:Destroy()
                                end
                            end
                            
                            -- Restore saved rim stones
                            for _, stoneData in ipairs(pondData.rimStones) do
                                local stone = Instance.new("Part")
                                stone.Name = "RimStone"
                                stone.Anchored = true
                                stone.CanCollide = true
                                stone.Material = Enum.Material[stoneData.material] or Enum.Material.Rock
                                stone.Color = Color3.new(stoneData.color.R, stoneData.color.G, stoneData.color.B)
                                stone.Size = Vector3.new(stoneData.size.X, stoneData.size.Y, stoneData.size.Z)
                                stone.Position = Vector3.new(stoneData.position.X, stoneData.position.Y, stoneData.position.Z)
                                stone.Rotation = Vector3.new(stoneData.rotation.X, stoneData.rotation.Y, stoneData.rotation.Z)
                                stone.TopSurface = Enum.SurfaceType.Smooth
                                stone.BottomSurface = Enum.SurfaceType.Smooth
                                stone:SetAttribute("pondId", pond.id)
                                stone.Parent = rimFolder
                            end
                            
                            print(string.format("[PondPersistence] Restored %d rim stones for pond %s", #pondData.rimStones, pond.id))
                        end
                    end
                end)
            end
        end
    end
    
    -- Small delay to let ponds initialize
    task.wait(0.5)
    
    -- Rebuild lakes/canals with enhanced restoration
    for id, lakeData in pairs(data.lakes or {}) do
        if lakeData.a and lakeData.b then
            local lake = PNS.connectPonds(lakeData.a, lakeData.b, lakeData.width)
            if lake then
                lakesLoaded = lakesLoaded + 1
                
                -- If this is enhanced save data (v2), restore canal stones
                if lakeData.schema == "v2" and lakeData.stoneData then
                    task.spawn(function()
                        task.wait(0.2) -- Delay to let canal creation complete
                        
                        local canalSegments = workspace:FindFirstChild("CanalSegments")
                        if canalSegments then
                            local canalFolder = canalSegments:FindFirstChild(lake.id)
                            if canalFolder then
                                -- Clear auto-generated stones
                                for _, child in ipairs(canalFolder:GetChildren()) do
                                    if child.Name == "CanalStone" then
                                        child:Destroy()
                                    end
                                end
                                
                                -- Restore saved canal stones
                                for _, stoneData in ipairs(lakeData.stoneData) do
                                    local stone = Instance.new("Part")
                                    stone.Name = "CanalStone"
                                    stone.Anchored = true
                                    stone.CanCollide = true
                                    stone.Material = Enum.Material.Rock
                                    stone.Color = Color3.fromRGB(118, 116, 112)
                                    stone.Size = Vector3.new(stoneData.size.X, stoneData.size.Y, stoneData.size.Z)
                                    stone.Position = Vector3.new(stoneData.position.X, stoneData.position.Y, stoneData.position.Z)
                                    stone.Rotation = Vector3.new(stoneData.rotation.X, stoneData.rotation.Y, stoneData.rotation.Z)
                                    stone.TopSurface = Enum.SurfaceType.Smooth
                                    stone.BottomSurface = Enum.SurfaceType.Smooth
                                    stone:SetAttribute("lakeId", lake.id)
                                    stone.Parent = canalFolder
                                end
                                
                                print(string.format("[PondPersistence] Restored %d canal stones for lake %s", #lakeData.stoneData, lake.id))
                            end
                        end
                    end)
                end
            end
        end
    end
    
    print("[PondPersistence] Loaded", pondsLoaded, "ponds and", lakesLoaded, "lakes from save")
    return true
end

-- Initialize the service
local function hasAsyncLoader(): boolean
    local systems = SSS:FindFirstChild("Systems")
    return systems ~= nil and systems:FindFirstChild("AsyncPondLoader") ~= nil
end

function PondPersistence.Init(services: any)
    if hasAsyncLoader() then
        print("[PondPersistence] AsyncPondLoader present; skipping internal load/auto-save scheduling")
        return
    end
    -- Load saved ponds after a delay to ensure everything is initialized
    task.spawn(function()
        task.wait(3)  -- Give time for world generation and other services
        PondPersistence.load()
    end)
    
    -- Auto-save every 5 minutes
    task.spawn(function()
        while true do
            task.wait(300)  -- 5 minutes
            PondPersistence.save()
        end
    end)
end

-- Save on server shutdown
game:BindToClose(function()
    print("[PondPersistence] Server shutting down, saving ponds...")
    PondPersistence.save()
    task.wait(2)  -- Give time to save
end)

return PondPersistence
