--!strict
-- THE LOBBY AS A GIANT BACK GARDEN (4 Nov remake; owner: "Remake heel de main lobby", then, on a re-arranged old
-- lobby: "I SAID REMAKE", and picked "Reuzetuin": you are tiny in a giant back garden). Nothing of the old lobby's
-- look is used: no tents, start gate, log lodge, barn, fence ring or forest. What works underneath stays (the party
-- pads, the classes, the garage, the rewards, the boards: server/Lobby drives them through the handles returned here).
--
-- You stand on a giant garden patio (sandstone slabs, moss in the joints), looking north at the landmark: a giant push
-- mower parked at the patio's edge, facing the uncut lawn, its handle toward you with START A RUN hanging from it.
-- Around the patio the lawn is a wall of grass blades taller than houses, giant daisies and tulips over it; far off,
-- the garden's wooden fence. The pads are giant bottle caps in an arc in front of you, each with a popsicle-stick
-- sign; the gold cap is CONTINUE (your saved run). The free rewards are a seed packet stuck in the soil a few steps
-- to your left, its bays two fallen leaves. The classes shop is a terracotta flower pot lying on its side (a
-- mannequin by its mouth wears the best class in stock); the garage is a watering can with a roll door; GRASS CUT
-- and BEST TIMES are giant plant labels. A garden hose, pebbles, a ball and a sprinkler dress the edges.
-- Pieces: server/YardKit. Lobby space: y = 0 is the lawn, +Z north (away from the spawn), +X to your LEFT.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local PropKit = require(script.Parent.PropKit)
local Models = require(script.Parent.Models)
local Environment = require(script.Parent.Environment)
local LobbyKit = require(script.Parent.LobbyKit)
local LobbyPads = require(script.Parent.LobbyPads)
local Kit = require(script.Parent.YardKit)

local YardBuilder = {}
YardBuilder.ON = true -- false: server/LobbyBuilder builds the old lobby again

local C = Color3.fromRGB
local K = Kit.C
local block = Kit.block

local SPAWN = Vector3.new(0, 0, -80)
local PATIO = { x0 = -60, x1 = 60, z0 = -100, z1 = 20, slab = 18, step = 20, top = 0.5 }
local PAD_R = 5.2
local PAD_RADIUS = 34
local PADS = { { a = 35, kind = "solo" }, { a = 13, kind = "party" }, { a = -13, kind = "party" }, { a = -35, kind = "party" }, { a = 57, kind = "continue" } }
local MOWER = Vector3.new(0, 0, 64) -- its middle; it faces north, its handle toward you
local POT = { mouth = Vector3.new(-40, 12, -58), len = 30 } -- lying along X, mouth to the east
local CAN = Vector3.new(-46, 0, -12)
local PACKET = Vector3.new(20, 0, -92)
local GRASS_CUT = Vector3.new(32, 0, 6) -- (either side of the mower's handle, clear of its bag and the can's spout)
local BEST_TIMES = Vector3.new(-32, 0, 6)

local OPEN = C(80, 255, 95)
local BUSY = C(40, 210, 255)
local SAVE = K.gold
local CYAN = C(40, 230, 255)

local function folder(name: string, parent: Instance): Folder
	return PropKit.folder(name, parent) :: Folder
end

local function facing(pos: Vector3, toward: Vector3): CFrame
	return CFrame.lookAt(pos, Vector3.new(toward.X, pos.Y, toward.Z))
end

local function onArc(angle: number, r: number): Vector3
	local a = math.rad(angle)
	return Vector3.new(SPAWN.X + math.sin(a) * r, 0, SPAWN.Z + math.cos(a) * r)
end

local function inPatio(x: number, z: number, grow: number): boolean
	return x > PATIO.x0 - grow and x < PATIO.x1 + grow and z > PATIO.z0 - grow and z < PATIO.z1 + grow
end

