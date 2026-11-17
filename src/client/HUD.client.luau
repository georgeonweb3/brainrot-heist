-- Brainrot Heist HUD: the screen interface over the 3D world.
-- Top bar shows cash, income per second and brainrots owned; the
-- buttons lock the base and rebirth; toasts carry the server's news.
-- Built from the BrainrotHUD ScreenGui in StarterGui.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotData = require(ReplicatedStorage:WaitForChild("BrainrotData"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("BrainrotHUD")

local topBar = gui:WaitForChild("TopBar")
local cashLabel = topBar:WaitForChild("CashLabel")
local incomeLabel = topBar:WaitForChild("IncomeLabel")
local ownedLabel = topBar:WaitForChild("OwnedLabel")
local toastLabel = gui:WaitForChild("ToastLabel")
local lockButton = gui:WaitForChild("LockButton")
local rebirthButton = gui:WaitForChild("RebirthButton")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local notifyEvent = remotes:WaitForChild("Notify")
local lockBaseEvent = remotes:WaitForChild("LockBase")
local requestRebirth = remotes:WaitForChild("RequestRebirth")

local leaderstats = player:WaitForChild("leaderstats")
local cash = leaderstats:WaitForChild("Cash")
local incomePerSec = leaderstats:WaitForChild("IncomePerSec")
local owned = leaderstats:WaitForChild("BrainrotsOwned")
local rebirths = leaderstats:WaitForChild("Rebirths")

local function refreshCash()
	cashLabel.Text = "Cash: " .. BrainrotData.formatMoney(cash.Value)
end

local function refreshIncome()
	incomeLabel.Text = "+" .. BrainrotData.formatMoney(incomePerSec.Value) .. "/s"
end

local function refreshOwned()
	ownedLabel.Text = tostring(owned.Value) .. " brainrots"
end

local function refreshRebirth()
	local nextTier, count = nil, rebirths.Value
	for i, tier in ipairs(BrainrotData.Rebirths) do
		if i == count + 1 then
			nextTier = tier
			break
		end
	end
	if nextTier then
		rebirthButton.Text = "Rebirth " .. (count + 1) .. " (" .. BrainrotData.formatMoney(nextTier.Cost) .. ")"
	else
		rebirthButton.Text = "Max Rebirth!"
	end
end

cash.Changed:Connect(refreshCash)
incomePerSec.Changed:Connect(refreshIncome)
owned.Changed:Connect(refreshOwned)
rebirths.Changed:Connect(refreshRebirth)
refreshCash()
refreshIncome()
refreshOwned()
refreshRebirth()

-- Toasts from the server: show for three seconds, then fade.
local toastToken = 0
notifyEvent.OnClientEvent:Connect(function(message)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = message
	toastLabel.TextTransparency = 0
	toastLabel.BackgroundTransparency = 0.3
	task.delay(3, function()
		if token == toastToken then
			toastLabel.TextTransparency = 1
			toastLabel.BackgroundTransparency = 1
		end
	end)
end)

-- Lock button: ask the server, then show the cooldown on the button.
local lockCooling = false
lockButton.MouseButton1Click:Connect(function()
	if lockCooling then
		return
	end
	lockBaseEvent:FireServer()
	lockCooling = true
	lockButton.Text = "Locked!"
	task.delay(5, function()
		lockButton.Text = "Lock Base (30s)"
		lockCooling = false
	end)
end)

-- Rebirth button: ask the server, toast the answer.
rebirthButton.MouseButton1Click:Connect(function()
	local ok, message = requestRebirth:InvokeServer()
	toastLabel.Text = message
	toastLabel.TextTransparency = 0
	toastLabel.BackgroundTransparency = 0.3
	task.delay(3, function()
		toastLabel.TextTransparency = 1
		toastLabel.BackgroundTransparency = 1
	end)
end)
