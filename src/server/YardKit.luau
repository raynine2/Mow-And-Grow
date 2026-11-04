--!strict
-- THE GIANT BACKYARD'S PIECES (4 Nov lobby remake; owner picked "Reuzetuin": you're tiny in a giant back garden).
-- Everything is voxel blocks on one grid per model, studded tops, three tones per material (LihFolk vault: Voxel Art
-- - Studs Outlines and Style Kits; no smooth spheres or cylinders: circles are rows of blocks). server/YardBuilder
-- puts them together into the lobby.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.MowALawn.Config)

local YardKit = {}

local C = Color3.fromRGB
YardKit.C = {
	soil = C(96, 64, 40),
	soilDark = C(70, 46, 30),
	lawn = C(98, 170, 64),
	slab = { C(222, 176, 112), C(210, 164, 102), C(230, 186, 124) },
	slabTop = C(236, 198, 140),
	moss = C(84, 128, 52),
	blade = { C(46, 120, 44), C(70, 152, 54), C(104, 184, 70), C(146, 208, 92) },
	red = C(214, 52, 44),
	redDark = C(160, 36, 32),
	black = C(40, 40, 46),
	steel = C(176, 180, 188),
	steelDark = C(120, 124, 132),
	terracotta = C(196, 98, 58),
	terracottaDark = C(160, 76, 44),
	terracottaLight = C(214, 120, 76),
	canGreen = C(62, 150, 92),
	canDark = C(42, 112, 68),
	wood = C(226, 190, 130),
	woodDark = C(176, 136, 84),
	paper = C(250, 244, 226),
	gold = C(255, 196, 46),
}

local count = 0
local function tick()
	count += 1
	if count % 400 == 0 then
		task.wait()
	end
end

export type Opts = { smooth: boolean?, material: Enum.Material?, collide: boolean?, name: string?, shadow: boolean? }

-- One block: anchored, studded top (the toy-voxel look) unless `smooth`.
function YardKit.block(parent: Instance, size: Vector3, cf: CFrame, color: Color3, o: Opts?): Part
	local p = Instance.new("Part")
	p.Name = o and o.name or "Block"
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	local smooth = o ~= nil and o.smooth == true
	p.Material = o and o.material or (if smooth then Enum.Material.SmoothPlastic else Enum.Material.Plastic)
	p.TopSurface = if smooth then Enum.SurfaceType.Smooth else Enum.SurfaceType.Studs
	p.BottomSurface = Enum.SurfaceType.Smooth
	if o and o.collide == false then
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	end
	if o and o.shadow == false then
		p.CastShadow = false
	end
	p.Parent = parent
	tick()
	return p
end
local block = YardKit.block

-- The rows of a voxel ring on a `g` grid (outer radius ro, inner ri; ri 0 = a solid disc), centred on 0:
-- each row { z, x0, x1 } (a run of blocks along X at height-row z).
function YardKit.ringRows(ro: number, ri: number, g: number): { { number } }
	local rows = {}
	local n = math.ceil(ro / g)
	for j = -n, n - 1 do
		local zc = (j + 0.5) * g
		if math.abs(zc) < ro then
			local hw = math.floor(math.sqrt(ro * ro - zc * zc) / g + 0.5) * g
			if hw > 0 then
				if ri > 0 and math.abs(zc) < ri then
					local hi = math.floor(math.sqrt(ri * ri - zc * zc) / g + 0.5) * g
					if hi < hw then
						table.insert(rows, { zc, -hw, -hi })
						table.insert(rows, { zc, hi, hw })
					end
				else
					table.insert(rows, { zc, -hw, hw })
				end
			end
		end
	end
	return rows
end

-- A voxel ring `h` thick lying in `cf`'s XZ plane (its middle at cf). `skip(x0, x1, z)` can leave a row out (a door).
function YardKit.ring(parent: Instance, cf: CFrame, ro: number, ri: number, h: number, g: number, color: Color3, o: Opts?, skip: ((number, number, number) -> boolean)?): { Part }
	local made = {}
	for _, r in YardKit.ringRows(ro, ri, g) do
		if not (skip and skip(r[2], r[3], r[1])) then
			table.insert(made, block(parent, Vector3.new(r[3] - r[2], h, g), cf * CFrame.new((r[2] + r[3]) / 2, 0, r[1]), color, o))
		end
	end
	return made
end

