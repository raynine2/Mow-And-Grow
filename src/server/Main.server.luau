-- Mow A Lawn server entry point. Picks the mode (lobby or run), starts its systems and keeps every
-- client's view of its own profile up to date.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Net = require(script.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)
local Stats = require(script.Parent.Stats)
local Mode = require(script.Parent.Mode)
local Monetization = require(script.Parent.Monetization)
local Quests = require(script.Parent.Quests)
local Loot = require(script.Parent.Loot)

-- Nobody spawns until the world is built (loading the models takes a few seconds).
Players.CharacterAutoLoads = false

-- The maps saved in the place (Workspace.Maps, see server/MapStore) leave Workspace before anyone joins.
require(script.Parent.MapStore).init()

-- Blender models first (uploaded ones only), so the world builders can use them
require(script.Parent.Models).loadAll()

local system: any = if Mode.isRun then require(script.Parent.Run) else require(script.Parent.Lobby)
system.start()
Monetization.start()
require(script.Parent.Anims).start() -- our character animations (once uploaded), set before anyone spawns
require(script.Parent.BestTimes).start() -- the trophy tag with your best time over your head

-- Spawn on the world's own SpawnLocation, not one from the place template (the Baseplate's). This only
-- changes the running game; the place file keeps its parts. The Baseplate is hidden while playing because
-- its top sits exactly at the world's ground level and would flicker through the grass.
local world = workspace:FindFirstChild("World")
for _, d in workspace:GetDescendants() do
	if d:IsA("SpawnLocation") and not (world and d:IsDescendantOf(world)) then
		d.Enabled = false
	end
end
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate and baseplate:IsA("BasePart") then
	baseplate.Transparency = 1 -- still solid, as a safety floor
	for _, d in baseplate:GetChildren() do
		if d:IsA("Texture") or d:IsA("Decal") then
			d.Transparency = 1
		end
	end
end
Players.CharacterAutoLoads = true
for _, p in Players:GetPlayers() do
	if not p.Character then
		task.spawn(function()
			p:LoadCharacter()
		end)
	end
end

-- Studio: teleports don't work, so a party pad turns this lobby into a run right here.
if Mode.isLobby and RunService:IsStudio() then
	system.onStudioStart = function(party: { Player })
		if Mode.isRun then
			return
		end
		system.stop()
		Mode.set("Run")
		system = require(script.Parent.Run)
		system.start()
		task.wait(0.5)
		for _, p in Players:GetPlayers() do
			Net.notify(p, "(Studio) Starting the run here. Live games teleport to a private server.", "yellow")
			p:LoadCharacter()
			PlayerData.changed(p)
		end
		local _ = party
	end
end

-- What a client needs to draw its HUD and windows.
local function snapshot(player: Player, data)
	local s = Stats.compute(player, data)
	local run = data.run
	local passes = {}
	for key in Config.PASSES do
		passes[key] = player:GetAttribute("Pass_" .. key) == true
	end
	local classes = {}
	for id in data.classes do
		table.insert(classes, id)
	end
	local mowers = {}
	for id in data.mowers do
		table.insert(mowers, id)
	end
	local index = {}
	for key in data.index do
		table.insert(index, key)
	end
	local view = {
		mode = Mode.current,
		gems = data.gems,
		class = data.class,
		classes = classes,
		perks = data.perks,
		mowers = mowers,
		dailyIn = math.max(0, data.lastDaily + Config.DAILY_COOLDOWN - os.time()),
		groupClaimed = data.groupClaimed,
		stats = data.stats,
		passes = passes,
		power = s.power,
		carryMax = math.floor(s.carry),
		endless = s.carry >= Config.ENDLESS_CARRY, -- the Bottomless Sack: the HUD shows an infinity sign
		sell = s.sell,
		luck = s.luck,
		walkSpeed = s.walkSpeed,
		grasp = s.grasp,
		swing = s.swing,
		index = index,
		bestTime = data.bestTime,
		dryRun = data._dryRun == true,
		run = nil :: any,
	}
	if run then
		local runMowers = {}
		for id in run.mowers do
			table.insert(runMowers, id)
		end
		local muts = 0
		for _, b in run.carry do
			if b.m then
				muts += 1
			end
		end
		view.run = {
			zone = run.zone,
			coins = run.coins,
			tool = run.tool,
			upgrades = run.upgrades,
			mowers = runMowers,
			trial = run.trial,
			fuel = run.fuel,
			carry = #run.carry,
			carryMutated = muts,
			ground = Loot.count(player), -- bundles still lying on the ground
			bag = run.bag or 0,
			vacuum = run.vacuum == true,
			time = run.time or 0,
			introSeen = run.introSeen == true,
			quest = Quests.view(run),
		}
	end
	return view
