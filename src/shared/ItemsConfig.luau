local ok, Vector3Mod = pcall(function()
    return Vector3
end)
local Vector3Util = ok and Vector3Mod or {
    new = function(x, y, z)
        return { x = x, y = y, z = z }
    end,
}

return {
    Types = {
        burst_small = {
            category = "burst",
            displayName = "Burst (Small)",
            burstValue = 25,
            stackable = true,
            icon = "rbxassetid://0",
        },

        prod_cube_basic = {
            category = "producer",
            displayName = "Cube Producer",
            rate = 0.5,
            allowedSurface = "plot",
            model = "CubeProducer",
            footprint = Vector3Util.new(2, 2, 2),
            icon = "rbxassetid://0",
        },
    },
}