-------------------------------------------------------------------------------------------------------------
-- ground, patio, lawn, fence
-------------------------------------------------------------------------------------------------------------
local function ground(world: Instance)
	local f = folder("Ground", world)
	local lawn = block(f, Vector3.new(900, 2, 900), CFrame.new(0, -1, 0), K.lawn, { name = "Lawn", material = Enum.Material.Grass })
	lawn.TopSurface = Enum.SurfaceType.Smooth
	-- the patio: a bed of moss and soil, and sandstone slabs on it in three close tones, a lighter inset top each
	local w, d = PATIO.x1 - PATIO.x0, PATIO.z1 - PATIO.z0
	block(f, Vector3.new(w + 2, 0.2, d + 2), CFrame.new((PATIO.x0 + PATIO.x1) / 2, 0.1, (PATIO.z0 + PATIO.z1) / 2), K.moss, { name = "PatioBed", smooth = true })
	local i = 0
	for x = PATIO.x0 + PATIO.step / 2, PATIO.x1, PATIO.step do
		for z = PATIO.z0 + PATIO.step / 2, PATIO.z1, PATIO.step do
			i += 1
			local tone = K.slab[(i * 7) % #K.slab + 1]
			local h = PATIO.top - 0.1
			local slab = block(f, Vector3.new(PATIO.slab, h, PATIO.slab), CFrame.new(x, h / 2 + 0.1, z), tone, { name = "Slab", smooth = true })
			slab.Material = Enum.Material.Sandstone
			block(f, Vector3.new(PATIO.slab - 1.6, 0.06, PATIO.slab - 1.6), CFrame.new(x, PATIO.top + 0.02, z), tone:Lerp(K.slabTop, 0.45), { name = "SlabTop", smooth = true, collide = false, shadow = false })
		end
	end
end

-- The lawn beyond the patio: the run's own grass tufts, giant (one mesh, cheap), thick near the patio, sparser and
-- bigger further out; none where the stations stand.
local function lawn(world: Instance)
	local f = folder("Lawn", world)
	local rng = Random.new(42)
	local keepOut = {
		{ MOWER, 40 },
		{ POT.mouth - Vector3.new(15, 0, 0), 22 },
		{ CAN, 20 },
	}
	local function clear(x: number, z: number): boolean
		for _, k in keepOut do
			if Vector2.new(x - k[1].X, z - k[1].Z).Magnitude < k[2] then
				return false
			end
		end
		return true
	end
	for x = -200, 200, 9 do
		for z = -220, 220, 9 do
			local px, pz = x + rng:NextNumber(-3, 3), z + rng:NextNumber(-3, 3)
			if not inPatio(px, pz, 4) and clear(px, pz) then
				local far = not inPatio(px, pz, 50)
				if not far or rng:NextNumber() < 0.45 then
					local s = if far then rng:NextNumber(10, 14) else rng:NextNumber(7, 10)
					if not Models.place("tuft_lawn", f, CFrame.new(px, 0, pz) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), s, true) then
						return
					end
				end
			end
		end
		task.wait()
	end
end

-- Hero blades arching over the patio's edges, leaning in (built, so they read as blades up close).
local function blades(world: Instance)
	local f = folder("Blades", world)
	local rng = Random.new(7)
	local function edge(a: Vector3, b: Vector3, inward: Vector3)
		local len = (b - a).Magnitude
		local n = math.floor(len / 7)
		for i = 0, n do
			local p = a + (b - a) * (i / n) - inward * rng:NextNumber(3, 7)
			local yaw = math.atan2(inward.X, inward.Z) + rng:NextNumber(-0.5, 0.5)
			for _ = 1, rng:NextInteger(1, 2) do
				local q = p + Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
				Kit.blade(f, q, rng:NextNumber(26, 50), rng:NextNumber(3, 4.6), yaw + math.pi, rng:NextNumber(0.05, 0.11))
			end
		end
	end
	local x0, x1, z0, z1 = PATIO.x0, PATIO.x1, PATIO.z0, PATIO.z1
	edge(Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z0), Vector3.zAxis) -- south, behind the spawn
	edge(Vector3.new(x1, 0, z0), Vector3.new(x1, 0, z1), -Vector3.xAxis) -- east
	edge(Vector3.new(x0, 0, -30), Vector3.new(x0, 0, z0), Vector3.xAxis) -- west, south of the pot only (the pot and can stand there)
	edge(Vector3.new(x1, 0, z1), Vector3.new(30, 0, z1), -Vector3.zAxis) -- north, either side of the mower
	edge(Vector3.new(-30, 0, z1), Vector3.new(x0, 0, z1), -Vector3.zAxis)
end

