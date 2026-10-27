-- WEAPON FX (owner, 28 Oct: "make each hit count, each hit shows that you've hit the grass, make it look satisfying,
-- make it sound satisfying ... make it with every weapon look different"). Every tool hits the grass its own way:
--   Bare Hands   PUNCH  a soft thump: the dust poof, clods and the clump's squash (FxPresets "punch" as it was)
--   Scissors     SNIP   two bright blades close in an X where they bite, fine snippets flutter down like confetti
--   Sickle       SWEEP  a silver crescent sweeps across the clump, blades fan out sideways along the swing
--   Mega Scythe  REAP   a big lavender crescent, purple petals and sparkles, a heavier jolt and a chime
--   Push Mower   clippings spray up from the deck
--   Weed Whacker a fast ring of fine green flecks whirling off the string
--   Laser Mower  a cyan sizzle line through the stems and bright sparks
-- On top of the look, every hit is registered three ways (client/Fx's chip handler and client/HitFx call these):
--   * its own sound recipe (licensed sounds from Config.SOUNDS, re-pitched), climbing with the streak on a clump
--   * a little leaf hit-marker flicks out of the middle of the screen the instant your blow lands
--   * a soft floating number of the bite you took out of the clump, in the tool's colour
-- The tool presets are built here from FxPresets' "hit" / "auto" (install), so the big preset file stays as it is.
-- Signature layers are cheap: a handful of neon parts tweened and destroyed, pooled UI, nothing per frame at rest.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.MowALawn:WaitForChild("Format"))
local Sound = require(script.Parent.Sound)
local UI = require(script.Parent.UI)
local CameraView = require(script.Parent.CameraView)

local WeaponFx = {}
local player = Players.LocalPlayer

-- which effect each tool plays, and what kind of hit it is underneath (punch / hit / auto: HitFx's camera feel,
-- prediction and default sounds follow the family)
local EVENT = {
	Hands = "punch",
	Scissors = "snip",
	Sickle = "sweep",
	MegaScythe = "reap",
	PushMower = "autoPush",
	WeedWhacker = "autoWhack",
	LaserMower = "autoLaser",
}
local FAMILY = {
	punch = "punch",
	hit = "hit",
	snip = "hit",
	sweep = "hit",
	reap = "hit",
	auto = "auto",
	autoPush = "auto",
	autoWhack = "auto",
	autoLaser = "auto",
}
-- each tool's colour for its marks, numbers and hit-marker
local ACCENT = {
	Hands = Color3.fromRGB(255, 222, 180),
	Scissors = Color3.fromRGB(255, 150, 150),
	Sickle = Color3.fromRGB(214, 228, 255),
	MegaScythe = Color3.fromRGB(206, 160, 255),
	PushMower = Color3.fromRGB(255, 190, 110),
	WeedWhacker = Color3.fromRGB(150, 235, 120),
	LaserMower = Color3.fromRGB(120, 240, 255),
}

local function toolDef(id: string?)
	for _, t in Config.TOOLS do
		if t.id == id then
			return t
		end
	end
	return nil
end

function WeaponFx.heldId(): string?
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	return tool and tool:GetAttribute("ToolId") :: string?
end

-- The effect a tool plays on a hit.
function WeaponFx.eventFor(toolId: string?): string
	local e = toolId and EVENT[toolId]
	if e then
		return e
	end
	local def = toolDef(toolId)
	return if def and def.kind == "auto" then "auto" elseif toolId == "Hands" then "punch" else "hit"
end

-- punch / hit / auto for any event (nil for cut, reveal and boss events)
function WeaponFx.family(event: string): string?
	return FAMILY[event]
end

function WeaponFx.accent(toolId: string?): Color3
	return toolId and ACCENT[toolId] or Color3.fromRGB(240, 250, 225)
end

-------------------------------------------------------------------------------------------------------------
-- the tool presets, built from FxPresets' own "hit" and "auto"
-------------------------------------------------------------------------------------------------------------
local function copy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local t = {}
	for k, x in v do
		t[k] = copy(x)
	end
	return t
end

local function layerNamed(p: any, name: string): any
	for _, l in p.layers do
		if l.name == name then
			return l
		end
	end
	return nil
end

local function without(p: any, names: { string })
	for i = #p.layers, 1, -1 do
		if table.find(names, p.layers[i].name or (p.layers[i].kind == "clippings" and "clippings" or "")) then
			table.remove(p.layers, i)
		end
	end
end

local function tint(l: any, a: { number }, b: any)
	if l then
		l.color = { { 0, a }, { 1, b } }
	end
end

function WeaponFx.install(P: any)
	if P.snip or not P.hit or not P.auto then
		return
	end
	-- SNIP: an X of bright blades closing where they bite, fine snippets fluttering down, a crisp little burst
	local snip = copy(P.hit)
	without(snip, { "marks", "shock" })
	local ch = layerNamed(snip, "chunks")
	if ch then
		ch.count = 3
		ch.size = 0.7
	end
	local sp = layerNamed(snip, "splinters")
	if sp then
		sp.count = 5
	end
	local crown = layerNamed(snip, "crownBlades")
	if crown then
		local flutter = copy(crown)
		flutter.name = "snippets"
		flutter.at = "contact"
		flutter.count = 9
		flutter.lifetime = { 1.3, 2.1 }
		flutter.speed = { 2, 4.5 }
		flutter.acceleration = { 0, -5, 0 }
		flutter.drag = 2.6
		flutter.size = { { 0, 0.32 }, { 0.85, 0.28 }, { 1, 0 } }
		table.insert(snip.layers, flutter)
	end
	table.insert(snip.layers, { kind = "snipX", name = "snipX", at = "contact" })
	snip.flash = 0.28
	snip.wobble = 0.75
	P.snip = snip

	-- SWEEP: a silver crescent across the clump, blades fanned out wide along the swing
	local sweep = copy(P.hit)
	without(sweep, { "marks" })
	local bl = layerNamed(sweep, "blades")
	if bl then
		bl.count = 12
		bl.spread = { 75, 30 }
	end
	tint(layerNamed(sweep, "glow"), { 240, 246, 255 }, "grassLight")
	table.insert(sweep.layers, { kind = "crescent", name = "crescent", at = "contact", color = { 226, 236, 255 }, radius = 1.7, span = 150, segs = 9, width = 1 })
	sweep.wobble = 1.05
	P.sweep = sweep

	-- REAP: everything bigger, lavender glow, a wide crescent, petals and sparkles
	local reap = copy(P.hit)
	without(reap, { "marks" })
	for _, name in { "blades", "splinters", "crownBlades" } do
		local l = layerNamed(reap, name)
		if l and l.count then
			l.count = math.ceil(l.count * 1.4)
		end
	end
	tint(layerNamed(reap, "glow"), { 236, 214, 255 }, { 190, 140, 255 })
	tint(layerNamed(reap, "impact"), { 250, 240, 255 }, { 200, 160, 255 })
	tint(layerNamed(reap, "shock"), { 230, 205, 255 }, { 170, 120, 255 })
	local sparkles = P.reveal and layerNamed(P.reveal, "sparkles")
	if sparkles then
		local s = copy(sparkles)
		s.name = "petals"
		s.at = "contact"
		s.count = 10
		s.color = { { 0, { 245, 225, 255 } }, { 1, { 186, 130, 255 } } }
		table.insert(reap.layers, s)
	end
	table.insert(reap.layers, { kind = "crescent", name = "crescent", at = "contact", color = { 214, 176, 255 }, radius = 2.7, span = 200, segs = 13, width = 1.6 })
	reap.flash = 0.36
	reap.wobble = 1.35
	P.reap = reap

	-- the auto tools: a spray (push mower), a whirl of fine flecks (weed whacker), a cyan sizzle (laser mower)
	local push = copy(P.auto)
	local pb = layerNamed(push, "blades")
	if pb then
		pb.count = 7
		pb.speed = { 11, 17 }
	end
	P.autoPush = push

	local whack = copy(P.auto)
	local wb = layerNamed(whack, "blades")
	if wb then
		wb.count = 8
		wb.speed = { 15, 23 }
		wb.spread = { 90, 90 }
		wb.size = { { 0, 0.24 }, { 0.8, 0.2 }, { 1, 0 } }
	end
	without(whack, { "poof" })
	P.autoWhack = whack

	local laser = copy(P.auto)
	local lb = layerNamed(laser, "blades")
	if lb then
		lb.color = { { 0, { 210, 255, 255 } }, { 1, { 70, 225, 255 } } }
		lb.lightEmission = 0.8
		lb.lightInfluence = 0
		lb.texture = "spark"
	end
	table.insert(laser.layers, { kind = "sizzle", name = "sizzle", at = "base", height = 0.7, color = { 110, 240, 255 } })
	P.autoLaser = laser
end

-------------------------------------------------------------------------------------------------------------
-- signature layers (client/HitFx hands us any layer kind it doesn't draw itself)
-------------------------------------------------------------------------------------------------------------
local folder = Instance.new("Folder")
folder.Name = "WeaponFx"
folder.Parent = workspace

local function rgb(v: { number }?, default: Color3): Color3
	return if v then Color3.fromRGB(v[1], v[2], v[3]) else default
end

local function neon(size: Vector3, color: Color3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Parent = folder
	return p
end

-- two blades close into an X where they bite
local function snipX(cf: CFrame, out: Vector3, sc: number)
	local at = cf.Position + out * 0.25
	local face = CFrame.lookAt(at, at + out)
	local len = 2.1 * math.sqrt(sc)
	for _, side in { 1, -1 } do
		local open = face * CFrame.Angles(0, 0, math.rad(40 * side))
		local p = neon(Vector3.new(0.09, len, 0.04), Color3.fromRGB(255, 252, 240), open)
		p.Transparency = 0.05
		TweenService:Create(p, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = face * CFrame.Angles(0, 0, math.rad(9 * side)) }):Play()
		TweenService:Create(p, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.09), { Transparency = 1, Size = Vector3.new(0.03, len * 0.8, 0.04) }):Play()
		Debris:AddItem(p, 0.35)
	end
	-- the glint where they meet
	local g = neon(Vector3.one * 0.32, Color3.fromRGB(255, 255, 255), CFrame.new(at))
	g.Shape = Enum.PartType.Ball
	g.Transparency = 1
	TweenService:Create(g, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.07), { Transparency = 0.1, Size = Vector3.one * 0.55 }):Play()
	TweenService:Create(g, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.13), { Transparency = 1, Size = Vector3.one * 0.1 }):Play()
	Debris:AddItem(g, 0.35)
