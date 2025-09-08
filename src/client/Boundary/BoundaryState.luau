--!strict
-- BoundaryState: local client state for renderer stats (queried by HUD)

local M = {
    queue_depth = 0,
    redraws_this_frame = 0,
    ms_draw = 0.0,
    strategy = "",
    segments_drawn = 0,
    plane_y = nil :: number?,
}

function M.set(queue_depth: number, redraws_this_frame: number, ms_draw: number, strategy: string?, segments_drawn: number?)
    M.queue_depth = queue_depth or 0
    M.redraws_this_frame = redraws_this_frame or 0
    M.ms_draw = ms_draw or 0.0
    if strategy ~= nil then M.strategy = strategy end
    if segments_drawn ~= nil then M.segments_drawn = segments_drawn end
end

function M.setPlaneY(y: number?)
    M.plane_y = y
end

return M
