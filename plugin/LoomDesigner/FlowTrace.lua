--!strict
--[=[
FlowTrace.lua - lightweight tracing utility
Provides structured logging to observe data/control flow in the plugin.
Each function is documented line-by-line to satisfy exhaustive
commenting requirements.
]=]

-- create module table
local FT = {}

FT.ENABLED = false -- master switch to disable verbose tracing
FT.TAG_ALLOW = nil -- optional set {tag=true} to filter logs
FT.MAX_STR = 200 -- max length when stringifying values

-- detect server/client context using RunService if available
local context = "C" -- default assume client
local ok, runService = pcall(function()
    return game:GetService("RunService")
end)
if ok and runService then
    -- pcall for IsServer/IsClient as they may not exist outside Roblox
    local isServer = false
    pcall(function()
        isServer = runService:IsServer()
    end)
    context = isServer and "S" or "C"
end

-- helper to truncate long strings safely
local function truncate(str: string): string
    -- guard against nil; tostring converts anything
    local s = tostring(str)
    if #s > FT.MAX_STR then
        -- cut to maximum and append ellipsis
        s = s:sub(1, FT.MAX_STR) .. "..."
    end
    return s
end

-- simple value formatter used across logging helpers
local function formatValue(v): string
    local t = typeof and typeof(v) or type(v)
    if t == "string" then
        -- direct string: truncate if necessary
        return truncate(v)
    elseif t == "table" then
        -- summarize table without iterating everything
        local count = 0
        for _ in pairs(v) do
            count += 1
            if count > 5 then break end -- cap iteration for performance
        end
        return string.format("{table,%d}", count)
    else
        -- numbers/booleans/others just tostring
        return truncate(tostring(v))
    end
end

