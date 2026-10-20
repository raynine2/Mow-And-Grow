-- A run server, like a round of Chop A Forest: chop grass, carry bundles, shred them for coins, buy tools, clear
-- every area to open the next one, earn gems. Party progress (which area is open) is shared; coins, tools and
-- upgrades are per player.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Net = require(script.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)
local Stats = require(script.Parent.Stats)
local RunBuilder = require(script.Parent.RunBuilder)
local Field = require(script.Parent.Field)
local Carry = require(script.Parent.Carry)
local Tools = require(script.Parent.Tools)
local Mowers = require(script.Parent.Mowers)
local Boss = require(script.Parent.Boss)
local Quests = require(script.Parent.Quests)
local GemShop = require(script.Parent.GemShop)
local Loot = require(script.Parent.Loot)
local Models = require(script.Parent.Models)
local BestTimes = require(script.Parent.BestTimes)

local Run = {}

local info = nil :: any
local zone = 1 -- the zone the party is working on (highest unlocked)
local started = false
local completing = false
local lastSwing: { [Player]: number } = {}
local worldDirty = true
local startedAt = workspace:GetServerTimeNow()
local devCutting = false -- DevHook clearZone: cut without dropping loot
local rng = Random.new()

-------------------------------------------------------------------------------------------------------------
-- world state for the HUD
-------------------------------------------------------------------------------------------------------------
local function worldState()
	local def = Config.ZONES[zone]
	local left = 0
	for z = 1, #Config.ZONES do
		left += Field.remainingIn(z)
	end
	local spots = {}
	for _, pad in (info and info.sellPads) or {} do
		table.insert(spots, pad.pos)
	end
	return {
		mode = "Run",
		zone = zone,
		zones = #Config.ZONES,
		name = def.name,
		cut = Field.totalIn(zone) - Field.remainingIn(zone),
		total = Field.totalIn(zone),
		boss = Boss.state(),
		sellPos = info and info.sellPos,
		sellSpots = spots, -- every shredder's pad (the hub's and the drop-off)
		left = left, -- clumps still standing in the whole map
		started = startedAt,
	}
end

local function pushWorld()
	worldDirty = true
end

-------------------------------------------------------------------------------------------------------------
-- zones
-------------------------------------------------------------------------------------------------------------
-- `hideAfter`: seconds to leave the gate visible (clients play it sinking into the ground), else at once.
local function openGate(gate: Model, hideAfter: number?)
	if gate:GetAttribute("Open") then
		return
	end
	gate:SetAttribute("Open", true)
	for _, p in gate:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false -- the way is open right away
		end
	end
	local function hide()
		for _, p in gate:GetDescendants() do
			if p:IsA("BasePart") then
				p.Transparency = 1
			elseif p:IsA("SurfaceGui") then
				p.Enabled = false
			end
		end
	end
	if hideAfter then
		task.delay(hideAfter, hide)
	else
		hide()
	end
end

local function unlock(z: number, gateShow: number?)
	zone = z
	Field.unlock(z)
	-- every gate between two open plots opens (the newest area's gates sink when its banner shows)
	for _, g in info.gates do
		if g.b <= z then
			openGate(g.model, if g.b == z then gateShow else nil)
		end
	end
	for _, p in Players:GetPlayers() do
		local data = PlayerData.get(p)
		if data and data.run and data.run.zone < z then
			data.run.zone = z
			PlayerData.changed(p)
		end
	end
	pushWorld()
end

local function completeRun()
	if completing then
		return
	end
	completing = true
	for _, p in Players:GetPlayers() do
		local data = PlayerData.get(p)
		if data then
			local gems = math.floor(Config.RUN_COMPLETE_GEMS * Stats.compute(p, data).gems)
			data.gems += gems
			data.stats.runs += 1
			local time = if data.run then data.run.time or 0 else 0
			local best = BestTimes.submit(p, data, time)
			data.run = nil -- coins, tools and coin mowers end with the run
			PlayerData.changed(p)
			Net.send(p, "Fx", "runComplete", { gems = gems, time = time, best = best })
			task.spawn(PlayerData.save, p)
		end
	end
	task.wait(12)
	if RunService:IsStudio() then
		Net.notifyAll("(Studio) Teleports don't work here. Stop and start the test to play again.", "yellow")
		return
	end
	local players = Players:GetPlayers()
	if #players > 0 then
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(game.PlaceId, players)
		end)
		if not ok then
			warn("[Run] teleport back to lobby failed: " .. tostring(err))
			Net.notifyAll("Couldn't send you back to the lobby. Please rejoin.", "red")
		end
	end
