--!strict
-- STUD FOUNTAIN (7 Nov 2026; owner: "Probeer de forgegui dingen in stud style maar ... super hoog kwaliteit", "Moet meer
-- accuraat zijn en donkerder", then "Yes" to the house and on to the rest). The ForgeGUI fountain by the spawn
-- (forge_fountain, 9 x 5.4 x 8.9) rebuilt from studded bricks to its own shape, measured from pictures of it from
-- above and the side: a twelve-sided basin of sandstone blocks under a plank rim with pale corner caps and rivets,
-- water with two lily pads, a stack of three mossy stones in the middle and on top a teal watering can with brass
-- bands, tipped forward, pouring a stream into the basin; flowers in clumps along the rim.
-- StudFountain.build(parent, pivot) -> the Model (pivot: the bottom middle).
local StudFountain = {}

-- (owner: "donkerder ... het moet niet zo bright zijn", for every stud model) every colour x Config.STUD_FORGE.tone
local TONE = (function(): number
	local ok, cfg = pcall(function()
		return require(game:GetService("ReplicatedStorage"):WaitForChild("MowALawn"):WaitForChild("Config")) :: any
	end)
	local t = ok and type(cfg.STUD_FORGE) == "table" and tonumber(cfg.STUD_FORGE.tone) or nil
	return math.clamp(t or 0.85, 0.4, 1)
end)()
local function toned(c: Color3): Color3
	return Color3.new(c.R * TONE, c.G * TONE, c.B * TONE)
end

local C = Color3.fromRGB
local SAND = { C(216, 172, 104), C(198, 152, 88), C(226, 186, 118) }
local PLANK = { C(150, 92, 52), C(132, 80, 44) }
local CORNER = C(204, 164, 108)
local RIVET = C(70, 66, 64)
local BASIN = C(46, 70, 96)
local WATER = C(56, 130, 206)
local STREAM = C(160, 214, 250)
local STONE = { C(150, 148, 140), C(128, 126, 120), C(166, 164, 156) }
local MOSS = { C(92, 140, 60), C(110, 156, 70) }
local TEAL = C(46, 128, 142)
local TEAL_DARK = C(34, 104, 118)
local BRASS = C(212, 170, 76)
local PAD = { C(92, 164, 72), C(76, 144, 60) }
local LEAF = { C(66, 136, 56), C(52, 114, 46) }
local FLOWERS = { C(176, 146, 232), C(250, 214, 92), C(246, 240, 226), C(232, 120, 160) }

local STUDS = Enum.SurfaceType.Studs
local INLET = Enum.SurfaceType.Inlet
local SMOOTH = Enum.SurfaceType.Smooth

local model: Model = nil :: any
local origin = CFrame.identity
local count = 0

local function brick(name: string, size: Vector3, cf: CFrame, color: Color3, smooth: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = origin * cf
	p.Color = toned(color)
	p.Material = Enum.Material.Plastic
	local s = if smooth then SMOOTH else STUDS
	p.TopSurface = s
	p.FrontSurface = s
	p.BackSurface = s
	p.LeftSurface = s
	p.RightSurface = s
	p.BottomSurface = if smooth then SMOOTH else INLET
	p.Parent = model
	count += 1
	return p
end

local function ball(name: string, d: number, cf: CFrame, color: Color3): Part
	local p = brick(name, Vector3.one * d, cf, color, true)
	p.Shape = Enum.PartType.Ball
	return p
end

-- a flat disc lying on the ground (a cylinder turned upright)
local function disc(name: string, d: number, h: number, cf: CFrame, color: Color3): Part
	local p = brick(name, Vector3.new(h, d, d), cf * CFrame.Angles(0, 0, math.pi / 2), color, true)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-------------------------------------------------------------------------------------------------------------
local SIDES = 12
local STEP = math.pi * 2 / SIDES
local TAN = math.tan(STEP / 2)
local A_STONE = 4.3 -- the stone course's outer apothem
local STONE_TOP = 1.45
local A_RIM = 4.45 -- the plank rim's
local RIM_TOP = 2.15
local WATER_Y = 1.8

-- side i's frame: its outer face's middle at apothem a, height y; X along the side, -Z out
local function side(i: number, a: number, y: number): CFrame
	return CFrame.Angles(0, (i + 0.5) * STEP, 0) * CFrame.new(0, y, -a)
end

local function basin()
	-- sandstone blocks, a plank rim proud of them with two rivets a plank, pale caps on the corners
	for i = 0, SIDES - 1 do
		local s1 = 2 * A_STONE * TAN
		brick("Stone", Vector3.new(s1 + 0.02, STONE_TOP, 1), side(i, A_STONE - 0.5, STONE_TOP / 2), SAND[i % 3 + 1])
		local s2 = 2 * A_RIM * TAN
		local plank = side(i, A_RIM - 0.62, (STONE_TOP + RIM_TOP) / 2)
		brick("Rim", Vector3.new(s2 + 0.02, RIM_TOP - STONE_TOP, 1.25), plank, PLANK[i % 2 + 1])
		for k = -1, 1, 2 do
			ball("Rivet", 0.2, plank * CFrame.new(k * s2 * 0.3, 0, -0.63), RIVET)
		end
		local corner = CFrame.Angles(0, (i + 1) * STEP, 0) * CFrame.new(0, (STONE_TOP + RIM_TOP) / 2 + 0.05, -(A_RIM / math.cos(STEP / 2) - 0.45))
		brick("RimCap", Vector3.new(0.75, RIM_TOP - STONE_TOP + 0.12, 0.75), corner, CORNER)
	end
	-- the inside: a dark floor under the water
	disc("BasinFloor", (A_STONE - 0.6) * 2, WATER_Y - 0.1, CFrame.new(0, (WATER_Y - 0.1) / 2, 0), BASIN)
	local w = disc("Water", (A_STONE - 0.75) * 2, 0.2, CFrame.new(0, WATER_Y, 0), WATER)
	w.Transparency = 0.12
	w.CanCollide = false
	-- two lily pads, one in flower
	for i, pad in { { 1.7, -0.9, 1.0 }, { -1.5, 1.6, 0.85 } } do
		disc("LilyPad", pad[3], 0.08, CFrame.new(pad[1], WATER_Y + 0.12, pad[2]), PAD[i])
	end
	ball("LilyFlower", 0.4, CFrame.new(1.85, WATER_Y + 0.35, -1.0), FLOWERS[4])
end

-- the mossy stones in the middle
local function stack(): number
	local y = WATER_Y - 0.3
	local tops = 0
	for i, s in { { 2.7, 0.8, 2.5, 8 }, { 2.1, 0.7, 2.0, -14 }, { 1.6, 0.5, 1.5, 22 } } do
		local cf = CFrame.new(0, y + s[2] / 2, 0) * CFrame.Angles(0, math.rad(s[4]), 0)
		brick("StackStone", Vector3.new(s[1], s[2], s[3]), cf, STONE[i])
		-- moss along two of its top edges
		brick("Moss", Vector3.new(s[1] * 0.55, 0.2, 0.5), cf * CFrame.new(-s[1] * 0.18, s[2] / 2 + 0.05, -s[3] / 2 + 0.25), MOSS[i % 2 + 1])
		brick("Moss", Vector3.new(0.5, 0.2, s[3] * 0.5), cf * CFrame.new(s[1] / 2 - 0.25, s[2] / 2 + 0.05, s[3] * 0.15), MOSS[(i + 1) % 2 + 1])
		y += s[2]
		tops = y
	end
	return tops
end

-- the watering can on top, tipped toward its spout, pouring
local SPOUT_YAW = math.rad(36) -- (as on the mesh: the spout out over the basin's front-left)
local TIP = math.rad(-22)

local function can(baseY: number)
	local frame = CFrame.new(0, baseY, 0) * CFrame.Angles(0, SPOUT_YAW, 0) * CFrame.Angles(0, 0, TIP)
	local body = frame * CFrame.new(0, 0.72, 0)
	brick("CanBody", Vector3.new(1.6, 1.4, 1.3), body, TEAL)
	brick("CanBand", Vector3.new(1.7, 0.24, 1.4), body * CFrame.new(0, -0.38, 0), BRASS, true)
	brick("CanBand", Vector3.new(1.7, 0.24, 1.4), body * CFrame.new(0, 0.62, 0), BRASS, true)
	brick("CanTop", Vector3.new(1.2, 0.25, 1), body * CFrame.new(-0.1, 0.82, 0), TEAL_DARK)
	-- the handle: an arch over the back of the top
	brick("CanHandle", Vector3.new(0.28, 1.1, 0.3), body * CFrame.new(-0.72, 1.15, 0), TEAL_DARK)
	brick("CanHandle", Vector3.new(1.2, 0.28, 0.3), body * CFrame.new(-0.25, 1.62, 0), TEAL_DARK)
	brick("CanHandle", Vector3.new(0.28, 0.6, 0.3), body * CFrame.new(0.28, 1.35, 0), TEAL_DARK)
	-- the spout from low on the front, rising, a brass rose on its end
	local spout = body * CFrame.new(0.8, -0.3, 0) * CFrame.Angles(0, 0, math.rad(28)) * CFrame.new(0.95, 0, 0)
	brick("CanSpout", Vector3.new(1.9, 0.32, 0.32), spout, TEAL)
	local rose = brick("CanRose", Vector3.new(0.3, 0.6, 0.6), spout * CFrame.new(1.05, 0, 0), BRASS, true)
	-- the stream from the rose down to the water, drifting out a little as it falls, and the splash
	local from = origin:PointToObjectSpace(rose.Position)
	local to = Vector3.new(from.X * 1.12, WATER_Y + 0.1, from.Z * 1.12)
	local seg = 5
	for k = 0, seg - 1 do
		local a = from:Lerp(to, k / seg)
		local b = from:Lerp(to, (k + 1) / seg)
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		local p = brick("Stream", Vector3.new(0.26 - k * 0.02, len + 0.08, 0.45 - k * 0.03), CFrame.lookAt(mid, mid + (b - a)) * CFrame.Angles(math.pi / 2, 0, 0), STREAM, true)
		p.Transparency = 0.25 + k * 0.05
		p.CanCollide = false
		p.CanQuery = false
	end
	local splash = disc("Splash", 1.1, 0.1, CFrame.new(to.X, WATER_Y + 0.12, to.Z), C(220, 240, 255))
	splash.Transparency = 0.35
	splash.CanCollide = false
	-- a few droplets where it lands
	local spray = Instance.new("Attachment")
	spray.Position = Vector3.new(0, 0.1, 0)
	spray.Parent = splash
	local e = Instance.new("ParticleEmitter")
	e.Rate = 10
	e.Lifetime = NumberRange.new(0.35, 0.6)
	e.Speed = NumberRange.new(2, 3.5)
	e.SpreadAngle = Vector2.new(40, 40)
	e.Acceleration = Vector3.new(0, -14, 0)
	e.Size = NumberSequence.new(0.18, 0.05)
	e.Color = ColorSequence.new(C(210, 236, 255))
	e.Transparency = NumberSequence.new(0.2, 1)
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = spray
end

-- flower clumps on the rim
local function flowers()
	for i, at in { 1.2, 3.1, 4.4, 7.6, 10.3 } do
		local cf = CFrame.Angles(0, at * STEP, 0) * CFrame.new(0, RIM_TOP, -(A_RIM - 0.55))
		brick("FlowerLeaves", Vector3.new(1.1, 0.5, 0.8), cf * CFrame.new(0, 0.25, 0), LEAF[1])
		brick("FlowerLeaves", Vector3.new(0.7, 0.45, 0.6), cf * CFrame.new(0.2, 0.7, 0.05), LEAF[2])
		for k = 0, 2 do
			ball("Flower", 0.36, cf * CFrame.new(-0.35 + k * 0.35, 0.75 + (k % 2) * 0.25, -0.15), FLOWERS[(i + k) % 3 + 1])
		end
	end
end

-------------------------------------------------------------------------------------------------------------
function StudFountain.build(parent: Instance, pivot: CFrame): Model
	model = Instance.new("Model")
	model.Name = "StudFountain"
	origin = pivot
	count = 0
	basin()
	local top = stack()
	can(top)
	flowers()
	model:SetAttribute("Bricks", count)
	model:SetAttribute("StudBuilt", true) -- (server/StudLook leaves it as built)
	model.WorldPivot = pivot
	model.Parent = parent
	return model
end

return StudFountain
