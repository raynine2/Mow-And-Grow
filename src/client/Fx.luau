-- Client-only juice: clipping bursts, mutation reveals, floating numbers, boss telegraphs, screen shake.
-- Nothing here affects gameplay; the server already decided everything.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.MowALawn:WaitForChild("Format"))
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)

local Fx = {}
local player = Players.LocalPlayer
local C = UI.colors

local folder = Instance.new("Folder")
folder.Name = "ClientFx"
folder.Parent = workspace

-- Built-in engine sounds only (licensed with Roblox itself).
local sounds = {}
local function sound(name: string, id: string, volume: number)
	local s = Instance.new("Sound")
	s.Name = "MowALawn_" .. name
	s.SoundId = id
	s.Volume = volume
	s.Parent = SoundService
	sounds[name] = s
end
sound("swish", "rbxasset://sounds/swordslash.wav", 0.25)
sound("ping", "rbxasset://sounds/electronicpingshort.wav", 0.4)
local function play(name: string, pitch: number?)
	local s = sounds[name]
	if s then
		local c = s:Clone()
		c.PlaybackSpeed = pitch or 1
		c.Parent = SoundService
		c:Play()
		Debris:AddItem(c, 3)
	end
end
Fx.play = play

local function myRoot(): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function near(pos: Vector3, dist: number): boolean
	local r = myRoot()
	return r ~= nil and (r.Position - pos).Magnitude <= dist
end

-- Little cubes that pop out and fall.
function Fx.debris(pos: Vector3, color: Color3, count: number, speed: number, size: number?)
	for _ = 1, count do
		local p = Instance.new("Part")
		p.Size = Vector3.one * (size or 0.5) * (0.7 + math.random() * 0.6)
		p.Color = color
		p.Material = Enum.Material.Plastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CFrame = CFrame.new(pos + Vector3.new(0, 1, 0)) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		p.Parent = folder
		local dir = Vector3.new(math.random() - 0.5, 0.8 + math.random() * 0.6, math.random() - 0.5).Unit
		p.AssemblyLinearVelocity = dir * speed * (0.6 + math.random() * 0.6)
		p.AssemblyAngularVelocity = Vector3.new(math.random() * 10, math.random() * 10, math.random() * 10)
		TweenService:Create(p, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.one * 0.05 }):Play()
		Debris:AddItem(p, 1)
	end
end

-- Floating text in the world that rises and fades.
function Fx.floatText(pos: Vector3, text: string, color: Color3, scale: number?)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))
	anchor.Parent = folder
	local s = scale or 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220 * s, 56 * s)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	gui.Adornee = anchor
	gui.Parent = anchor
	local label = UI.text(gui, text, UDim2.fromScale(1, 1), { color = color, stroke = 3 })
	UI.bounce(label)
	TweenService:Create(anchor, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = anchor.CFrame + Vector3.new(0, 5, 0) }):Play()
	task.delay(0.8, function()
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		local st = label:FindFirstChildOfClass("UIStroke")
		if st then
			TweenService:Create(st, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end
	end)
	Debris:AddItem(anchor, 1.3)
end

-- Flat neon disc on the ground.
local function disc(pos: Vector3, radius: number, color: Color3, transparency: number): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency
	p.Size = Vector3.new(0.2, radius * 2, radius * 2)
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = folder
	return p
end

function Fx.ring(pos: Vector3, radius: number, color: Color3, life: number)
	local p = disc(pos + Vector3.new(0, 0.3, 0), 1, color, 0.2)
	TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.2, radius * 2, radius * 2), Transparency = 1 }):Play()
	Debris:AddItem(p, life + 0.1)
end

local shakeUntil, shakePower = 0, 0
function Fx.shake(power: number, time: number)
	shakeUntil = math.max(shakeUntil, os.clock() + time)
	shakePower = math.max(shakePower, power)
end
RunService.RenderStepped:Connect(function()
	if os.clock() < shakeUntil then
		local cam = workspace.CurrentCamera
		local p = shakePower * (shakeUntil - os.clock())
		cam.CFrame = cam.CFrame * CFrame.Angles((math.random() - 0.5) * p * 0.02, (math.random() - 0.5) * p * 0.02, 0)
	else
		shakePower = 0
	end
end)

-- Big centre-screen text.
function Fx.banner(text: string, color: Color3, time: number, sub: string?)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(900, 160)
	holder.Position = UDim2.fromScale(0.5, 0.32)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.ZIndex = 40
	holder.Parent = UI.gui
	local t = UI.text(holder, text, UDim2.new(1, 0, 0, 96), { color = color, stroke = 5 })
	t.ZIndex = 40
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(UI.shade(color, 1.25), UI.shade(color, 0.85))
	g.Rotation = 90
	g.Parent = t
	if sub then
		local s = UI.text(holder, sub, UDim2.new(1, 0, 0, 44), { pos = UDim2.fromOffset(0, 104), stroke = 3 })
		s.ZIndex = 40
	end
	UI.bounce(holder)
	task.delay(time, function()
		holder:Destroy()
	end)