end

-- An area is mowed bare (Chop A Forest: the next wood unlocks). Everyone gets the area's reward, its stubble
-- puffs away and the next area's gates sink; the last area finishes the run.
local function onAreaCleared(z: number)
	local def = Config.ZONES[z].boss -- the area reward is the old boss reward
	for _, p in Players:GetPlayers() do
		local data = PlayerData.get(p)
		if data and data.run then
			local gems = math.floor(def.gems * Stats.compute(p, data).gems)
			data.gems += gems
			data.run.coins += def.coins
			PlayerData.changed(p)
			Net.send(p, "Fx", "reward", { coins = def.coins, gems = gems, title = Config.ZONES[z].name:upper() .. " CLEARED!" })
		end
	end
	Field.clearStubble(z)
	if z >= #Config.ZONES then
		task.spawn(completeRun)
	else
		unlock(z + 1, 6)
		task.delay(3, function()
			Net.all("Fx", "zoneOpen", { zone = z + 1, name = Config.ZONES[z + 1].name })
		end)
	end
end

local function onBossDefeated(z: number, _damageBy: { [Player]: number })
	local def = Config.ZONES[z].boss
	for _, p in Players:GetPlayers() do
		local data = PlayerData.get(p)
		if data and data.run then
			-- everyone in the party gets the reward; helpers get the full amount too
			local gems = math.floor(def.gems * Stats.compute(p, data).gems)
			data.gems += gems
			data.run.coins += def.coins
			data.stats.bosses += 1
			PlayerData.changed(p)
			Net.send(p, "Fx", "reward", { coins = def.coins, gems = gems, title = def.name:upper() .. " DEFEATED!" })
		end
	end
	for _, p in Players:GetPlayers() do
		Quests.event(p, "boss", 1)
	end
	if z >= #Config.ZONES then
		task.spawn(completeRun)
	else
		-- the gate sinks into the ground when the banner shows (3 s after the boss falls, for ~2.5 s)
		unlock(z + 1, 6)
		task.delay(3, function()
			Net.all("Fx", "zoneOpen", { zone = z + 1, name = Config.ZONES[z + 1].name })
		end)
	end
end

-------------------------------------------------------------------------------------------------------------
-- cutting
-------------------------------------------------------------------------------------------------------------
local bagWarn: { [Player]: number } = {}
local function warnBagFull(player: Player)
	local now = os.clock()
	if (bagWarn[player] or 0) + 3 < now then
		bagWarn[player] = now
		-- the bag bar shakes and the guide arrow points at the Shredder (or says to pick up your loot first)
		Net.send(player, "Fx", "bagFull", { ground = Loot.count(player) })
	end
end

-- Bundles in the bag plus bundles still on the ground: you can't cut more than you can carry.
local function bagFull(player: Player): boolean
	local ground = Loot.count(player)
	return Carry.count(player) + ground >= Carry.capacity(player) or ground >= Config.LOOT.maxOnGround
end

-- A patch was cut: its bundle drops on the ground (two with Bigger Bundle luck, sometimes a gem too) for the
-- cutter to pick up (server/Loot). Returns false when there's no room for it, so the patch stays standing.
local function onCut(player: Player, patch): boolean
	local data = PlayerData.get(player)
	if not data or not data.run then
		return false
	end
	if devCutting then
		data.stats.cut += 1
		return true
	end
	if bagFull(player) then
		warnBagFull(player)
		return false
	end
	local stats = Stats.compute(player, data)
	local pos = patch.part.Position
	-- the bundles land where the clump falls, when it hits the ground (a big clump breaks into several, like a
	-- tree into logs); Bigger Bundle sometimes adds one
	local land = patch.landPos or pos
	local wait = Field.FALL_TIME
	local count = Config.ZONES[patch.z].drops or 1
	if stats.bundle > 0 and rng:NextNumber() < stats.bundle then
		count += 1
	end
	for i = 1, count do
		local along = (i - (count + 1) / 2) * 1.6
		local spot = land + (if patch.fallDir then patch.fallDir * along else Vector3.zero)
		Loot.drop(player, "bundle", spot, patch.z, patch.mut, nil, wait)
	end
	if rng:NextNumber() < Config.GEM_DROP.chance then
		Loot.drop(player, "gem", land, patch.z, nil, rng:NextInteger(Config.GEM_DROP.min, Config.GEM_DROP.max), wait)
	end
	Quests.event(player, "cut", 1)
	data.stats.cut += 1
	local m = Config.mutation(patch.mut or "None")
	if m.id ~= "None" then
		data.stats.rare = (data.stats.rare or 0) + 1
	end
	if m.gems > 0 then
		local gems = math.max(1, math.floor(m.gems * stats.gems))
		data.gems += gems
		Net.send(player, "Fx", "gems", { pos = pos, amount = gems, mut = m.id })
	end
	return true