-- format extras table as key=value pairs
local function formatExtras(extras: any?): string
    if type(extras) ~= "table" then
        return ""
    end
    local parts = {}
    for k, v in pairs(extras) do
        parts[#parts+1] = string.format("%s=%s", truncate(k), formatValue(v))
    end
    return table.concat(parts, " ")
end

local function makePrefix(tag: string, level: number?)
    -- default to stack level 3 which corresponds to the external caller when
    -- FT.log/FT.warn are invoked directly. Additional wrapper layers can pass
    -- in a higher level so we report the true callsite.
    local lvl = level or 3
    local src = "?"
    local line = "?"
    if debug and debug.info then
        -- debug.info returns individual pieces of information so we call it
        -- separately for source and line number.
        src = debug.info(lvl, "s") or src
        line = debug.info(lvl, "l") or line
    end
    local now = string.format("%.3f", os.clock())
    return string.format("[FT][%s][%s][%s:%s][%s]", context, now, src, line, tag)
end

-- internal dispatch function used by log/warn
local function emit(level: ("print"|"warn"), tag: string, msg: string)
    -- warnings always surface regardless of FT.ENABLED so errors are visible
    if level == "warn" then
        warn(msg)
        return
    end
    -- skip debug logs when tracing disabled
    if not FT.ENABLED then return end
    -- tag filtering when TAG_ALLOW is a set of allowed tags
    if FT.TAG_ALLOW and not FT.TAG_ALLOW[tag] then return end
    print(msg)
end

-- public logging API ------------------------------------------------------

-- FT.init(opts) : configure tracing module
function FT.init(opts)
    -- merge runtime overrides from global flags if present
    if _G and _G.LD_FT_ENABLED ~= nil then
        FT.ENABLED = _G.LD_FT_ENABLED and true or false
    end
    if _G and _G.LD_FT_TAGS then
        FT.TAG_ALLOW = {}
        for tag in tostring(_G.LD_FT_TAGS):gmatch("[^,]+") do
            FT.TAG_ALLOW[tag] = true
        end
    end
    -- apply explicit options table
    if type(opts) == "table" then
        if opts.enabled ~= nil then FT.ENABLED = opts.enabled end
        if opts.maxStr ~= nil then FT.MAX_STR = opts.maxStr end
        if opts.tagAllow ~= nil then
            FT.TAG_ALLOW = nil
            if type(opts.tagAllow) == "table" then
                FT.TAG_ALLOW = {}
                for _, tag in ipairs(opts.tagAllow) do
                    FT.TAG_ALLOW[tag] = true
                end
            elseif type(opts.tagAllow) == "string" then
                FT.TAG_ALLOW = {}
                for tag in opts.tagAllow:gmatch("[^,]+") do
                    FT.TAG_ALLOW[tag] = true
                end
            end
        end
    end
end

-- log helper
function FT.log(tag: string, fmt: string, ...)
    local args = { ... }
    local n = select("#", ...)
    local extraLevel = 0
    if n > 0 and type(args[n]) == "number" then
        extraLevel = args[n]
        args[n] = nil
        n -= 1
    end
    local prefix = makePrefix(tag, 3 + extraLevel)
    local msg = string.format(fmt, table.unpack(args, 1, n))
    emit("print", tag, prefix .. " " .. truncate(msg))
end

-- warn helper
function FT.warn(tag: string, fmt: string, ...)
    local args = { ... }
    local n = select("#", ...)
    local extraLevel = 0
    if n > 0 and type(args[n]) == "number" then
        extraLevel = args[n]
        args[n] = nil
        n -= 1
    end
    local prefix = makePrefix(tag, 3 + extraLevel)
    local msg = string.format(fmt, table.unpack(args, 1, n))
    emit("warn", tag, prefix .. " " .. truncate(msg))
end

-- wrapper for functions to log entry/exit/errors
function FT.fn(tag: string, f: (any) -> any)
    return function(...)
        -- log entry with arguments
        local argParts = {}
        for i = 1, select("#", ...) do
            argParts[i] = formatValue(select(i, ...))
        end
        -- use Unicode arrow to denote function entry
        FT.log(tag, "→ %s", table.concat(argParts, ","), 1) -- entry

        -- execute function safely
        local results = {pcall(f, ...)}
        if results[1] then
            -- success path: log return values
            local ret = {}
            for i = 2, #results do
                ret[#ret+1] = formatValue(results[i])
            end
            -- arrow left marks function return values
            FT.log(tag, "← %s", table.concat(ret, ","), 1) -- return
            return table.unpack(results, 2)
        else
            -- failure path: log and rethrow
            -- cross symbol marks an error during execution
            FT.warn(tag, "× %s", formatValue(results[2]), 1) -- error

            error(results[2])
        end
    end
end

-- wrap all function fields of a table
function FT.traceTable(tag: string, tbl: table)
    for k, v in pairs(tbl) do -- iterate over entries in the table
        if type(v) == "function" then -- only wrap callable fields
            tbl[k] = FT.fn(tag .. "." .. tostring(k), v) -- replace with traced wrapper
        end
    end
    return tbl -- return mutated table to caller

end

-- watchTable: proxy that logs reads and writes. Optional onWrite callback fires on mutations
function FT.watchTable(tag: string, t: table, onWrite: ((any, any) -> ())?)
    local proxy = {} -- table returned to the caller
    local meta = {} -- metatable housing interception logic

    -- log reading
    function meta:__index(k)
        local v = t[k] -- fetch original value
        FT.log(tag, "GET %s=%s", truncate(k), formatValue(v), 1) -- emit read trace
        return v -- provide value to caller
    end

    -- log writing
    function meta:__newindex(k, v)
        local old = t[k] -- capture previous value
        t[k] = v -- perform the write on real table
        FT.log(tag, "SET %s %s->%s", truncate(k), formatValue(old), formatValue(v), 1) -- emit write trace
        if onWrite then onWrite(k, v) end
    end

    -- forward table functions
    meta.__len = function() -- length operator (#)
        return #t -- delegate to original table
    end
    meta.__pairs = function() -- generic iteration
        return pairs(t)
    end
    meta.__ipairs = function() -- array iteration
        return ipairs(t)
    end

    return setmetatable(proxy, meta), t -- return proxy along with original
end

-- branch probe
function FT.branch(tag: string, cond: boolean, extras: table?)
    FT.log(tag, "IF %s %s", tostring(cond), formatExtras(extras), 1) -- log condition result
    return cond -- pass through condition for inline 
end

-- loop probe
function FT.loop(tag: string, i: number, n: number, extras: table?)
    FT.log(tag, "FOR %d/%d %s", i, n, formatExtras(extras), 1) -- log iteration index and extras
end

-- checkpoint probe
function FT.check(tag: string, kv: table)
    FT.log(tag, "CHECK %s", formatExtras(kv), 1) -- log arbitrary key/value snapshot
end

return FT