end

-- a crescent of light sweeping across the clump, from top right to bottom left, segment by segment
local function crescent(layer: any, cf: CFrame, out: Vector3, sc: number)
	local at = cf.Position + out * 0.35
	local plane = CFrame.lookAt(at, at + out) * CFrame.Angles(0, 0, math.rad(-35))
	local R = (layer.radius or 1.7) * math.sqrt(sc)
	local span = math.rad(layer.span or 150)
	local n = layer.segs or 9
	local color = rgb(layer.color, Color3.new(1, 1, 1))
	local seg = R * span / n * 1.15
	for i = 0, n - 1 do
		local k = i / (n - 1)
		local a = span / 2 - k * span -- right to left
		local local_ = Vector3.new(math.cos(a) * R, math.sin(a) * R * 0.55, 0)
		local tangent = Vector3.new(-math.sin(a), math.cos(a) * 0.55, 0)
		local pos = plane:PointToWorldSpace(local_)
		local dir = plane:VectorToWorldSpace(tangent).Unit
		-- thickest in the middle of the arc, tapering at both ends
		local w = (0.06 + 0.12 * math.sin(k * math.pi)) * (layer.width or 1) * math.sqrt(sc)
		local p = neon(Vector3.new(w, seg, 0.05), color, CFrame.fromMatrix(pos, dir:Cross(plane.LookVector), dir))
		p.Transparency = 1
		local delay = k * 0.07
		TweenService:Create(p, TweenInfo.new(0.03, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, delay), { Transparency = 0.05 }):Play()
		TweenService:Create(p, TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, delay + 0.05), { Transparency = 1, Size = Vector3.new(w * 0.3, seg, 0.05) }):Play()
		Debris:AddItem(p, delay + 0.4)
	end
