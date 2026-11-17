-- Brainrot Heist: main server script.
-- Wires the whole game together: bases, economy, the conveyor spawner
-- and stealing, plus the remotes the client talks to.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local modules = ServerScriptService:WaitForChild("Server"):WaitForChild("modules")
local BaseManager = require(modules:WaitForChild("BaseManager"))
local Economy = require(modules:WaitForChild("Economy"))
local Spawner = require(modules:WaitForChild("Spawner"))
local StealSystem = require(modules:WaitForChild("StealSystem"))

-- Remotes the client uses: Notify (server -> client toasts),
-- LockBase (client asks to lock their base), RequestRebirth
-- (client asks to rebirth, answered true/false).
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local notifyEvent = Instance.new("RemoteEvent")
notifyEvent.Name = "Notify"
notifyEvent.Parent = remotes

local lockBaseEvent = Instance.new("RemoteEvent")
lockBaseEvent.Name = "LockBase"
lockBaseEvent.Parent = remotes

local requestRebirth = Instance.new("RemoteFunction")
requestRebirth.Name = "RequestRebirth"
requestRebirth.Parent = remotes

BaseManager.setup()
Economy.setup()
Spawner.start()
StealSystem.setup(remotes)

lockBaseEvent.OnServerEvent:Connect(function(player)
	local ok, message = BaseManager.lockBase(player)
	notifyEvent:FireClient(player, message)
end)

requestRebirth.OnServerInvoke = function(player)
	local ok, message = Economy.requestRebirth(player)
	return ok, message
end

Players.PlayerAdded:Connect(function(player)
	local entry = BaseManager.assignBase(player)
	if entry then
		notifyEvent:FireClient(player, "Welcome to Brainrot Heist! This is your base. Grab brainrots off the conveyor!")
	else
		notifyEvent:FireClient(player, "Welcome to Brainrot Heist! All bases are taken right now, one will free up soon.")
	end
end)

Players.PlayerRemoving:Connect(function(player)
	BaseManager.releaseBase(player)
end)

-- Players who were already here when the server started (Studio playtest).
for _, player in ipairs(Players:GetPlayers()) do
	BaseManager.assignBase(player)
end

print("Brainrot Heist is running: bases, economy, spawner and stealing are live.")
