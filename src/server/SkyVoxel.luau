--!strict
-- The floating-island lobby's working pieces in the VOXEL look of its trees (7 Nov; owner, after the first island:
-- "i dont like the signs and builidngs and stuff man", then picked: the two boards, the floating text over the pads and
-- the houses, the windmill, the classes house / garage / rewards stall, all "voxel, like the trees").
--   * the buildings are the game's own voxel models (ServerStorage.VoxelModels, the trees' texture): the windmill with
--     turning sails, the purple mushroom hut for CLASSES, the log cabin for the GARAGE, the gift stall for REWARDS;
--   * every sign is a wooden board built of 1-stud blocks (planks in warm tones, log posts, a strip of grass on top),
--     its words painted on its face: no text floats in the air any more;
--   * the pads are round stepped daises of stone blocks with a ring of light, a board behind each (title, state, count).
-- server/SkyIsland places them; each returns what server/Lobby needs, the same as the old stations.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local PropKit = require(script.Parent.PropKit)
local Models = require(script.Parent.Models)
local VM = require(script.Parent.VoxelModels)
local LobbyKit = require(script.Parent.LobbyKit)
local LobbyPads = require(script.Parent.LobbyPads)

local SkyVoxel = {}

local C = Color3.fromRGB
local WOOD = { C(150, 98, 58), C(138, 88, 52), C(160, 106, 62), C(128, 82, 48) }
local DARK = { C(74, 50, 36), C(66, 44, 32), C(82, 56, 40), C(60, 40, 30) }
local LOG = { C(112, 74, 46), C(100, 66, 42), C(120, 80, 50) }
local GRASS = { C(92, 178, 54), C(80, 164, 48), C(106, 190, 62) }
local STONE = { C(176, 172, 164), C(160, 156, 150), C(188, 184, 176), C(150, 146, 140) }
local STONE_D = { C(120, 116, 112), C(108, 104, 100), C(130, 126, 120) }
local OPEN_C = C(80, 255, 95)
local BUSY_C = C(40, 210, 255)
local SAVE_C = C(255, 196, 46)

local count = 0
local rng = Random.new(77)

