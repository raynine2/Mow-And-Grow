-- GLITCH (owner, 27 Oct: the ending teases "world 2, a corrupt world with a demon glitch type of enemy and boss",
-- with a sneak peek in the opening): the screen side of the corruption. Everything here is UI or a colour grade on
-- this client only, in its own ScreenGui above the films' letterbox (IntroCinema is 20):
--   Glitch.burst(power, time)   torn horizontal bars, stray pixel blocks, a jittery colour split and a little static
--   Glitch.static(alpha, time)  a noise veil (VFXLib's energy-noise texture) over the picture
--   Glitch.grade(goal, time)    the corrupted colour grade (its own ColorCorrection); returns a fade-back function
--   Glitch.text(parent, text, size, pos, color)  a glitched title line: red and cyan ghosts, jitter, corrupted
--                                 letters now and then; returns the label and a stop function
--   Glitch.stutter(key, pitch, volume, hits)  a sound cut into quick stuttering hits (licensed game sounds only)
--   Glitch.clear()              everything off
-- Kind to eyes: bars and blocks cover well under a quarter of the screen, nothing flashes the whole screen white,
-- the colour split is a soft tint, and "Reduce camera shake" (the CalmCamera attribute) or Potato Mode tone it all
-- right down. Nothing here runs on its own: it costs nothing until a film calls it.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Sound = require(script.Parent.Sound)
local Potato = require(script.Parent.Potato)

local Glitch = {}
local player = Players.LocalPlayer

local MAGENTA = Color3.fromRGB(255, 40, 170)
local CYAN = Color3.fromRGB(60, 240, 255)
local RED = Color3.fromRGB(255, 50, 70)
local INK = Color3.fromRGB(14, 6, 20)
local BAR_COLORS = { INK, MAGENTA, CYAN, Color3.fromRGB(235, 225, 255), Color3.fromRGB(70, 255, 140), INK }
local CORRUPT = { "#", "%", "@", "&", "?", "!", "/", "\\", "0", "1", "X", "_", "*", "=" }

-- the VFX Lab's noise texture (ReplicatedStorage.VFXLib, in the place only); without it there's no static
local NOISE: string? = nil
pcall(function()
	local lib = ReplicatedStorage:FindFirstChild("VFXLib")
	local assets = lib and lib:FindFirstChild("Assets")
	if assets then
		NOISE = (require(assets) :: any).Tex.EnergyNoise
	end
end)

-- How strong to make it: 1 normally, much less with "Reduce camera shake" or Potato Mode.
function Glitch.calm(): number
	if Potato.on then
		return 0.35
	end
	return if player:GetAttribute("CalmCamera") == true then 0.3 else 1
end

local gui: ScreenGui? = nil
local function screen(): ScreenGui
	if gui and gui.Parent then
		return gui
	end
	local g = Instance.new("ScreenGui")
	g.Name = "GlitchFx"
	g.IgnoreGuiInset = true
	g.ResetOnSpawn = false
	g.DisplayOrder = 22
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.Parent = player:WaitForChild("PlayerGui")
	gui = g
	return g
end

local function frame(color: Color3, transparency: number, z: number): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.ZIndex = z
	f.Parent = screen()
	return f
end

-------------------------------------------------------------------------------------------------------------
-- the colour split: a soft tint that hops between red and cyan, and the corrupted grade
-------------------------------------------------------------------------------------------------------------
local split: ColorCorrectionEffect? = nil
local function splitFx(): ColorCorrectionEffect
	if split and split.Parent then
		return split
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "GlitchSplit"
	cc.Enabled = false
	cc.Parent = Lighting
	split = cc
	return cc
end

-- The corrupted world's colour grade (darker, harder, tinted toward red-violet). `goal` overrides the defaults.
-- Returns a function that fades it back out over its argument (seconds) and removes it.
function Glitch.grade(goal: { [string]: any }?, time: number?): (number?) -> ()
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "CorruptGrade"
	cc.Parent = Lighting
	local g = goal or {}
	local target = {
		Brightness = g.Brightness or -0.08,
		Contrast = g.Contrast or 0.28,
		Saturation = g.Saturation or -0.15,
		TintColor = g.TintColor or Color3.fromRGB(255, 176, 214),
	}
	TweenService:Create(cc, TweenInfo.new(time or 1.5, Enum.EasingStyle.Sine), target):Play()
	return function(out: number?)
		if not cc.Parent then
			return
		end
		local t = out or 0.6
		TweenService:Create(cc, TweenInfo.new(t), { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) }):Play()
		task.delay(t + 0.05, function()
			cc:Destroy()
		end)
	end
