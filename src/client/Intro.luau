-- The run's fly-over: the first time you're in a new run, the camera glides over the hub and along every zone to
-- the last one, with a caption for each, then drops back to you. A SKIP button ends it early. Once it has played
-- (or been skipped) the server remembers it for this run ("Seen" remote), so it doesn't play again on a rejoin.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local Intro = {}
local player = Players.LocalPlayer

local SEGMENT = 2.4 -- seconds per camera move
local playing = false
local played = false
local worldReady = false

-- Camera stops: { from, lookAt, caption }. Built from the zone layout so it follows Config.
local function path(): { { CFrame | string } }
	local stops = {}
	local function stop(eye: Vector3, look: Vector3, caption: string)
		table.insert(stops, { CFrame.lookAt(eye, look), caption })
	end
	local C = Config.RING.centre
	local function around(r: number, deg: number, y: number): Vector3
		local a = math.rad(deg)
		return C + Vector3.new(math.sin(a) * r, y, math.cos(a) * r)
	end
	-- the whole world from high above, then down to the hub
	stop(around(Config.RING.edge * 0.9, 200, 420), C, "Welcome to " .. Config.GAME_NAME .. "!")
	stop(around(70, 210, 34), C + Vector3.new(-16, 4, -4), "Cut grass, pick up the bundles, sell them here")
	-- out through the rings, each one bigger than the last
	for z, def in Config.ZONES do
		local ring = Config.RING.zones[z]
		local mid = (ring.inner + ring.outer) / 2
		local caption = if z == 1 then "Mow every patch in a ring to wake its boss"
			elseif z == #Config.ZONES then "Make it all the way out to the " .. def.name .. "!"
			else "Beat each boss to open the gate to the next ring"
		stop(around(mid - 30, 24 + z * 22, 40 + z * 12), around(mid, 40 + z * 22, 0), caption)
	end
	return stops
end

local skipButton: TextButton? = nil
local caption: TextLabel? = nil

local function finish()
	if not playing then
		return
	end
	playing = false
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
	end
	if skipButton then
		skipButton:Destroy()
		skipButton = nil
	end
	if caption then
		caption:Destroy()
		caption = nil
	end
	State.fire("Seen", "intro")
end

local function play()
	local cam = workspace.CurrentCamera
	if playing or played or not cam then
		return
	end
	played = true
	playing = true
	cam.CameraType = Enum.CameraType.Scriptable
	caption = UI.text(UI.gui, "", UDim2.fromOffset(900, 56), { pos = UDim2.new(0.5, 0, 0, 120), anchor = Vector2.new(0.5, 0), stroke = 4, name = "IntroCaption" })
	skipButton = UI.button(UI.gui, "SKIP", UI.colors.red, UDim2.fromOffset(160, 56), finish, { pos = UDim2.new(0.5, 0, 1, -40), anchor = Vector2.new(0.5, 1), name = "IntroSkip" })
	local stops = path()
	cam.CFrame = stops[1][1] :: CFrame
	for _, s in stops do
		if not playing then
			return
		end
		if caption then
			caption.Text = s[2] :: string
		end
		local t = TweenService:Create(cam, TweenInfo.new(SEGMENT, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = s[1] })
		t:Play()
		t.Completed:Wait()
	end
	-- back to the player
	local char = player.Character
	local head = char and char:FindFirstChild("Head") :: BasePart?
	if playing and head then
		local t = TweenService:Create(cam, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = head.CFrame })
		t:Play()
		t.Completed:Wait()
	end
	finish()
end

local function maybePlay()
	local d = State.data
	if worldReady and State.isRun() and d and d.run and not d.run.introSeen and player.Character then
		task.spawn(play)
	end
end

State.on("world", function(w)
	if w.mode == "Run" and not w.loading then
		worldReady = true
		maybePlay()
	end
end)
State.on("data", maybePlay)

return Intro
