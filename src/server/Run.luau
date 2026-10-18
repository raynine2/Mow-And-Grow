-- A run server: cut grass, carry bundles, shred them for coins, buy tools, beat 5 bosses, earn gems.
-- Party progress (which zone is open) is shared; coins, tools and upgrades are per player.
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

local Run = {}

local info = nil :: any
local zone = 1 -- the zone the party is working on (highest unlocked)
local started = false
local completing = false
local lastSwing: { [Player]: number } = {}
local worldDirty = true

-------------------------------------------------------------------------------------------------------------
-- world state for the HUD
-------------------------------------------------------------------------------------------------------------
local function worldState()
	local def = Config.ZONES[zone]
	return {
		mode = "Run",
		zone = zone,
		zones = #Config.ZONES,
		name = def.name,
		cut = Field.total - Field.remainingIn(zone),
		total = Field.total,
		boss = Boss.state(),
		sellPos = info and info.sellPos,
	}
end

local function pushWorld()
	worldDirty = true
end

-------------------------------------------------------------------------------------------------------------
-- zones
-------------------------------------------------------------------------------------------------------------
local function openGate(z: number)
	local gate = info.gates[z]
	if gate then
		for _, p in gate:GetDescendants() do
			if p:IsA("BasePart") then
				p.CanCollide = false
				p.Transparency = 1
			elseif p:IsA("SurfaceGui") then
				p.Enabled = false
			end
		end
	end
end

local function unlock(z: number)
	zone = z
	Field.unlock(z)
	for i = 2, z do
		openGate(i)
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
			data.run = nil -- coins, tools and coin mowers end with the run
			PlayerData.changed(p)
			Net.send(p, "Fx", "runComplete", { gems = gems })
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
	if z >= #Config.ZONES then
		task.spawn(completeRun)
	else
		unlock(z + 1)
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
		Net.send(player, "Fx", "bagFull", {}) -- the bag bar shakes and the guide arrow points at the Shredder
	end
end

local function onCut(player: Player, patch): boolean
	if not Carry.add(player, patch.z, patch.mut) then
		warnBagFull(player)
		return false
	end
	local data = PlayerData.get(player)
	if data then
		data.stats.cut += 1
		local m = Config.mutation(patch.mut or "None")
		if m.gems > 0 then
			local gems = math.max(1, math.floor(m.gems * Stats.compute(player, data).gems))
			data.gems += gems
			Net.send(player, "Fx", "gems", { pos = patch.part.Position, amount = gems, mut = m.id })
		end
	end
	return true
end

local function rootOf(player: Player): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function onSwing(player: Player)
	local data = PlayerData.get(player)
	if not data or not data.run or completing then
		return
	end
	local def, tool = Tools.equipped(player)
	if not def or def.kind ~= "swing" or not tool then
		return
	end
	local now = os.clock()
	if (lastSwing[player] or 0) + def.cooldown * 0.85 > now then
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
	local look = root.CFrame.LookVector
	local centre = root.Position + Vector3.new(look.X, 0, look.Z) * def.radius * 0.45
	if Carry.isFull(player) then
		warnBagFull(player)
	else
		Field.hit(player, centre, def.radius, damage, def.targets, stats.luck)
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
					if Carry.isFull(player) then
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
					if Carry.isFull(player) then
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
local function sell(player: Player)
	local data = PlayerData.get(player)
	if not data or not data.run or #data.run.carry == 0 then
		return
	end
	local count = #data.run.carry
	local coins = math.floor(Carry.value(data) * Stats.compute(player, data).sell)
	data.run.coins += coins
	Carry.clear(player)
	Net.send(player, "Fx", "sell", { coins = coins, count = count, from = info.shredderMouth, out = info.shredderOut })
	Net.all("Fx", "shred", { pos = info.shredderMouth, count = count })
end

local function sellLoop()
	while true do
		task.wait(0.3)
		for _, player in Players:GetPlayers() do
			local root = rootOf(player)
			if root then
				local d = Vector3.new(root.Position.X - info.sellPos.X, 0, root.Position.Z - info.sellPos.Z).Magnitude
				if d <= info.sellRadius and root.Position.Y < info.sellPos.Y + 10 then
					sell(player)
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
	-- runs are played in first person, like the Chop A Forest trailer (the client draws the hands + tool)
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	PlayerData.changed(player)
	local function onCharacter(char: Model)
		char:WaitForChild("HumanoidRootPart", 10)
		task.wait(0.2)
		Stats.applyCharacter(player, data)
		Tools.give(player)
		Carry.refresh(player)
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
	Mowers.setup(info.world, info.garageSpawn)
	Boss.setup(info.world)

	Field.onCut = onCut
	Field.onProgress = pushWorld
	Field.onZoneCleared = function(z)
		if z == zone then
			Boss.spawn(z)
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
			buyCoinMower(player, data, id)
		end
		PlayerData.changed(player)
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
		for _ = 1, Field.total do
			if Field.remainingIn(zone) <= 0 then
				break
			end
			-- cut everything left in the zone instantly
			local player = Players:GetPlayers()[1]
			if not player then
				break
			end
			local data = PlayerData.get(player)
			if data and data.run then
				table.clear(data.run.carry)
			end
			Field.hit(player, RunBuilder.zoneCentre(zone), 200, math.huge, 1, 1)
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
