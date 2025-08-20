--!strict
-- FlowTrace.lua: Lightweight tracing utilities for LoomDesigner plugin
-- This module exposes logging helpers and wrappers to observe function calls,
-- table operations and control-flow checkpoints. Every line is carefully
-- commented so behavior is explicit.

-- Attempt to get RunService; may fail outside Roblox Studio
local RunService
-- pcall protects against environments without `game`
do
    -- Try to access game:GetService("RunService") safely
    local ok, rs = pcall(function() return game:GetService("RunService") end)
    -- Only assign if service was fetched
    if ok then RunService = rs end
end

-- Module table that will hold all exported functions
local FT = {}

-- Default configuration values
FT.ENABLED = true -- global enable switch
FT.tagAllow = nil -- optional set of allowed tags; nil means allow all
FT.maxStr = 200 -- maximum length when stringifying values

-- Helper to apply runtime options and global overrides
function FT.init(opts)
    -- Normalize opts table
    opts = opts or {}
    -- Check global flag for enable override
    if _G and _G.LD_FT_ENABLED ~= nil then
        FT.ENABLED = _G.LD_FT_ENABLED
    else
        FT.ENABLED = opts.enabled ~= false
    end
    -- Determine allowed tags from globals or opts
    local tagStr
    if _G and type(_G.LD_FT_TAGS) == "string" then
        tagStr = _G.LD_FT_TAGS
    elseif type(opts.tagAllow) == "string" then
        tagStr = opts.tagAllow
    end
    -- Plugin setting may provide tag string
    if opts.plugin and opts.plugin.GetSetting then
        local s = opts.plugin:GetSetting("ld.ft.tags")
        if type(s) == "string" and s ~= "" then tagStr = s end
    end
    -- Build allow map from comma separated list
    if tagStr and tagStr ~= "" then
        FT.tagAllow = {}
        for tag in string.gmatch(tagStr, "[^,]+") do
            FT.tagAllow[ tag ] = true
        end
    else
        FT.tagAllow = nil
    end
    -- Limit for stringification
    FT.maxStr = opts.maxStr or FT.maxStr
end

-- Decide if a tag should be logged
local function shouldLog(tag)
    -- Respect global enable flag first
    if not FT.ENABLED then return false end
    -- If a tag allow-set exists ensure tag is present
    if FT.tagAllow and not FT.tagAllow[tag] then return false end
    return true
end

-- Stringify helper with length limit and simple table summary
local function ser(v)
    -- Convert strings with length guard
    if type(v) == "string" then
        local s = v
        if #s > FT.maxStr then s = s:sub(1, FT.maxStr) .. "…" end
        return string.format("%q", s)
    end
    -- Summarize tables by listing first few keys
    if type(v) == "table" then
        local keys = {}
        local count = 0
        for k in pairs(v) do
            count += 1
            keys[#keys+1] = tostring(k)
            if #keys >= 5 then break end
        end
        local summary = table.concat(keys, ",")
        if count > #keys then summary = summary .. ",…" end
        return "{" .. summary .. "}"
    end
    -- Fallback to tostring for other types
    local s = tostring(v)
    if #s > FT.maxStr then s = s:sub(1, FT.maxStr) .. "…" end
    return s
end

-- Build extras string from key/value table
local function extrasStr(extras)
    if type(extras) ~= "table" then return "" end
    local parts = {}
    for k,v in pairs(extras) do
        parts[#parts+1] = tostring(k) .. "=" .. ser(v)
    end
    if #parts > 0 then
        return " " .. table.concat(parts, ",")
    end
    return ""
end

-- Fetch file:line info for log prefix
local function src(level)
    -- Default values when debug info unavailable
    local file, line = "?", 0
    -- Use debug.info when available (Luau)
    if debug and debug.info then
        local s,l = debug.info(level, "sl")
        if type(s) == "string" then file = s end
        if type(l) == "number" then line = l end
    elseif debug and debug.getinfo then
        local info = debug.getinfo(level, "Sl")
        if info then
            file = info.source or info.short_src or file
            line = info.currentline or line
        end
    end
    return string.format("%s:%d", file, line)
end

-- Compose log prefix with env, time, source and tag
local function prefix(tag, level)
    -- Determine server/client marker
    local env = "C" -- default to client
    if RunService and RunService:IsServer() then env = "S" end
    -- Current time with 3 decimals
    local t = string.format("%05.3f", os.clock())
    -- File and line from caller
    local s = src(level + 1)
    -- Build final prefix string
    return string.format("[FT][%s][%s][%s][%s] ", env, t, s, tag)
end

-- Core logging function
function FT.log(tag, fmt, ...)
    -- Skip if tag filtered
    if not shouldLog(tag) then return end
    -- Format message
    local msg = string.format(fmt, ...)
    -- Print with prefix; level 2 so caller file shows
    print(prefix(tag, 2) .. msg)
end

-- Warning variant using warn()
function FT.warn(tag, fmt, ...)
    if not shouldLog(tag) then return end
    local msg = string.format(fmt, ...)
    warn(prefix(tag, 2) .. msg)
end

-- Wrap function calls to log entry, return and errors
function FT.fn(tag, f)
    -- Return original if not a function
    if type(f) ~= "function" then return f end
    -- Wrapped function
    return function(...)
        -- Log entry with argument list
        FT.log(tag, "→ %s", ser({...}))
        -- Execute protected call to capture errors
        local ok, results = pcall(function(...)
            return { f(...) }
        end, ...)
        -- On error log and rethrow
        if not ok then
            FT.warn(tag, "× %s", ser(results))
            error(results)
        end
        -- Log normal return
        FT.log(tag, "← %s", ser(results))
        -- Unpack result list
        return table.unpack(results)
    end
end

-- Wrap all function fields of a table
function FT.traceTable(tag, tbl)
    -- Only operate on tables
    if type(tbl) ~= "table" then return tbl end
    for k,v in pairs(tbl) do
        if type(v) == "function" then
            tbl[k] = FT.fn(tag .. "." .. tostring(k), v)
        end
    end
    return tbl
end

-- Create proxy that logs table reads and writes
function FT.watchTable(tag, t)
    -- Original table is referenced as `t`
    local proxy = {}
    -- Metatable implementing interception
    local mt = {}
    -- __index handles reads
    function mt.__index(_, k)
        local v = t[k]
        FT.log(tag, "GET %s -> %s", ser(k), ser(v))
        return v
    end
    -- __newindex handles writes
    function mt.__newindex(_, k, v)
        FT.log(tag, "SET %s = %s", ser(k), ser(v))
        t[k] = v
    end
    -- Allow pairs() to iterate while logging
    function mt.__pairs()
        local function iter(_, k)
            local nk, nv = next(t, k)
            if nk ~= nil then
                FT.log(tag, "GET %s -> %s", ser(nk), ser(nv))
            end
            return nk, nv
        end
        return iter, proxy, nil
    end
    -- Return proxy with metatable and also original table (for optional use)
    return setmetatable(proxy, mt), t
end

-- Branch probe: logs boolean result and extras
function FT.branch(tag, cond, extras)
    FT.log(tag, "IF %s = %s%s", tag, tostring(cond), extrasStr(extras))
    return cond
end

-- Loop probe: logs each iteration index and count
function FT.loop(tag, i, n, extras)
    FT.log(tag, "FOR %s %d/%d%s", tag, i, n, extrasStr(extras))
end

-- Generic checkpoint of variable map
function FT.check(tag, kv)
    FT.log(tag, extrasStr(kv))
end

return FT