end

-------------------------------------------------------------------------------------------------------------
-- server fx events
-------------------------------------------------------------------------------------------------------------
local handlers = {}

handlers.cut = function(d)
	if not near(d.pos, 120) then
		return
	end
	local m = Config.mutation(d.mut or "None")
	Fx.debris(d.pos, m.color or d.color, if m.id == "None" then 6 else 14, 22)
	if near(d.pos, 30) then
		play("swish", 0.9 + math.random() * 0.3)
	end
end

handlers.chip = function(d)
	Fx.debris(d.pos, d.color, 2, 14, 0.35)
end

handlers.reveal = function(d)
	local m = Config.mutation(d.mut)
	if not near(d.pos, 160) or not m.color then
		return
	end
	Fx.debris(d.pos, m.color, 18, 30, 0.6)
	Fx.ring(d.pos, 8, m.color, 0.6)
	Fx.floatText(d.pos, m.id:upper() .. "!", m.color, 1.3)
	play("ping", 1.2)
end

handlers.gems = function(d)
	Fx.floatText(d.pos + Vector3.new(0, 2, 0), "+" .. d.amount .. " GEMS", C.purple)
end

handlers.sell = function(d)
	local r = myRoot()
	if r then
		Fx.floatText(r.Position + Vector3.new(0, 3, 0), "+$" .. Format.short(d.coins), C.green, 1.5)
	end
	if d.out then
		Fx.debris(d.out, C.yellow, math.min(30, 6 + d.count), 26, 0.7)
	end
	play("ping", 1)
end

handlers.shred = function(d)
	if d.pos and near(d.pos, 150) then
		Fx.debris(d.pos + Vector3.new(0, 1, 0), Color3.fromRGB(150, 230, 80), math.min(30, 8 + d.count * 2), 30, 0.5)
	end
end

handlers.telegraph = function(d)
	local p = disc(d.pos + Vector3.new(0, 0.25, 0), d.radius, C.red, 0.55)
	local inner = disc(d.pos + Vector3.new(0, 0.3, 0), 0.5, C.red, 0.2)
	TweenService:Create(inner, TweenInfo.new(d.delay, Enum.EasingStyle.Linear), { Size = Vector3.new(0.2, d.radius * 2, d.radius * 2) }):Play()
	Debris:AddItem(p, d.delay + 0.05)
	Debris:AddItem(inner, d.delay + 0.05)
end

handlers.slam = function(d)
	Fx.ring(d.pos, d.radius * 1.4, Color3.fromRGB(255, 240, 200), 0.5)
	Fx.debris(d.pos, Color3.fromRGB(140, 100, 60), 16, 34, 0.8)
	if near(d.pos, d.radius + 30) then
		Fx.shake(6, 0.4)
	end
end

handlers.knock = function(d)
	local r = myRoot()
	if r then
		r.AssemblyLinearVelocity = d.dir * 70 + Vector3.new(0, 40, 0)
	end
	Fx.banner("BONKED!", C.red, 1)
end

handlers.bossSpawn = function(d)
	Fx.banner(d.name:upper(), C.red, 2.5, "BOSS FIGHT! Watch the red circles!")
	Fx.shake(5, 1)
	Fx.debris(d.pos, Color3.fromRGB(120, 90, 60), 30, 40, 1)
end

handlers.bossHit = function(d)
	Fx.floatText(d.pos + Vector3.new(math.random(-4, 4), math.random(-2, 2), math.random(-4, 4)), "-" .. Format.short(d.amount), C.yellow, 0.8)
end

handlers.bossDown = function(d)
	Fx.banner("DEFEATED!", C.green, 2.5, d.name)
	Fx.debris(d.pos, C.green, 40, 50, 1.2)
	Fx.ring(d.pos, 30, C.yellow, 1)
	Fx.shake(4, 0.6)
end

handlers.runComplete = function()
	Fx.banner("RUN COMPLETE!", C.yellow, 10, "Heading back to the lobby...")
end

handlers.purchase = function(d)
	play("ping", if d.big then 1.4 else 1.2)
end

State.on("fx", function(kind, payload)
	local h = handlers[kind]
	if h then
		local ok, err = pcall(h, payload)
		if not ok then
			warn("[Fx] " .. kind .. ": " .. tostring(err))
		end
	end
end)

-- spin the shredder rollers
task.spawn(function()
	local rollers = {}
	local world = workspace:WaitForChild("World", 30)
	if not world then
		return
	end
	task.wait(2)
	for _, p in world:GetDescendants() do
		if p:IsA("BasePart") and p:GetAttribute("Spin") then
			table.insert(rollers, { part = p, base = p.CFrame, speed = p:GetAttribute("Spin") })
		end
	end
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for i, r in rollers do
			r.part.CFrame = r.base * CFrame.Angles(t * r.speed * (if i % 2 == 0 then 1 else -1), 0, 0)
		end
	end)
end)

return Fx
