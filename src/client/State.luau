-- The client's copy of its own profile + the world (zone, boss), and a tiny event bus.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local State = {}

local remotes = ReplicatedStorage:WaitForChild("MowALawnRemotes")
State.remotes = remotes

State.data = nil :: any -- latest snapshot from the server (see Main.server snapshot())
State.world = {} :: any
State.mode = ReplicatedStorage:GetAttribute("MowALawnMode") or "Lobby"

local listeners: { [string]: { (...any) -> () } } = {}

function State.on(name: string, fn: (...any) -> ())
	listeners[name] = listeners[name] or {}
	table.insert(listeners[name], fn)
end

function State.emit(name: string, ...)
	local list = listeners[name]
	if list then
		for _, fn in list do
			task.spawn(fn, ...)
		end
	end
end

function State.fire(remote: string, ...)
	(remotes:WaitForChild(remote) :: RemoteEvent):FireServer(...)
end

State.dataAt = os.clock() -- when the latest snapshot arrived (timers in it count down from here)
remotes:WaitForChild("State").OnClientEvent:Connect(function(data)
	if type(data) == "table" and data.__delta then
		-- (4 Nov) only the fields that changed (server/Main.server): merged into the last snapshot, a fresh table
		local cur = State.data
		if type(cur) ~= "table" then
			return -- (the whole snapshot comes within 10 s)
		end
		local merged = table.clone(cur)
		for k, v in data.set do
			merged[k] = v
		end
		for _, k in data.gone do
			merged[k] = nil
		end
		if data.set.daily ~= nil or data.set.dailyIn ~= nil or data.set.freeGems ~= nil then
			State.dataAt = os.clock() -- (the timers' fields came: they count down from now)
		end
		data = merged
	else
		State.dataAt = os.clock()
	end
	State.data = data
	State.mode = data.mode or State.mode
	State.emit("data", data)
end)
remotes:WaitForChild("World").OnClientEvent:Connect(function(world)
	State.world = world
	State.emit("world", world)
end)
remotes:WaitForChild("Fx").OnClientEvent:Connect(function(kind, payload)
	State.emit("fx", kind, payload or {})
end)
remotes:WaitForChild("Notify").OnClientEvent:Connect(function(text, color)
	State.emit("notify", text, color)
end)

function State.isRun(): boolean
	return State.mode == "Run"
end

return State
