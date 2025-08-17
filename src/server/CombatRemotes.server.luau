local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
    remotesFolder = Instance.new("Folder")
    remotesFolder.Name = "Remotes"
    remotesFolder.Parent = ReplicatedStorage
end

local combatFolder = Instance.new("Folder")
combatFolder.Name = "Combat"
combatFolder.Parent = remotesFolder

local firePrimary = Instance.new("RemoteEvent")
firePrimary.Name = "FirePrimary"
firePrimary.Parent = combatFolder
