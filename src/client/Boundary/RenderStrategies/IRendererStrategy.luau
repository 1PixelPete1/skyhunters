--!strict
-- IRendererStrategy: interface documentation for boundary render strategies
-- Implementations should export:
--   acquire(): () -> ()        -- optional one-time setup
--   clearAll(): () -> ()       -- clear all visuals owned by the strategy
--   renderSoup(soup: any): (segments: number) -- draw, return segment-ish count for HUD
--   setConfig(cfg: any): ()    -- optional live config hook

export type RendererStrategy = {
    acquire: (() -> ())?,
    clearAll: (() -> ()),
    renderSoup: ((any) -> number),
    setConfig: ((any) -> ())?,
}

return {}