-- A tube along cf's Y: rings from radius r0 (at cf) to r1 (len further), walls `wall` thick (0 = solid), in layers
-- `step` high. `colorAt(i, n)` picks each layer's colour (bands).
function YardKit.tube(parent: Instance, cf: CFrame, r0: number, r1: number, len: number, wall: number, step: number, g: number, colorAt: (number, number) -> Color3, o: Opts?, skip: ((number, number, number, number) -> boolean)?)
	local n = math.max(1, math.floor(len / step + 0.5))
	local h = len / n
	for i = 1, n do
		local r = r0 + (r1 - r0) * (i - 0.5) / n
		local y = (i - 0.5) * h
		local layerSkip = if skip then function(x0: number, x1: number, z: number): boolean
			return skip(x0, x1, z, y)
		end else nil
		YardKit.ring(parent, cf * CFrame.new(0, y, 0), r, if wall > 0 then r - wall else 0, h, g, colorAt(i, n), o, layerSkip)
	end
end

-- A bar of blocks from a to b (square section `w`).
function YardKit.bar(parent: Instance, a: Vector3, b: Vector3, w: number, color: Color3, o: Opts?): Part
	local len = (b - a).Magnitude
	return block(parent, Vector3.new(w, w, len), CFrame.lookAt((a + b) / 2, b), color, o)
end

