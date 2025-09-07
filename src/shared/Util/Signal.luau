local Signal = {}
Signal.__index = Signal

function Signal.new()
    local self = setmetatable({}, Signal)
    self._connections = {}
    return self
end

function Signal:Connect(fn)
    local conn = { fn = fn, Connected = true }
    function conn:Disconnect()
        self.Connected = false
    end
    table.insert(self._connections, conn)
    return conn
end

function Signal:Fire(...)
    for _, conn in ipairs(self._connections) do
        if conn.Connected then
            conn.fn(...)
        end
    end
end

function Signal:Destroy()
    self._connections = nil
end

return Signal

