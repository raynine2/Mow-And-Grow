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
	local hub = Config.zoneCentre(0)
	local middle = Config.zoneCentre(1) -- the middle of the map
	-- the whole map from high above, then down to the hub
	stop(hub + Vector3.new(-60, 330, -260), middle, "Welcome to " .. Config.GAME_NAME .. "!")
	stop(hub + Vector3.new(-40, 30, -70), hub + Vector3.new(-16, 4, 12), "Chop grass, pick up the bundles, sell them here")
	-- over the areas in the order they open
	for z, def in Config.ZONES do
		if z == 1 or z == 4 or z == #Config.ZONES then
			local c = Config.zoneCentre(z)
			local gate = Config.gatePos(z)
			local caption = if z == 1 then "Mow every clump in an area to open the next one"
				elseif z == #Config.ZONES then "Mow all the way to the " .. def.name .. "!"
				else "Each area has bigger, tougher grass"
			stop(gate + (gate - c).Unit * 30 + Vector3.new(0, 45, 0), c, caption)
		end
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
