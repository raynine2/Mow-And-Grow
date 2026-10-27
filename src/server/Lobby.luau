-- The lobby: party pads (teleport to a private run), class booth (stock rolls every 5 min), gem perks,
-- free rewards and the garage (permanent mowers).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Format = require(ReplicatedStorage.MowALawn.Format)
local Net = require(script.Parent.Net)
local Daily = require(script.Parent.Daily)
local PlayerData = require(script.Parent.PlayerData)
local Stats = require(script.Parent.Stats)
local LobbyBuilder = require(script.Parent.LobbyBuilder)
local GemShop = require(script.Parent.GemShop)
local BestTimes = require(script.Parent.BestTimes)

local Lobby = {}

local built = nil :: any
local running = true
Lobby.onStudioStart = nil :: ((party: { Player }) -> ())?

-------------------------------------------------------------------------------------------------------------
-- class booth
-------------------------------------------------------------------------------------------------------------
local function stockWindow(): number
	return math.floor(workspace:GetServerTimeNow() / Config.STOCK_WINDOW)
end

local Classes = require(script.Parent.Classes) -- buying / equipping classes (shared with the run's village)
local inStock = Classes.inStock
local _ = inStock

local function updateBoard()
	local stock = Config.classStock(stockWindow())
	local lines = { "IN STOCK" }
	for _, id in stock do
		local c = Config.class(id)
		if c then
			table.insert(lines, c.name .. " (" .. c.rarity .. ")")
		end
	end
	local left = Config.STOCK_WINDOW - (workspace:GetServerTimeNow() % Config.STOCK_WINDOW)
	table.insert(lines, "Restock in " .. Format.clock(left))
	built.stockLabel.Text = table.concat(lines, "\n")
end

-- The leaderboard by the party booths: this server's players, most grass cut first.
local function updateLeaders()
	if not built.leaderLabel then
		return
	end
	local rows = {}
	for _, p in Players:GetPlayers() do
		local data = PlayerData.get(p)
		if data then
			table.insert(rows, { name = p.DisplayName, cut = data.stats.cut or 0 })
		end
	end
	table.sort(rows, function(a, b)
		return a.cut > b.cut
	end)
	local lines = {}
	for i = 1, math.min(8, #rows) do
		table.insert(lines, ("%d. %s  -  %s cut"):format(i, rows[i].name, Format.short(rows[i].cut)))
	end
	built.leaderLabel.Text = if #lines > 0 then table.concat(lines, "\n") else "Mow some grass to get on the board!"
end

-- The BEST TIMES trophy board: the fastest finished runs from every server.
local function updateBest()
	if not built.bestLabel then
		return
	end
	local top = BestTimes.top(8)
	local lines = {}
	for i, row in top do
		table.insert(lines, ("%d. %s  -  %s"):format(i, row.name, Format.clock(row.time)))
	end
	built.bestLabel.Text = if #lines > 0 then table.concat(lines, "\n") else "Finish a run to set the first time!"
end

local buyClass = Classes.buy

-------------------------------------------------------------------------------------------------------------
-- perks + garage
-------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------
-- rewards
-------------------------------------------------------------------------------------------------------------
local function claim(player: Player, data, kind: string)
	if kind == "daily" then
		if not Daily.claim(player, data) then -- the streak ladder (server/Daily)
			return
		end
	elseif kind == "group" then
		if data.groupClaimed then
			Net.notify(player, "Already claimed. Thanks for joining!", "yellow")
			return
		end
		local ok, inGroup = pcall(function()
			return player:IsInGroupAsync(Config.GROUP_ID)
		end)
		if not ok or not inGroup then
			Net.notify(player, "Join the Atlas Interactive Inc group first, then claim!", "red")
			return
		end
		data.groupClaimed = true
		data.gems += Config.GROUP_GEMS
		Net.notify(player, "+" .. Config.GROUP_GEMS .. " gems! Thanks for joining!", "purple")
		Net.send(player, "Fx", "purchase", { big = true })
	end
	task.spawn(PlayerData.save, player)
end

-------------------------------------------------------------------------------------------------------------
-- party pads
-------------------------------------------------------------------------------------------------------------
-- A free PARTY bay doesn't start on its own any more (like Chop A Forest): the first player to step on it gets
-- the Create Party window (client/PartyWindow) and picks the difficulty, Peaceful Mode and the party size; CREATE
-- makes them the host and starts the countdown, and friends can step on to join. The SOLO bay starts at once.
type Pad = {
	index: number,
	kind: string,
	pos: Vector3,
	radius: number,
	label: TextLabel,
	title: string,
	show: ((state: string, count: number, left: number?, who: string?, limit: number?) -> ())?, -- the pad's look
	host: Player?,
	members: { Player },
	startAt: number?,
	teleporting: boolean,
	pending: Player?, -- who has the Create Party window open for this bay
	pendingAt: number,
	declined: { [Player]: boolean }, -- pressed BACK: don't reopen until they step off
	limit: number?, -- the party size the host picked
	difficulty: string,
	peaceful: boolean,
}
local pads: { Pad } = {}
local friendCache: { [string]: boolean } = {}
local denyWarn: { [Player]: number } = {}
local SETUP_TIMEOUT = 45 -- seconds the Create Party window can stay open

local function isFriend(a: Player, b: Player): boolean
	if a == b then
		return true
	end
	local k = math.min(a.UserId, b.UserId) .. ":" .. math.max(a.UserId, b.UserId)
	if friendCache[k] == nil then
		local ok, res = pcall(function()
			return a:IsFriendsWithAsync(b.UserId)
		end)
		friendCache[k] = ok and res == true
	end
	return friendCache[k]
end

local function onPad(player: Player, pad: Pad): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local d = Vector3.new(root.Position.X - pad.pos.X, 0, root.Position.Z - pad.pos.Z).Magnitude
	return d <= pad.radius and root.Position.Y < pad.pos.Y + 12
end

local function warnOnce(p: Player, text: string)
	if (denyWarn[p] or 0) + 4 < os.clock() then
		denyWarn[p] = os.clock()
		Net.notify(p, text, "red")
	end
end

-- Send `party` to a new private run server (in Studio: turn this server into the run). Every client shows the
-- loading screen first (client/Loading) and hands it to the teleport, so it stays up on the other side.
local function sendParty(party: { Player }, host: Player?, settings: { [string]: any }): boolean
	for _, p in party do
		Net.send(p, "Fx", "loading", {})
	end
	task.wait(1.2) -- time for the clients to put up the loading screen
	if RunService:IsStudio() then
		if Lobby.onStudioStart then
			task.spawn(Lobby.onStudioStart, party)
		end
		return true
	end
	for _, p in party do
		task.spawn(PlayerData.save, p)
	end
	local ok, err = pcall(function()
		local code = TeleportService:ReserveServer(game.PlaceId)
		local options = Instance.new("TeleportOptions")
		options.ReservedServerAccessCode = code
		options:SetTeleportData({
			host = host and host.UserId or party[1].UserId,
			difficulty = settings.difficulty or "Normal",
			peaceful = settings.peaceful == true,
		})
		TeleportService:TeleportAsync(game.PlaceId, party, options)
	end)
	if not ok then
		warn("[Lobby] teleport failed: " .. tostring(err))
		for _, p in party do
			Net.send(p, "Fx", "loadingDone", {})
			Net.notify(p, "Teleport failed, try again!", "red")
		end
	end
	return ok
end

local function resetPad(pad: Pad)
	pad.host = nil
	table.clear(pad.members)
	pad.startAt = nil
	pad.limit = nil
	pad.difficulty = "Normal"
	pad.peaceful = false
	pad.teleporting = false
end

local function teleport(pad: Pad)
	pad.teleporting = true
	local party = table.clone(pad.members)
	if pad.show then
		pad.show("teleporting", #party, 0, nil, pad.limit)
	else
		pad.label.Text = "TELEPORTING..."
	end
	local studio = RunService:IsStudio()
	sendParty(party, pad.host, { difficulty = pad.difficulty, peaceful = pad.peaceful })
	if studio then
		return
	end
	task.wait(5)
	resetPad(pad)
end

-- (report #1, Config.FIRST_TIMER) A brand-new player goes straight to their first lawn: after a short countdown
-- (client/FirstLawn shows it, with STAY IN LOBBY and GO NOW) they're sent into a solo run like a solo pad would.
-- Stepping onto a pad or joining a party first cancels it.
local function firstLawn(player: Player, seconds: number)
	-- the countdown starts when their screen says it can show the card (client/FirstLawn: the loading screen is gone).
	-- (A fixed 2.5 s after the data loaded was too soon: the card was sent before the client listened, so it never
	-- showed and the player was moved without a word.) No word within 45 s: no trip, the arrow shows the SOLO pad.
	local waited = 0
	while not player:GetAttribute("FirstLawnReady") do
		if waited > 45 or not player.Parent then
			return
		end
		waited += task.wait(0.25)
	end
	if not player.Parent or player:GetAttribute("FirstLawnStay") then
		return
	end
	Net.send(player, "Fx", "firstLawn", { seconds = seconds })
	local deadline = os.clock() + seconds
	while os.clock() < deadline and not player:GetAttribute("FirstLawnGo") do
		task.wait(0.25)
		if not player.Parent or player:GetAttribute("FirstLawnStay") then
			return
		end
		for _, pad in pads do
			if table.find(pad.members, player) or pad.pending == player then
				return -- they're starting a run of their own
			end
		end
	end
	sendParty({ player }, player, { difficulty = "Normal" })
end

-- What the Create Party window's SAVED RUNS panel shows.
local function savedRun(data): { [string]: any }?
	local run = data.run
	if not run then
		return nil
	end
	return {
		zone = run.zone or 1,
		cut = data.stats and data.stats.cut or 0,
		started = run.started or os.time(),
		time = run.time or 0,
	}
end

-- A player stepped onto a free PARTY bay: open the Create Party window for them.
local function offerSetup(pad: Pad, p: Player, data)
	pad.pending = p
	pad.pendingAt = os.clock()
	Net.send(p, "Fx", "partySetup", {
		pad = pad.index,
		wins = data.stats and data.stats.runs or 0,
		max = Config.PARTY_MAX,
		run = savedRun(data),
		now = os.time(),
	})
end

local function inOtherParty(pad: Pad, p: Player): boolean
	for _, other in pads do
		if other ~= pad and (table.find(other.members, p) or other.pending == p) then
			return true
		end
	end
	return false
end

-- Somebody standing on `pad` who isn't in its party yet.
local function arrive(pad: Pad, p: Player)
	local data = PlayerData.get(p)
	if not data or inOtherParty(pad, p) then
		return
	end
	if pad.kind == "party" and not pad.host then
		if pad.pending == nil and not pad.declined[p] then
			offerSetup(pad, p, data)
		elseif pad.pending and pad.pending ~= p then
			warnOnce(p, pad.pending.DisplayName .. " is creating a party here...")
		end
		return
	end
	local limit = if pad.kind == "solo" then 1 else (pad.limit or Config.PARTY_MAX)
	if #pad.members >= limit then
		warnOnce(p, "This pad is full!")
	elseif pad.host and not isFriend(pad.host, p) then
		warnOnce(p, "This party is for " .. pad.host.DisplayName .. "'s friends!")
	else
		table.insert(pad.members, p)
		pad.host = pad.host or p
		if not pad.startAt then
			pad.startAt = os.clock() + (if pad.kind == "solo" then Config.SOLO_COUNTDOWN else Config.PARTY_COUNTDOWN)
		end
	end
end

local function dropLeavers(pad: Pad)
	for i = #pad.members, 1, -1 do
		local p = pad.members[i]
		if not p.Parent or not onPad(p, pad) then
			table.remove(pad.members, i)
			if p == pad.host then
				pad.host = nil
			end
		end
	end
	if pad.host == nil and #pad.members > 0 then
		pad.host = pad.members[1]
	end
	if pad.host == nil then
		table.clear(pad.members)
		pad.startAt = nil
		pad.limit = nil
	end
	-- the Create Party window closes when its player steps off, leaves, or takes too long
	local pending = pad.pending
	if pending and (not pending.Parent or not onPad(pending, pad) or os.clock() - pad.pendingAt > SETUP_TIMEOUT) then
		pad.pending = nil
		if pending.Parent then
			Net.send(pending, "Fx", "partySetupClose", { pad = pad.index })
		end
	end
	for p in pad.declined do
		if not p.Parent or not onPad(p, pad) then
			pad.declined[p] = nil
		end
	end
end

local function showPad(pad: Pad)
	if #pad.members == 0 then
		if pad.show then
			if pad.pending then
				pad.show("creating", 0, nil, pad.pending.DisplayName)
			else
				pad.show("open", 0, nil)
			end
		else
			pad.label.Text = pad.title
		end
		return
	end
	local left = math.max(0, math.ceil((pad.startAt or os.clock()) - os.clock()))
	if pad.show then
		pad.show("starting", #pad.members, left, nil, pad.limit)
	elseif pad.kind == "solo" then
		pad.label.Text = "SOLO\nStarting in " .. left
	else
		pad.label.Text = ("PARTY %d/%d\nHost: %s\nStarting in %d"):format(#pad.members, Config.PARTY_MAX, pad.host and pad.host.DisplayName or "?", left)
	end
end

local function updatePad(pad: Pad)
	if pad.teleporting then
		return
	end
	dropLeavers(pad)
	for _, p in Players:GetPlayers() do
		if not table.find(pad.members, p) and pad.pending ~= p and onPad(p, pad) then
			arrive(pad, p)
		end
	end
	showPad(pad)
	if #pad.members > 0 and pad.startAt and os.clock() >= pad.startAt then
		task.spawn(teleport, pad)
	end
end

-- The Create Party window's buttons: create (size, difficulty, peaceful), cancel, or load the saved run.
local DIFFICULTY_WINS = { Normal = 0, Hard = 1, Expert = 5 }
local function onPartyAction(player: Player, action: any, padIndex: any, size: any, difficulty: any, peaceful: any)
	if action == "start" then
		for _, pad in pads do
			if pad.host == player and not pad.teleporting and #pad.members > 0 then
				pad.startAt = os.clock()
			end
		end
		return
	end
	if action == "load" then
		local data = PlayerData.get(player)
		if not data or not data.run then
			Net.notify(player, "You don't have a saved run.", "red")
			return
		end
		for _, pad in pads do
			if pad.pending == player then
				pad.pending = nil
			end
		end
		task.spawn(sendParty, { player }, player, {})
		return
	end
	local pad = type(padIndex) == "number" and pads[padIndex] or nil
	if not pad or pad.pending ~= player then
		return
	end
	pad.pending = nil
	if action == "cancel" then
		pad.declined[player] = true
		return
	end
	if action ~= "create" or pad.host or not onPad(player, pad) then
		return
	end
	local data = PlayerData.get(player)
	local wins = data and data.stats and data.stats.runs or 0
	local diff = if type(difficulty) == "string" and DIFFICULTY_WINS[difficulty] and wins >= DIFFICULTY_WINS[difficulty] then difficulty else "Normal"
	pad.limit = math.clamp(math.floor(tonumber(size) or Config.PARTY_MAX), 1, Config.PARTY_MAX)
	pad.difficulty = diff
	pad.peaceful = peaceful == true
	pad.host = player
	table.insert(pad.members, player)
	pad.startAt = os.clock() + (if pad.limit == 1 then Config.SOLO_COUNTDOWN else Config.PARTY_COUNTDOWN)
end

-------------------------------------------------------------------------------------------------------------
function Lobby.start()
	built = require(script.Parent.MapStore).load("Lobby", LobbyBuilder.build) -- the saved map, if the place has one
	require(script.Parent.LobbyBoards).start() -- the all-time leaderboards
	for i, def in built.pads do
		table.insert(pads, {
			index = i,
			kind = def.kind,
			pos = def.pos,
			radius = def.radius,
			label = def.label,
			title = def.title,
			show = def.show,
			host = nil,
			members = {},
			startAt = nil,
			teleporting = false,
			pending = nil,
			pendingAt = 0,
			declined = {},
			limit = nil,
			difficulty = "Normal",
			peaceful = false,
		})
	end

	Net.on("Buy", 6, function(player, kind, id)
		local data = PlayerData.get(player)
		if not data or type(kind) ~= "string" or type(id) ~= "string" then
			return
		end
		if kind == "class" then
			buyClass(player, data, id)
		elseif kind == "perk" then
			GemShop.buyPerk(player, data, id)
		elseif kind == "mower" then
			GemShop.buyGemMower(player, data, id)
		end
		PlayerData.changed(player)
	end)
	Net.on("EquipClass", 4, function(player, id)
		local data = PlayerData.get(player)
		if data then
			Classes.equip(player, data, id)
		end
	end)
	-- Peaceful Mode: runs this player hosts have no night monsters (and don't set a best time)
	Net.on("Setting", 3, function(player, key, value)
		local data = PlayerData.get(player)
		if data and key == "peaceful" and type(value) == "boolean" then
			data.peaceful = value
			PlayerData.changed(player)
			Net.notify(player, if value then "Peaceful Mode ON: no night monsters, no best times" else "Peaceful Mode OFF", "green")
		end
		-- the SETTINGS panel's rare-stock alerts (client/Settings): the big IN STOCK banner for Legendary / Mythic;
		-- and Reduce camera shake (calmCamera). Runs save them too (server/Run)
		if data and (key == "alertLegendary" or key == "alertMythic" or key == "calmCamera") and type(value) == "boolean" then
			data.alerts = if type(data.alerts) == "table" then data.alerts else {}
			data.alerts[key] = value
			PlayerData.changed(player)
		end
	end)
	Net.on("Claim", 2, function(player, kind)
		local data = PlayerData.get(player)
		if data and type(kind) == "string" then
			claim(player, data, kind)
			PlayerData.changed(player)
		end
	end)
	Net.on("Party", 3, onPartyAction)

	PlayerData.onLoaded(function(player, data)
		-- (report #1) a brand-new player is taken to their first lawn
		local wait = Config.FIRST_TIMER.autoStart
		if wait > 0 and PlayerData.isNew(data) then
			task.spawn(firstLawn, player, wait)
		end
		local function onCharacter()
			task.wait(0.2)
			Stats.applyCharacter(player, data)
		end
		player.CharacterAdded:Connect(onCharacter)
		if player.Character then
			task.spawn(onCharacter)
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		denyWarn[p] = nil
		for _, pad in pads do
			pad.declined[p] = nil
		end
	end)

	task.spawn(function()
		while running do
			local hosts = {}
			for _, pad in pads do
				local ok, err = pcall(updatePad, pad)
				if not ok then
					warn("[Lobby] pad: " .. tostring(err))
				end
				if pad.host and pad.kind == "party" and not pad.teleporting then
					hosts[pad.host] = true
				end
			end
			-- the HUD shows a START NOW button to party hosts
			for _, p in Players:GetPlayers() do
				local isHost = hosts[p] == true
				if (p:GetAttribute("PartyHost") == true) ~= isHost then
					p:SetAttribute("PartyHost", if isHost then true else nil)
				end
			end
			task.wait(0.25)
		end
	end)
	task.spawn(function()
		local tick = 0
		while running do
			pcall(updateBoard)
			if tick % 5 == 0 then
				pcall(updateLeaders)
			end
			if tick % 60 == 0 then
				task.spawn(pcall, updateBest) -- a DataStore read, once a minute
			end
			tick += 1
			task.wait(1)
		end
	end)
end

function Lobby.stop()
	running = false
	for _, p in Players:GetPlayers() do
		p:SetAttribute("PartyHost", nil)
	end
end

function Lobby.worldState()
	return { mode = "Lobby", stockWindow = Config.STOCK_WINDOW }
end

return Lobby