end

-------------------------------------------------------------------------------------------------------------
-- bursts: bars, blocks, split, static
-------------------------------------------------------------------------------------------------------------
local live: { GuiObject } = {}
local burstUntil = 0
local burstPower = 0
local conn: RBXScriptConnection? = nil

local function dropLive()
	for _, f in live do
		f:Destroy()
	end
	table.clear(live)
end

-- one frame of glitch: a few torn bars and stray blocks (re-rolled every couple of frames)
local function rollFrame(power: number)
	dropLive()
	local calm = Glitch.calm()
	local n = math.floor((3 + 7 * power) * calm + 0.5)
	for _ = 1, n do
		local h = math.random(2, 22) / 700 -- a sliver of the screen
		local bar = frame(BAR_COLORS[math.random(1, #BAR_COLORS)], 0.25 + math.random() * 0.45, 3)
		bar.Size = UDim2.new(math.random(40, 100) / 100, 0, h, 0)
		bar.Position = UDim2.fromScale(math.random(-30, 60) / 100, math.random() * 0.95)
		table.insert(live, bar)
	end
	for _ = 1, math.floor((2 + 6 * power) * calm + 0.5) do
		local s = math.random(10, 46)
		local block = frame(BAR_COLORS[math.random(1, #BAR_COLORS)], 0.15 + math.random() * 0.4, 4)
		block.Size = UDim2.fromOffset(s * math.random(1, 4), s)
		block.Position = UDim2.fromScale(math.random(), math.random())
		table.insert(live, block)
	end
	local cc = splitFx()
	if calm >= 1 and math.random() < 0.7 then
		cc.Enabled = true
		local red = math.random() < 0.5
		cc.TintColor = if red then Color3.fromRGB(255, 190, 200) else Color3.fromRGB(190, 245, 255)
		cc.Contrast = 0.15 + power * 0.25
		cc.Saturation = -0.1
	else
		cc.Enabled = false
	end
end

local function stopBurst()
	burstUntil = 0
	dropLive()
	if split then
		split.Enabled = false
	end
	if conn then
		conn:Disconnect()
		conn = nil
	end
end

-- A burst of glitch for `time` seconds at `power` (0..1). Bursts that overlap just extend each other.
function Glitch.burst(power: number, time: number)
	burstPower = math.max(if os.clock() < burstUntil then burstPower else 0, math.clamp(power, 0, 1))
	burstUntil = math.max(burstUntil, os.clock() + time)
	if conn then
		return
	end
	local frames = 0
	conn = RunService.RenderStepped:Connect(function()
		if os.clock() >= burstUntil then
			stopBurst()
			return
		end
		frames += 1
		if frames % 2 == 1 then
			rollFrame(burstPower)
		end
	end)
end

-------------------------------------------------------------------------------------------------------------
-- static: a noise veil that crawls
-------------------------------------------------------------------------------------------------------------
local veil: ImageLabel? = nil
local veilConn: RBXScriptConnection? = nil

-- Static over the picture at transparency 1 - alpha, for `time` seconds (time <= 0: until Glitch.clear()).
function Glitch.static(alpha: number, time: number)
	if not NOISE then
		return
	end
	local v = veil
	if not v or not v.Parent then
		local img = Instance.new("ImageLabel")
		img.Name = "Static"
		img.BackgroundTransparency = 1
		img.Image = NOISE :: string
		img.ScaleType = Enum.ScaleType.Tile
		img.TileSize = UDim2.fromOffset(180, 180)
		img.Size = UDim2.new(1, 360, 1, 360)
		img.ImageColor3 = Color3.fromRGB(220, 210, 255)
		img.ZIndex = 2
		img.Parent = screen()
		veil = img
		v = img
	end
	local label = v :: ImageLabel
	label.ImageTransparency = 1 - math.clamp(alpha * Glitch.calm(), 0, 0.9)
	if not veilConn then
		veilConn = RunService.RenderStepped:Connect(function()
			if label.Parent then
				label.Position = UDim2.fromOffset(-math.random(0, 180), -math.random(0, 180))
			end
		end)
	end
	if time > 0 then
		task.delay(time, function()
			if veil == label then
				TweenService:Create(label, TweenInfo.new(0.2), { ImageTransparency = 1 }):Play()
			end
		end)
	end
end

-------------------------------------------------------------------------------------------------------------
-- glitched text
-------------------------------------------------------------------------------------------------------------
local function corrupted(text: string, amount: number): string
	if amount <= 0 then
		return text
	end
	local out = {}
	for _, code in utf8.codes(text) do
		local ch = utf8.char(code)
		if ch ~= " " and math.random() < amount then
			ch = CORRUPT[math.random(1, #CORRUPT)]
		end
		table.insert(out, ch)
	end
	return table.concat(out)
end

local function textLabel(parent: Instance, text: string, size: UDim2, pos: UDim2, color: Color3, z: number): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Size = size
	t.Position = pos
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color
	t.ZIndex = z
	t.Parent = parent
	return t
end

export type GlitchText = { label: TextLabel, stop: () -> (), set: (string) -> () }

-- A glitched line of text in `parent` (default: the glitch screen): the line itself (with a dark outline) and a
-- red and a cyan ghost that jump apart now and then; every so often letters turn to junk for a frame or two.
function Glitch.text(parent: Instance?, text: string, size: UDim2, pos: UDim2, color: Color3?): GlitchText
	local host = parent or screen()
	local red = textLabel(host, text, size, pos, RED, 5)
	local cyan = textLabel(host, text, size, pos, CYAN, 5)
	red.TextTransparency, cyan.TextTransparency = 0.35, 0.35
	local main = textLabel(host, text, size, pos, color or Color3.fromRGB(255, 236, 244), 6)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = INK
	stroke.Parent = main
	local base = text
	local alive = true
	local calm = Glitch.calm()
	task.spawn(function()
		local nextBurst = os.clock() + 0.2
		while alive and main.Parent do
			local now = os.clock()
			local bursting = now >= nextBurst
			if bursting then
				nextBurst = now + 0.25 + math.random() * 0.9
			end
			local spread = if bursting then 10 * calm else 2.5 * calm
			red.Position = pos + UDim2.fromOffset(-spread + math.random(-2, 2) * calm, math.random(-2, 2) * calm)
			cyan.Position = pos + UDim2.fromOffset(spread + math.random(-2, 2) * calm, math.random(-2, 2) * calm)
			main.Position = pos + UDim2.fromOffset(if bursting then math.random(-6, 6) * calm else 0, 0)
			local junk = if bursting and calm >= 1 then 0.25 else 0
			main.Text = corrupted(base, junk)
			red.Text, cyan.Text = main.Text, main.Text
			task.wait(if bursting then 0.06 else 0.05)
		end
	end)
	return {
		label = main,
		stop = function()
			alive = false
			for _, l in { red, cyan, main } do
				l:Destroy()
			end
		end,
		set = function(s: string)
			base = s
		end,
	}
end

-------------------------------------------------------------------------------------------------------------
-- sound
-------------------------------------------------------------------------------------------------------------
-- `key` (a Config.SOUNDS name) cut into `hits` quick stuttering hits, each a touch higher.
function Glitch.stutter(key: string, pitch: number, volume: number, hits: number?)
	task.spawn(function()
		for i = 1, hits or 4 do
			Sound.playAt(key, pitch * (1 + i * 0.04), volume)
			task.wait(0.045 + math.random() * 0.03)
		end
	end)
end

-- Everything off at once (a film ending or skipped).
function Glitch.clear()
	stopBurst()
	if veilConn then
		veilConn:Disconnect()
		veilConn = nil
	end
	if veil then
		veil:Destroy()
		veil = nil
	end
	if split then
		split:Destroy()
		split = nil
	end
	for _, d in Lighting:GetChildren() do
		if d.Name == "CorruptGrade" then
			d:Destroy()
		end
	end
	if gui then
		gui:Destroy()
		gui = nil
	end
end

return Glitch
