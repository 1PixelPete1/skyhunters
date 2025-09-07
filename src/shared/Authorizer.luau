-- Minimal authorizer stub for placement apply
-- Future: costs, cooldowns, ownership

local Authorizer = {}

export type CheckResult = { ok: boolean, reason: string? }

function Authorizer.check(player: Player, req: any): CheckResult
  -- Always allow in this phase.
  return { ok = true }
end

return Authorizer