end

local function rootOf(player: Player): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Where a player picks up loot: their Grasp reach round them, and round the mower they're driving.
Loot.reach = function(player: Player)
	local points = {}
	local data = PlayerData.get(player)
	local root = rootOf(player)
	if root and data then
		table.insert(points, { pos = root.Position, radius = Stats.compute(player, data).grasp })
	end
	local mower, mdef = Mowers.driving(player)
	if mower and mdef and mower.PrimaryPart then
		table.insert(points, { pos = mower.PrimaryPart.Position, radius = mdef.radius + 4 })
	end
	return points
end

Loot.onGem = function(player: Player, amount: number, _pos: Vector3)
	local data = PlayerData.get(player)
	if data then
		data.gems += math.max(1, math.floor(amount * Stats.compute(player, data).gems))
		PlayerData.changed(player)
	end
end

-- A bundle went into the bag: a grass type you've never collected goes into your Index (and pays gems once).
Loot.onBundle = function(player: Player, z: number, m: string?)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local key = z .. ":" .. (m or "None")
	if not data.index[key] then
		data.index[key] = true
		local gems = math.max(1, math.floor(Config.INDEX_GEMS * Stats.compute(player, data).gems))
		data.gems += gems
		Net.send(player, "Fx", "indexNew", { z = z, mut = m or "None", gems = gems })
		PlayerData.changed(player)
	end
end

Loot.onFull = function(player: Player)
	warnBagFull(player)
end

local function onSwing(player: Player, look: any)
	local data = PlayerData.get(player)
	if not data or not data.run or completing then
		return
	end
	local def, tool = Tools.equipped(player)
	if not def or def.kind ~= "swing" or not tool then
		return
	end
	local now = os.clock()
	if (lastSwing[player] or 0) + def.cooldown * Stats.compute(player, data).swing * 0.85 > now then
		return
	end
	lastSwing[player] = now
	local root = rootOf(player)
	if not root then
		return
	end
	Tools.slash(tool)
	local stats = Stats.compute(player, data)
	local damage = def.damage * stats.power
	-- the camera's look direction from the client picks the clump (checked: a unit vector; else the body's facing)
	local aim = root.CFrame.LookVector
	if typeof(look) == "Vector3" and look.Magnitude > 0.5 and look.Magnitude < 1.5 and look.X == look.X then
		aim = look.Unit
	end
	if bagFull(player) then
		warnBagFull(player)
	else
		Field.hitAim(player, root.Position, aim, def.radius, damage, def.targets, stats.luck)
	end
	if Boss.inReach(root.Position, def.radius) then
		Boss.damage(player, damage * Config.BOSS_TOOL_MULT)
	end
end

