-- The lobby: party pads (teleport to a private run), class booth (stock rolls every 5 min), gem perks,
-- free rewards and the garage (permanent mowers).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Format = require(ReplicatedStorage.MowALawn.Format)
local Net = require(script.Parent.Net)
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

local function inStock(classId: string): boolean
	local w = stockWindow()
	-- a few seconds of grace so a click right at the restock still counts
	for _, win in { w, if workspace:GetServerTimeNow() % Config.STOCK_WINDOW < 5 then w - 1 else w } do
		if table.find(Config.classStock(win), classId) then
			return true
		end
	end
	return false
end

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

local function buyClass(player: Player, data, id: string)
	local c = Config.class(id)
	if not c or c.gems <= 0 then
		return
	end
	if data.classes[id] then
		data.class = id
		Net.notify(player, "Equipped " .. c.name, "green")
		return
	end
	if not inStock(id) then
		Net.notify(player, c.name .. " isn't in stock right now. Check back after the restock!", "red")
		return
	end
	if data.gems < c.gems then
		Net.notify(player, "Not enough gems!", "red")
		return
	end
	data.gems -= c.gems
	data.classes[id] = true
	data.class = id
	Net.notify(player, "You are now a " .. c.name .. "!", "purple")
	Net.send(player, "Fx", "purchase", { big = true })
	task.spawn(PlayerData.save, player)
end

-------------------------------------------------------------------------------------------------------------
-- perks + garage
-------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------
-- rewards
-------------------------------------------------------------------------------------------------------------
local function claim(player: Player, data, kind: string)
	if kind == "daily" then
		local wait = data.lastDaily + Config.DAILY_COOLDOWN - os.time()
		if wait > 0 then
			Net.notify(player, "Next daily reward in " .. Format.clock(wait), "yellow")
			return
		end
		data.lastDaily = os.time()
		data.gems += Config.DAILY_GEMS
		Net.notify(player, "+" .. Config.DAILY_GEMS .. " gems!", "purple")
		Net.send(player, "Fx", "purchase", { big = true })
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
type Pad = {
	kind: string,
	pos: Vector3,
	radius: number,
	label: TextLabel,
	title: string,
	show: ((state: string, count: number, left: number?) -> ())?, -- the pad's glow, sign tag and status line
	host: Player?,
	members: { Player },
	startAt: number?,
	teleporting: boolean,
}
local pads: { Pad } = {}
local friendCache: { [string]: boolean } = {}
local denyWarn: { [Player]: number } = {}

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

local function teleport(pad: Pad)
	pad.teleporting = true
	local party = table.clone(pad.members)
	local host = pad.host
	if pad.show then
		pad.show("teleporting", #party, 0)
	else
		pad.label.Text = "TELEPORTING..."
	end
	if RunService:IsStudio() then
		-- Teleports don't work in Studio: turn this server into the run instead.
		if Lobby.onStudioStart then
			task.spawn(Lobby.onStudioStart, party)
		end
		return
	else
		for _, p in party do
			task.spawn(PlayerData.save, p)
		end
		local ok, err = pcall(function()
			local code = TeleportService:ReserveServer(game.PlaceId)
			local options = Instance.new("TeleportOptions")
			options.ReservedServerAccessCode = code
			options:SetTeleportData({ host = host and host.UserId or party[1].UserId })
			TeleportService:TeleportAsync(game.PlaceId, party, options)
		end)
		if not ok then
			warn("[Lobby] teleport failed: " .. tostring(err))
			for _, p in party do
				Net.notify(p, "Teleport failed, try again!", "red")
			end
		end
		task.wait(5)
	end
	pad.host = nil
	table.clear(pad.members)
	pad.startAt = nil
	pad.teleporting = false
end

local function updatePad(pad: Pad)
	if pad.teleporting then
		return
	end
	-- who is standing on it
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
	end
	for _, p in Players:GetPlayers() do
		if not table.find(pad.members, p) and onPad(p, pad) and PlayerData.get(p) then
			local alreadyElsewhere = false
			for _, other in pads do
				if other ~= pad and table.find(other.members, p) then
					alreadyElsewhere = true
				end
			end
			if not alreadyElsewhere then
				local limit = if pad.kind == "solo" then 1 else Config.PARTY_MAX
				if #pad.members >= limit then
					if (denyWarn[p] or 0) + 4 < os.clock() then
						denyWarn[p] = os.clock()
						Net.notify(p, "This pad is full!", "red")
					end
				elseif pad.host and not isFriend(pad.host, p) then
					if (denyWarn[p] or 0) + 4 < os.clock() then
						denyWarn[p] = os.clock()
						Net.notify(p, "This party is for " .. pad.host.DisplayName .. "'s friends!", "red")
					end
				else
					table.insert(pad.members, p)
					if not pad.host then
						pad.host = p
					end
					if not pad.startAt then
						pad.startAt = os.clock() + (if pad.kind == "solo" then Config.SOLO_COUNTDOWN else Config.PARTY_COUNTDOWN)
					end
				end
			end
		end
	end
	-- label + countdown
	if #pad.members == 0 then
		if pad.show then
			pad.show("open", 0, nil)
		else
			pad.label.Text = pad.title
		end
		return
	end
	local left = math.max(0, math.ceil((pad.startAt or os.clock()) - os.clock()))
	if pad.show then
		pad.show("starting", #pad.members, left)
	elseif pad.kind == "solo" then
		pad.label.Text = "SOLO\nStarting in " .. left
	else
		pad.label.Text = ("PARTY %d/%d\nHost: %s\nStarting in %d"):format(#pad.members, Config.PARTY_MAX, pad.host and pad.host.DisplayName or "?", left)
	end
	if pad.startAt and os.clock() >= pad.startAt then
		task.spawn(teleport, pad)
	end
end

-------------------------------------------------------------------------------------------------------------
function Lobby.start()
	built = LobbyBuilder.build()
	for _, def in built.pads do
		table.insert(pads, {
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
		if data and type(id) == "string" and data.classes[id] then
			data.class = id
			Stats.applyCharacter(player, data)
			PlayerData.changed(player)
			Net.notify(player, "Equipped " .. (Config.class(id) :: any).name, "green")
		end
	end)
	Net.on("Claim", 2, function(player, kind)
		local data = PlayerData.get(player)
		if data and type(kind) == "string" then
			claim(player, data, kind)
			PlayerData.changed(player)
		end
	end)
	Net.on("Party", 3, function(player, action)
		if action == "start" then
			for _, pad in pads do
				if pad.host == player and not pad.teleporting and #pad.members > 0 then
					pad.startAt = os.clock()
				end
			end
		end
	end)

	PlayerData.onLoaded(function(player, data)
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