-------------------------------------------------------------------------------------------------------------
-- plants
-------------------------------------------------------------------------------------------------------------
-- A giant grass blade: segments stacked from `foot`, narrowing to a point and bending more toward the tip, dark at
-- the root and light at the tip. `yaw` turns it, `lean` (radians per segment, growing) bends it.
function YardKit.blade(parent: Instance, foot: Vector3, height: number, width: number, yaw: number, lean: number)
	local segs = 6
	local segH = height / segs
	local at = CFrame.new(foot) * CFrame.Angles(0, yaw, 0)
	local tones = YardKit.C.blade
	for i = 1, segs do
		local t = (i - 1) / segs
		local w = width * (1 - t * 0.78)
		at = at * CFrame.Angles(-lean * i / segs, 0, 0)
		local tone = tones[math.clamp(math.floor(t * #tones) + 1, 1, #tones)]
		block(parent, Vector3.new(w, segH + 0.4, math.max(0.8, w * 0.3)), at * CFrame.new(0, segH / 2, 0), tone, { collide = false })
		at = at * CFrame.new(0, segH, 0)
	end
end

-- A giant daisy: a bent stem, two leaves, and a head of white petals round a yellow middle, turned toward `toward`.
function YardKit.daisy(parent: Instance, foot: Vector3, height: number, toward: Vector3)
	local m = Instance.new("Model")
	m.Name = "Daisy"
	local stem = YardKit.C.blade[2]
	local yaw = math.atan2(-(toward.X - foot.X), -(toward.Z - foot.Z))
	local at = CFrame.new(foot) * CFrame.Angles(0, yaw, 0)
	local seg = height / 5
	for i = 1, 5 do
		at = at * CFrame.Angles(-0.05, 0, 0)
		block(m, Vector3.new(2.2, seg + 0.4, 2.2), at * CFrame.new(0, seg / 2, 0), stem, { collide = false })
		if i == 2 then
			for _, sx in { -1, 1 } do
				block(m, Vector3.new(9, 0.8, 3.2), at * CFrame.new(sx * 4.5, seg * 0.5, 0) * CFrame.Angles(0, 0, sx * 0.4), YardKit.C.blade[3], { collide = false })
			end
		end
		at = at * CFrame.new(0, seg, 0)
	end
	-- the head faces forward and up
	local head = at * CFrame.Angles(math.rad(-65), 0, 0)
	YardKit.ring(m, head, 4, 0, 2.2, 1, C(250, 200, 40), { collide = false })
	YardKit.ring(m, head * CFrame.new(0, 0.6, 0), 2.6, 0, 1.4, 1, C(240, 160, 30), { collide = false })
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local tone = if i % 2 == 0 then C(255, 255, 255) else C(236, 238, 246)
		block(m, Vector3.new(2.8, 0.9, 8), head * CFrame.Angles(0, a, 0) * CFrame.new(0, -0.2, -8), tone, { collide = false })
	end
	m.Parent = parent
	return m
end

-- A giant tulip: a straight stem, two long leaves, a cup of petals.
function YardKit.tulip(parent: Instance, foot: Vector3, height: number, color: Color3)
	local m = Instance.new("Model")
	m.Name = "Tulip"
	local stem = YardKit.C.blade[2]
	block(m, Vector3.new(2, height, 2), CFrame.new(foot + Vector3.new(0, height / 2, 0)), stem, { collide = false })
	for i, a in { 0.5, 3.6 } do
		local at = CFrame.new(foot) * CFrame.Angles(0, a, 0) * CFrame.Angles(0, 0, if i == 1 then 0.35 else -0.35)
		block(m, Vector3.new(3.4, height * 0.45, 1), at * CFrame.new(0, height * 0.22, 0), YardKit.C.blade[3], { collide = false })
	end
	local top = CFrame.new(foot + Vector3.new(0, height, 0))
	local dark = Color3.new(color.R * 0.78, color.G * 0.78, color.B * 0.78)
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		block(m, Vector3.new(4.6, 9, 1.2), top * CFrame.Angles(0, a, 0) * CFrame.new(0, 3.4, -2.6) * CFrame.Angles(0.18, 0, 0), if i % 2 == 0 then color else dark, { collide = false })
	end
	block(m, Vector3.new(5, 2, 5), top * CFrame.new(0, 0.2, 0), dark, { collide = false })
	m.Parent = parent
	return m
end

-- A pebble: a few stacked, shrinking blocks in three greys.
function YardKit.pebble(parent: Instance, foot: Vector3, size: number, rng: Random)
	local greys = { C(150, 148, 142), C(128, 126, 122), C(172, 170, 162) }
	local at = CFrame.new(foot) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	local w, d = size, size * rng:NextNumber(0.6, 0.9)
	local y = 0
	for i = 1, 3 do
		local h = size * 0.28
		block(parent, Vector3.new(w, h, d), at * CFrame.new(rng:NextNumber(-0.3, 0.3), y + h / 2 - size * 0.08, 0), greys[i], { name = "Pebble" })
		y += h
		w *= 0.72
		d *= 0.72
	end
end

-------------------------------------------------------------------------------------------------------------
-- station pieces
-------------------------------------------------------------------------------------------------------------
export type Cap = { setColor: (Color3) -> (), top: Vector3 }

-- A giant bottle cap lying on the ground as a party pad: a metal crimped rim round a painted top whose inlay takes
-- the pad's state colour. `cf` at the ground, the cap `r` studs across its half.
function YardKit.cap(parent: Instance, cf: CFrame, r: number, rim: Color3, inlay: Color3): Cap
	local m = Instance.new("Model")
	m.Name = "BottleCap"
	local h = 1.3
	YardKit.ring(m, cf * CFrame.new(0, h / 2, 0), r, 0, h, 1, rim)
	-- the crimps round the edge
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		block(m, Vector3.new(1.6, h + 0.3, 1.2), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, (h + 0.3) / 2, -(r + 0.3)), Color3.new(rim.R * 0.85, rim.G * 0.85, rim.B * 0.85), { collide = false })
	end
	local parts = YardKit.ring(m, cf * CFrame.new(0, h + 0.06, 0), r - 1.6, 0, 0.12, 1, inlay, { smooth = true, collide = false })
	m.Parent = parent
	return {
		setColor = function(c: Color3)
			for _, p in parts do
				p.Color = c
			end
		end,
		top = (cf * CFrame.new(0, h, 0)).Position,
	}
end

export type StickSign = { title: TextLabel, pill: TextLabel, pillBox: Frame }

-- A giant popsicle stick stuck in a mound of soil behind a pad, a paper card pinned to it with the pad's word and
-- its state pill. `at`: the stick's foot, its front facing at.LookVector.
function YardKit.stickSign(parent: Instance, at: CFrame, height: number, title: string, pillColor: Color3): StickSign
	local m = Instance.new("Model")
	m.Name = "StickSign"
	local W = YardKit.C.wood
	block(m, Vector3.new(2.6, height, 0.7), at * CFrame.new(0, height / 2 - 1, 0), W, { name = "Stick" })
	block(m, Vector3.new(1.8, 0.7, 0.7), at * CFrame.new(0, height - 0.65, 0), W, { name = "StickTip" })
	YardKit.ring(m, at * CFrame.new(0, 0.4, 0), 2.6, 0, 0.8, 1, YardKit.C.soil)
	-- the card
	local card = block(m, Vector3.new(8.4, 5.6, 0.3), at * CFrame.new(0, height - 3.8, -0.55), YardKit.C.paper, { smooth = true, name = "Card", collide = false })
	block(m, Vector3.new(0.6, 0.6, 0.3), at * CFrame.new(0, height - 1.4, -0.8), YardKit.C.red, { smooth = true, collide = false })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.6
	gui.Parent = card
	local function label(text: string, size: UDim2, pos: UDim2, color: Color3, stroke: number, par: Instance): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = size
		l.Position = pos
		l.Font = Config.UI.font
		l.TextScaled = true
		l.Text = text
		l.TextColor3 = color
		local s = Instance.new("UIStroke")
		s.Thickness = stroke
		s.Color = C(58, 34, 18)
		s.Parent = l
		l.Parent = par
		return l
	end
	local t = label(title, UDim2.fromScale(0.9, 0.46), UDim2.fromScale(0.05, 0.08), YardKit.C.gold, 4, gui)
	local box = Instance.new("Frame")
	box.BorderSizePixel = 0
	box.Size = UDim2.fromScale(0.66, 0.3)
	box.Position = UDim2.fromScale(0.17, 0.6)
	box.BackgroundColor3 = pillColor
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = box
	local bs = Instance.new("UIStroke")
	bs.Thickness = 2
	bs.Color = C(30, 60, 40)
	bs.Parent = box
	box.Parent = gui
	local pill = label("OPEN", UDim2.fromScale(0.9, 0.8), UDim2.fromScale(0.05, 0.1), Color3.new(1, 1, 1), 1.5, box)
	m.Parent = parent
	return { title = t, pill = pill, pillBox = box }
end

-- A giant white plant label (the stake you push into a pot) stuck in the soil, front facing at.LookVector, with a
-- face for a board. Returns the face part (for PropKit.facePanel at its local origin) and its frame.
function YardKit.plantLabel(parent: Instance, at: CFrame, w: number, h: number): CFrame
	local m = Instance.new("Model")
	m.Name = "PlantLabel"
	local white, shade = C(244, 244, 236), C(214, 216, 208)
	local y0 = 5
	block(m, Vector3.new(w, h, 1), at * CFrame.new(0, y0 + h / 2, 0), white, { name = "Label" })
	-- rounded top: two shorter steps
	block(m, Vector3.new(w - 2, 1, 1), at * CFrame.new(0, y0 + h + 0.5, 0), white)
	block(m, Vector3.new(w - 5, 1, 1), at * CFrame.new(0, y0 + h + 1.5, 0), white)
	-- the point going into the ground
	for i, ww in { w * 0.7, w * 0.42, w * 0.18 } do
		block(m, Vector3.new(ww, 2, 1), at * CFrame.new(0, y0 - (i - 0.5) * 2 + 0.6, 0), shade)
	end
	YardKit.ring(m, at * CFrame.new(0, 0.5, 0), w * 0.42, 0, 1, 1, YardKit.C.soil)
	m.Parent = parent
	return at * CFrame.new(0, y0, 0)
end

-- A garden hose through `points` (on the ground), green with a darker stripe, non-solid.
function YardKit.hose(parent: Instance, points: { Vector3 }, w: number)
	local m = Instance.new("Model")
	m.Name = "Hose"
	for i = 1, #points - 1 do
		local a, b = points[i] + Vector3.new(0, w / 2, 0), points[i + 1] + Vector3.new(0, w / 2, 0)
		YardKit.bar(m, a, b, w, if i % 2 == 0 then C(64, 170, 74) else C(56, 152, 66), { collide = false })
		block(m, Vector3.new(w + 0.2, w + 0.2, w + 0.2), CFrame.new(b), C(44, 120, 52), { collide = false })
	end
	m.Parent = parent
	return m
end

-- A voxel ball (stacked rings), two colours in halves, sunk a little into the ground.
function YardKit.ball(parent: Instance, centre: Vector3, r: number, a: Color3, b: Color3)
	local m = Instance.new("Model")
	m.Name = "Ball"
	local g = 1.5
	local n = math.floor(r / g)
	for j = -n, n - 1 do
		local y = (j + 0.5) * g
		local rr = math.sqrt(math.max(0, r * r - y * y))
		if rr > 0.5 then
			YardKit.ring(m, CFrame.new(centre + Vector3.new(0, y, 0)), rr, 0, g, g, if math.abs(y) < g then C(250, 250, 250) elseif y > 0 then a else b)
		end
	end
	m.Parent = parent
	return m
end

return YardKit