end

PlayerData.onChanged(function(player, data)
	Net.send(player, "State", snapshot(player, data))
end)

Net.on("Ready", 1, function(player)
	PlayerData.changed(player)
	Net.send(player, "World", system.worldState())
end)

-- The NEWS window was seen (newest Config.NEWS id). A run registers its own "Seen" (Run.start) that also
-- handles this, so only the lobby registers this one.
if not Mode.isRun then
	Net.on("Seen", 1, function(player, what, id)
		local data = PlayerData.get(player)
		if what == "news" and data and type(id) == "number" then
			data.stats.newsSeen = math.clamp(math.floor(id), 0, #Config.NEWS)
			PlayerData.changed(player)
		end
	end)
end

-- Dev panel (client/DevPanel): everyone in Studio, and in live servers only Config.ADMINS or the game's owner.
local function isDev(player: Player): boolean
	if RunService:IsStudio() or table.find(Config.ADMINS, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
	return ok and rank >= 255
end
local function markDev(player: Player)
	if isDev(player) then
		player:SetAttribute("IsDev", true)
	end
end
Players.PlayerAdded:Connect(markDev)
for _, p in Players:GetPlayers() do
	task.spawn(markDev, p)
end
Net.on("Dev", 8, function(player, action, arg)
	if player:GetAttribute("IsDev") ~= true or type(action) ~= "string" then
		return
	end
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local msg: string?
	if action == "gems" then
		data.gems += 100000
		msg = "+100K gems"
	elseif system.devAction then
		msg = system.devAction(player, data, action, arg)
	else
		msg = "Start a run first (stand on a pad)"
	end
	PlayerData.changed(player)
	if msg then
		Net.notify(player, "[DEV] " .. msg, "yellow")
	end
end)

-- Studio test hook: ServerStorage.DevHook:Invoke("gems", player, 1000), ("coins", player, n),
-- ("set", player, key, value), ("save", player, true/false), ("clearZone"), ("killBoss"), ("zone", n)
if RunService:IsStudio() then
	local hook = Instance.new("BindableFunction")
	hook.Name = "DevHook"
	hook.OnInvoke = function(cmd: string, a: any, b: any, c: any)
		local player = if typeof(a) == "Instance" and a:IsA("Player") then a else Players:GetPlayers()[1]
		local data = player and PlayerData.get(player)
		if cmd == "gems" and data then
			data.gems += tonumber(b) or 0
		elseif cmd == "coins" and data and data.run then
			data.run.coins += tonumber(b) or 0
		elseif cmd == "set" and data then
			data[b] = c
		elseif cmd == "save" and data then
			data._dryRun = not b -- ("save", player, true) lets this Studio session save for real
		elseif Mode.isRun then
			(system :: any).dev(cmd, a)
		end
		if player then
			PlayerData.changed(player)
		end
		return true
	end
	hook.Parent = ServerStorage
end

print(("[MowALawn] %s server started (%s)"):format(Mode.current, if RunService:IsStudio() then "Studio, saves off" else "live"))