-- The garden's wooden fence far off on all four sides, taller than everything.
local function fence(world: Instance)
	local f = folder("Fence", world)
	local E = 230
	local wood, dark = C(168, 120, 78), C(130, 90, 58)
	for _, side in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		for t = -E, E - 14, 14 do
			local along = t + 7
			local pos = if side[1] ~= 0 then Vector3.new(side[1] * E, 60, along) else Vector3.new(along, 60, side[2] * E)
			local size = if side[1] ~= 0 then Vector3.new(3, 120, 13.4) else Vector3.new(13.4, 120, 3)
			block(f, size, CFrame.new(pos), if (t // 14) % 2 == 0 then wood else wood:Lerp(dark, 0.3), { smooth = true, collide = false })
		end
		for _, y in { 30, 92 } do
			local pos = if side[1] ~= 0 then Vector3.new(side[1] * (E - 3), y, 0) else Vector3.new(0, y, side[2] * (E - 3))
			local size = if side[1] ~= 0 then Vector3.new(3, 8, E * 2) else Vector3.new(E * 2, 8, 3)
			block(f, size, CFrame.new(pos), dark, { smooth = true, collide = false })
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- the landmark: a giant push mower
-------------------------------------------------------------------------------------------------------------
local function mower(world: Instance)
	local m = folder("Landmark", world)
	-- (its front, -Z in its own frame, looks north at the uncut lawn; the handle comes back toward the spawn)
	local at = CFrame.lookAt(MOWER, MOWER + Vector3.zAxis)
	local function L(x: number, y: number, z: number): CFrame
		return at * CFrame.new(x, y, z)
	end
	-- wheels: black tyres, grey hubs, yellow caps
	for _, w in { { -25, 9, -16, 9 }, { 25, 9, -16, 9 }, { -25, 10, 18, 10 }, { 25, 10, 18, 10 } } do
		local axle = L(w[1], w[2], w[3]) * CFrame.Angles(0, 0, math.rad(90))
		Kit.ring(m, axle, w[4], 0, 4, 1.5, K.black)
		Kit.ring(m, axle, 4.5, 0, 4.6, 1, K.steel, { smooth = true })
		Kit.ring(m, axle, 1.8, 0, 5.2, 0.6, C(250, 200, 40), { smooth = true })
	end
	-- the deck
	block(m, Vector3.new(45, 2, 47), L(0, 6.2, 0), K.redDark)
	block(m, Vector3.new(44, 7, 46), L(0, 10.2, 0), K.red)
	block(m, Vector3.new(44.4, 1, 46.4), L(0, 14.2, 0), K.redDark)
	block(m, Vector3.new(40, 5, 3), L(0, 9, -24.5), K.redDark) -- front bumper
	-- the engine: a grey base, a black block with fins, a red cap, a fuel cap and an air filter
	block(m, Vector3.new(20, 3, 20), L(0, 16.2, -2), K.steelDark)
	block(m, Vector3.new(16, 10, 16), L(0, 22.7, -2), K.black)
	for i, y in { 19, 22, 25 } do
		block(m, Vector3.new(17, 0.8, 17), L(0, y, -2), if i == 2 then K.steelDark else K.steel, { smooth = true })
	end
	block(m, Vector3.new(14, 2, 14), L(0, 28.7, -2), K.red)
	block(m, Vector3.new(2.6, 1.4, 2.6), L(4, 30.4, -5), C(250, 200, 40))
	block(m, Vector3.new(6, 5, 4), L(-8.5, 23, -10), K.steelDark)
	-- the grass bag behind it
	block(m, Vector3.new(32, 18, 20), L(0, 16, 34), C(64, 128, 52), { material = Enum.Material.Fabric })
	block(m, Vector3.new(33, 1.4, 21), L(0, 25.6, 34), K.steel, { smooth = true })
	block(m, Vector3.new(26, 12, 0.6), L(0, 15, 44.2), C(52, 108, 44), { material = Enum.Material.Fabric })
	-- the handle: two bars rising back toward the spawn, a middle bar, the black grip
	local top = 50
	for _, sx in { -1, 1 } do
		Kit.bar(m, L(sx * 18, 13, 22).Position, L(sx * 16, top, 50).Position, 2.4, K.steel, { smooth = true })
	end
	Kit.bar(m, L(-17, 31, 36).Position, L(17, 31, 36).Position, 1.8, K.steel, { smooth = true })
	Kit.bar(m, L(-17.5, top, 50).Position, L(17.5, top, 50).Position, 3, K.black)
	-- START A RUN on a banner hanging from the grip, facing the spawn
	local banner = block(m, Vector3.new(26, 9, 0.5), L(0, top - 5.8, 50.6) * CFrame.Angles(0, math.pi, 0), K.paper, { smooth = true, collide = false, name = "Banner" })
	for _, x in { -12, 12 } do
		Kit.bar(m, L(x, top - 1.4, 50.4).Position, L(x, top - 0.2, 50.2).Position, 0.5, K.black, { collide = false })
	end
	block(m, Vector3.new(27, 1, 0.6), L(0, top - 10.6, 50.6), K.red, { smooth = true, collide = false })
	local face = PropKit.surfaceText(banner, "START A RUN", PropKit.TITLE)
	face.Size = UDim2.fromScale(0.94, 0.8)
	face.Position = UDim2.fromScale(0.03, 0.1)
	-- (a solid box round it so nobody walks into the mower's insides)
	local box = block(m, Vector3.new(58, 30, 70), L(0, 15, 8), C(255, 255, 255), { name = "MowerCollider" })
	box.Transparency = 1
	box.CastShadow = false
	box.CanQuery = false
end

-------------------------------------------------------------------------------------------------------------
-- the pads: giant bottle caps
-------------------------------------------------------------------------------------------------------------
local function statusTag(parent: Instance, pos: Vector3): TextLabel
	local holder = PropKit.part({ size = Vector3.one, cf = CFrame.new(pos), color = Color3.new(1, 1, 1), parent = parent, transparency = 1, collide = false, name = "PadStatus" })
	holder.CanQuery = false
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(10, 1.8)
	gui.LightInfluence = 0.6
	gui.MaxDistance = 140
	gui.Parent = holder
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Config.UI.font
	l.TextScaled = true
	l.TextColor3 = C(255, 240, 205)
	local s = Instance.new("UIStroke")
	s.Thickness = 2.5
	s.Color = C(58, 34, 18)
	s.Parent = l
	l.Parent = gui
	return l
end

local CAP_COLORS = { solo = C(52, 118, 214), party = C(206, 52, 46), continue = C(214, 160, 40) }

local function padDef(m: Instance, i: number, kind: string): any
	local pos = onArc(PADS[i].a, PAD_RADIUS)
	local at = facing(Vector3.new(pos.X, PATIO.top, pos.Z), SPAWN)
	local base = if kind == "continue" then SAVE else OPEN
	local cap = Kit.cap(m, at, PAD_R, CAP_COLORS[kind] or CAP_COLORS.party, base)
	local marker = PropKit.part({ size = Vector3.one, cf = CFrame.new(cap.top + Vector3.new(0, 1, 0)), color = base, parent = m, transparency = 1, collide = false, name = "PadInfo" .. i })
	marker.CanQuery = false
	local title = if kind == "solo" then "SOLO" elseif kind == "continue" then "CONTINUE" else "PARTY"
	local sign = Kit.stickSign(m, at * CFrame.new(0, 0, PAD_R + 3), 15, title, base)
	local top = statusTag(m, (at * CFrame.new(0, 18.5, PAD_R + 3)).Position)
	local maxN = if kind == "party" then Config.PARTY_MAX else 1
	local state = ""
	local def = {
		kind = kind,
		pos = cap.top,
		radius = PAD_R - 0.4,
		label = top,
		title = title,
		show = function(newState: string, n: number, left: number?, who: string?, limit: number?)
			local capN = limit or maxN
			if newState == "open" then
				top.Text = if kind == "continue" then "Your saved run" elseif kind == "solo" then "Play alone" else ("%d/%d"):format(n, capN)
			elseif newState == "creating" then
				top.Text = (who or "Someone") .. " is setting up"
			elseif newState == "starting" then
				top.Text = if kind == "party" then ("%d/%d  -  %d"):format(n, capN, left or 0) else ("Starting in %d"):format(left or 0)
			else
				top.Text = "Teleporting..."
			end
			local pill = LobbyPads.pillFor(kind, newState, n, capN, left)
			if pill ~= sign.pill.Text or newState ~= state then
				state = newState
				local c = if newState == "open" then base else BUSY
				cap.setColor(c)
				sign.pillBox.BackgroundColor3 = c
				sign.pill.Text = pill
			end
		end,
	}
	def.show("open", 0, nil)
	return def
end

local function pads(world: Instance): { any }
	local m = folder("PartyBooths", world)
	local defs = {}
	for i, p in PADS do
		table.insert(defs, padDef(m, i, p.kind))
	end
	return defs
end

-------------------------------------------------------------------------------------------------------------
-- stations
-------------------------------------------------------------------------------------------------------------
-- A fallen leaf lying flat (a doormat, or a walk-on bay): an elongated diamond of stepped blocks and a midrib.
local function leaf(parent: Instance, cf: CFrame, len: number, color: Color3): Model
	local m = Instance.new("Model")
	m.Name = "Leaf"
	local rows = 9
	for i = 0, rows - 1 do
		local t = (i + 0.5) / rows
		local w = len * 0.55 * math.sin(t * math.pi) ^ 0.8
		block(m, Vector3.new(w, 0.3, len / rows + 0.05), cf * CFrame.new(0, 0.15, -len / 2 + t * len), if i % 2 == 0 then color else color:Lerp(Color3.new(0, 0, 0), 0.08), { smooth = true, collide = false })
	end
	block(m, Vector3.new(0.5, 0.36, len * 0.92), cf * CFrame.new(0, 0.18, 0), color:Lerp(Color3.new(1, 1, 0.6), 0.35), { smooth = true, collide = false })
	m.Parent = parent
	return m
end

local function promptAt(parent: Instance, cf: CFrame, name: string): BasePart
	local p = PropKit.part({ size = Vector3.new(2, 2, 2), cf = cf, color = Color3.new(1, 1, 1), parent = parent, transparency = 1, collide = false, name = name })
	p.CanQuery = false
	return p
end

-- The classes shop: a giant terracotta flower pot lying on its side, its mouth to the east, soil spilling out with
-- a seedling, CLASSES painted on its side, a mannequin by its mouth.
local function classes(world: Instance): (TextLabel, Model?)
	local m = folder("Classes", world)
	local mouth = POT.mouth
	local base = CFrame.new(mouth - Vector3.new(POT.len, 0, 0)) * CFrame.Angles(0, 0, -math.rad(90)) -- its Y runs east
	Kit.tube(m, base, 11, 14, POT.len, 2.4, 3, 1, function(i: number)
		return if i % 3 == 0 then K.terracottaDark else K.terracotta
	end)
	Kit.ring(m, base * CFrame.new(0, -0.6, 0), 11, 0, 1.4, 1, K.terracottaDark) -- its bottom
	Kit.ring(m, base * CFrame.new(0, POT.len + 1.2, 0), 15.6, 12.4, 3, 1, K.terracottaLight) -- the rim
	-- a soil floor inside, and a spill out of the mouth with a seedling on it
	block(m, Vector3.new(POT.len, 2, 14), CFrame.new(mouth.X - POT.len / 2, 1, mouth.Z), K.soil, { name = "PotFloor" })
	for i, s in { { 14, 2.2 }, { 10, 1.4 }, { 7, 0.7 } } do
		block(m, Vector3.new(s[1], s[2], 14 - i * 2), CFrame.new(mouth.X + 2 + i * 2.5, s[2] / 2, mouth.Z), if i == 1 then K.soil else K.soilDark)
	end
	local sprout = Vector3.new(mouth.X + 6, 2.2, mouth.Z + 3)
	block(m, Vector3.new(0.9, 5, 0.9), CFrame.new(sprout + Vector3.new(0, 2.5, 0)), K.blade[2], { collide = false })
	for _, sx in { -1, 1 } do
		block(m, Vector3.new(4, 0.5, 2.4), CFrame.new(sprout + Vector3.new(sx * 2, 5.2, 0)) * CFrame.Angles(0, 0, sx * 0.35), K.blade[3], { collide = false })
	end
	-- CLASSES on its side, facing the spawn
	local sideAt = CFrame.lookAt(Vector3.new(mouth.X - 14, 15, mouth.Z - 14.2), Vector3.new(mouth.X - 14, 15, mouth.Z - 40))
	local sign = block(m, Vector3.new(20, 5, 0.1), sideAt, Color3.new(1, 1, 1), { smooth = true, collide = false, name = "PotSign" })
	sign.Transparency = 1
	PropKit.surfaceText(sign, "CLASSES", C(255, 236, 200))
	-- the doormat leaf, the prompts
	leaf(m, CFrame.new(mouth.X + 9, 0.6, mouth.Z) * CFrame.Angles(0, math.rad(90), 0), 12, C(150, 92, 200))
	PropKit.prompt(promptAt(m, CFrame.new(mouth + Vector3.new(4, -8, 0)), "ClassPorch"), "Browse", "Classes", "Classes", 12)
	PropKit.prompt(promptAt(m, CFrame.new(mouth + Vector3.new(-10, -8, 0)), "ClassCounter"), "Browse", "Classes", "Classes", 12)
	LobbyKit.tag(LobbyKit.spot(m, CFrame.new(mouth + Vector3.new(-6, -7, 0)), Vector3.new(16, 4, 10), "ClassesFX"), "LobbyFX", { Kind = "sparkle", Color = C(200, 160, 255) })
	-- the mannequin by the mouth, turned to the spawn
	local dummy = require(script.Parent.AuraMannequin).build(m, facing(Vector3.new(mouth.X + 8, PATIO.top, mouth.Z + 15), SPAWN))
	local hidden = Instance.new("TextLabel") -- (server/Lobby writes the stock here; the Classes window shows it)
	hidden.Name = "StockText"
	return hidden, dummy
end

-- The garage: a giant watering can with a roll door cut into its front (east), its spout up to the north, and the
-- mower on a turntable in front.
local function garage(world: Instance)
	local m = folder("Garage", world)
	local c = CFrame.new(CAN)
	local DOOR_W, DOOR_H = 6.5, 13
	Kit.tube(m, c, 13, 12, 22, 2, 2.75, 1, function(i: number)
		return if i == 4 then K.canDark else K.canGreen
	end, nil, function(_x0: number, x1: number, z: number, y: number): boolean
		return y < DOOR_H and math.abs(z) < DOOR_W and x1 > 0
	end)
	Kit.ring(m, c * CFrame.new(0, 22.5, 0), 12.4, 0, 1, 1, K.canDark) -- the top
	Kit.ring(m, c * CFrame.new(0, 23.4, 3), 4, 2.6, 1, 1, K.steel, { smooth = true }) -- the filling hole
	-- the handle over the top
	local p = CAN
	Kit.bar(m, p + Vector3.new(-10, 21, 0), p + Vector3.new(-7, 32, 0), 2.6, K.canDark)
	Kit.bar(m, p + Vector3.new(-7, 32, 0), p + Vector3.new(3, 32, 0), 2.6, K.canDark)
	Kit.bar(m, p + Vector3.new(3, 32, 0), p + Vector3.new(6, 23, 0), 2.6, K.canDark)
	-- the spout and its rose
	local s0, s1 = p + Vector3.new(0, 6, 11), p + Vector3.new(0, 27, 32)
	Kit.bar(m, s0, s1, 3.2, K.canGreen)
	local rose = CFrame.lookAt(s1, s1 + (s1 - s0).Unit) * CFrame.Angles(math.rad(90), 0, 0)
	Kit.ring(m, rose, 4.6, 0, 1.6, 1, K.steel, { smooth = true })
	for _, q in { { 0, 0 }, { 1.8, 0 }, { -1.8, 0 }, { 0, 1.8 }, { 0, -1.8 } } do
		block(m, Vector3.new(0.6, 0.4, 0.6), rose * CFrame.new(q[1], 0.9, q[2]), K.steelDark, { smooth = true, collide = false })
	end
	-- the door: a light frame, a striped roll door half up, GARAGE over it
	local front = CFrame.lookAt(p + Vector3.new(12.6, 0, 0), p + Vector3.new(40, 0, 0))
	for _, x in { -DOOR_W - 0.6, DOOR_W + 0.6 } do
		block(m, Vector3.new(1.2, DOOR_H, 1.2), front * CFrame.new(x, DOOR_H / 2, 0), K.steel, { smooth = true })
	end
	block(m, Vector3.new(DOOR_W * 2 + 2.4, 1.2, 1.2), front * CFrame.new(0, DOOR_H + 0.6, 0), K.steel, { smooth = true })
	for i = 0, 3 do
		block(m, Vector3.new(DOOR_W * 2, 1, 0.4), front * CFrame.new(0, DOOR_H - 0.5 - i, -0.2), if i % 2 == 0 then C(90, 110, 140) else C(120, 140, 170), { smooth = true, collide = false })
	end
	local plate = block(m, Vector3.new(12, 2.6, 0.2), front * CFrame.new(0, DOOR_H + 3, -0.4), Color3.new(1, 1, 1), { smooth = true, collide = false, name = "GarageSign" })
	plate.Transparency = 1
	PropKit.surfaceText(plate, "GARAGE", PropKit.TITLE)
	-- the turntable with the mower on it
	local spot = CFrame.lookAt(p + Vector3.new(22, PATIO.top, 0), p + Vector3.new(40, PATIO.top, -10))
	Kit.ring(m, spot * CFrame.new(0, 0.3, 0), 6, 0, 0.6, 1, K.steelDark, { smooth = true })
	local floor = PropKit.cylinder(m, 5, 0.6, spot * CFrame.new(0, 0.3, 0), Color3.new(1, 1, 1))
	floor.Transparency = 1
	floor.CanCollide = false
	floor.Name = "Turntable"
	Models.place("mower_tractor", m, spot * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, math.rad(200), 0), 1, true)
	PropKit.prompt(floor, "Open", "Garage", "Garage", 14)
	PropKit.prompt(promptAt(m, front * CFrame.new(0, 3, -1), "GarageDoor"), "Open", "Garage", "Garage", 12)
end

-- The free rewards: a giant seed packet stuck in the soil, its two bays fallen leaves (the left one, DAILY, gives
-- the daily reward when you step on it; the right one opens the Rewards window).
local function rewards(world: Instance)
	local m = folder("FreeRewards", world)
	local flat = facing(PACKET, Vector3.new(4, 0, -78))
	local at = flat * CFrame.Angles(math.rad(-6), 0, 0) -- (leaning back a little, as if pushed in by hand)
	block(m, Vector3.new(16, 22, 1.6), at * CFrame.new(0, 8, 0), K.paper, { name = "Packet", smooth = true })
	for i = 0, 7 do
		block(m, Vector3.new(1.6, 1, 1.6), at * CFrame.new(-7 + i * 2, 19.5, 0) * CFrame.Angles(0, 0, math.rad(45)), K.paper, { smooth = true, collide = false })
	end
	block(m, Vector3.new(20, 2, 6), flat * CFrame.new(0, 0.6, 0), K.soil, { name = "Mound" })
	-- the print on its front: a sky, a big flower, the title and what's free
	local face = block(m, Vector3.new(15, 20, 0.1), at * CFrame.new(0, 8.5, -0.86), Color3.new(1, 1, 1), { smooth = true, collide = false, name = "PacketFace" })
	face.Transparency = 1
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0.6
	gui.Parent = face
	local sky = Instance.new("Frame")
	sky.Size = UDim2.fromScale(1, 0.62)
	sky.BorderSizePixel = 0
	sky.BackgroundColor3 = C(120, 200, 255)
	sky.Parent = gui
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(C(110, 190, 255), C(220, 245, 255))
	g.Rotation = 90
	g.Parent = sky
	local function dot(par: Instance, size: number, x: number, y: number, col: Color3)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = UDim2.fromScale(size, size * 0.75)
		f.Position = UDim2.fromScale(x, y)
		f.BackgroundColor3 = col
		f.BorderSizePixel = 0
		local cr = Instance.new("UICorner")
		cr.CornerRadius = UDim.new(0.5, 0)
		cr.Parent = f
		f.Parent = par
	end
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		dot(sky, 0.2, 0.5 + math.cos(a) * 0.15, 0.55 + math.sin(a) * 0.2, C(255, 120, 170))
	end
	dot(sky, 0.18, 0.5, 0.55, C(255, 210, 60))
	local function text(s: string, h: number, y: number, col: Color3)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(0.92, h)
		l.Position = UDim2.fromScale(0.04, y)
		l.Font = Config.UI.font
		l.TextScaled = true
		l.Text = s
		l.TextColor3 = col
		local st = Instance.new("UIStroke")
		st.Thickness = 3
		st.Color = C(58, 34, 18)
		st.Parent = l
		l.Parent = gui
	end
	text("FREE REWARDS", 0.13, 0.03, PropKit.TITLE)
	text(("DAILY: up to +%d gems"):format(Config.DAILY_STREAK[#Config.DAILY_STREAK]), 0.09, 0.66, C(40, 120, 60))
	text(("GROUP: +%d gems"):format(Config.GROUP_GEMS), 0.09, 0.77, C(40, 120, 60))
	text("step on a leaf", 0.08, 0.88, C(120, 90, 60))
	-- the two leaf bays in front
	for i, x in { 4.5, -4.5 } do
		local bay = leaf(m, flat * CFrame.new(x, PATIO.top, -8), 9, if i == 1 then C(90, 190, 90) else C(70, 160, 200))
		bay.Name = "PadFrame"
		LobbyKit.tag(bay, "LobbyPadZone", { Window = "Rewards", Color = CYAN, Claim = if i == 1 then "daily" else nil })
	end
	PropKit.prompt(promptAt(m, flat * CFrame.new(0, 3, -6), "RewardsPrompt"), "Open", "Free Rewards", "Rewards", 14)
	LobbyKit.tag(LobbyKit.spot(m, flat * CFrame.new(0, 6, -2), Vector3.new(14, 4, 3), "RewardsFX"), "LobbyFX", { Kind = "sparkle", Color = CYAN })
end

-- A leaderboard on a giant plant label, facing the spawn: its title and rows on the label's face.
local function board(world: Instance, name: string, pos: Vector3, title: string, key: string, cycle: string?): TextLabel
	local m = folder(name, world)
	local W, H = 16, 18
	local at = Kit.plantLabel(m, facing(pos, SPAWN), W, H)
	local head = PropKit.facePanel(m, at, Vector3.new(0, H - 2, -0.55), Vector2.new(W - 1.6, 2.6), title, PropKit.TITLE)
	local body = PropKit.facePanel(m, at, Vector3.new(0, (H - 3.6) / 2, -0.55), Vector2.new(W - 1.6, H - 4.6), "", C(70, 50, 30))
	LobbyKit.boardFace(body, key)
	if cycle then
		local part = (body.Parent :: Instance).Parent :: Instance
		part:SetAttribute("Cycle", cycle)
		local ref = Instance.new("ObjectValue")
		ref.Name = "TitleLabel"
		ref.Value = head
		ref.Parent = part
	end
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	return body
end

-------------------------------------------------------------------------------------------------------------
-- dressing
-------------------------------------------------------------------------------------------------------------
local function sprinkler(parent: Instance, pos: Vector3)
	local m = Instance.new("Model")
	m.Name = "Sprinkler"
	block(m, Vector3.new(5, 1.6, 5), CFrame.new(pos + Vector3.new(0, 0.8, 0)), K.steelDark, { smooth = true })
	block(m, Vector3.new(1.2, 4, 1.2), CFrame.new(pos + Vector3.new(0, 3.4, 0)), K.steel, { smooth = true })
	local head = block(m, Vector3.new(6, 1, 1.2), CFrame.new(pos + Vector3.new(0, 5.8, 0)), C(250, 200, 40), { smooth = true, name = "SprinklerHead" })
	for _, sx in { -1, 1 } do
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(C(200, 240, 255), C(120, 200, 255))
		e.LightEmission = 0.5
		e.Size = NumberSequence.new(0.5, 0.2)
		e.Transparency = NumberSequence.new(0.2, 1)
		e.Lifetime = NumberRange.new(1.4, 1.8)
		e.Speed = NumberRange.new(16, 20)
		e.SpreadAngle = Vector2.new(8, 8)
		e.Acceleration = Vector3.new(0, -18, 0)
		e.Rate = 40
		e.EmissionDirection = Enum.NormalId.Top
		local a = Instance.new("Attachment")
		a.Position = Vector3.new(sx * 3, 0.5, 0)
		a.Orientation = Vector3.new(0, 0, sx * -40)
		a.Parent = head
		e.Parent = a
	end
	m.Parent = parent
end

local function dressing(world: Instance)
	local f = folder("Dressing", world)
	local rng = Random.new(11)
	Kit.daisy(f, Vector3.new(74, 0, 30), 46, SPAWN)
	Kit.daisy(f, Vector3.new(-76, 0, 34), 52, SPAWN)
	Kit.daisy(f, Vector3.new(76, 0, -104), 40, SPAWN)
	Kit.daisy(f, Vector3.new(-74, 0, -106), 44, SPAWN)
	Kit.tulip(f, Vector3.new(72, 0, -44), 34, C(232, 60, 70))
	Kit.tulip(f, Vector3.new(54, 0, 44), 40, C(250, 200, 50))
	Kit.tulip(f, Vector3.new(-56, 0, 42), 36, C(240, 120, 190))
	Kit.tulip(f, Vector3.new(-74, 0, -84), 30, C(250, 140, 50))
	-- pebbles along the patio's edges (never on it)
	for _, p in { { 64, -70 }, { 66, -20 }, { 64, 14 }, { -64, -92 }, { -30, 24 }, { 34, 25 }, { 12, -105 }, { -40, -104 } } do
		Kit.pebble(f, Vector3.new(p[1], 0, p[2]), rng:NextNumber(4, 7), rng)
	end
	Kit.ball(f, Vector3.new(-82, 7, 66), 10, C(220, 50, 50), C(50, 110, 220))
	-- a garden hose from the watering can, out across the patio's edge, coiled
	local pts = { CAN + Vector3.new(9, 0, -10), Vector3.new(-32, PATIO.top, -26) }
	for i = 0, 10 do
		local a = i / 10 * math.pi * 1.8 + math.pi
		table.insert(pts, Vector3.new(-26 + math.cos(a) * 5, PATIO.top, -30 + math.sin(a) * 5))
	end
	Kit.hose(f, pts, 1.6)
	sprinkler(f, Vector3.new(58, 0, -6))
	-- pollen drifting over the patio
	LobbyKit.tag(LobbyKit.spot(f, CFrame.new(0, 10, -40), Vector3.new(110, 12, 110), "Motes"), "LobbyFX", { Kind = "motes" })
end

local function bounds(world: Instance)
	local f = folder("Bounds", world)
	local x0, x1, z0, z1 = -86, 86, -114, 104
	for _, b in {
		{ Vector3.new(x1 - x0, 80, 2), Vector3.new(0, 40, z0) },
		{ Vector3.new(x1 - x0, 80, 2), Vector3.new(0, 40, z1) },
		{ Vector3.new(2, 80, z1 - z0), Vector3.new(x0, 40, (z0 + z1) / 2) },
		{ Vector3.new(2, 80, z1 - z0), Vector3.new(x1, 40, (z0 + z1) / 2) },
	} do
		local p = block(f, b[1], CFrame.new(b[2]), Color3.new(1, 1, 1), { name = "Bound" })
		p.Transparency = 1
		p.CastShadow = false
		p.CanQuery = false
	end
end

function YardBuilder.build()
	local world = Environment.apply()
	workspace.Terrain:Clear()
	require(script.Parent.WorldGen).lighting()
	ground(world)
	fence(world)
	mower(world)
	local padDefs = pads(world)
	local stockLabel, dummy = classes(world)
	garage(world)
	rewards(world)
	local leaderLabel = board(world, "Leaderboard", GRASS_CUT, "GRASS CUT", "cut")
	local bestLabel = board(world, "BestTimes", BEST_TIMES, "BEST TIMES", "best", "best:BEST TIMES,bosses:BOSS SLAYERS")
	blades(world)
	dressing(world)
	lawn(world)
	bounds(world)
	local sp = SPAWN + Vector3.new(0, PATIO.top + 0.5, 0)
	Environment.spawn(world, CFrame.lookAt(sp, sp + Vector3.zAxis)) -- looking north at the mower
	return { world = world, stockLabel = stockLabel, leaderLabel = leaderLabel, bestLabel = bestLabel, pads = padDefs, mannequin = dummy }
end

return YardBuilder
