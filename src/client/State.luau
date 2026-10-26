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
	State.dataAt = os.clock()
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