end

-- a cyan line flashing through the stems (laser mower), at most every 0.1 s
local lastSizzle = 0
local function sizzle(layer: any, cf: CFrame, out: Vector3, sc: number)
	local now = os.clock()
	if now - lastSizzle < 0.1 then
		return
	end
	lastSizzle = now
	local across = out:Cross(Vector3.yAxis)
	across = if across.Magnitude > 1e-3 then across.Unit else Vector3.xAxis
	local len = 2.6 * sc
	local p = neon(Vector3.new(len, 0.14, 0.14), rgb(layer.color, Color3.fromRGB(110, 240, 255)), CFrame.fromMatrix(cf.Position, across, Vector3.yAxis))
	TweenService:Create(p, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1, Size = Vector3.new(len * 1.15, 0.03, 0.03) }):Play()
	Debris:AddItem(p, 0.25)
end

-- Draw a layer kind HitFx doesn't know. Returns true when it drew it.
function WeaponFx.layer(layer: any, cf: CFrame, out: Vector3, sc: number, mine: boolean): boolean
	if layer.kind == "snipX" then
		if mine then
			snipX(cf, out, sc)
		end
		return true
	elseif layer.kind == "crescent" then
		crescent(layer, cf, out, sc)
		return true
	elseif layer.kind == "sizzle" then
		sizzle(layer, cf, out, sc)
		return true
	end
	return false
