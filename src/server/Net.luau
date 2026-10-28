-- Every RemoteEvent lives here. Clients ask, the server checks and decides.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

-- client -> server
local INBOUND = {
	"Swing", -- ()                          swing the equipped tool
	"Buy", -- (kind, id)                    tool | upgrade | mower | class | perk
	"EquipClass", -- (classId)
	"SpawnMower", -- (mowerId)
	"Claim", -- (kind)                      daily | group
	"Prompt", -- (kind, key)                product | pass
	"Party", -- (action, pad, ...)          start | create (pad, size, difficulty, peaceful) | cancel (pad) | load
	"Ready", -- ()                          client finished loading, send state
	"Seen", -- (what)                       "intro": the run's fly-over was shown ("introStart": it began)
	"Dev", -- (action, arg)                 dev panel (Studio, or Config.ADMINS / the game's owner)
	"Hatch", -- (eggId, count)              open a gem egg (Robux eggs go through Prompt)
	"Pet", -- (action, uid)                 equip | unequip | best | delete
	"Shoot", -- (aimDir)                    fire the boss-crate gun (server checks rate + range)
	"Setting", -- (key, value)              peaceful (lobby); alertLegendary / alertMythic / calmCamera (lobby + run)
	"Graphics", -- (potato)                 Potato Mode on/off (saved; the client does the rest)
	"Boss", -- (action)                     "skip": vote to skip the boss cutscene (server/Boss)
	"ClassAct", -- (action)                 "stomp": a Grass Titan landed from a jump (server/ClassPerks)
}
-- server -> client
local OUTBOUND = {
	"State", -- (snapshot)                  the player's own profile view
	"Notify", -- (text, colorName)
	"Fx", -- (kind, data)                   cut bursts, sells, telegraphs, knockback ...
	"World", -- (data)                      zone progress, boss HP, run info
}

local folder = Instance.new("Folder")
folder.Name = "MowALawnRemotes"
local remotes: { [string]: RemoteEvent } = {}
for _, name in INBOUND do
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = folder
	remotes[name] = r
end
for _, name in OUTBOUND do
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = folder
	remotes[name] = r
end
folder.Parent = ReplicatedStorage

-- Per-player rate limit: at most `perSecond` calls of `key`, with a small burst.
local buckets: { [Player]: { [string]: { tokens: number, last: number } } } = {}
function Net.allow(player: Player, key: string, perSecond: number): boolean
	local byKey = buckets[player]
	if not byKey then
		byKey = {}
		buckets[player] = byKey
	end
	local now = os.clock()
	local b = byKey[key]
	if not b then
		b = { tokens = perSecond * 2, last = now }
		byKey[key] = b
	end
	b.tokens = math.min(perSecond * 2, b.tokens + (now - b.last) * perSecond)
	b.last = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end
Players.PlayerRemoving:Connect(function(p)
	buckets[p] = nil
end)

-- Connect a handler for a client -> server remote, with a rate limit and error isolation.
-- One handler per remote; registering again replaces it (Studio switches a lobby into a run live).
local handlers: { [string]: { fn: (Player, ...any) -> (), rate: number } } = {}
function Net.on(name: string, perSecond: number, handler: (Player, ...any) -> ())
	local first = handlers[name] == nil
	handlers[name] = { fn = handler, rate = perSecond }
	if not first then
		return
	end
	remotes[name].OnServerEvent:Connect(function(player, ...)
		local h = handlers[name]
		if not h or not Net.allow(player, name, h.rate) then
			return
		end
		local ok, err = pcall(h.fn, player, ...)
		if not ok then
			warn(("[Net] %s from %s failed: %s"):format(name, player.Name, tostring(err)))
		end
	end)
end

function Net.send(player: Player, name: string, ...)
	remotes[name]:FireClient(player, ...)
end

function Net.all(name: string, ...)
	remotes[name]:FireAllClients(...)
end

function Net.notify(player: Player, text: string, color: string?)
	remotes.Notify:FireClient(player, text, color or "yellow")
end

function Net.notifyAll(text: string, color: string?)
	remotes.Notify:FireAllClients(text, color or "yellow")
end

return Net
