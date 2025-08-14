local DataStoreAdapter = {}

local okDS, DataStoreService = pcall(function()
    return game:GetService("DataStoreService")
end)
local okHttp, HttpService = pcall(function()
    return game:GetService("HttpService")
end)

local store
if okDS and okHttp then
    store = DataStoreService:GetDataStore("Skyhunters_Player_v1")
end

local memoryStore = {}

local function backoff(attempt)
    local delayTime = 0.5 * 2 ^ (attempt - 1)
    if task and task.wait then
        task.wait(delayTime)
    end
end

local function attempt(fn)
    for i = 1, 5 do
        local ok, result = pcall(fn)
        if ok then
            return result
        end
        backoff(i)
    end
    return nil
end

function DataStoreAdapter.Load(player)
    if store then
        local raw = attempt(function()
            return store:GetAsync(tostring(player.UserId))
        end)
        if not raw then
            return nil
        end
        if type(raw) == "table" and raw.blob then
            raw = raw.blob
        end
        if HttpService then
            local ok, data = pcall(function()
                return HttpService:JSONDecode(raw)
            end)
            if ok then
                return data
            end
        end
        return nil
    else
        return memoryStore[tostring(player.UserId)]
    end
end

function DataStoreAdapter.Save(player, data)
    if store then
        if not HttpService then
            return false
        end
        local okEncode, payload = pcall(function()
            return HttpService:JSONEncode(data)
        end)
        if not okEncode then
            return false
        end
        local result = attempt(function()
            store:SetAsync(tostring(player.UserId), payload)
            return true
        end)
        return result ~= nil
    else
        memoryStore[tostring(player.UserId)] = data
        return true
    end
end

return DataStoreAdapter

