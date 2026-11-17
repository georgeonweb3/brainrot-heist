-- Economy: cash, income and rebirths.
-- Every second each player's brainrots pay out their income (times
-- mutation and rebirth multipliers) into leaderstats Cash. Rebirth
-- resets cash and clears the base for a permanent income multiplier.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotData = require(ReplicatedStorage:WaitForChild("BrainrotData"))
local BaseManager = require(script.Parent:WaitForChild("BaseManager"))

local Economy = {}

-- Rebirth multiplier for a player: 2 per rebirth, from the ladder.
function Economy.getRebirthMultiplier(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return 1
	end
	local rebirths = leaderstats:FindFirstChild("Rebirths")
	local count = rebirths and rebirths.Value or 0
	local tier = BrainrotData.Rebirths[count]
	if tier then
		return tier.Multiplier
	end
	-- Past the last ladder rung, keep doubling.
	return 2 ^ count
end

-- The next rebirth tier for a player, or nil at the end of the ladder.
function Economy.nextRebirth(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local count = 0
	if leaderstats then
		local rebirths = leaderstats:FindFirstChild("Rebirths")
		count = rebirths and rebirths.Value or 0
	end
	return BrainrotData.Rebirths[count + 1], count
end

-- Handle a rebirth request from the client. Returns ok, message.
function Economy.requestRebirth(player)
	local tier, count = Economy.nextRebirth(player)
	if not tier then
		return false, "You are at the top of the rebirth ladder!"
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return false, "Your stats are not ready yet."
	end
	local cash = leaderstats:FindFirstChild("Cash")
	if not cash or cash.Value < tier.Cost then
		return false, "Rebirth " .. (count + 1) .. " costs " .. BrainrotData.formatMoney(tier.Cost) .. "."
	end
	local entry = BaseManager.getBase(player)
	if entry then
		BaseManager.clearBase(entry)
	end
	cash.Value = BrainrotData.Config.StartCash
	leaderstats.Rebirths.Value = count + 1
	return true, "REBIRTH! Your income is now x" .. tier.Multiplier .. " forever."
end

function Economy.setup()
	Players.PlayerAdded:Connect(function(player)
		local leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player

		local cash = Instance.new("IntValue")
		cash.Name = "Cash"
		cash.Value = BrainrotData.Config.StartCash
		cash.Parent = leaderstats

		local rebirths = Instance.new("IntValue")
		rebirths.Name = "Rebirths"
		rebirths.Value = 0
		rebirths.Parent = leaderstats

		local income = Instance.new("IntValue")
		income.Name = "IncomePerSec"
		income.Value = 0
		income.Parent = leaderstats

		local owned = Instance.new("IntValue")
		owned.Name = "BrainrotsOwned"
		owned.Value = 0
		owned.Parent = leaderstats
	end)

	-- Pay out once a second.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local leaderstats = player:FindFirstChild("leaderstats")
				if leaderstats then
					local entry = BaseManager.getBase(player)
					local total = 0
					local count = 0
					if entry then
						for _, model in ipairs(BaseManager.getOwnedBrainrots(entry)) do
							local income = model:GetAttribute("Income") or 0
							local multiplier = model:GetAttribute("Multiplier") or 1
							total += income * multiplier
							count += 1
						end
					end
					total = math.floor(total * Economy.getRebirthMultiplier(player))
					leaderstats.IncomePerSec.Value = total
					leaderstats.BrainrotsOwned.Value = count
					leaderstats.Cash.Value += total
				end
			end
		end
	end)
end

return Economy
