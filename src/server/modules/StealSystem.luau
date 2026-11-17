-- StealSystem: the threat that makes the game a game.
-- Walk into another player's base and touch their brainrot to steal it:
-- it floats above your head and you have to run it home to your own
-- base before the timer runs out. The owner (or anyone) can slap you
-- with the Slap tool: a slapped thief drops the brainrot and it runs
-- home. A locked base cannot be stolen from at all.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BrainrotData = require(ReplicatedStorage:WaitForChild("BrainrotData"))
local BaseManager = require(script.Parent:WaitForChild("BaseManager"))

local StealSystem = {}

local carried = {} -- [player] = { Model, FromBase, ReturnAt }
local stealConnections = {} -- [model] = touch connection, cut on steal
local lastSlap = {} -- [player] = last slap time

local remotes = nil

local function notify(player, message)
	if remotes then
		local event = remotes:FindFirstChild("Notify")
		if event then
			event:FireClient(player, message)
		end
	end
end

-- Send a brainrot back to the base it was stolen from.
local function returnHome(carry)
	local entry = carry.FromBase
	local model = carry.Model
	if model.Parent then
		BaseManager.placeInSlot(entry, model)
		StealSystem.armStealTouch(entry, model)
	end
end

-- Watch a brainrot that sits on a base: an enemy touch steals it.
function StealSystem.armStealTouch(entry, model)
	local root = model:FindFirstChild("RootPart")
	if not root then
		return
	end
	local old = stealConnections[model]
	if old then
		old:Disconnect()
	end
	local connection
	connection = root.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end
		if player == entry.Owner then
			return
		end
		if carried[player] then
			return -- already carrying one
		end
		if BaseManager.isLocked(entry) then
			notify(player, "That base is locked! Come back later.")
			return
		end
		if model:GetAttribute("SlotIndex") == 0 then
			return -- not sitting on a base right now
		end
		local char = BrainrotData.getCharacter(model:GetAttribute("CharacterId"))
		local name = char and char.Name or "brainrot"
		BaseManager.removeFromSlot(entry, model)
		model:SetAttribute("StolenBy", player.UserId)
		carried[player] = {
			Model = model,
			FromBase = entry,
			ReturnAt = os.clock() + BrainrotData.Config.StealReturnSeconds,
		}
		if connection then
			connection:Disconnect()
		end
		stealConnections[model] = nil
		notify(player, "You stole " .. name .. "! Run it home to your base!")
		if entry.Owner then
			notify(entry.Owner, player.Name .. " is stealing your " .. name .. "! Slap them!")
		end
	end)
	stealConnections[model] = connection
end

-- The Slap tool: one swing, one target in range. A carrier drops the
-- brainrot; anyone else just gets shoved to a walk.
local function hookSlapTool(player, tool)
	tool.Activated:Connect(function()
		local now = os.clock()
		if now - (lastSlap[player] or 0) < 1 then
			return
		end
		lastSlap[player] = now
		local character = player.Character
		if not character then
			return
		end
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then
			return
		end
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player and other.Character then
				local otherRoot = other.Character:FindFirstChild("HumanoidRootPart")
				if otherRoot and (otherRoot.Position - rootPart.Position).Magnitude < 8 then
					local carry = carried[other]
					if carry then
						local model = carry.Model
						carried[other] = nil
						model:SetAttribute("StolenBy", 0)
						returnHome({ Model = model, FromBase = carry.FromBase })
						notify(other, "You got slapped! Your stolen brainrot ran home.")
						notify(player, "SLAP! You saved the brainrot.")
					else
						local humanoid = other.Character:FindFirstChildOfClass("Humanoid")
						if humanoid then
							humanoid.WalkSpeed = 8
							task.delay(2, function()
								if humanoid.Parent then
									humanoid.WalkSpeed = 16
								end
							end)
						end
					end
				end
			end
		end
	end)
end

function StealSystem.setup(remoteFolder)
	remotes = remoteFolder

	-- Hook the Slap tool every time a player spawns with it.
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(_character)
			local tool = player.Backpack:WaitForChild("Slap", 10)
			if tool then
				hookSlapTool(player, tool)
			end
		end)
		player.CharacterRemoving:Connect(function()
			local carry = carried[player]
			if carry then
				carried[player] = nil
				carry.Model:SetAttribute("StolenBy", 0)
				returnHome(carry)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local carry = carried[player]
		if carry then
			carried[player] = nil
			carry.Model:SetAttribute("StolenBy", 0)
			returnHome(carry)
		end
	end)

	-- Carry loop: the stolen brainrot floats above the thief's head
	-- until they reach their own base, the timer ends, or they are slapped.
	RunService.Heartbeat:Connect(function()
		for player, carry in pairs(carried) do
			local character = player.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			local model = carry.Model
			if not rootPart or not model.Parent then
				carried[player] = nil
				model:SetAttribute("StolenBy", 0)
				returnHome(carry)
			else
				model:PivotTo(CFrame.new(rootPart.Position + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, math.rad(90), 0))
				local own = BaseManager.getBase(player)
				if own and BaseManager.isPointInBase(rootPart.Position, own) then
					if BaseManager.getFreeSlot(own) then
						carried[player] = nil
						model:SetAttribute("StolenBy", 0)
						BaseManager.placeInSlot(own, model)
						StealSystem.armStealTouch(own, model)
						notify(player, "Stolen brainrot secured! It earns for you now.")
					else
						carried[player] = nil
						model:SetAttribute("StolenBy", 0)
						returnHome(carry)
						notify(player, "Your base is full! The brainrot ran home.")
					end
				elseif os.clock() > carry.ReturnAt then
					carried[player] = nil
					model:SetAttribute("StolenBy", 0)
					returnHome(carry)
					notify(player, "Too slow! The brainrot ran home.")
				end
			end
		end
	end)
end

return StealSystem
