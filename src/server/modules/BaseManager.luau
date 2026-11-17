-- BaseManager: owns the eight player bases.
-- A base is a Model under workspace.Bases with a Slots folder (the eight
-- pads a brainrot can sit on), an Owned folder (the brainrots living
-- there now), a Door part and a Sign part. This module hands bases to
-- players as they join, tracks who owns what, where each brainrot sits,
-- and runs the base lock (door shut, stealing blocked).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotData = require(ReplicatedStorage:WaitForChild("BrainrotData"))

local BaseManager = {}

local bases = {} -- [baseModel] = entry
local byOwner = {} -- [player] = entry

local function entryFor(model)
	return bases[model]
end

-- Read the world once at startup. Bases are named Base1..Base8 and
-- their Slots folders hold pads named Slot1..Slot8.
function BaseManager.setup()
	local folder = workspace:WaitForChild("Bases")
	for _, base in ipairs(folder:GetChildren()) do
		if base:IsA("Model") then
			local slotsFolder = base:FindFirstChild("Slots")
			local slots = {}
			if slotsFolder then
				for _, slot in ipairs(slotsFolder:GetChildren()) do
					if slot:IsA("BasePart") then
						table.insert(slots, slot)
					end
				end
				table.sort(slots, function(a, b)
					return a.Name < b.Name
				end)
			end
			local floor = base:FindFirstChild("Floor")
			local center = Vector3.new(0, 0, 0)
			if floor and floor:IsA("BasePart") then
				center = floor.Position
			end
			bases[base] = {
				Model = base,
				Name = base.Name,
				Owner = nil,
				LockedUntil = 0,
				LockCooldownUntil = 0,
				Slots = slots,
				Occupied = {}, -- [slotIndex] = brainrot model
				Center = center,
			}
		end
	end
end

function BaseManager.getBase(player)
	return byOwner[player]
end

function BaseManager.getEntry(model)
	return entryFor(model)
end

function BaseManager.isLocked(entry)
	return os.clock() < entry.LockedUntil
end

-- Give the joining player the first free base and write their name
-- on its sign. Returns the entry, or nil when the map is full.
function BaseManager.assignBase(player)
	for _, entry in pairs(bases) do
		if entry.Owner == nil then
			entry.Owner = player
			byOwner[player] = entry
			local sign = entry.Model:FindFirstChild("Sign")
			if sign then
				local gui = sign:FindFirstChildOfClass("SurfaceGui")
				local label = gui and gui:FindFirstChildOfClass("TextLabel")
				if label then
					label.Text = player.Name .. "'s Base"
				end
			end
			return entry
		end
	end
	return nil
end

-- Free a base when its player leaves: clear the owner, wipe the sign
-- and destroy the brainrots left on it.
function BaseManager.releaseBase(player)
	local entry = byOwner[player]
	if not entry then
		return
	end
	byOwner[player] = nil
	entry.Owner = nil
	entry.LockedUntil = 0
	entry.LockCooldownUntil = 0
	entry.Occupied = {}
	local owned = entry.Model:FindFirstChild("Owned")
	if owned then
		for _, model in ipairs(owned:GetChildren()) do
			model:Destroy()
		end
	end
	local sign = entry.Model:FindFirstChild("Sign")
	if sign then
		local gui = sign:FindFirstChildOfClass("SurfaceGui")
		local label = gui and gui:FindFirstChildOfClass("TextLabel")
		if label then
			label.Text = entry.Name
		end
	end
end

-- First empty slot index, or nil when the base is full.
function BaseManager.getFreeSlot(entry)
	for i = 1, #entry.Slots do
		if entry.Occupied[i] == nil then
			return i
		end
	end
	return nil
end

-- Make sure a brainrot model has a PrimaryPart so PivotTo works.
local function ensurePrimary(model)
	if model.PrimaryPart == nil then
		model.PrimaryPart = model:FindFirstChild("RootPart")
	end
end

-- Sit a brainrot on a base slot: parent it under Owned, stand it on
-- the pad, anchor it, and record who owns it and where it sits.
-- Returns the slot index, or nil when the base is full.
function BaseManager.placeInSlot(entry, model)
	local slotIndex = BaseManager.getFreeSlot(entry)
	if not slotIndex then
		return nil
	end
	local pad = entry.Slots[slotIndex]
	local owned = entry.Model:FindFirstChild("Owned")
	if not owned then
		return nil
	end
	ensurePrimary(model)
	model:SetAttribute("SlotIndex", slotIndex)
	if entry.Owner then
		model:SetAttribute("OwnerId", entry.Owner.UserId)
	else
		model:SetAttribute("OwnerId", 0)
	end
	model.Parent = owned
	entry.Occupied[slotIndex] = model
	local feetY = pad.Position.Y + pad.Size.Y / 2
	-- Face the conveyor: bases above the belt face down (-Z), below face up (+Z).
	local faceAngle = 0
	if entry.Center.Z > 0 then
		faceAngle = 180
	end
	model:PivotTo(CFrame.new(pad.Position.X, feetY + 2.5, pad.Position.Z) * CFrame.Angles(0, math.rad(faceAngle), 0))
	return slotIndex
end

-- Lift a brainrot off its slot (stealing, rebirth, leaving). The model
-- is left parented where it is; the caller re-parents or destroys it.
function BaseManager.removeFromSlot(entry, model)
	local slotIndex = model:GetAttribute("SlotIndex")
	if slotIndex and entry.Occupied[slotIndex] == model then
		entry.Occupied[slotIndex] = nil
	end
	model:SetAttribute("SlotIndex", 0)
end

-- Every brainrot currently living on a base.
function BaseManager.getOwnedBrainrots(entry)
	local owned = entry.Model:FindFirstChild("Owned")
	if not owned then
		return {}
	end
	local list = {}
	for _, model in ipairs(owned:GetChildren()) do
		if model:IsA("Model") then
			table.insert(list, model)
		end
	end
	return list
end

-- Destroy every brainrot on a base (rebirth).
function BaseManager.clearBase(entry)
	entry.Occupied = {}
	local owned = entry.Model:FindFirstChild("Owned")
	if owned then
		for _, model in ipairs(owned:GetChildren()) do
			model:Destroy()
		end
	end
end

-- Is a world position inside this base's walls?
function BaseManager.isPointInBase(position, entry)
	return math.abs(position.X - entry.Center.X) < 15 and math.abs(position.Z - entry.Center.Z) < 15
end

-- Lock the caller's base for LockDuration: the door shuts (solid) and
-- stealing is blocked. One lock, then a cooldown before the next.
-- Returns ok, message.
function BaseManager.lockBase(player)
	local entry = byOwner[player]
	if not entry then
		return false, "You have no base yet."
	end
	local now = os.clock()
	if now < entry.LockCooldownUntil then
		return false, "Lock is recharging. Try again soon."
	end
	entry.LockedUntil = now + BrainrotData.Config.LockDuration
	entry.LockCooldownUntil = now + BrainrotData.Config.LockCooldown
	local door = entry.Model:FindFirstChild("Door")
	if door and door:IsA("BasePart") then
		door.CanCollide = true
		door.Transparency = 0.1
	end
	task.delay(BrainrotData.Config.LockDuration, function()
		if door and door.Parent then
			door.CanCollide = false
			door.Transparency = 0.7
		end
	end)
	return true, "Base locked for " .. BrainrotData.Config.LockDuration .. " seconds!"
end

return BaseManager