end

-------------------------------------------------------------------------------------------------------------
-- sounds: each tool's own recipe (licensed Config.SOUNDS, re-pitched). `up` climbs with the hits on one clump.
-- Returns true when it played (HitFx's chip tick still plays on top).
-------------------------------------------------------------------------------------------------------------
local lastAuto = 0
local function jitter(): number
	return 0.96 + math.random() * 0.08
end
function WeaponFx.sounds(event: string, up: number): boolean
	if event == "snip" then
		Sound.playAt("slice", 2.15 * jitter(), 0.5) -- the bright snick of the blades
		Sound.playAt("click", 1.45 * up, 0.22) -- the blades meeting
		Sound.play("rustle", 0.12, 0.55)
		return true
	elseif event == "sweep" then
		Sound.playAt("slice", 1.15 * jitter(), 0.85) -- the long draw through the stems
		Sound.playAt("stepGrass", 0.85 * jitter(), 1.6) -- a grassy crunch
		Sound.play("rustle", 0.15)
		return true
	elseif event == "reap" then
		Sound.playAt("slice", 0.82 * jitter(), 1)
		Sound.playAt("whoosh", 0.72 * jitter(), 0.5)
		Sound.play("rustle", 0.1, 1.2)
		Sound.playAt("rareChime", 1.55 * up, 0.14) -- a soft sparkle on top
		return true
	elseif FAMILY[event] == "auto" then
		local now = os.clock()
		if now - lastAuto < 0.07 then
			return true
		end
		lastAuto = now
		if event == "autoWhack" then
			Sound.playAt("rustle", 1.55 * jitter(), 0.3)
		elseif event == "autoLaser" then
			Sound.playAt("burst", 2.3 * jitter(), 0.18)
			Sound.playAt("rustle", 1.2 * jitter(), 0.22)
		else
			Sound.playAt("rustle", 0.92 * jitter(), 0.4)
		end
		return true
	end
	return false -- punch / hit: HitFx's own
end

-- the extra weight of a hit, on top of HitFx's jolt (the scythe hits heavier)
function WeaponFx.feel(event: string)
	if event == "reap" then
		local k = Config.CAMERA_KICK
		CameraView.jolt(k.hit.pitch * 0.7, 0)
	end
end

-------------------------------------------------------------------------------------------------------------
-- hit-marker: four little leaves flick out of the middle of the screen when your blow lands
-------------------------------------------------------------------------------------------------------------
local marker = Instance.new("Frame")
marker.Name = "HitMarker"
marker.AnchorPoint = Vector2.new(0.5, 0.5)
marker.Position = UDim2.fromScale(0.5, 0.5)
marker.Size = UDim2.fromOffset(2, 2)
marker.BackgroundTransparency = 1
marker.ZIndex = 6
marker.Parent = UI.gui
local petals: { { frame: Frame, dir: Vector2 } } = {}
for i = 0, 3 do
	local a = math.rad(45 + 90 * i)
	local f = Instance.new("Frame")
	f.Name = "Leaf" .. i
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromOffset(11, 5)
	f.Rotation = math.deg(a)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.ZIndex = 6
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = f
	local s = Instance.new("UIStroke")
	s.Thickness = 1
	s.Color = Color3.fromRGB(30, 52, 34)
	s.Transparency = 1
	s.Parent = f
	f.Parent = marker
	table.insert(petals, { frame = f, dir = Vector2.new(math.cos(a), math.sin(a)) })
end

function WeaponFx.marker(color: Color3, big: boolean?)
	local r0, r1 = 7, if big then 19 else 15
	for _, p in petals do
		local f = p.frame
		f.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35)
		f.Position = UDim2.fromOffset(p.dir.X * r0, p.dir.Y * r0)
		f.BackgroundTransparency = 0
		f.Size = UDim2.fromOffset(if big then 14 else 11, 5)
		local s = f:FindFirstChildOfClass("UIStroke") :: UIStroke
		s.Transparency = 0.4
		local info = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(f, info, { Position = UDim2.fromOffset(p.dir.X * r1, p.dir.Y * r1), BackgroundTransparency = 1 }):Play()
		TweenService:Create(s, info, { Transparency = 1 }):Play()
	end