local function pick(list: { Color3 }): Color3
	return list[rng:NextInteger(1, #list)]
end

-- One voxel block (SmoothPlastic, the trees' flat look), anchored.
local function vox(parent: Instance, size: Vector3, cf: CFrame, color: Color3, solid: boolean?): Part
	local p = Instance.new("Part")
	p.Name = "Voxel"
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = solid == true
	p.CanQuery = solid == true
	p.CanTouch = false
	p.Parent = parent
	count += 1
	if count % 300 == 0 then
		task.wait()
	end
	return p
end

local function collider(parent: Instance, size: Vector3, cf: CFrame): Part
	local p = vox(parent, size, cf, Color3.new(1, 1, 1), true)
	p.Name = "Collider"
	p.Transparency = 1
	p.CastShadow = false
	return p
end

local function facing(pos: Vector3, toward: Vector3): CFrame
	return CFrame.lookAt(pos, Vector3.new(toward.X, pos.Y, toward.Z))
end

-- The yaw that turns a VoxelModels piece at `pos` to look at `toward` (its front is the CFrame's LookVector).
local function yawTo(pos: Vector3, toward: Vector3): number
	local d = Vector3.new(toward.X - pos.X, 0, toward.Z - pos.Z)
	return math.atan2(-d.X, -d.Z)
end

local function styled(label: TextLabel, color: Color3, stroke: number)
	label.BackgroundTransparency = 1
	label.Font = Config.UI.font
	label.TextScaled = true
	label.TextColor3 = color
	local s = Instance.new("UIStroke")
	s.Color = C(40, 24, 14)
	s.Thickness = stroke
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = label
end

-------------------------------------------------------------------------------------------------------------
-- the wooden sign
-------------------------------------------------------------------------------------------------------------
export type Sign = { face: Part, gui: SurfaceGui, top: number }

-- A wooden board `w` x `h` studs on two log posts, its foot at `at` (front = LookVector), its bottom `lift` over the
-- ground: planks of 1-stud blocks in a few tones (dark ones for a board with rows), a darker frame, a strip of grass
-- on top with a few blades. Returns its face (a thin invisible part just in front, with a SurfaceGui on it).
function SkyVoxel.sign(parent: Instance, at: CFrame, w: number, h: number, lift: number, dark: boolean?): Sign
	local m = Instance.new("Model")
	m.Name = "WoodSign"
	local planks = if dark then DARK else WOOD
	local T = 0.8 -- the board's thickness
	-- the planks: each row split into lengths of 2-4
	local rows = math.max(1, math.floor(h + 0.5))
	local rh = h / rows
	for r = 0, rows - 1 do
		local x = -w / 2
		while x < w / 2 - 0.01 do
			local len = math.min(rng:NextInteger(2, 4), w / 2 - x)
			vox(m, Vector3.new(len, rh, T), at * CFrame.new(x + len / 2, lift + rh * (r + 0.5), 0), pick(planks))
			x += len
		end
	end
	-- the frame round it
	local frame = if dark then C(48, 32, 24) else C(96, 62, 38)
	vox(m, Vector3.new(w + 1, 0.8, T + 0.3), at * CFrame.new(0, lift + h + 0.4, 0), frame)
	vox(m, Vector3.new(w + 1, 0.6, T + 0.3), at * CFrame.new(0, lift - 0.3, 0), frame)
	-- the posts: log blocks stacked from the ground to over the board
	for _, sx in { -1, 1 } do
		local x = sx * (w / 2 + 0.5)
		local top = lift + h + 1.4
		local y = 0
		while y < top - 0.01 do
			local bh = math.min(1, top - y)
			vox(m, Vector3.new(1, bh, 1), at * CFrame.new(x, y + bh / 2, 0), pick(LOG), true)
			y += bh
		end
	end
	-- a strip of grass on top, a few blades sticking up
	for x = -w / 2 - 0.5, w / 2 + 0.5 - 0.01, 1 do
		vox(m, Vector3.new(1, 0.5, T + 0.5), at * CFrame.new(x + 0.5, lift + h + 1.05, 0), pick(GRASS))
		if rng:NextNumber() < 0.35 then
			vox(m, Vector3.new(0.4, rng:NextNumber(0.6, 1.3), 0.4), at * CFrame.new(x + 0.5 + rng:NextNumber(-0.2, 0.2), lift + h + 1.6, rng:NextNumber(-0.2, 0.2)), pick(GRASS))
		end
	end
	collider(m, Vector3.new(w, h, T), at * CFrame.new(0, lift + h / 2, 0))
	-- the face for the words
	local face = vox(m, Vector3.new(w - 0.4, h - 0.3, 0.05), at * CFrame.new(0, lift + h / 2, -T / 2 - 0.04), Color3.new(1, 1, 1))
	face.Name = "SignText"
	face.Transparency = 1
	face.CastShadow = false
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.4
	gui.MaxDistance = 260
	gui.Parent = face
	m.Parent = parent
	return { face = face, gui = gui, top = lift + h + 1.4 }
end

-- A label on a sign's face: `y0`..`y1` of its height (0 top, 1 bottom).
function SkyVoxel.text(s: Sign, text: string, y0: number, y1: number, color: Color3?, stroke: number?): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(0.92, y1 - y0)
	l.Position = UDim2.fromScale(0.04, y0)
	l.Text = text
	styled(l, color or PropKit.TITLE, stroke or 3)
	l.Parent = s.gui
	return l
end

-------------------------------------------------------------------------------------------------------------
-- the pads
-------------------------------------------------------------------------------------------------------------
-- A round dais of blocks: a ring of dark stone, a step of light stone, its top 1.2 over the ground.
local function dais(m: Instance, cf: CFrame, r: number): number
	for gx = -r, r - 1 do
		for gz = -r, r - 1 do
			local cx, cz = gx + 0.5, gz + 0.5
			local d = math.sqrt(cx * cx + cz * cz)
			if d <= r then
				local outer = d > r - 1.3
				vox(m, Vector3.new(1, 0.6, 1), cf * CFrame.new(cx, 0.3, cz), pick(if outer then STONE_D else STONE))
				if not outer then
					vox(m, Vector3.new(1, 0.6, 1), cf * CFrame.new(cx, 0.9, cz), pick(STONE))
				end
			end
		end
	end
	return 1.2
end

local function glowRing(parent: Instance, cf: CFrame, r: number): { BasePart }
	local parts: { BasePart } = {}
	local n = 28
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		local p = vox(parent, Vector3.new(2 * math.pi * r / n + 0.15, 0.12, 0.5), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -r), OPEN_C)
		p.Material = Enum.Material.Neon
		p.CastShadow = false
		table.insert(parts, p)
	end
	return parts
end

-- One pad: the dais at `pos`, its board behind it (away from `toward`, the spawn) facing the spawn. Returns the
-- def server/Lobby drives (the same fields as server/LandsBuilder's pads).
function SkyVoxel.pad(parent: Instance, i: number, pos: Vector3, toward: Vector3, kind: string): any
	local m = Instance.new("Model")
	m.Name = "Pad" .. i
	m.Parent = parent
	local cf = facing(pos, toward)
	local top = dais(m, cf, 6)
	local step = collider(parent, Vector3.new(10, top, 10), cf * CFrame.new(0, top / 2, 0))
	step.Name = "PadStep"
	local base = if kind == "continue" then SAVE_C else OPEN_C
	local r = 4.7
	local ring = glowRing(m, cf * CFrame.new(0, top + 0.06, 0), r)
	for _, q in ring do
		q.Color = base
	end
	local marker = PropKit.part({ size = Vector3.one, cf = cf * CFrame.new(0, top + 1.6, 0), color = base, parent = parent, transparency = 1, collide = false, name = "PadInfo" .. i })
	marker.CanQuery = false
	local title = if kind == "solo" then "SOLO" elseif kind == "continue" then "CONTINUE" else "PARTY"
	-- the board behind the dais
	local sign = SkyVoxel.sign(m, cf * CFrame.new(0, 0, 7.2), 9, 4, 1.6)
	SkyVoxel.text(sign, title, 0.02, 0.44, PropKit.TITLE, 4)
	local box = Instance.new("Frame")
	box.BorderSizePixel = 0
	box.Size = UDim2.fromScale(0.56, 0.24)
	box.Position = UDim2.fromScale(0.22, 0.47)
	box.BackgroundColor3 = base
	local cr = Instance.new("UICorner")
	cr.CornerRadius = UDim.new(0.5, 0)
	cr.Parent = box
	local bs = Instance.new("UIStroke")
	bs.Thickness = 3
	bs.Color = C(30, 60, 40)
	bs.Parent = box
	box.Parent = sign.gui
	local pill = Instance.new("TextLabel")
	pill.Size = UDim2.fromScale(0.9, 0.8)
	pill.Position = UDim2.fromScale(0.05, 0.1)
	pill.Text = "OPEN"
	styled(pill, Color3.new(1, 1, 1), 2)
	pill.Parent = box
	local status = SkyVoxel.text(sign, "", 0.74, 0.98, C(255, 240, 205), 2.5)
	local maxN = if kind == "party" then Config.PARTY_MAX else 1
	local state = ""
	local def = {
		kind = kind,
		pos = (cf * CFrame.new(0, top, 0)).Position,
		radius = r + 0.6,
		label = status,
		title = title,
		show = function(newState: string, n: number, left: number?, who: string?, limit: number?)
			local capN = limit or maxN
			if newState == "open" then
				status.Text = if kind == "continue" then "Your saved run" elseif kind == "solo" then "Play alone" else ("%d/%d"):format(n, capN)
			elseif newState == "creating" then
				status.Text = (who or "Someone") .. " is setting up"
			elseif newState == "starting" then
				status.Text = if kind == "party" then ("%d/%d  -  %d"):format(n, capN, left or 0) else ("Starting in %d"):format(left or 0)
			else
				status.Text = "Teleporting..."
			end
			local text = LobbyPads.pillFor(kind, newState, n, capN, left)
			if text ~= pill.Text or newState ~= state then
				state = newState
				local c = if newState == "open" then base else BUSY_C
				for _, q in ring do
					q.Color = c
				end
				box.BackgroundColor3 = c
				pill.Text = text
			end
		end,
	}
	def.show("open", 0, nil)
	LobbyKit.tag(LobbyKit.spot(m, cf * CFrame.new(0, top + 1.5, 0), Vector3.new(r * 1.6, 2, r * 1.6), "PadFX"), "LobbyFX", { Kind = "sparkle", Color = base })
	return def
end

-------------------------------------------------------------------------------------------------------------
-- the hero and the stations
-------------------------------------------------------------------------------------------------------------
-- The voxel windmill, `k` times its size, its sails on the axle turning (client/Fx spins parts with Spin).
function SkyVoxel.windmill(parent: Instance, pos: Vector3, toward: Vector3, k: number)
	local m = PropKit.folder("Landmark", parent)
	local body = VM.place(m, "Landmark_windmill", pos, { scale = k, yaw = yawTo(pos, toward), collide = false })
	if not body then
		return
	end
	local axle = body.CFrame * CFrame.new(0, -body.Size.Y / 2 + 25.8 * k, 14.4 * k)
	local sails = VM.place(m, "Landmark_windmill_sails", pos, { scale = k })
	if sails then
		sails.CFrame = axle
		sails:SetAttribute("Spin", 0.5)
		sails:SetAttribute("SpinAxis", "Z")
	end
	-- the tower is solid (a drum round its middle; the mesh's own collision is its box)
	local drum = collider(m, Vector3.new(body.Size.Y * 0.62, body.Size.X * 0.82, body.Size.X * 0.82), CFrame.new(pos + Vector3.new(0, body.Size.Y * 0.31, 0)) * CFrame.Angles(0, 0, math.rad(90)))
	drum.Shape = Enum.PartType.Cylinder
end

-- A sign on posts in front of a station, `title` painted on it, facing `toward`.
local function stationSign(parent: Instance, at: Vector3, toward: Vector3, title: string, w: number, color: Color3?)
	local s = SkyVoxel.sign(parent, facing(at, toward), w, 2.6, 2.2)
	SkyVoxel.text(s, title, 0.06, 0.94, color or PropKit.TITLE, 4)
end

-- CLASSES: the purple mushroom hut, its door toward `toward`, the aura mannequin beside it, a sign by the path.
-- Returns the hidden stock label (server/Lobby writes the stock there) and the mannequin.
function SkyVoxel.classes(parent: Instance, pos: Vector3, toward: Vector3): (TextLabel, Model?)
	local m = PropKit.folder("Classes", parent)
	local yaw = yawTo(pos, toward)
	local hut = VM.place(m, "Landmark_mushroomhut", pos, { scale = 0.5, yaw = yaw })
	local at = facing(pos, toward)
	if hut then
		local stem = collider(m, Vector3.new(16, 9, 9), CFrame.new(pos + Vector3.new(0, 8, 0)) * CFrame.Angles(0, 0, math.rad(90)))
		stem.Shape = Enum.PartType.Cylinder
	end
	stationSign(m, (at * CFrame.new(6.5, 0, -12)).Position, toward, "CLASSES", 10, C(206, 160, 255))
	local porch = PropKit.part({ size = Vector3.new(2, 2, 2), cf = at * CFrame.new(0, 3, -6.5), color = Color3.new(1, 1, 1), parent = m, transparency = 1, collide = false, name = "ClassPorch" })
	porch.CanQuery = false
	PropKit.prompt(porch, "Browse", "Classes", "Classes", 12)
	LobbyKit.tag(LobbyKit.spot(m, at * CFrame.new(0, 2, -7), Vector3.new(8, 3, 4), "ClassesFX"), "LobbyFX", { Kind = "sparkle", Color = C(200, 160, 255) })
	local dummy = require(script.Parent.AuraMannequin).build(m, facing((at * CFrame.new(-8, 0, -9)).Position, toward))
	local hidden = Instance.new("TextLabel")
	hidden.Name = "StockText"
	return hidden, dummy
end

-- The GARAGE: the log cabin, its porch toward `toward`, the mower on a turntable in front (its prompt opens the
-- Garage window; client/MowerLock hangs its padlock over it while the mowers are locked), a sign by the path.
function SkyVoxel.garage(parent: Instance, pos: Vector3, toward: Vector3)
	local m = PropKit.folder("Garage", parent)
	local yaw = yawTo(pos, toward)
	local cabin = VM.place(m, "Prop_log_cabin", pos, { scale = 0.85, yaw = yaw })
	local at = facing(pos, toward)
	if cabin then
		-- its walls are solid; the porch in front is open
		collider(m, Vector3.new(24, 16, 12), at * CFrame.new(0, 8, 4))
	end
	local spot = at * CFrame.new(0, 0, -16)
	if not VM.place(m, "Prop_turntable", spot.Position, { yaw = yaw }) then
		vox(m, Vector3.new(10, 0.6, 10), spot * CFrame.new(0, 0.3, 0), C(70, 70, 78), true)
	end
	-- (the voxel turntable is 2 studs high: the prompt's holder fills it, so client/MowerLock's ring sits on its top)
	local floor = PropKit.cylinder(m, 5, 2, spot * CFrame.new(0, 1, 0), Color3.new(1, 1, 1))
	floor.Transparency = 1
	floor.CanCollide = false
	floor.Name = "Turntable"
	Models.place("mower_tractor", m, spot * CFrame.new(0, 2, 0) * CFrame.Angles(0, math.rad(200), 0), 1, true)
	PropKit.prompt(floor, "Open", "Garage", "Garage", 14)
	stationSign(m, (at * CFrame.new(-9, 0, -12)).Position, toward, "GARAGE", 10)
end

-- FREE REWARDS: the gift stall facing `toward`, two walk-on bays in front of it (left = the daily claim), a sign.
function SkyVoxel.rewards(parent: Instance, pos: Vector3, toward: Vector3)
	local m = PropKit.folder("FreeRewards", parent)
	local yaw = yawTo(pos, toward)
	VM.place(m, "Prop_rewards_stall", pos, { scale = 0.85, yaw = yaw })
	local at = facing(pos, toward)
	collider(m, Vector3.new(18, 8, 6), at * CFrame.new(0, 4, 1.5))
	local gold = SAVE_C
	LobbyKit.padZone(m, at * CFrame.new(3.9, 0, -8.4), 6.2, 6, gold, "Rewards", "daily")
	LobbyKit.padZone(m, at * CFrame.new(-3.9, 0, -8.4), 6.2, 6, gold, "Rewards")
	for _, x in { 3.6, -3.6 } do
		LobbyKit.tag(LobbyKit.spot(m, at * CFrame.new(x, 4.5, -3.5), Vector3.new(3, 2, 2), "RewardsFX"), "LobbyFX", { Kind = "sparkle", Color = gold })
	end
	local p = PropKit.part({ size = Vector3.new(2, 2, 2), cf = at * CFrame.new(0, 3, -8.4), color = Color3.new(1, 1, 1), parent = m, transparency = 1, collide = false, name = "RewardsPrompt" })
	p.CanQuery = false
	PropKit.prompt(p, "Open", "Free Rewards", "Rewards", 14)
	-- the sign beside it: what the two bays give
	local s = SkyVoxel.sign(m, at * CFrame.new(-14.5, 0, -5) * CFrame.Angles(0, math.rad(-20), 0), 10, 3.4, 2.2)
	SkyVoxel.text(s, "FREE REWARDS", 0.04, 0.5, PropKit.TITLE, 4)
	SkyVoxel.text(s, ("DAILY up to +%d     GROUP +%d"):format(Config.DAILY_STREAK[#Config.DAILY_STREAK], Config.GROUP_GEMS), 0.56, 0.94, Color3.new(1, 1, 1), 2.5)
end

-- A leaderboard: a dark board of rows on posts, its title on top. Returns the rows label (server/LobbyBoards fills
-- it) and the title label. `cycle` = the boards it takes turns with (server/LobbyBoards).
function SkyVoxel.board(parent: Instance, name: string, pos: Vector3, toward: Vector3, title: string, key: string, color: Color3, cycle: string?): TextLabel
	local m = PropKit.folder(name, parent)
	local s = SkyVoxel.sign(m, facing(pos, toward), 13, 11, 1.6, true)
	local head = SkyVoxel.text(s, title, 0.02, 0.15, color, 4)
	local body = Instance.new("TextLabel")
	body.Name = "Rows"
	body.Size = UDim2.fromScale(0.92, 0.82)
	body.Position = UDim2.fromScale(0.04, 0.17)
	body.Text = ""
	styled(body, Color3.new(1, 1, 1), 2)
	body.Parent = s.gui
	LobbyKit.boardFace(body, key)
	if cycle then
		s.face:SetAttribute("Cycle", cycle)
		local ref = Instance.new("ObjectValue")
		ref.Name = "TitleLabel"
		ref.Value = head
		ref.Parent = s.face
	end
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	-- a gold trophy of blocks on its top
	local at = facing(pos, toward)
	local y = s.top + 0.4
	local gold = C(255, 200, 40)
	vox(m, Vector3.new(2.4, 0.6, 1.4), at * CFrame.new(0, y, 0), C(120, 84, 40))
	vox(m, Vector3.new(0.8, 1, 0.8), at * CFrame.new(0, y + 0.8, 0), gold)
	vox(m, Vector3.new(2.6, 1.6, 1.6), at * CFrame.new(0, y + 2.1, 0), gold)
	for _, sx in { -1, 1 } do
		vox(m, Vector3.new(0.6, 1, 0.6), at * CFrame.new(sx * 1.6, y + 2.2, 0), gold)
	end
	return body
end

-------------------------------------------------------------------------------------------------------------
-- small things
-------------------------------------------------------------------------------------------------------------
-- A fountain of blocks: an eight-sided stone basin with water in it, a pillar with a bowl, water spraying
-- (client/LobbyFX "fountain") and butterflies.
function SkyVoxel.fountain(parent: Instance, pos: Vector3)
	local m = PropKit.folder("FountainGarden", parent)
	local R = 5
	for gx = -R, R - 1 do
		for gz = -R, R - 1 do
			local cx, cz = gx + 0.5, gz + 0.5
			local d = math.max(math.abs(cx), math.abs(cz), (math.abs(cx) + math.abs(cz)) * 0.72)
			if d <= R and d > R - 1.2 then
				vox(m, Vector3.new(1, 1.4, 1), CFrame.new(pos + Vector3.new(cx, 0.7, cz)), pick(STONE), true)
				vox(m, Vector3.new(1, 0.3, 1), CFrame.new(pos + Vector3.new(cx, 1.55, cz)), pick(STONE_D))
			elseif d <= R - 1.2 then
				local w = vox(m, Vector3.new(1, 0.3, 1), CFrame.new(pos + Vector3.new(cx, 1.0, cz)), C(96, 196, 240))
				w.Material = Enum.Material.Glass
				w.Transparency = 0.2
			end
		end
	end
	vox(m, Vector3.new(1.6, 3.4, 1.6), CFrame.new(pos + Vector3.new(0, 2.4, 0)), pick(STONE), true)
	vox(m, Vector3.new(3.4, 0.6, 3.4), CFrame.new(pos + Vector3.new(0, 4.1, 0)), pick(STONE_D))
	local water = vox(m, Vector3.new(2.6, 0.2, 2.6), CFrame.new(pos + Vector3.new(0, 4.45, 0)), C(110, 206, 250))
	water.Material = Enum.Material.Glass
	water.Transparency = 0.15
	LobbyKit.tag(LobbyKit.spot(m, CFrame.new(pos + Vector3.new(0, 4.6, 0)), Vector3.new(1, 1, 1), "FountainFX"), "LobbyFX", { Kind = "fountain", Color = C(170, 225, 255) })
	LobbyKit.tag(LobbyKit.spot(m, CFrame.new(pos + Vector3.new(0, 3, 0)), Vector3.new(16, 4, 16), "Butterflies"), "LobbyFX", { Kind = "butterflies", Color = C(255, 214, 90) })
end

-- A wooden fence of blocks from `a` to `b`: log posts every 3 studs, two rails.
function SkyVoxel.fence(parent: Instance, a: Vector3, b: Vector3)
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt(a, b)
	local n = math.max(1, math.floor(len / 3 + 0.5))
	for i = 0, n do
		local p = cf * CFrame.new(0, 0, -len * i / n)
		vox(parent, Vector3.new(0.8, 3.2, 0.8), p * CFrame.new(0, 1.6, 0), pick(LOG), true)
	end
	for _, y in { 1.2, 2.4 } do
		vox(parent, Vector3.new(0.4, 0.5, len), cf * CFrame.new(0, y, -len / 2), pick(WOOD))
	end
end

-- A lamp post (the voxel one), turned to `toward`.
function SkyVoxel.lamp(parent: Instance, pos: Vector3, toward: Vector3)
	VM.place(parent, "Prop_lantern_post", pos, { yaw = yawTo(pos, toward), collide = true })
end

return SkyVoxel
