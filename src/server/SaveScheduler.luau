local SaveScheduler = {}

local DEBOUNCE = 2
local AUTOSAVE = 210
local JITTER = 30

local entries = {}

local function run(userId)
    local entry = entries[userId]
    if not entry then
        return
    end
    local thunk = entry.pending
    entry.pending = nil
    if thunk then
        thunk()
    end
end

local function scheduleDebounce(userId)
    local entry = entries[userId]
    if entry.debounceHandle then
        return
    end
    if task and task.delay then
        entry.debounceHandle = task.delay(DEBOUNCE, function()
            entry.debounceHandle = nil
            run(userId)
        end)
    else
        run(userId)
    end
end

function SaveScheduler.enqueue(userId, thunk)
    local entry = entries[userId]
    if not entry then
        entry = {}
        entries[userId] = entry
    end
    entry.pending = thunk
    scheduleDebounce(userId)
end

local function scheduleAutosave(userId)
    local entry = entries[userId]
    if not entry or not entry.saveFn then
        return
    end
    if task and task.delay then
        local interval = AUTOSAVE + math.random(-JITTER, JITTER)
        entry.autoHandle = task.delay(interval, function()
            SaveScheduler.enqueue(userId, entry.saveFn)
            scheduleAutosave(userId)
        end)
    end
end

function SaveScheduler.start(userId, saveFn)
    local entry = entries[userId]
    if not entry then
        entry = {}
        entries[userId] = entry
    end
    entry.saveFn = saveFn
    scheduleAutosave(userId)
end

function SaveScheduler.remove(userId)
    entries[userId] = nil
end

function SaveScheduler.flush()
    for userId, _ in pairs(entries) do
        run(userId)
    end
end

function SaveScheduler.flushImmediate(player)
    local uid = typeof(player) == "table" and player.UserId or player
    run(uid)
    return true
end

return SaveScheduler