end

-------------------------------------------------------------------------------------------------------------
-- the bite: a soft number floating up off the clump, in the tool's colour (pooled)
-------------------------------------------------------------------------------------------------------------
local numbers: { { gui: BillboardGui, label: TextLabel, a: Attachment } } = {}
local nextNumber = 1
for i = 1, 6 do
	local a = Instance.new("Attachment")
	a.Name = "Bite" .. i
	a.Parent = workspace.Terrain
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(110, 40)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 70
	gui.Adornee = a
	gui.Enabled = false
	gui.Parent = a
	local label = UI.text(gui, "", UDim2.fromScale(1, 1), { color = Color3.fromRGB(250, 246, 226), stroke = 2.5 })
	local sc = Instance.new("UIScale")
	sc.Parent = label
	table.insert(numbers, { gui = gui, label = label, a = a })
end

local function num(v: number): string
	if v >= 1000 then
		return Format.short(v)
	end
	local r = math.floor(v * 10 + 0.5) / 10
	return if r % 1 == 0 then tostring(math.floor(r)) else ("%.1f"):format(r)
end

-- `share`: how much of the clump this bite was (0..1): a bigger bite gets a bigger number
function WeaponFx.bite(pos: Vector3, amount: number, share: number, color: Color3)
	if amount <= 0 then
		return
	end
	local n = numbers[nextNumber]
	nextNumber = nextNumber % #numbers + 1
	local start = pos + Vector3.new((math.random() - 0.5) * 1.2, 0, (math.random() - 0.5) * 1.2)
	n.a.WorldPosition = start
	n.label.Text = "-" .. num(amount)
	n.label.TextColor3 = Color3.fromRGB(250, 246, 226)
	n.label.TextTransparency = 0
	local stroke = n.label:FindFirstChildOfClass("UIStroke") :: UIStroke
	stroke.Color = UI.shade(color, 0.42)
	stroke.Transparency = 0
	n.gui.Enabled = true
	local sc = n.label:FindFirstChildOfClass("UIScale") :: UIScale
	local size = 0.85 + math.clamp(share, 0, 1) * 0.55
	sc.Scale = size * 1.35
	TweenService:Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = size }):Play()
	local rise = TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(n.a, rise, { WorldPosition = start + Vector3.new(0, 2.2, 0) }):Play()
	local fade = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.6)
	TweenService:Create(n.label, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
	local my = n.label.Text .. tostring(os.clock())
	n.label:SetAttribute("Tag", my)
	task.delay(1.0, function()
		if n.label:GetAttribute("Tag") == my then
			n.gui.Enabled = false
		end
	end)
end

return WeaponFx
