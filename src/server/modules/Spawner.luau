-- Spawner: brainrots walk the conveyor, and players buy them by touch.
-- A spawn rolls a character (weighted by rarity) and a mutation, clones
-- the matching template from ReplicatedStorage.BrainrotTemplates, and
-- walks it from the spawn portal to the despawn gate. Touching a
-- brainrot buys it when the player can afford it and has a free slot;
-- the brainrot then moves to their base and starts earning.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotData = require(ReplicatedStorage:WaitForChild("BrainrotData"))
local BaseManager = require(script.Parent:WaitForChild("BaseManager"))
local StealSystem = require(script.Parent:WaitForChild("StealSystem"))

local Spawner = {}

local active = {} -- brainrot models currently walking the belt
local buyConnections = {} -- [model] = touch connection, cut on sale

local function removeActive(model)
	for i, item in ipairs(active) do
		if item == model then
			table.remove(active, i)
			return
		end
	end
end

-- Paint the mutation onto the name tag: GOLD / DIAMOND / RAINBOW.
local function applyMutationTag(model, char, mutation)
	local root = model:FindFirstChild("RootPart")
	if not root then
		return
	end
	local gui = root:FindFirstChildOfClass("BillboardGui")
	local label = gui and gui:FindFirstChildOfClass("TextLabel")
	if not label then
		return
	end
	local income = char.Income * mutation.Multiplier
	local text = char.Name .. "\n" .. BrainrotData.formatMoney(income) .. "/s"
	if mutation.Tag ~= "" then
		text = char.Name .. " [" .. mutation.Tag .. "]\n" .. BrainrotData.formatMoney(income) .. "/s"
	end
	label.Text = text
end

function Spawner.spawnOne()
	local char = BrainrotData.rollCharacter()
	local mutation = BrainrotData.rollMutation()
	local templates = ReplicatedStorage:WaitForChild("BrainrotTemplates")
	local template = templates:FindFirstChild(char.Model)
	if not template then
		return
	end

	local model = template:Clone()
	model:SetAttribute("CharacterId", char.Id)
	model:SetAttribute("Price", char.Price)
	model:SetAttribute("Income", char.Income)
	model:SetAttribute("Multiplier", mutation.Multiplier)
	model:SetAttribute("Mutation", mutation.Id)
	model:SetAttribute("Sold", false)
	model:SetAttribute("SlotIndex", 0)
	model:SetAttribute("OwnerId", 0)
	applyMutationTag(model, char, mutation)

	local belt = workspace:WaitForChild("ConveyorBrainrots")
	model.Parent = belt
	if model.PrimaryPart == nil then
		model.PrimaryPart = model:FindFirstChild("RootPart")
	end
	-- Feet on the belt: the pivot (RootPart) sits 2.5 studs above them.
	model:PivotTo(
		CFrame.new(BrainrotData.Config.ConveyorStartX, BrainrotData.Config.ConveyorTopY + 2.5, 0)
			* CFrame.Angles(0, math.rad(90), 0)
	)
	table.insert(active, model)

	-- Buying: touch the brainrot and it is yours when you can pay.
	local root = model:FindFirstChild("RootPart")
	if root then
		local connection
		connection = root.Touched:Connect(function(hit)
			if model:GetAttribute("Sold") then
				return
			end
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player then
				return
			end
			local entry = BaseManager.getBase(player)
			if not entry then
				return
			end
			local leaderstats = player:FindFirstChild("leaderstats")
			local cash = leaderstats and leaderstats:FindFirstChild("Cash")
			if not cash or cash.Value < char.Price then
				return
			end
			if not BaseManager.getFreeSlot(entry) then
				return
			end
			model:SetAttribute("Sold", true)
			cash.Value -= char.Price
			if connection then
				connection:Disconnect()
			end
			buyConnections[model] = nil
			removeActive(model)
			BaseManager.placeInSlot(entry, model)
			StealSystem.armStealTouch(entry, model)
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			local notify = remotes and remotes:FindFirstChild("Notify")
			if notify then
				notify:FireClient(player, "You bought " .. char.Name .. " for " .. BrainrotData.formatMoney(char.Price) .. "!")
			end
		end)
		buyConnections[model] = connection
	end

	-- Walking: step along +X until bought or the gate eats it.
	task.spawn(function()
		while model.Parent do
			if model:GetAttribute("Sold") then
				break
			end
			local pivot = model:GetPivot()
			local x = pivot.Position.X + BrainrotData.Config.WalkSpeed * 0.1
			if x >= BrainrotData.Config.ConveyorEndX then
				model:Destroy()
				break
			end
			local bob = math.sin(os.clock() * 6) * 0.12
			local sway = math.sin(os.clock() * 6) * 0.05
			model:PivotTo(
				CFrame.new(x, BrainrotData.Config.ConveyorTopY + 2.5 + bob, 0)
					* CFrame.Angles(0, math.rad(90), sway)
			)
			task.wait(0.1)
		end
		removeActive(model)
		local connection = buyConnections[model]
		if connection then
			connection:Disconnect()
			buyConnections[model] = nil
		end
	end)
end

function Spawner.start()
	local belt = Instance.new("Folder")
	belt.Name = "ConveyorBrainrots"
	belt.Parent = workspace
	task.spawn(function()
		while true do
			task.wait(BrainrotData.Config.SpawnInterval)
			if #active < BrainrotData.Config.MaxOnBelt then
				Spawner.spawnOne()
			end
		end
	end)
end

return Spawner
