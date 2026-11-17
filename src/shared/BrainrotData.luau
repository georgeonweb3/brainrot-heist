-- BrainrotData: the whole game's data in one place.
-- Every brainrot character, its rarity, price and income per second,
-- the mutations that can roll on spawn, the rebirth ladder, and the
-- numbers the conveyor, bases and steal timer run on.
-- Shared by the server (spawner, economy, stealing) and the client (HUD).

local BrainrotData = {}

-- Rarity ladder. Weight is the spawn weight; higher rarities are rarer.
BrainrotData.Rarities = {
	Common = { Order = 1, Color = Color3.fromRGB(170, 170, 170), Weight = 40 },
	Rare = { Order = 2, Color = Color3.fromRGB(80, 140, 255), Weight = 25 },
	Epic = { Order = 3, Color = Color3.fromRGB(170, 80, 255), Weight = 16 },
	Legendary = { Order = 4, Color = Color3.fromRGB(255, 165, 0), Weight = 10 },
	Mythic = { Order = 5, Color = Color3.fromRGB(255, 60, 120), Weight = 6 },
	God = { Order = 6, Color = Color3.fromRGB(0, 220, 255), Weight = 2 },
	Secret = { Order = 7, Color = Color3.fromRGB(255, 215, 0), Weight = 1 },
}

-- The cast. Model must match a model of the same name under
-- ReplicatedStorage.BrainrotTemplates. Income is cash per second
-- while the brainrot sits on your base.
BrainrotData.Characters = {
	{ Id = "NoobiniPizzanini", Name = "Noobini Pizzanini", Rarity = "Common", Price = 25, Income = 1, Model = "NoobiniPizzanini" },
	{ Id = "ChimpanziniBananini", Name = "Chimpanzini Bananini", Rarity = "Common", Price = 75, Income = 3, Model = "ChimpanziniBananini" },
	{ Id = "TungTungSahur", Name = "Tung Tung Tung Sahur", Rarity = "Rare", Price = 250, Income = 10, Model = "TungTungSahur" },
	{ Id = "TrippiTroppi", Name = "Trippi Troppi", Rarity = "Rare", Price = 400, Income = 15, Model = "TrippiTroppi" },
	{ Id = "TralaleroTralala", Name = "Tralalero Tralala", Rarity = "Epic", Price = 1000, Income = 35, Model = "TralaleroTralala" },
	{ Id = "CappuccinoAssassino", Name = "Cappuccino Assassino", Rarity = "Epic", Price = 1500, Income = 50, Model = "CappuccinoAssassino" },
	{ Id = "BombardiroCrocodilo", Name = "Bombardiro Crocodilo", Rarity = "Legendary", Price = 3000, Income = 100, Model = "BombardiroCrocodilo" },
	{ Id = "LiriliLarila", Name = "Lirili Larila", Rarity = "Legendary", Price = 5000, Income = 150, Model = "LiriliLarila" },
	{ Id = "BrrBrrPatapim", Name = "Brr Brr Patapim", Rarity = "Mythic", Price = 10000, Income = 300, Model = "BrrBrrPatapim" },
	{ Id = "LaVacaSaturno", Name = "La Vaca Saturno Saturnita", Rarity = "Mythic", Price = 15000, Income = 500, Model = "LaVacaSaturno" },
	{ Id = "FrigoCamelo", Name = "Frigo Camelo", Rarity = "God", Price = 50000, Income = 1000, Model = "FrigoCamelo" },
	{ Id = "GiraffaCeleste", Name = "Giraffa Celeste", Rarity = "Secret", Price = 250000, Income = 10000, Model = "GiraffaCeleste" },
}

-- Mutations roll when a brainrot spawns. Multiplier applies to its income.
BrainrotData.Mutations = {
	{ Id = "None", Tag = "", Multiplier = 1, Chance = 0.86 },
	{ Id = "Gold", Tag = "GOLD", Multiplier = 2, Chance = 0.10 },
	{ Id = "Diamond", Tag = "DIAMOND", Multiplier = 4, Chance = 0.03 },
	{ Id = "Rainbow", Tag = "RAINBOW", Multiplier = 8, Chance = 0.01 },
}

-- Rebirth ladder. A rebirth resets your cash to the start amount and
-- clears your base, but multiplies ALL future income by Multiplier.
BrainrotData.Rebirths = {
	{ Cost = 10000, Multiplier = 2 },
	{ Cost = 100000, Multiplier = 4 },
	{ Cost = 1000000, Multiplier = 8 },
	{ Cost = 10000000, Multiplier = 16 },
	{ Cost = 100000000, Multiplier = 32 },
}

BrainrotData.Config = {
	StartCash = 100,
	ConveyorStartX = -150,
	ConveyorEndX = 150,
	ConveyorTopY = 1,
	WalkSpeed = 6, -- studs per second along the belt
	SpawnInterval = 4, -- seconds between spawns
	MaxOnBelt = 8,
	BaseSlotCount = 8,
	LockDuration = 30, -- seconds a base lock holds
	LockCooldown = 60, -- seconds before the base can lock again
	StealReturnSeconds = 45, -- a stolen brainrot runs home after this long
	BaseCount = 8,
}

-- Look a character up by its Id.
function BrainrotData.getCharacter(id)
	for _, char in ipairs(BrainrotData.Characters) do
		if char.Id == id then
			return char
		end
	end
	return nil
end

-- Roll one character: pick a rarity by weight, then a character of
-- that rarity at random.
function BrainrotData.rollCharacter()
	local total = 0
	for _, rarity in pairs(BrainrotData.Rarities) do
		total += rarity.Weight
	end
	local roll = math.random() * total
	local pickedRarity = "Common"
	for name, rarity in pairs(BrainrotData.Rarities) do
		roll -= rarity.Weight
		if roll <= 0 then
			pickedRarity = name
			break
		end
	end
	local pool = {}
	for _, char in ipairs(BrainrotData.Characters) do
		if char.Rarity == pickedRarity then
			table.insert(pool, char)
		end
	end
	if #pool == 0 then
		return BrainrotData.Characters[1]
	end
	return pool[math.random(1, #pool)]
end

-- Roll one mutation by its chance.
function BrainrotData.rollMutation()
	local roll = math.random()
	local running = 0
	for _, mutation in ipairs(BrainrotData.Mutations) do
		running += mutation.Chance
		if roll <= running then
			return mutation
		end
	end
	return BrainrotData.Mutations[1]
end

-- Short money text: 1250 -> "$1,250", 2500000 -> "$2.5M".
function BrainrotData.formatMoney(amount)
	amount = math.floor(amount)
	if amount >= 1000000 then
		return "$" .. string.format("%.1fM", amount / 1000000)
	elseif amount >= 10000 then
		return "$" .. string.format("%.1fK", amount / 1000)
	end
	local text = tostring(amount)
	local out = ""
	while #text > 3 do
		out = "," .. string.sub(text, -3) .. out
		text = string.sub(text, 1, -4)
	end
	return "$" .. text .. out
end

return BrainrotData
