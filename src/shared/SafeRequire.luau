--!strict
-- SafeRequire: Non-throwing validation and load helpers

local SafeRequire = {}

export type ValidateResult = { ok: boolean, reason: string?, path: string?, class: string? }
export type LoadResult = { ok: boolean, mod: any?, reason: string?, path: string? }

local REASONS = {
    not_found = true,
    class_mismatch = true,
    pcall_error = true,
    missing_dependency = true,
    cycle_detected = true,
}

local function fullPath(inst: Instance?): string
    if inst == nil then
        return "[nil]"
    end
    local ok, name = pcall(function()
        return inst:GetFullName()
    end)
    return ok and name or ("[Instance:%s]"):format(tostring(inst))
end

function SafeRequire.validate(inst: Instance?): ValidateResult
    if inst == nil then
        return { ok = false, reason = "not_found", path = fullPath(inst), class = "[nil]" }
    end
    local class = inst.ClassName
    if class ~= "ModuleScript" then
        return { ok = false, reason = "class_mismatch", path = fullPath(inst), class = class }
    end
    return { ok = true, path = fullPath(inst), class = class }
end

function SafeRequire.load(inst: Instance?): LoadResult
    local v = SafeRequire.validate(inst)
    if not v.ok then
        return { ok = false, reason = v.reason, path = v.path }
    end
    local ok, modOrErr = pcall(function()
        return require(inst :: ModuleScript)
    end)
    if ok then
        return { ok = true, mod = modOrErr, path = v.path }
    end
    return { ok = false, reason = "pcall_error", path = v.path }
end

return SafeRequire

