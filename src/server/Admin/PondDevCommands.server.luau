--!strict

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local PondNetworkService = require(SSS:WaitForChild("Systems"):WaitForChild("PondNetworkService"))
local PlotService = require(SSS:WaitForChild("Systems"):WaitForChild("PlotService"))
local SaveStore = require(SSS:WaitForChild("Server"):WaitForChild("LanternSaveStore"))

-- Dev remotes for client toggles
local Net = RS:FindFirstChild("Net") or Instance.new("Folder"); Net.Name = "Net"; Net.Parent = RS
local Remotes = Net:FindFirstChild("Remotes") or Instance.new("Folder"); Remotes.Name = "Remotes"; Remotes.Parent = Net
local RE_ToggleGhost = Remotes:FindFirstChild("RE_DevToggleGhost") or Instance.new("RemoteEvent")
RE_ToggleGhost.Name = "RE_DevToggleGhost"; RE_ToggleGhost.Parent = Remotes
local RE_BoundaryDebug = Remotes:FindFirstChild("RE_DevBoundaryDebug") or Instance.new("RemoteEvent")
RE_BoundaryDebug.Name = "RE_DevBoundaryDebug"; RE_BoundaryDebug.Parent = Remotes

game:GetService("Players").PlayerAdded:Connect(function(plr)
    plr.Chatted:Connect(function(msg)
        local args = string.split(msg, " ")
        if args[1] == "/pond" and args[2] == "add" then
            local x = tonumber(args[3]); local z = tonumber(args[4]); local r = tonumber(args[5]) or 10
            if x and z then PondNetworkService.addPond(Vector2.new(x, z), r) end
        elseif args[1] == "/pond" and args[2] == "link" then
            local a = args[3]; local b = args[4]; local w = tonumber(args[5])
            if a and b then PondNetworkService.connectPonds(a, b, w) end
        elseif args[1] == "/pond" and args[2] == "print" then
            warn("Snapshot v" .. PondNetworkService.getSnapshot().version)
        elseif args[1] == "/ghost" then
            local mode = tostring(args[2] or "")
            if mode == "on" then
                RE_ToggleGhost:FireClient(plr, true)
            elseif mode == "off" then
                RE_ToggleGhost:FireClient(plr, false)
            end
        elseif args[1] == "/boundary" and args[2] == "debug" then
            local mode = tostring(args[3] or "")
            if mode == "on" then
                RE_BoundaryDebug:FireClient(plr, true)
            elseif mode == "off" then
                RE_BoundaryDebug:FireClient(plr, false)
            end
        elseif args[1] == "/mode" and args[2] == "pond" then
            -- Hide default ghost and equip PondTool
            RE_ToggleGhost:FireClient(plr, false)
            local char = plr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local bp = plr:FindFirstChildOfClass("Backpack")
            if hum and bp then
                -- Find PondTool in Backpack or StarterPack clone
                local tool = bp:FindFirstChild("PondTool")
                if not tool then
                    local sp = game:GetService("StarterPack")
                    local t = sp and sp:FindFirstChild("PondTool")
                    if t and t:IsA("Tool") then
                        tool = t:Clone()
                        tool.Parent = bp
                    end
                end
                if tool and tool:IsA("Tool") then
                    hum:EquipTool(tool)
                end
            end
        elseif args[1] == "/wipe" then
            local sub = tostring(args[2] or "")
            if sub == "plot" then
                local a = PlotService and PlotService.ClaimPlot(plr)
                local pk = a and a.plotId
                if pk then
                    SaveStore.clearPlot(pk)
                    -- also clear workspace models for immediate feedback
                    local plots = workspace:FindFirstChild("Plots")
                    local pf = plots and plots:FindFirstChild(pk)
                    local lan = pf and pf:FindFirstChild("Lanterns")
                    if lan then lan:ClearAllChildren() end
                    warn("[Dev] Wiped lantern save for plot " .. pk)
                end
            end
        end
    end)
end)