-- Auto tools and mowers cut every tick.
local function autoTick()
	for _, player in Players:GetPlayers() do
		local data = PlayerData.get(player)
		if data and data.run then
			local stats = Stats.compute(player, data)
			local mower, mdef = Mowers.driving(player)
			if mower and mdef and mower.PrimaryPart then
				local fuel = mower:GetAttribute("Fuel") or 0
				if fuel > 0 then
					local pos = mower.PrimaryPart.Position
					local dmg = mdef.damage * stats.power
					if bagFull(player) then
						warnBagFull(player)
					else
						Field.hit(player, pos, mdef.radius, dmg, nil, stats.luck)
					end
					if Boss.inReach(pos, mdef.radius) then
						Boss.damage(player, dmg)
					end
				end
			else
				local def = Tools.equipped(player)
				local root = rootOf(player)
				if def and def.kind == "auto" and root then
					local dmg = def.damage * stats.power
					if bagFull(player) then
						warnBagFull(player)
					else
						Field.hit(player, root.Position, def.radius, dmg, nil, stats.luck)
					end
					if Boss.inReach(root.Position, def.radius) then
						Boss.damage(player, dmg)
					end
				end
			end
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- selling + shops
-------------------------------------------------------------------------------------------------------------
local function sell(player: Player, pad)
	local data = PlayerData.get(player)
	if not data or not data.run or #data.run.carry == 0 then
		return
	end
	local count = #data.run.carry
	local coins = math.floor(Carry.value(data) * Stats.compute(player, data).sell)
	data.run.coins += coins
	data.stats.sold = (data.stats.sold or 0) + count
	data.stats.coinsEarned = (data.stats.coinsEarned or 0) + coins
	Carry.clear(player)
	Net.send(player, "Fx", "sell", { coins = coins, count = count, from = pad.mouth, out = pad.out })
	Net.all("Fx", "shred", { pos = pad.mouth, count = count, by = player.UserId })
	Quests.event(player, "sell", count)
end

-- Walk onto any shredder's pad (the hub's or the drop-off) to sell.
local function sellLoop()
	local pads = info.sellPads or {}
	if #pads == 0 and info.sellPos then
		pads = { { pos = info.sellPos, radius = info.sellRadius, mouth = info.shredderMouth, out = info.shredderOut } }
	end
	while true do
		task.wait(0.3)
		for _, player in Players:GetPlayers() do
			local root = rootOf(player)
			if root then
				for _, pad in pads do
					local d = Vector3.new(root.Position.X - pad.pos.X, 0, root.Position.Z - pad.pos.Z).Magnitude
					if d <= pad.radius and root.Position.Y < pad.pos.Y + 10 then
						sell(player, pad)
						break
					end
				end
			end
		end
	end
end

local function buyTool(player: Player, data, id: string)
	local nextIndex = data.run.tool + 1
	local def = Config.TOOLS[nextIndex]
	if not def or def.id ~= id then
		Net.notify(player, "Buy the tools in order!", "red")
		return
	end
	if data.run.coins < def.cost then
		Net.notify(player, "Not enough coins!", "red")
		return
	end
	data.run.coins -= def.cost
	data.run.tool = nextIndex
	Tools.give(player)
	Quests.event(player, "tool", nextIndex)
	Net.send(player, "Fx", "purchase", { big = true, item = def.name })
end

local function buyUpgrade(player: Player, data, id: string)
	local u = Config.upgrade(id)
	if not u then
		return
	end
	local level = data.run.upgrades[id] or 0
	if level >= u.max then
		Net.notify(player, u.name .. " is maxed!", "yellow")
		return
	end
	local cost = Config.upgradeCost(id, level)
	if data.run.coins < cost then
		Net.notify(player, "Not enough coins!", "red")
		return
	end
	data.run.coins -= cost
	data.run.upgrades[id] = level + 1
	Stats.applyCharacter(player, data)
	Carry.refresh(player)
	Net.send(player, "Fx", "purchase", {})
end

