--!strict
-- Minimal bootstrap to guarantee the loading overlay shows ASAP
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

print("[CLIENT_BOOT] LoadingBootstrap starting")

local parent = script.Parent
local mod = parent and parent:FindFirstChild("LoadingScreen")
if mod and mod:IsA("ModuleScript") then
    local ok, LoadingScreen = pcall(function() return require(mod) end)
    if ok and LoadingScreen and type(LoadingScreen.Show) == "function" then
        LoadingScreen:Show()
        LoadingScreen:UpdateProgress({ percentage = 3, message = "Preparing UI..." })
        print("[LoadingScreen] Show (bootstrap)")
        -- Safety: only auto-hide if no server-driven progress is present
        task.delay(6, function()
            local net = ReplicatedStorage:FindFirstChild("Net")
            local remotes = net and net:FindFirstChild("Remotes")
            local hasServerProgress = remotes and remotes:FindFirstChild("RE_LoadingProgress")
            if not hasServerProgress and LoadingScreen and type(LoadingScreen.Hide) == "function" then
                -- If still at initial state, close it gracefully
                pcall(function()
                    LoadingScreen:UpdateProgress({ percentage = 100, message = "Ready" })
                    LoadingScreen:Hide()
                end)
            end
        end)
    else
        warn("[CLIENT_BOOT] LoadingBootstrap failed to require LoadingScreen:", LoadingScreen)
    end
else
    warn("[CLIENT_BOOT] LoadingBootstrap could not find LoadingScreen module")
end