-- The Leaf Vacuum rides on your back (it works on its own, you don't hold it).
local function showVacuum(player: Player)
	local data = PlayerData.get(player)
	local char = player.Character
	local torso = char and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")) :: BasePart?
	if not torso or not data or not data.run or not data.run.vacuum or char:FindFirstChild("VacuumPack") then
		return
	end
	-- hanging at the hip, nozzle pointing down and forward
	local cf = torso.CFrame * CFrame.new(1.35, -0.8, 0.2) * CFrame.Angles(math.rad(-70), 0, 0)
	local m = Models.place("tool_vacuum", char, cf, 0.55, true)
	if m then
		m.Name = "VacuumPack"
		Models.weldTo(m, torso)
	end
end

local function buyBag(player: Player, data, id: string)
	local nextIndex = (data.run.bag or 0) + 1
	local def = Config.BAGS[nextIndex]
	if not def or def.id ~= id then
		Net.notify(player, "Buy the bags in order!", "red")
		return
	end
	if data.run.coins < def.cost then
		Net.notify(player, "Not enough coins!", "red")
		return
	end
	data.run.coins -= def.cost
	data.run.bag = nextIndex
	Quests.event(player, "bag", nextIndex)
	Carry.refresh(player)
	Net.send(player, "Fx", "purchase", { big = true, item = def.name })
end

local function buyVacuum(player: Player, data)
	if data.run.vacuum then
		return
	end
	if data.run.coins < Config.VACUUM.cost then
		Net.notify(player, "Not enough coins!", "red")
		return
	end
	data.run.coins -= Config.VACUUM.cost
	data.run.vacuum = true
	showVacuum(player)
	Net.send(player, "Fx", "purchase", { big = true, item = Config.VACUUM.name })
end

local function buyCoinMower(player: Player, data, id: string)
	local def = Config.mower(id)
	if not def or def.currency ~= "coins" then
		return
	end
	if data.run.mowers[id] then
		Mowers.spawn(player, id)
		return
	end
	if data.run.coins < def.price then
		Net.notify(player, "Not enough coins!", "red")
		return
	end
	data.run.coins -= def.price
	data.run.mowers[id] = true
	data.run.fuel[id] = def.fuel
	Mowers.spawn(player, id)
	Quests.event(player, "mower", 1)
	Net.send(player, "Fx", "purchase", {})
end

-------------------------------------------------------------------------------------------------------------
-- players
-------------------------------------------------------------------------------------------------------------
local function setupPlayer(player: Player, data)
	if not data.run then
		data.run = PlayerData.newRun()
	end
	-- join the party's progress
	if data.run.zone < zone then
		data.run.zone = zone
	end
	-- runs start in first person like the Chop A Forest trailer, but aren't locked there: the client
	-- (CameraView) lets you press V or scroll out to free the mouse, and Shift toggles shift lock
	player.CameraMode = Enum.CameraMode.Classic
	player.DevEnableMouseLock = true
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 30
	PlayerData.changed(player)
	local function onCharacter(char: Model)
		char:WaitForChild("HumanoidRootPart", 10)
		task.wait(0.2)
		Stats.applyCharacter(player, data)
		Tools.give(player)
		Carry.refresh(player)
		showVacuum(player)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

-- The first loaded player decides where the run starts (their saved zone).
local function waitForHost(): number
	local deadline = os.clock() + 60
	while os.clock() < deadline do
		for _, p in Players:GetPlayers() do
			local data = PlayerData.get(p)
			if data then
				local host = p
				local tpData = p:GetJoinData().TeleportData
				if type(tpData) == "table" and tpData.host then
					local h = Players:GetPlayerByUserId(tpData.host)
					if h and PlayerData.get(h) then
						host = h
					end
				end
				local hd = PlayerData.get(host)
				return if hd and hd.run then math.clamp(hd.run.zone, 1, #Config.ZONES) else 1
			end
		end
		task.wait(0.2)
	end
	return 1
end

function Run.start()
	info = RunBuilder.build()
	Loot.start(info.world)
	Mowers.setup(info.world, info.garageSpawn)
	Boss.setup(info.world)

	Field.onCut = onCut
	Field.onProgress = pushWorld
	Field.onZoneCleared = function(z)
		if z == zone then
			for _, p in Players:GetPlayers() do
				Quests.event(p, "zone", 1)
			end
			if Config.BOSSES then
				Boss.spawn(z)
			else
				onAreaCleared(z)
			end
		end
	end
	Boss.onDefeated = onBossDefeated
	Boss.onChanged = pushWorld

	-- remotes
	Net.on("Swing", 12, onSwing)
	Net.on("Buy", 6, function(player, kind, id)
		local data = PlayerData.get(player)
		if not data or not data.run or completing or type(kind) ~= "string" or type(id) ~= "string" then
			return
		end
		if kind == "tool" then
			buyTool(player, data, id)
		elseif kind == "upgrade" then
			buyUpgrade(player, data, id)
		elseif kind == "mower" then
			if (Config.mower(id) or {}).currency == "gems" then
				GemShop.buyGemMower(player, data, id)
			else
				buyCoinMower(player, data, id)
			end
		elseif kind == "perk" then
			GemShop.buyPerk(player, data, id)
		elseif kind == "bag" then
			buyBag(player, data, id)
		elseif kind == "vacuum" then
			buyVacuum(player, data)
		end
		PlayerData.changed(player)
	end)
	Net.on("Seen", 1, function(player, what, id)
		local data = PlayerData.get(player)
		if what == "intro" and data and data.run then
			data.run.introSeen = true
		elseif what == "news" and data and type(id) == "number" then
			data.stats.newsSeen = math.clamp(math.floor(id), 0, #Config.NEWS)
		end
	end)
	Net.on("SpawnMower", 2, function(player, id)
		if type(id) == "string" then
			if not Mowers.spawn(player, id) then
				Net.notify(player, "You don't own that mower in this run.", "red")
			end
		end
	end)

	-- pumps
	for _, pump in info.pumps do
		pump.prompt.Triggered:Connect(function(player)
			local price = Config.FUEL_PRICE_PER_ZONE[zone] or 1
			Mowers.refuel(player, pump.pos, price)
		end)
	end

	-- the host's saved zone decides where we start
	task.spawn(function()
		local startZone = waitForHost()
		zone = startZone
		Field.build(info.world, startZone)
		unlock(startZone)
		started = true
		PlayerData.onLoaded(setupPlayer)
	end)

	Players.PlayerRemoving:Connect(function(p)
		lastSwing[p] = nil
		bagWarn[p] = nil
	end)

	task.spawn(sellLoop)
	-- the run clock: one second per second you're in the run (the HUD ticks it between updates)
	task.spawn(function()
		while true do
			task.wait(1)
			if started and not completing then
				for _, p in Players:GetPlayers() do
					local data = PlayerData.get(p)
					if data and data.run then
						data.run.time = (data.run.time or 0) + 1
					end
				end
			end
		end
	end)
	-- walking up to a locked gate explains what's needed ("Pine Wood is locked: clear Oak Wood first")
	task.spawn(function()
		local lastNote: { [Player]: number } = {}
		local gates = Config.gates()
		while true do
			task.wait(0.4)
			if started then
				for _, p in Players:GetPlayers() do
					local root = rootOf(p)
					if root and (lastNote[p] or 0) + 3 < os.clock() then
						for _, g in gates do
							local d = Vector3.new(root.Position.X - g.pos.X, 0, root.Position.Z - g.pos.Z).Magnitude
							if g.b > zone and d < 12 then
								lastNote[p] = os.clock()
								local here = Config.ZONES[zone]
								local left = Field.remainingIn(zone)
								local sub
								if g.b > zone + 1 then
									sub = ("Clear the %s and the areas after it first"):format(here.name)
								elseif left > 0 then
									sub = ("Mow every clump in the %s first (%d left)"):format(here.name, left)
								else
									sub = ("Beat the %s first"):format(here.boss.name)
								end
								Net.send(p, "Fx", "locked", { title = "🔒 " .. Config.ZONES[g.b].name .. " is locked", sub = sub })
								break
							end
						end
					end
				end
			end
		end
	end)
	task.spawn(function()
		local acc = 0
		while true do
			local dt = task.wait(Config.TICK)
			if started and not completing then
				autoTick()
				acc += dt
				if acc >= 0.5 then
					Mowers.burn(acc)
					acc = 0
				end
			end
		end
	end)
	-- world state, at most 5 times a second
	task.spawn(function()
		while true do
			task.wait(0.2)
			if worldDirty and started then
				worldDirty = false
				Net.all("World", worldState())
			end
		end
	end)
end

function Run.worldState()
	return if info and started then worldState() else { mode = "Run", loading = true }
end

-- Studio test helpers (DevHook).
function Run.dev(cmd: string, ...)
	if cmd == "clearZone" then
		-- cut everything left in the area instantly
		local player = Players:GetPlayers()[1]
		if player then
			devCutting = true
			Field.devClear(player, zone)
			devCutting = false
		end
	elseif cmd == "killBoss" then
		local player = Players:GetPlayers()[1]
		if player then
			Boss.damage(player, math.huge)
		end
	elseif cmd == "zone" then
		unlock(math.clamp(tonumber((...)) or 1, 1, #Config.ZONES))
	end
end

return Run
