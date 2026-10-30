-- SHOP ROOM (30 Oct, owner: "Shop-interieur in de map. (use forgeUI) use the pictures ive send, copy and remake it
-- exactly"; answers: Chop A Forest's shop layout in our voxel look, lawn props in the same spots, all our tools on
-- the boards, the Mega Scythe on the middle spotlight board (Robux), buy with a hold-E prompt, rebuild the outside
-- too). server/CampBuildings still builds the log lodge (walls, roof, beams, chandelier, porch); with
-- CampBuildings.ROOM on it leaves the old shelves, counter, barrels and rug out and this file fills the room:
--
--   * back wall: five tool boards like Chop's axe wall (planks in a frame, the tool on two pegs or a mower on a
--     ledge, a name plaque on top, a price plaque with a status lamp under it, a picture lamp), cheapest on the
--     left as you come in. The middle one is Chop's RAINBOWMAKER spot: a tall dark wood panel, the board with gold
--     corners and a sunburst (ForgeGUI) behind the Mega Scythe, its Robux price, a soft spotlight and glints;
--   * left wall: the Laser Mower on a bench under its name board (Chop's OIL SAW), the window, a painting of a
--     mowed meadow (ForgeGUI), wall pegs with a jacket, an apron, a beanie and a straw hat (Chop's coats);
--   * right wall (the chimney side): a stone fireplace with a fire, a GOLDEN lawn gnome head mounted over the mantel
--     (Chop's deer head), grass bundles stacked under the window (Chop's firewood), big hedge shears on the wall
--     (Chop's saw), a notice board, a barrel of rakes in the corner (Chop's bucket of sticks);
--   * front left: a round table on a stump with stump stools on a round lawn-stripe rug (ForgeGUI), a seed tray on
--     it (Chop's game board);
--   * two lanterns hanging from the beams, a red runner from the door to the middle board.
-- Outside: giant hedge shears on a carved wooden medallion on the front of the roof, a white picket fence with
-- flower beds along the front, a wheelbarrow of clippings, a lawn gnome, a watering can, a mailbox, grass bundles.
--
-- Every display is a Folder "ToolDisplay" (ToolId) with "PriceText", "StatusLamp" and the tool model
-- (DisplayItem), like before, so client/ShopDisplays colours it and turns the tool when you walk up. The prompts
-- are hold-E (0.5 s): client/ShopDisplays sets "Buy $x" when it's your next tool and you can afford it, and
-- client/Input then buys it straight away; otherwise it opens the tool popup (coins, or Robux this run / forever).
--
-- Coordinates are the lodge's own (server/CampBuildings): y 0 is the ground, the floor top is at 0.75, the room is
-- x -19.6..19.6 and z -7.2 (front, the door) .. 14.3 (back), -Z faces out of the door.
local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Format = require(ReplicatedStorage.MowALawn.Format)
local PropKit = require(script.Parent.PropKit)
local Models = require(script.Parent.Models)

local okIcons, IconIds = pcall(require, ReplicatedStorage.MowALawn:FindFirstChild("IconIds"))

local ShopRoom = {}
ShopRoom.ON = true

-- ForgeGUI pictures (published 30 Oct as @bbrrbrrbrbrb images)
ShopRoom.PAINTING = "rbxassetid://101341631596932" -- a mowed meadow with a red push mower and a log cottage
ShopRoom.RUG = "rbxassetid://115459550401080" -- red border, lawn stripes, golden leaves (square)
ShopRoom.ROUND_RUG = "rbxassetid://89510995724451" -- a round braided rug, lawn stripes in the middle (transparent round it)
ShopRoom.SUNBURST = "" -- golden rays behind the middle board's tool (transparent); "" = the hatch's rays (IconIds.ui_rays)

local FLOOR = 0.75
local XI = 19.6 -- the room's inner half width
local ZF, ZB = -7.2, 14.3 -- inner front and back faces
local HOLD = 0.5 -- the prompts' hold time (s)

local C = {
	timber = Color3.fromRGB(92, 66, 50),
	timberDark = Color3.fromRGB(70, 50, 38),
	board = Color3.fromRGB(214, 168, 116),
	plaque = Color3.fromRGB(56, 36, 28),
	iron = Color3.fromRGB(54, 52, 52),
	brass = Color3.fromRGB(226, 176, 74),
	gold = Color3.fromRGB(234, 182, 58),
	goldDeep = Color3.fromRGB(200, 138, 36),
	goldPale = Color3.fromRGB(246, 214, 130),
	velvet = Color3.fromRGB(98, 54, 150),
	velvetDark = Color3.fromRGB(70, 36, 112),
	stone = Color3.fromRGB(200, 196, 188),
	stoneDark = Color3.fromRGB(132, 128, 124),
	soot = Color3.fromRGB(36, 28, 24),
	lamp = Color3.fromRGB(255, 214, 150),
	fire = Color3.fromRGB(255, 140, 40),
	fireCore = Color3.fromRGB(255, 220, 110),
	leaf = Color3.fromRGB(78, 150, 58),
	grass = Color3.fromRGB(112, 196, 70),
	straw = Color3.fromRGB(232, 198, 112),
	red = Color3.fromRGB(204, 62, 54),
	runner = Color3.fromRGB(150, 44, 40),
	white = Color3.fromRGB(244, 240, 230),
	metal = Color3.fromRGB(200, 204, 210),
	terracotta = Color3.fromRGB(196, 104, 66),
	skin = Color3.fromRGB(240, 196, 160),
	blue = Color3.fromRGB(70, 110, 190),
	soil = Color3.fromRGB(86, 60, 42),
}
local FLOWERS = { Color3.fromRGB(236, 96, 110), Color3.fromRGB(250, 214, 80), Color3.fromRGB(244, 244, 236), Color3.fromRGB(170, 120, 220), Color3.fromRGB(250, 150, 80) }

local TOOL_MODEL = {
	Scissors = "tool_scissors",
	Sickle = "tool_sickle",
	PushMower = "tool_pushmower",
	WeedWhacker = "tool_whacker",
	MegaScythe = "tool_scythe",
	LaserMower = "tool_lasermower",
}
local MOWERS = { PushMower = true, LaserMower = true }
-- hand tools hang across the pegs: their length (model Z) along the board, flat side out
local HANG = CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(90))

type Ctx = { at: CFrame, rng: Random }

-------------------------------------------------------------------------------------------------------------
-- blocks
-------------------------------------------------------------------------------------------------------------
local function jitter(rng: Random, c: Color3, amt: number): Color3
	local k = 1 + (rng:NextNumber() * 2 - 1) * amt
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

-- A block at `cf` (world). Decoration unless `solid`; tiny ones cast no shadow (cheaper on phones).
local function part(parent: Instance, name: string, cf: CFrame, size: Vector3, color: Color3, mat: Enum.Material?, solid: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if not solid then
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	end
	if size.X + size.Y + size.Z < 1.6 then
		p.CastShadow = false
	end
	p.Parent = parent
	return p
end

-- A cylinder whose axis is the cf's Y (upright when cf is).
local function cyl(parent: Instance, name: string, cf: CFrame, h: number, d: number, color: Color3, mat: Enum.Material?, solid: boolean?): Part
	local p = part(parent, name, cf * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(h, d, d), color, mat, solid)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(parent: Instance, name: string, cf: CFrame, d: number, color: Color3, mat: Enum.Material?): Part
	local p = part(parent, name, cf, Vector3.one * d, color, mat)
	p.Shape = Enum.PartType.Ball
	return p
end

-- the Studio-made pixel stone texture on the lodge's stone, if this place has it
local stoneSkin: boolean? = nil
local function stoneLook(p: BasePart)
	if stoneSkin == nil then
		stoneSkin = MaterialService:FindFirstChild("MowVoxelStone1", true) ~= nil
	end
	if stoneSkin then
		p.Material = Enum.Material.Cobblestone
		p.MaterialVariant = "MowVoxelStone1"
	else
		p.Material = Enum.Material.Slate
	end
end

-- [a, b] in pieces between minL and maxL long
local function chop(rng: Random, a: number, b: number, minL: number, maxL: number): { { number } }
	local out = {}
	local x = a
	while b - x > 0.01 do
		local len = math.min(rng:NextNumber(minL, maxL), b - x)
		if b - (x + len) < minL then
			len = b - x
		end
		table.insert(out, { x, x + len })
		x += len
	end
	return out
end

local function light(parent: BasePart, kind: string, props: { [string]: any })
	local l = Instance.new(kind)
	l.Shadows = false
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

local function emitter(parent: BasePart, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function holder(parent: Instance, name: string, cf: CFrame, size: Vector3): Part
	local p = part(parent, name, cf, size, Color3.new(1, 1, 1))
	p.Transparency = 1
	p.CastShadow = false
	return p
end

local function textOn(p: BasePart, text: string, color: Color3): TextLabel
	local label = PropKit.surfaceText(p, text, color)
	label.Size = UDim2.fromScale(0.9, 0.8)
	label.Position = UDim2.fromScale(0.05, 0.1)
	return label
end

local function toolDef(id: string)
	for _, t in Config.TOOLS do
		if t.id == id then
			return t
		end
	end
	return nil
end

-------------------------------------------------------------------------------------------------------------
-- hedge shears (the wall piece inside, and the giant pair on the roof)
-------------------------------------------------------------------------------------------------------------
-- An open pair of hedge shears in cf's XY plane (blades up, handles down, -Z toward you), `s` = scale.
local function shears(parent: Instance, cf: CFrame, s: number)
	local handle = Color3.fromRGB(150, 102, 64)
	for _, side in { -1, 1 } do
		local arm = cf * CFrame.Angles(0, 0, math.rad(side * 24))
		-- the blade: a long flat piece narrowing to the tip, a darker edge, a bright bevel
		part(parent, "ShearBlade", arm * CFrame.new(0, 1.9 * s, -0.04 * s * side), Vector3.new(0.62 * s, 3.0 * s, 0.14 * s), C.metal, Enum.Material.Metal)
		part(parent, "ShearTip", arm * CFrame.new(0, 3.65 * s, -0.04 * s * side), Vector3.new(0.38 * s, 0.5 * s, 0.14 * s), C.metal, Enum.Material.Metal)
		part(parent, "ShearEdge", arm * CFrame.new(-side * 0.27 * s, 2.0 * s, -0.12 * s * side), Vector3.new(0.1 * s, 2.8 * s, 0.06 * s), Color3.fromRGB(240, 244, 250), Enum.Material.Metal)
		-- the handle: wood with a red rubber grip
		part(parent, "ShearHandle", arm * CFrame.new(0, -1.5 * s, -0.04 * s * side), Vector3.new(0.42 * s, 2.6 * s, 0.4 * s), handle)
		part(parent, "ShearGrip", arm * CFrame.new(0, -3.1 * s, -0.04 * s * side), Vector3.new(0.52 * s, 0.9 * s, 0.5 * s), C.red)
		part(parent, "ShearCollar", arm * CFrame.new(0, -0.15 * s, -0.04 * s * side), Vector3.new(0.6 * s, 0.32 * s, 0.44 * s), C.iron, Enum.Material.Metal)
	end
	cyl(parent, "ShearBolt", cf * CFrame.new(0, 0, -0.32 * s) * CFrame.Angles(math.rad(90), 0, 0), 0.3 * s, 0.42 * s, C.brass, Enum.Material.Metal)
end

-------------------------------------------------------------------------------------------------------------
-- tool boards
-------------------------------------------------------------------------------------------------------------
type BoardOpts = { w: number, h: number, big: boolean? }

-- One tool's board. `cf`: the middle of the board on the wall's face, -Z into the room.
local function toolBoard(ctx: Ctx, shop: Instance, tool, cf: CFrame, o: BoardOpts)
	local rng = ctx.rng
	local d = PropKit.folder("ToolDisplay", shop)
	d:SetAttribute("ToolId", tool.id)
	local w, h, big = o.w, o.h, o.big == true
	local t = 0.45 -- frame thickness
	local frame = C.timber
	local frameMat = Enum.Material.Plastic
	if big then
		-- Chop's middle spot: a tall dark wood panel behind the board, from the floor nearly to the beams, framed
		local pw, ph = w + 2.6, 13.0
		local pBase = cf * CFrame.new(0, -cf.Position.Y + ctx.at.Position.Y + FLOOR + ph / 2, 0)
		local n = 6
		for i = 0, n - 1 do
			local x = -pw / 2 + (i + 0.5) * pw / n
			part(d, "DarkPanel", pBase * CFrame.new(x, 0, -0.12), Vector3.new(pw / n - 0.05, ph, 0.24), jitter(rng, C.timberDark, 0.05))
		end
		for _, sx in { -1, 1 } do
			part(d, "PanelPost", pBase * CFrame.new(sx * (pw / 2 + 0.3), 0, -0.25), Vector3.new(0.6, ph, 0.5), C.timber, nil, true)
		end
		part(d, "PanelHead", pBase * CFrame.new(0, ph / 2 + 0.3, -0.25), Vector3.new(pw + 1.2, 0.6, 0.5), C.timber)
		part(d, "PanelSkirt", pBase * CFrame.new(0, -ph / 2 + 0.3, -0.3), Vector3.new(pw, 0.6, 0.4), C.timber)
		cf = cf * CFrame.new(0, 0, -0.24)
	end
	do
		local n = 4
		for i = 0, n - 1 do
			local x = -w / 2 + (i + 0.5) * w / n
			part(d, "BoardPlank", cf * CFrame.new(x, 0, -0.18), Vector3.new(w / n - 0.06, h, 0.34), jitter(rng, C.board, 0.06), Enum.Material.Plastic)
		end
		-- two battens behind the planks show at the edges, a few nail heads
		for _, sy in { -0.3, 0.3 } do
			for _, sx in { -1, 1 } do
				part(d, "Nail", cf * CFrame.new(sx * (w / 2 - 0.35), sy * h, -0.38), Vector3.new(0.14, 0.14, 0.06), C.iron)
			end
		end
	end
	-- the frame, with corner blocks (gold L-brackets on the middle board, like Chop's)
	for _, s in { -1, 1 } do
		part(d, "BoardFrame", cf * CFrame.new(0, s * (h / 2 + t / 2), -0.3), Vector3.new(w + 2 * t, t, 0.6), frame, frameMat, true)
		part(d, "BoardFrame", cf * CFrame.new(s * (w / 2 + t / 2), 0, -0.3), Vector3.new(t, h, 0.6), frame, frameMat, true)
	end
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			part(d, "FrameCorner", cf * CFrame.new(sx * (w / 2 + t / 2), sy * (h / 2 + t / 2), -0.36), Vector3.new(t + 0.2, t + 0.2, 0.7), frame:Lerp(Color3.new(0, 0, 0), 0.18), frameMat)
			if big then
				part(d, "GoldCorner", cf * CFrame.new(sx * (w / 2 - 0.2), sy * (h / 2 - 0.55), -0.4), Vector3.new(0.3, 1.2, 0.08), C.gold, Enum.Material.Metal)
				part(d, "GoldCorner", cf * CFrame.new(sx * (w / 2 - 0.55), sy * (h / 2 - 0.2), -0.4), Vector3.new(1.0, 0.3, 0.08), C.gold, Enum.Material.Metal)
			end
		end
	end
	local burstImage = if ShopRoom.SUNBURST ~= "" then ShopRoom.SUNBURST elseif okIcons and type(IconIds) == "table" then IconIds.ui_rays else nil
	if big and type(burstImage) == "string" and burstImage ~= "" then
		-- the sunburst behind the tool, warm gold
		local burst = holder(d, "Sunburst", cf * CFrame.new(0, 0.1, -0.4), Vector3.new(math.min(w, h) - 0.4, math.min(w, h) - 0.4, 0.05))
		local decal = Instance.new("Decal")
		decal.Face = Enum.NormalId.Front
		decal.Texture = burstImage
		decal.Color3 = Color3.fromRGB(255, 214, 110)
		decal.Transparency = 0.15
		decal.Parent = burst
	end
	-- the name plaque on top, on two little iron hangers
	local nameW, nameH = (if big then w * 0.86 else w * 0.94), (if big then 1.55 else 1.25)
	local nameAt = cf * CFrame.new(0, h / 2 + t + 0.25 + nameH / 2, -0.32)
	local name = part(d, "NameText", nameAt, Vector3.new(nameW, nameH, 0.3), C.plaque, Enum.Material.Wood)
	part(d, "NameRim", nameAt * CFrame.new(0, 0, 0.04), Vector3.new(nameW + 0.24, nameH + 0.24, 0.24), if big then C.gold else C.timberDark, if big then Enum.Material.Metal else frameMat)
	textOn(name, tool.name:upper(), if big then C.goldPale else PropKit.TITLE)
	for _, sx in { -1, 1 } do
		part(d, "NameHanger", cf * CFrame.new(sx * nameW * 0.32, h / 2 + t + 0.15, -0.3), Vector3.new(0.14, 0.4, 0.14), C.iron)
	end
	-- the price plaque under it, with the status lamp (client/ShopDisplays tints both)
	local priceW = math.min(w * 0.82, 4.6)
	local priceAt = cf * CFrame.new(0, -h / 2 - t - 0.85, -0.32)
	local price = part(d, "PriceText", priceAt, Vector3.new(priceW, 1.15, 0.3), C.plaque, Enum.Material.Wood)
	part(d, "PriceRim", priceAt * CFrame.new(0, 0, 0.04), Vector3.new(priceW + 0.22, 1.37, 0.24), if big then C.gold else C.timberDark, if big then Enum.Material.Metal else frameMat)
	local robux = big and tool.once and Config.PRODUCTS[tool.once]
	if robux then
		-- the spotlight board shows the Robux price (this run), like Chop's R$ board
		d:SetAttribute("RobuxText", "R$ " .. Format.commas(robux.robux))
		textOn(price, "R$ " .. Format.commas(robux.robux), Color3.fromRGB(140, 240, 90))
	else
		textOn(price, "$" .. Format.commas(tool.cost), PropKit.PRICE)
	end
	local lampAt = priceAt * CFrame.new(priceW / 2 + 0.55, 0, -0.05)
	cyl(d, "StatusRim", lampAt * CFrame.Angles(math.rad(90), 0, 0), 0.14, 0.62, C.brass, Enum.Material.Metal)
	local glass = ball(d, "StatusLamp", lampAt * CFrame.new(0, 0, -0.08), 0.44, Color3.fromRGB(150, 150, 150), Enum.Material.Glass)
	glass.Transparency = 0.15
	-- the tool: across two pegs, or a mower standing on a ledge
	local id = tool.id
	local model: Model? = nil
	if MOWERS[id] then
		local ledgeY = -h / 2 + 0.55
		part(d, "Ledge", cf * CFrame.new(0, ledgeY, -1.25), Vector3.new(w - 0.3, 0.4, 2.3), C.timber, nil, true)
		for _, sx in { -1, 1 } do
			part(d, "LedgeBracket", cf * CFrame.new(sx * (w / 2 - 0.7), ledgeY - 0.6, -0.65) * CFrame.Angles(math.rad(-40), 0, 0), Vector3.new(0.35, 1.3, 0.35), C.timberDark)
		end
		model = Models.place(TOOL_MODEL[id], d, cf * CFrame.new(0, ledgeY + 0.2, -1.3) * CFrame.Angles(0, math.rad(25), 0), 1, true)
		if model then
			local _, size = model:GetBoundingBox()
			local fit = (w - 0.8) / math.max(size.X, size.Z, size.Y * 0.8)
			if fit < 1 then
				model:ScaleTo(fit)
			end
			local box, s2 = model:GetBoundingBox()
			local want = (cf * CFrame.new(0, ledgeY + 0.2 + s2.Y / 2, -1.3)).Position
			model:PivotTo(model:GetPivot() + (want - box.Position))
		end
	else
		for _, sx in { -1, 1 } do
			cyl(d, "Peg", cf * CFrame.new(sx * w * 0.3, -0.55, -0.7) * CFrame.Angles(math.rad(90), 0, 0), 0.9, 0.3, C.timberDark)
		end
		local scythe = id == "MegaScythe"
		local target = cf * CFrame.new(0, 0.2, -0.95)
		-- (the Mega Scythe across the velvet on a diagonal, blade up: more of a showpiece)
		model = Models.place(TOOL_MODEL[id], d, target * (if scythe then CFrame.Angles(0, 0, math.rad(-28)) * CFrame.Angles(0, math.rad(90), 0) else HANG), 1, true)
		if model then
			local _, size = model:GetBoundingBox()
			local fit = (if big then h * 0.86 else math.min(w, h) * 0.86) / math.max(size.X, size.Y, size.Z)
			if fit < 1 then
				model:ScaleTo(fit)
			end
			local box = model:GetBoundingBox()
			model:PivotTo(model:GetPivot() + (target.Position - box.Position))
		end
	end
	if model then
		model:SetAttribute("DisplayItem", true)
	end
	-- a picture lamp over the name plaque (the spotlight board has its ceiling spotlight instead)
	if not big then
		local lampY = h / 2 + t + 0.25 + nameH + 0.75
		part(d, "PictureLampArm", cf * CFrame.new(0, lampY, -0.6), Vector3.new(0.25, 0.25, 1.2), C.iron)
		local hood = part(d, "PictureLamp", cf * CFrame.new(0, lampY - 0.1, -1.25), Vector3.new(1.6, 0.38, 0.6), C.brass, Enum.Material.Metal)
		local bulb = part(d, "PictureBulb", hood.CFrame * CFrame.new(0, -0.24, 0), Vector3.new(hood.Size.X - 0.3, 0.1, 0.36), C.lamp, Enum.Material.Neon)
		bulb.Transparency = 0.3
		light(bulb, "SpotLight", { Face = Enum.NormalId.Bottom, Angle = 80, Brightness = 0.5, Range = 9, Color = Color3.fromRGB(255, 222, 176) })
	end
	-- the hold-E prompt, at eye height in front of the board (a prompt only shows while it's on screen, and in first
	-- person you look straight ahead, not up at the board)
	local promptY = (ctx.at.Position.Y + FLOOR + 3.6) - cf.Position.Y
	local spot = holder(d, "ToolFrame", cf * CFrame.new(0, promptY, -2.2), Vector3.new(2, 2, 2))
	local prompt = PropKit.prompt(spot, if robux then "Buy" else "View", tool.name, "ToolView", 8)
	prompt.HoldDuration = HOLD
	prompt:SetAttribute("Item", id)
	prompt:SetAttribute("ShopBoard", true)
	return d, model
end

-- Chop's OIL SAW spot, for the Laser Mower: the mower on a work bench against the wall, its name on a sign board
-- above it, the price on the bench's front. `cf`: the wall's face at floor height where the bench stands, -Z out.
local function benchDisplay(ctx: Ctx, shop: Instance, tool, cf: CFrame)
	local rng = ctx.rng
	local d = PropKit.folder("ToolDisplay", shop)
	d:SetAttribute("ToolId", tool.id)
	local L, D, TOP = 7.8, 3.2, FLOOR + 2.4
	local benchAt = cf * CFrame.new(0, 0, -D / 2 - 0.2)
	local function y(v: number): number
		return v - cf.Position.Y + ctx.at.Position.Y
	end
	-- the bench: plank top, an apron in front, four legs, a low shelf
	for k = -1, 1 do
		part(d, "BenchPlank", benchAt * CFrame.new(0, y(TOP - 0.18), k * D / 3), Vector3.new(L, 0.36, D / 3 - 0.05), jitter(rng, C.board, 0.06), nil, true)
	end
	part(d, "BenchApron", benchAt * CFrame.new(0, y(TOP - 0.7), -D / 2 + 0.2), Vector3.new(L - 0.6, 0.7, 0.25), C.timber)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(d, "BenchLeg", benchAt * CFrame.new(sx * (L / 2 - 0.45), y(FLOOR + (TOP - FLOOR) / 2 - 0.18), sz * (D / 2 - 0.35)), Vector3.new(0.5, TOP - FLOOR - 0.36, 0.5), C.timber, nil, true)
		end
	end
	part(d, "BenchShelf", benchAt * CFrame.new(0, y(FLOOR + 0.6), 0), Vector3.new(L - 1.0, 0.25, D - 0.8), C.timberDark)
	-- a few things on the low shelf: a fuel can and a toolbox
	part(d, "FuelCan", benchAt * CFrame.new(-2.2, y(FLOOR + 1.2), 0.2), Vector3.new(0.9, 1.0, 0.6), C.red, Enum.Material.Metal)
	part(d, "Toolbox", benchAt * CFrame.new(1.8, y(FLOOR + 1.05), 0.1), Vector3.new(1.8, 0.7, 0.9), Color3.fromRGB(70, 120, 190), Enum.Material.Metal)
	-- the mower on top
	local model = Models.place(TOOL_MODEL[tool.id], d, benchAt * CFrame.new(0, y(TOP + 0.5), 0) * CFrame.Angles(0, math.rad(25), 0), 1, true)
	if model then
		local _, size = model:GetBoundingBox()
		local fit = (L - 1.4) / math.max(size.X, size.Z, size.Y * 1.2)
		if fit < 1 then
			model:ScaleTo(fit)
		end
		local box, s2 = model:GetBoundingBox()
		local want = (benchAt * CFrame.new(0, y(TOP + s2.Y / 2), 0)).Position
		model:PivotTo(model:GetPivot() + (want - box.Position))
		model:SetAttribute("DisplayItem", true)
	end
	-- the sign board on the wall: light planks in a frame, the name on a plaque
	local signAt = cf * CFrame.new(0, y(FLOOR + 8.0), 0)
	for i = 0, 2 do
		part(d, "SignPlank", signAt * CFrame.new(-2.6 + (i + 0.5) * 5.2 / 3, 0, -0.16), Vector3.new(5.2 / 3 - 0.06, 2.6, 0.3), jitter(rng, C.board, 0.06))
	end
	for _, s in { -1, 1 } do
		part(d, "SignFrame", signAt * CFrame.new(0, s * 1.5, -0.3), Vector3.new(6.1, 0.4, 0.5), C.timber)
		part(d, "SignFrame", signAt * CFrame.new(s * 2.85, 0, -0.3), Vector3.new(0.4, 2.6, 0.5), C.timber)
	end
	local name = part(d, "NameText", signAt * CFrame.new(0, 0, -0.42), Vector3.new(4.8, 1.6, 0.12), C.plaque, Enum.Material.Wood)
	textOn(name, tool.name:upper(), PropKit.TITLE)
	-- the price on the bench's front, the status lamp beside it
	local priceAt = benchAt * CFrame.new(-0.6, y(TOP - 0.7), -D / 2 + 0.02)
	local price = part(d, "PriceText", priceAt, Vector3.new(3.8, 0.9, 0.12), C.plaque, Enum.Material.Wood)
	textOn(price, "$" .. Format.commas(tool.cost), PropKit.PRICE)
	local lampAt = priceAt * CFrame.new(2.5, 0, -0.05)
	cyl(d, "StatusRim", lampAt * CFrame.Angles(math.rad(90), 0, 0), 0.14, 0.62, C.brass, Enum.Material.Metal)
	local glass = ball(d, "StatusLamp", lampAt * CFrame.new(0, 0, -0.08), 0.44, Color3.fromRGB(150, 150, 150), Enum.Material.Glass)
	glass.Transparency = 0.15
	-- a picture lamp over the sign
	local hood = part(d, "PictureLamp", signAt * CFrame.new(0, 2.3, -1.0), Vector3.new(1.8, 0.38, 0.6), C.brass, Enum.Material.Metal)
	part(d, "PictureLampArm", signAt * CFrame.new(0, 2.4, -0.45), Vector3.new(0.25, 0.25, 1.0), C.iron)
	local bulb = part(d, "PictureBulb", hood.CFrame * CFrame.new(0, -0.24, 0), Vector3.new(1.5, 0.1, 0.36), C.lamp, Enum.Material.Neon)
	bulb.Transparency = 0.3
	light(bulb, "SpotLight", { Face = Enum.NormalId.Bottom, Angle = 90, Brightness = 0.6, Range = 11, Color = Color3.fromRGB(255, 222, 176) })
	-- the hold-E prompt
	local spot = holder(d, "ToolFrame", benchAt * CFrame.new(0, y(TOP + 1.2), -D / 2 - 0.6), Vector3.new(2, 2, 2))
	local prompt = PropKit.prompt(spot, "View", tool.name, "ToolView", 8)
	prompt.HoldDuration = HOLD
	prompt:SetAttribute("Item", tool.id)
	prompt:SetAttribute("ShopBoard", true)
end

-- The spotlight over the middle board: a lamp on the purlin shining on it, and slow glints round the tool.
local function spotlight(ctx: Ctx, d: Instance, boardCf: CFrame, model: Model?)
	local at = ctx.at
	local lampPos = (at * CFrame.new(0, 13.7, 9.6)).Position
	local aim = (boardCf * CFrame.new(0, -0.4, -0.6)).Position
	local look = CFrame.lookAt(lampPos, aim)
	part(d, "SpotRod", at * CFrame.new(0, 14.1, 9.6), Vector3.new(0.25, 0.8, 0.25), C.iron)
	local can = part(d, "SpotCan", look * CFrame.new(0, 0, 0.2), Vector3.new(1.3, 1.3, 1.8), C.iron, Enum.Material.Metal)
	part(d, "SpotRim", look * CFrame.new(0, 0, -0.75), Vector3.new(1.55, 1.55, 0.3), C.brass, Enum.Material.Metal)
	local lens = part(d, "SpotLens", look * CFrame.new(0, 0, -0.93), Vector3.new(1.1, 1.1, 0.08), C.lamp, Enum.Material.Neon)
	light(lens, "SpotLight", { Face = Enum.NormalId.Front, Angle = 34, Brightness = 1.6, Range = 18, Color = Color3.fromRGB(255, 236, 196) })
	local _ = can
	-- the sparkles: a few slow gold glints round the tool
	local box = if model then model:GetBoundingBox() else boardCf * CFrame.new(0, 0.2, -0.9)
	local glint = holder(d, "Glints", box * CFrame.new(0, 0, 0), Vector3.new(4.5, 6, 1))
	emitter(glint, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Rate = 5,
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(0.2, 0.6),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(1, 0) }),
		Color = ColorSequence.new(Color3.fromRGB(255, 236, 160), Color3.fromRGB(220, 170, 255)),
		LightEmission = 1,
		LightInfluence = 0,
		RotSpeed = NumberRange.new(-60, 60),
		Rotation = NumberRange.new(0, 360),
	})
end

-------------------------------------------------------------------------------------------------------------
-- the fireplace, with the golden gnome over the mantel
-------------------------------------------------------------------------------------------------------------
-- The golden lawn gnome's head on a wooden shield, `cf` = the shield's middle on the wall (-Z out).
local function gnomeTrophy(parent: Instance, cf: CFrame)
	-- the shield: a darker rim round a board
	part(parent, "TrophyShieldRim", cf * CFrame.new(0, 0, -0.15), Vector3.new(3.0, 3.6, 0.3), C.timberDark)
	part(parent, "TrophyShield", cf * CFrame.new(0, 0, -0.32), Vector3.new(2.5, 3.1, 0.12), C.board:Lerp(C.timber, 0.35))
	part(parent, "TrophyPoint", cf * CFrame.new(0, -1.95, -0.15) * CFrame.Angles(0, 0, math.rad(45)), Vector3.new(1.2, 1.2, 0.3), C.timberDark)
	cyl(parent, "TrophyNeck", cf * CFrame.new(0, -0.2, -0.6) * CFrame.Angles(math.rad(90), 0, 0), 0.6, 1.4, C.goldDeep, Enum.Material.Metal)
	local head = cf * CFrame.new(0, 0.1, -1.25) * CFrame.Angles(math.rad(-8), 0, 0)
	-- the face, cheeks, nose and eyes
	part(parent, "GnomeFace", head, Vector3.new(1.5, 1.2, 1.2), C.gold, Enum.Material.Metal)
	ball(parent, "GnomeNose", head * CFrame.new(0, -0.05, -0.7), 0.6, C.goldPale, Enum.Material.Metal)
	for _, sx in { -1, 1 } do
		part(parent, "GnomeEye", head * CFrame.new(sx * 0.36, 0.22, -0.61), Vector3.new(0.2, 0.24, 0.06), Color3.fromRGB(40, 30, 20))
		part(parent, "GnomeCheek", head * CFrame.new(sx * 0.52, -0.2, -0.6), Vector3.new(0.3, 0.2, 0.05), C.goldDeep, Enum.Material.Metal)
	end
	-- the beard: wide under the face, then a point
	part(parent, "GnomeBeard", head * CFrame.new(0, -0.85, -0.25), Vector3.new(1.7, 0.9, 1.1), C.goldPale, Enum.Material.Metal)
	part(parent, "GnomeBeard", head * CFrame.new(0, -1.5, -0.3), Vector3.new(1.2, 0.6, 0.9), C.goldPale, Enum.Material.Metal)
	part(parent, "GnomeBeard", head * CFrame.new(0, -1.95, -0.35), Vector3.new(0.6, 0.45, 0.7), C.goldPale, Enum.Material.Metal)
	part(parent, "GnomeMoustache", head * CFrame.new(0, -0.42, -0.66), Vector3.new(1.1, 0.24, 0.16), C.goldPale, Enum.Material.Metal)
	-- the hat: a stack of shrinking blocks leaning back and over, with a brim
	part(parent, "GnomeHatBrim", head * CFrame.new(0, 0.66, 0), Vector3.new(1.75, 0.22, 1.4), C.goldDeep, Enum.Material.Metal)
	local hat = head * CFrame.new(0, 0.77, 0.05)
	local sizes = { 1.45, 1.15, 0.85, 0.58, 0.34 }
	for i, s in sizes do
		hat = hat * CFrame.new(0, 0.28, 0.04) * CFrame.Angles(math.rad(-7), 0, math.rad(4))
		part(parent, "GnomeHat", hat * CFrame.new(0, 0.14, 0), Vector3.new(s, 0.56, s * 0.92), C.goldDeep, Enum.Material.Metal)
		hat = hat * CFrame.new(0, 0.28, 0)
		local _ = i
	end
	ball(parent, "GnomeHatTip", hat * CFrame.new(0, 0.18, 0), 0.36, C.goldPale, Enum.Material.Metal)
	-- it's THE golden gnome: a few glints
	local spark = holder(parent, "GnomeGlints", head, Vector3.new(1.6, 2.6, 1.2))
	emitter(spark, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Rate = 2,
		Lifetime = NumberRange.new(0.6, 1.0),
		Speed = NumberRange.new(0.1, 0.3),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.35), NumberSequenceKeypoint.new(1, 0) }),
		Color = ColorSequence.new(Color3.fromRGB(255, 236, 150)),
		LightEmission = 1,
		LightInfluence = 0,
	})
end

-- `F`: the fireplace's middle at the floor on the wall, -Z into the room, X along the wall.
local function fireplace(ctx: Ctx, parent: Instance, F: CFrame)
	local rng = ctx.rng
	local W, D = 6.8, 2.8 -- width along the wall, how far it stands out
	local OPEN = 1.75 -- half the opening's width
	local OPEN_H = 3.4
	local function stone(name: string, cf: CFrame, size: Vector3, tone: Color3?)
		local p = part(parent, name, cf, size, jitter(rng, tone or C.stone, 0.07), nil, true)
		stoneLook(p)
		return p
	end
	-- the hearth
	stone("Hearth", F * CFrame.new(0, 0.2, -D - 0.7), Vector3.new(W + 1.0, 0.4, 1.6), C.stoneDark)
	-- the surround: rows of stones, the opening left free below its lintel
	local row = 0.8
	for r = 0, 6 do
		local y0 = r * row
		local runs = if y0 < OPEN_H then { { -W / 2, -OPEN }, { OPEN, W / 2 } } else { { -W / 2, W / 2 } }
		for _, run in runs do
			for _, piece in chop(rng, run[1], run[2], 0.8, 1.7) do
				local len = piece[2] - piece[1] - 0.06
				local bulge = rng:NextNumber(0, 0.12)
				stone("FireStone", F * CFrame.new((piece[1] + piece[2]) / 2, y0 + row / 2, -D / 2 - bulge / 2), Vector3.new(len, row - 0.06, D + bulge))
			end
		end
	end
	-- the dark lintel over the opening
	part(parent, "FireLintel", F * CFrame.new(0, OPEN_H + 0.3, -D - 0.12), Vector3.new(2 * OPEN + 1.2, 0.6, 0.3), C.timberDark)
	-- the firebox: soot inside, logs on an iron grate, the fire
	part(parent, "FireBack", F * CFrame.new(0, OPEN_H / 2, -0.35), Vector3.new(2 * OPEN, OPEN_H, 0.6), C.soot)
	for _, sx in { -1, 1 } do
		part(parent, "FireSide", F * CFrame.new(sx * (OPEN - 0.15), OPEN_H / 2, -D / 2), Vector3.new(0.3, OPEN_H, D - 0.4), C.soot)
	end
	part(parent, "FireTop", F * CFrame.new(0, OPEN_H - 0.15, -D / 2), Vector3.new(2 * OPEN, 0.3, D - 0.4), C.soot)
	part(parent, "Ash", F * CFrame.new(0, 0.42, -D / 2 - 0.1), Vector3.new(2 * OPEN - 0.3, 0.06, D - 0.8), Color3.fromRGB(70, 64, 60))
	for k = -1, 1 do
		local log = cyl(parent, "FireLog", F * CFrame.new(0, 0.75 + (if k == 0 then 0.35 else 0), -D / 2 - 0.1 + k * 0.45) * CFrame.Angles(0, 0, math.rad(90)), 2.6, 0.5, Color3.fromRGB(112, 72, 46), Enum.Material.Wood)
		log.CastShadow = false
	end
	for k = -2, 2 do
		part(parent, "Grate", F * CFrame.new(k * 0.6, 0.85, -D + 0.25), Vector3.new(0.12, 0.9, 0.12), C.iron)
	end
	part(parent, "GrateBar", F * CFrame.new(0, 1.2, -D + 0.25), Vector3.new(2.6, 0.12, 0.12), C.iron)
	-- flames: bright blocks plus soft particles and a warm light
	local flames = {
		{ Vector3.new(-0.5, 1.3, -1.4), Vector3.new(0.5, 0.9, 0.5), C.fire },
		{ Vector3.new(0.35, 1.45, -1.3), Vector3.new(0.55, 1.2, 0.5), C.fire },
		{ Vector3.new(-0.05, 1.35, -1.5), Vector3.new(0.35, 0.8, 0.35), C.fireCore },
		{ Vector3.new(0.8, 1.15, -1.5), Vector3.new(0.3, 0.5, 0.3), C.fireCore },
	}
	for _, f in flames do
		local p = part(parent, "Flame", F * CFrame.new(f[1]) * CFrame.Angles(0, math.rad(rng:NextNumber(-20, 20)), 0), f[2], f[3], Enum.Material.Neon)
		p.Transparency = 0.15
		p.CastShadow = false
	end
	local fireSpot = holder(parent, "Fire", F * CFrame.new(0, 1.3, -1.4), Vector3.new(2.2, 0.4, 1.0))
	emitter(fireSpot, {
		Texture = "rbxasset://textures/particles/fire_main.dds",
		Rate = 14,
		Lifetime = NumberRange.new(0.5, 0.8),
		Speed = NumberRange.new(1.2, 2.2),
		SpreadAngle = Vector2.new(8, 8),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0.1) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 90, 30)),
		LightEmission = 0.8,
		LightInfluence = 0,
	})
	emitter(fireSpot, {
		Name = "Embers",
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Rate = 3,
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(1.5, 2.5),
		SpreadAngle = Vector2.new(20, 20),
		Size = NumberSequence.new(0.18),
		Color = ColorSequence.new(Color3.fromRGB(255, 170, 60)),
		LightEmission = 1,
		LightInfluence = 0,
	})
	light(fireSpot, "PointLight", { Brightness = 0.7, Range = 11, Color = Color3.fromRGB(255, 150, 70) })
	-- the mantel on two corbels, and the chimney breast up to the beams
	part(parent, "Mantel", F * CFrame.new(0, 5.85, -D / 2 - 0.25), Vector3.new(W + 0.8, 0.5, D + 0.7), C.timber, nil, true)
	part(parent, "MantelTrim", F * CFrame.new(0, 5.55, -D - 0.55), Vector3.new(W + 0.8, 0.12, 0.12), C.timberDark)
	for _, sx in { -1, 1 } do
		part(parent, "MantelCorbel", F * CFrame.new(sx * (W / 2 - 0.4), 5.25, -D - 0.25), Vector3.new(0.6, 0.7, 0.6), C.timberDark)
	end
	local BW, BD = 4.8, 1.9
	for r = 0, 6 do
		local y0 = 6.1 + r * 1.2
		for _, piece in chop(rng, -BW / 2, BW / 2, 1.0, 2.0) do
			stone("ChimneyStone", F * CFrame.new((piece[1] + piece[2]) / 2, y0 + 0.6, -BD / 2 - rng:NextNumber(0, 0.06)), Vector3.new(piece[2] - piece[1] - 0.06, 1.14, BD))
		end
	end
	-- on the mantel: two candles, a potted flower and a jar of seeds
	local top = 6.1
	for _, x in { -2.9, 2.9 } do
		cyl(parent, "Candlestick", F * CFrame.new(x, top + 0.12, -D / 2), 0.24, 0.6, C.brass, Enum.Material.Metal)
		cyl(parent, "Candle", F * CFrame.new(x, top + 0.65, -D / 2), 0.85, 0.32, C.white)
		local fl = part(parent, "CandleFlame", F * CFrame.new(x, top + 1.2, -D / 2), Vector3.new(0.14, 0.26, 0.14), C.fireCore, Enum.Material.Neon)
		fl.CastShadow = false
	end
	cyl(parent, "Pot", F * CFrame.new(-1.6, top + 0.4, -D / 2 - 0.2), 0.8, 0.75, C.terracotta)
	for k = 0, 3 do
		part(parent, "PotLeaf", F * CFrame.new(-1.6 + (k % 2 - 0.5) * 0.4, top + 1.0 + k * 0.12, -D / 2 - 0.2 + (k // 2 - 0.5) * 0.3), Vector3.new(0.42, 0.42, 0.42), jitter(rng, C.leaf, 0.1))
	end
	part(parent, "PotFlower", F * CFrame.new(-1.55, top + 1.55, -D / 2 - 0.2), Vector3.new(0.34, 0.34, 0.34), FLOWERS[1])
	local jar = cyl(parent, "SeedJar", F * CFrame.new(1.7, top + 0.45, -D / 2 - 0.1), 0.9, 0.62, Color3.fromRGB(176, 214, 196), Enum.Material.Glass)
	jar.Transparency = 0.35
	cyl(parent, "SeedJarLid", F * CFrame.new(1.7, top + 0.95, -D / 2 - 0.1), 0.14, 0.66, C.brass, Enum.Material.Metal)
	-- the trophy
	gnomeTrophy(parent, F * CFrame.new(0, 10.0, -BD))
end

-------------------------------------------------------------------------------------------------------------
-- the other props inside
-------------------------------------------------------------------------------------------------------------
-- A picture in a wooden frame, `cf` its middle on the wall (-Z out).
local function painting(parent: Instance, cf: CFrame, w: number, h: number)
	part(parent, "PaintingFrame", cf * CFrame.new(0, 0, -0.15), Vector3.new(w + 0.7, h + 0.7, 0.3), C.timber)
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			part(parent, "PaintingCorner", cf * CFrame.new(sx * (w / 2 + 0.2), sy * (h / 2 + 0.2), -0.33), Vector3.new(0.55, 0.55, 0.1), C.brass, Enum.Material.Metal)
		end
	end
	local canvas = part(parent, "Painting", cf * CFrame.new(0, 0, -0.33), Vector3.new(w, h, 0.06), Color3.fromRGB(120, 180, 90))
	if ShopRoom.PAINTING ~= "" then
		local decal = Instance.new("Decal")
		decal.Face = Enum.NormalId.Front
		decal.Texture = ShopRoom.PAINTING
		decal.Parent = canvas
	end
	part(parent, "PaintingWire", cf * CFrame.new(0, h / 2 + 0.75, -0.08), Vector3.new(0.12, 0.6, 0.12), C.iron)
end

-- Chop's coats on wall pegs, lawn style: a peg rail on the wall (`cf` its middle, -Z out) with a green work jacket,
-- a red flannel shirt, a straw sun hat and a beanie.
local function wallPegs(ctx: Ctx, parent: Instance, cf: CFrame)
	local L = 3.6
	part(parent, "PegRail", cf * CFrame.new(0, 0, -0.15), Vector3.new(L, 0.45, 0.3), C.timber)
	local xs = { -1.3, -0.4, 0.5, 1.4 }
	for _, x in xs do
		part(parent, "Peg", cf * CFrame.new(x, 0.05, -0.5) * CFrame.Angles(math.rad(20), 0, 0), Vector3.new(0.18, 0.18, 0.6), C.timberDark)
	end
	-- a jacket: body, two sleeves, a collar, buttons
	local function jacket(x: number, col: Color3, stripe: Color3?)
		local at = cf * CFrame.new(x, -1.3, -0.42)
		part(parent, "JacketBody", at, Vector3.new(1.1, 2.0, 0.35), col, Enum.Material.Fabric)
		for _, sx in { -1, 1 } do
			part(parent, "JacketSleeve", at * CFrame.new(sx * 0.62, -0.1, 0.05) * CFrame.Angles(0, 0, math.rad(sx * 6)), Vector3.new(0.32, 1.7, 0.3), col:Lerp(Color3.new(0, 0, 0), 0.12), Enum.Material.Fabric)
		end
		part(parent, "JacketCollar", at * CFrame.new(0, 1.0, -0.05), Vector3.new(0.8, 0.25, 0.4), col:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Fabric)
		if stripe then
			for k = -1, 1 do
				part(parent, "JacketCheck", at * CFrame.new(0, k * 0.55, -0.19), Vector3.new(1.12, 0.14, 0.02), stripe, Enum.Material.Fabric)
			end
			part(parent, "JacketCheck", at * CFrame.new(0.2, 0, -0.19), Vector3.new(0.14, 2.0, 0.02), stripe, Enum.Material.Fabric)
		else
			for k = 0, 2 do
				part(parent, "JacketButton", at * CFrame.new(0, 0.5 - k * 0.5, -0.19), Vector3.new(0.12, 0.12, 0.05), C.brass, Enum.Material.Metal)
			end
		end
	end
	jacket(-1.3, Color3.fromRGB(70, 132, 70))
	jacket(-0.4 + 0.05, Color3.fromRGB(196, 56, 50), Color3.fromRGB(70, 30, 30))
	-- the straw hat and the beanie on the last two pegs
	local hat = cf * CFrame.new(0.55, -0.45, -0.75) * CFrame.Angles(math.rad(-70), 0, 0)
	cyl(parent, "HatBrim", hat, 0.12, 2.0, C.straw, Enum.Material.Fabric)
	cyl(parent, "HatCrown", hat * CFrame.new(0, 0.33, 0), 0.6, 1.05, C.straw, Enum.Material.Fabric)
	cyl(parent, "HatBand", hat * CFrame.new(0, 0.12, 0), 0.16, 1.1, C.red, Enum.Material.Fabric)
	local beanie = cf * CFrame.new(1.45, -0.35, -0.6)
	part(parent, "Beanie", beanie, Vector3.new(0.8, 0.7, 0.6), Color3.fromRGB(226, 140, 50), Enum.Material.Fabric)
	part(parent, "BeanieCuff", beanie * CFrame.new(0, -0.3, 0), Vector3.new(0.86, 0.22, 0.66), Color3.fromRGB(196, 110, 40), Enum.Material.Fabric)
	ball(parent, "BeaniePom", beanie * CFrame.new(0, 0.48, 0), 0.34, C.white, Enum.Material.Fabric)
	local _ = ctx
end

-- A cork notice board (`cf` its middle on the wall, -Z out) with notes and pins.
local function noticeBoard(ctx: Ctx, parent: Instance, cf: CFrame)
	local w, h = 3.4, 2.5
	part(parent, "NoticeFrame", cf * CFrame.new(0, 0, -0.12), Vector3.new(w + 0.5, h + 0.5, 0.24), C.timber)
	part(parent, "Cork", cf * CFrame.new(0, 0, -0.26), Vector3.new(w, h, 0.06), Color3.fromRGB(196, 150, 100), Enum.Material.Sand)
	local notes = {
		{ -0.95, 0.5, 1.0, 1.1, Color3.fromRGB(250, 246, 226), -6 },
		{ 0.25, 0.55, 0.9, 0.8, Color3.fromRGB(252, 230, 120), 8 },
		{ 1.15, 0.35, 0.8, 1.0, Color3.fromRGB(240, 240, 236), -4 },
		{ -0.6, -0.6, 1.2, 0.8, Color3.fromRGB(176, 220, 160), 5 },
		{ 0.75, -0.65, 0.9, 0.7, Color3.fromRGB(250, 196, 196), -9 },
	}
	for _, n in notes do
		local at = cf * CFrame.new(n[1], n[2], -0.3) * CFrame.Angles(0, 0, math.rad(n[6] + ctx.rng:NextNumber(-2, 2)))
		part(parent, "Note", at, Vector3.new(n[3], n[4], 0.03), n[5])
		-- a couple of scribbled lines
		for k = 0, 1 do
			part(parent, "NoteLine", at * CFrame.new(0, n[4] * 0.15 - k * n[4] * 0.25, -0.02), Vector3.new(n[3] * 0.7, 0.05, 0.01), Color3.fromRGB(110, 110, 120))
		end
		ball(parent, "Pin", at * CFrame.new(0, n[4] / 2 - 0.12, -0.06), 0.16, FLOWERS[ctx.rng:NextInteger(1, #FLOWERS)])
	end
end

-- An iron lantern hanging from a beam: `top` where the chain starts (world), `drop` how far down.
local function lantern(parent: Instance, top: CFrame, drop: number)
	part(parent, "LanternChain", top * CFrame.new(0, -drop / 2, 0), Vector3.new(0.1, drop, 0.1), C.iron)
	local at = top * CFrame.new(0, -drop - 0.7, 0)
	part(parent, "LanternCap", at * CFrame.new(0, 0.62, 0), Vector3.new(0.9, 0.3, 0.9), C.iron)
	part(parent, "LanternTop", at * CFrame.new(0, 0.85, 0), Vector3.new(0.4, 0.2, 0.4), C.iron)
	local core = part(parent, "LanternGlass", at, Vector3.new(0.65, 0.95, 0.65), C.lamp, Enum.Material.SmoothPlastic)
	core.Transparency = 0.1
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(parent, "LanternBar", at * CFrame.new(sx * 0.36, 0, sz * 0.36), Vector3.new(0.1, 1.05, 0.1), C.iron)
		end
	end
	part(parent, "LanternBase", at * CFrame.new(0, -0.58, 0), Vector3.new(0.85, 0.2, 0.85), C.iron)
	light(core, "PointLight", { Brightness = 0.4, Range = 12, Color = Color3.fromRGB(255, 208, 150) })
end

-- A barrel at `base` (floor) holding a rake, a broom and a shovel.
local function toolBarrel(ctx: Ctx, parent: Instance, base: CFrame)
	local h, d = 2.6, 2.0
	cyl(parent, "Barrel", base * CFrame.new(0, h / 2, 0), h, d, jitter(ctx.rng, Color3.fromRGB(150, 104, 66), 0.05), Enum.Material.Wood, true)
	for _, f in { 0.18, 0.82 } do
		cyl(parent, "Hoop", base * CFrame.new(0, h * f, 0), 0.22, d + 0.08, C.iron)
	end
	local handle = Color3.fromRGB(176, 130, 84)
	local function stick(tilt: CFrame, len: number)
		part(parent, "Handle", tilt * CFrame.new(0, len / 2, 0), Vector3.new(0.22, len, 0.22), handle)
		return tilt * CFrame.new(0, len, 0)
	end
	local rake = stick(base * CFrame.new(-0.4, 1.2, 0.2) * CFrame.Angles(math.rad(8), 0, math.rad(12)), 5.2)
	part(parent, "RakeHead", rake, Vector3.new(1.8, 0.24, 0.24), C.iron)
	for k = -3, 3 do
		part(parent, "RakeTine", rake * CFrame.new(k * 0.26, 0.28, 0), Vector3.new(0.08, 0.4, 0.08), C.iron)
	end
	local broom = stick(base * CFrame.new(0.4, 1.2, -0.1) * CFrame.Angles(math.rad(-6), 0, math.rad(-10)), 4.6)
	part(parent, "BroomBind", broom, Vector3.new(0.5, 0.3, 0.5), C.red)
	part(parent, "BroomStraw", broom * CFrame.new(0, 0.85, 0), Vector3.new(0.9, 1.4, 0.6), C.straw, Enum.Material.Fabric)
	local shovel = stick(base * CFrame.new(0, 1.2, 0.5) * CFrame.Angles(math.rad(12), 0, 0), 4.2)
	part(parent, "ShovelBlade", shovel * CFrame.new(0, 0.6, 0), Vector3.new(0.9, 1.1, 0.12), C.metal, Enum.Material.Metal)
end

-- Chop's round table: a round top on a stump, four stump stools, a round rug (ForgeGUI) under it, a seed tray on it
-- (Chop's game board), a watering can, a mug and a pot of flowers. `cf` = its middle on the ground.
local function tableSet(ctx: Ctx, parent: Instance, cf: CFrame)
	local rng = ctx.rng
	-- the rug: the round ForgeGUI rug on a flat holder (its corners are see-through), else two rings of cloth
	if ShopRoom.ROUND_RUG ~= "" then
		-- (the picture is 1672 x 941 with the rug 94% of its height in the middle: sized so the rug is 10 across)
		local rug = holder(parent, "Rug", cf * CFrame.new(0, FLOOR + 0.03, 0), Vector3.new(18.9, 0.05, 10.64))
		local decal = Instance.new("Decal")
		decal.Face = Enum.NormalId.Top
		decal.Texture = ShopRoom.ROUND_RUG
		decal.Parent = rug
	else
		cyl(parent, "Rug", cf * CFrame.new(0, FLOOR + 0.03, 0), 0.06, 10, Color3.fromRGB(86, 60, 46), Enum.Material.Fabric)
		cyl(parent, "Rug", cf * CFrame.new(0, FLOOR + 0.05, 0), 0.06, 8.4, C.runner, Enum.Material.Fabric)
	end
	-- the table: a round top on a thick stump
	local top = FLOOR + 3.0
	cyl(parent, "TableTop", cf * CFrame.new(0, top, 0), 0.4, 5.0, jitter(rng, C.board, 0.04), Enum.Material.Wood, true)
	cyl(parent, "TableEdge", cf * CFrame.new(0, top - 0.25, 0), 0.2, 5.1, C.timber, Enum.Material.Wood)
	cyl(parent, "TableStump", cf * CFrame.new(0, FLOOR + 1.4, 0), 2.8, 1.5, Color3.fromRGB(122, 84, 52), Enum.Material.Wood, true)
	for k = 0, 3 do
		local a = math.rad(k * 90 + 20)
		part(parent, "StumpRoot", cf * CFrame.Angles(0, a, 0) * CFrame.new(0, FLOOR + 0.3, -0.95) * CFrame.Angles(math.rad(-30), 0, 0), Vector3.new(0.6, 0.8, 0.8), Color3.fromRGB(112, 76, 48), Enum.Material.Wood)
	end
	local y = top + 0.2
	-- the seed tray: a little grid of soil cells, some sprouting (Chop's game board)
	local tray = cf * CFrame.new(0.3, y, -0.3) * CFrame.Angles(0, math.rad(15), 0)
	part(parent, "SeedTray", tray * CFrame.new(0, 0.08, 0), Vector3.new(2.0, 0.16, 2.0), C.timberDark)
	for gx = 0, 3 do
		for gz = 0, 3 do
			local cell = tray * CFrame.new(-0.72 + gx * 0.48, 0.19, -0.72 + gz * 0.48)
			part(parent, "SeedCell", cell, Vector3.new(0.42, 0.06, 0.42), if (gx + gz) % 2 == 0 then C.soil else Color3.fromRGB(110, 80, 56))
			if (gx * 3 + gz) % 3 == 0 then
				part(parent, "Sprout", cell * CFrame.new(0, 0.16, 0), Vector3.new(0.14, 0.26, 0.14), C.grass)
			end
		end
	end
	-- a watering can
	local can = cf * CFrame.new(-1.4, y, 0.9) * CFrame.Angles(0, math.rad(30), 0)
	part(parent, "CanBody", can * CFrame.new(0, 0.5, 0), Vector3.new(1.1, 1.0, 0.8), Color3.fromRGB(80, 170, 110), Enum.Material.Metal)
	part(parent, "CanTop", can * CFrame.new(0, 1.05, 0), Vector3.new(0.9, 0.1, 0.6), Color3.fromRGB(66, 146, 94), Enum.Material.Metal)
	part(parent, "CanSpout", can * CFrame.new(-0.85, 0.75, 0) * CFrame.Angles(0, 0, math.rad(-40)), Vector3.new(0.18, 1.0, 0.18), Color3.fromRGB(66, 146, 94), Enum.Material.Metal)
	part(parent, "CanRose", can * CFrame.new(-1.2, 1.15, 0), Vector3.new(0.3, 0.3, 0.3), Color3.fromRGB(66, 146, 94), Enum.Material.Metal)
	part(parent, "CanHandle", can * CFrame.new(0.35, 1.3, 0), Vector3.new(0.8, 0.14, 0.14), Color3.fromRGB(66, 146, 94), Enum.Material.Metal)
	-- a mug and a pot of flowers
	cyl(parent, "Mug", cf * CFrame.new(1.5, y + 0.3, 0.9), 0.6, 0.5, C.white)
	cyl(parent, "Pot", cf * CFrame.new(-1.0, y + 0.4, -1.4), 0.8, 0.8, C.terracotta)
	for k = 0, 4 do
		part(parent, "PotLeaf", cf * CFrame.new(-1.0 + (k % 2 - 0.5) * 0.36, y + 1.0 + k * 0.1, -1.4 + ((k // 2) % 2 - 0.5) * 0.3), Vector3.new(0.4, 0.4, 0.4), jitter(rng, C.leaf, 0.12))
	end
	for k = 0, 2 do
		part(parent, "PotFlower", cf * CFrame.new(-1.2 + k * 0.2, y + 1.55 + (k % 2) * 0.12, -1.5 + k * 0.1), Vector3.new(0.3, 0.3, 0.3), FLOWERS[(k + 2) % #FLOWERS + 1])
	end
	-- stump stools round it
	for k = 0, 3 do
		local a = math.rad(k * 90 + 45)
		local at = cf * CFrame.Angles(0, a, 0) * CFrame.new(0, FLOOR, -3.6) * CFrame.Angles(0, math.rad(rng:NextNumber(0, 90)), 0)
		cyl(parent, "Stool", at * CFrame.new(0, 0.95, 0), 1.9, 1.7, Color3.fromRGB(122, 84, 52), Enum.Material.Wood, true)
		cyl(parent, "StoolTop", at * CFrame.new(0, 1.92, 0), 0.08, 1.5, Color3.fromRGB(222, 184, 128), Enum.Material.Wood)
		cyl(parent, "StoolRing", at * CFrame.new(0, 1.95, 0), 0.06, 0.9, Color3.fromRGB(176, 130, 84), Enum.Material.Wood)
	end
end

-- Grass bundles (the clippings players carry) stacked against a wall: `cf` at the floor by the wall, -Z out, X along.
local function bundleStack(parent: Instance, cf: CFrame, bottom: number, deep: number)
	local L, H, Dp = 2.2, 1.5, 1.4
	local function put(x: number, y: number, z: number)
		if not Models.place("bundle", parent, cf * CFrame.new(x, y, z), 1, false) then
			part(parent, "Bundle", cf * CFrame.new(x, y + H / 2, z), Vector3.new(L, H, Dp), C.grass, Enum.Material.Grass, true)
		end
	end
	for row = 0, deep - 1 do
		for i = 0, bottom - 1 do
			put((i - (bottom - 1) / 2) * (L + 0.05), 0, -Dp / 2 - row * (Dp + 0.05))
		end
	end
	for i = 0, bottom - 2 do
		put((i - (bottom - 2) / 2) * (L + 0.05), H, -Dp / 2 - (deep - 1) * (Dp + 0.05) / 2)
	end
end

-------------------------------------------------------------------------------------------------------------
-- inside
-------------------------------------------------------------------------------------------------------------
local BACK = { -- x on the back wall, left to right as you come in (+X is on your left)
	{ id = "Scissors", x = 14.3 },
	{ id = "Sickle", x = 7.6 },
	{ id = "MegaScythe", x = 0, big = true },
	{ id = "PushMower", x = -7.6 },
	{ id = "WeedWhacker", x = -14.3 },
}

local function inside(ctx: Ctx, shop: Instance)
	local at = ctx.at
	local room = PropKit.folder("ShopRoom", shop)
	-- the boards on the back wall
	for _, b in BACK do
		local tool = toolDef(b.id)
		if tool then
			if b.big then
				local cf = at * CFrame.new(b.x, FLOOR + 7.1, ZB)
				local d, model = toolBoard(ctx, shop, tool, cf, { w = 7.4, h = 7.2, big = true })
				spotlight(ctx, d, cf, model)
			else
				toolBoard(ctx, shop, tool, at * CFrame.new(b.x, FLOOR + 6.1, ZB), { w = 5.4, h = 6.0 })
			end
		end
	end
	-- the Laser Mower on its bench against the left wall (+X), between the window and the front corner (away from
	-- the back wall, so its prompt never steals the Garden Scissors' E)
	local laser = toolDef("LaserMower")
	if laser then
		benchDisplay(ctx, shop, laser, at * CFrame.new(XI, FLOOR, -2.4) * CFrame.Angles(0, math.rad(90), 0))
	end
	-- the right wall (-X, the chimney side): the fireplace, bundles under the window, the shears, a barrel of rakes
	fireplace(ctx, room, at * CFrame.new(-XI, FLOOR, 9.9) * CFrame.Angles(0, math.rad(-90), 0))
	bundleStack(room, at * CFrame.new(-XI, FLOOR, 3.2) * CFrame.Angles(0, math.rad(-90), 0), 3, 2)
	local shearsAt = at * CFrame.new(-XI, FLOOR + 7.4, -3.0) * CFrame.Angles(0, math.rad(-90), 0)
	part(room, "ShearsBoard", shearsAt * CFrame.new(0, 0, -0.15), Vector3.new(4.6, 0.6, 0.3), C.timber)
	shears(room, shearsAt * CFrame.new(0, 0, -0.55), 0.95)
	for _, sx in { -1, 1 } do
		part(room, "ShearsHook", shearsAt * CFrame.new(sx * 1.4, 0.45, -0.45), Vector3.new(0.18, 0.5, 0.5), C.iron)
	end
	toolBarrel(ctx, room, at * CFrame.new(-XI + 1.6, FLOOR, ZF + 1.7))
	-- front left: the round table, the painting; by the door (the front wall, inside): coats on pegs, the notice board
	tableSet(ctx, room, at * CFrame.new(9.2, 0, 3.2))
	painting(room, at * CFrame.new(XI, FLOOR + 7.6, 10.4) * CFrame.Angles(0, math.rad(90), 0), 6.0, 3.35)
	local inFront = CFrame.Angles(0, math.rad(180), 0) -- facing into the room from the front wall
	wallPegs(ctx, room, at * CFrame.new(7.0, FLOOR + 7.2, ZF) * inFront)
	noticeBoard(ctx, room, at * CFrame.new(-7.4, FLOOR + 7.0, ZF) * inFront)
	-- two lanterns hanging from the tie beams
	for _, x in { -7, 7 } do
		lantern(room, at * CFrame.new(x, 14.25, 3.6), 2.2)
	end
	-- the runner from the door to the spotlight board
	local zA, zB = ZF + 0.6, 10.6
	part(room, "Runner", at * CFrame.new(0, FLOOR + 0.03, (zA + zB) / 2), Vector3.new(4.6, 0.06, zB - zA), C.runner, Enum.Material.Fabric)
	for _, sx in { -1, 1 } do
		part(room, "RunnerBorder", at * CFrame.new(sx * 1.95, FLOOR + 0.05, (zA + zB) / 2), Vector3.new(0.3, 0.06, zB - zA - 0.4), C.gold, Enum.Material.Fabric)
	end
end

-------------------------------------------------------------------------------------------------------------
-- outside
-------------------------------------------------------------------------------------------------------------
local function gnome(parent: Instance, base: CFrame)
	cyl(parent, "GnomeBase", base * CFrame.new(0, 0.15, 0), 0.3, 1.4, Color3.fromRGB(110, 170, 70), Enum.Material.Grass)
	part(parent, "GnomeBoots", base * CFrame.new(0, 0.5, 0), Vector3.new(1.0, 0.4, 0.8), Color3.fromRGB(80, 54, 40))
	part(parent, "GnomeBody", base * CFrame.new(0, 1.2, 0), Vector3.new(1.1, 1.1, 0.9), C.blue)
	part(parent, "GnomeBelt", base * CFrame.new(0, 0.95, 0), Vector3.new(1.16, 0.2, 0.96), Color3.fromRGB(60, 40, 30))
	part(parent, "GnomeFace", base * CFrame.new(0, 2.05, 0), Vector3.new(0.9, 0.7, 0.8), C.skin)
	ball(parent, "GnomeNose", base * CFrame.new(0, 2.0, -0.45), 0.38, Color3.fromRGB(240, 170, 140))
	part(parent, "GnomeBeard", base * CFrame.new(0, 1.55, -0.2), Vector3.new(1.0, 0.8, 0.6), C.white)
	part(parent, "GnomeBeard", base * CFrame.new(0, 1.05, -0.35), Vector3.new(0.6, 0.45, 0.35), C.white)
	local hat = base * CFrame.new(0, 2.45, 0)
	for _, s in { 1.05, 0.8, 0.55, 0.32 } do
		part(parent, "GnomeHat", hat * CFrame.new(0, 0.2, 0), Vector3.new(s, 0.42, s), C.red)
		hat = hat * CFrame.new(0, 0.4, 0.04) * CFrame.Angles(math.rad(-6), 0, 0)
	end
	for _, sx in { -1, 1 } do
		part(parent, "GnomeEye", base * CFrame.new(sx * 0.2, 2.2, -0.41), Vector3.new(0.12, 0.14, 0.04), Color3.fromRGB(40, 30, 20))
	end
end

local function wheelbarrow(parent: Instance, cf: CFrame)
	local red = Color3.fromRGB(196, 62, 52)
	-- the tray: a floor and four sloped sides
	part(parent, "TrayFloor", cf * CFrame.new(0, 1.5, 0), Vector3.new(2.4, 0.2, 3.0), red, Enum.Material.Metal, true)
	for _, sx in { -1, 1 } do
		part(parent, "TraySide", cf * CFrame.new(sx * 1.35, 2.05, 0) * CFrame.Angles(0, 0, math.rad(-sx * 15)), Vector3.new(0.18, 1.1, 3.2), red, Enum.Material.Metal)
	end
	for _, sz in { -1, 1 } do
		part(parent, "TrayEnd", cf * CFrame.new(0, 2.05, sz * 1.6) * CFrame.Angles(math.rad(sz * 18), 0, 0), Vector3.new(2.8, 1.1, 0.18), red, Enum.Material.Metal)
	end
	-- a heap of clippings
	part(parent, "Clippings", cf * CFrame.new(0, 2.25, 0), Vector3.new(2.5, 0.9, 3.0), C.grass, Enum.Material.Grass)
	part(parent, "Clippings", cf * CFrame.new(0.2, 2.8, -0.2), Vector3.new(1.6, 0.6, 1.9), Color3.fromRGB(96, 178, 60), Enum.Material.Grass)
	-- the wheel at the front, the handles and legs at the back
	local wheel = cyl(parent, "Wheel", cf * CFrame.new(0, 0.75, -2.0) * CFrame.Angles(0, 0, math.rad(90)), 0.45, 1.5, Color3.fromRGB(40, 38, 38), nil, true)
	local _ = wheel
	cyl(parent, "WheelHub", cf * CFrame.new(0, 0.75, -2.0) * CFrame.Angles(0, 0, math.rad(90)), 0.55, 0.45, C.metal, Enum.Material.Metal)
	for _, sx in { -1, 1 } do
		part(parent, "Handle", cf * CFrame.new(sx * 0.95, 1.5, 0.5) * CFrame.Angles(math.rad(-8), 0, 0), Vector3.new(0.22, 0.22, 5.2), C.timber)
		part(parent, "Grip", cf * CFrame.new(sx * 0.95, 1.85, 3.1), Vector3.new(0.3, 0.3, 0.7), Color3.fromRGB(40, 38, 38))
		part(parent, "Leg", cf * CFrame.new(sx * 0.95, 0.7, 1.2), Vector3.new(0.2, 1.4, 0.2), C.iron, nil, true)
	end
end

local function mailbox(parent: Instance, base: CFrame)
	part(parent, "MailPost", base * CFrame.new(0, 1.6, 0), Vector3.new(0.35, 3.2, 0.35), C.timber, nil, true)
	part(parent, "MailBox", base * CFrame.new(0, 3.55, 0), Vector3.new(0.9, 0.8, 1.6), Color3.fromRGB(70, 130, 200), Enum.Material.Metal)
	cyl(parent, "MailTop", base * CFrame.new(0, 3.95, 0) * CFrame.Angles(math.rad(90), 0, 0), 1.6, 0.9, Color3.fromRGB(70, 130, 200), Enum.Material.Metal)
	part(parent, "MailFlagPole", base * CFrame.new(0.5, 3.8, 0.2), Vector3.new(0.08, 0.9, 0.08), C.red)
	part(parent, "MailFlag", base * CFrame.new(0.5, 4.1, -0.05), Vector3.new(0.06, 0.35, 0.5), C.red)
end

-- A white picket fence along X at z (building space, on the ground) from x0 to x1, with a flower bed behind it
-- (toward the lodge, +Z).
local function picketFence(ctx: Ctx, parent: Instance, x0: number, x1: number, z: number, bedDepth: number)
	local at = ctx.at
	local len = math.abs(x1 - x0)
	-- -Z along the fence (toward +X), so the fence's +X is the lodge's +Z (behind the fence)
	local rot = at * CFrame.new((x0 + x1) / 2, 0, z) * CFrame.Angles(0, math.rad(-90), 0)
	for _, y in { 0.9, 2.0 } do
		part(parent, "FenceRail", rot * CFrame.new(0, y, 0), Vector3.new(0.18, 0.28, len), C.white, nil, true)
	end
	local n = math.floor(len / 0.8)
	for i = 0, n do
		local pz = -len / 2 + i * len / n
		part(parent, "Picket", rot * CFrame.new(-0.15, 1.25, pz), Vector3.new(0.14, 2.5, 0.42), C.white)
		part(parent, "PicketTip", rot * CFrame.new(-0.15, 2.6, pz) * CFrame.Angles(math.rad(45), 0, 0), Vector3.new(0.14, 0.3, 0.3), C.white)
	end
	for _, pz in { -len / 2, len / 2 } do
		part(parent, "FencePost", rot * CFrame.new(0, 1.4, pz), Vector3.new(0.45, 2.8, 0.45), C.white, nil, true)
		part(parent, "FenceCap", rot * CFrame.new(0, 2.9, pz), Vector3.new(0.6, 0.2, 0.6), C.white)
	end
	-- the bed behind the fence
	local bed = rot * CFrame.new(bedDepth / 2 + 0.25, 0, 0)
	part(parent, "FlowerBedSoil", bed * CFrame.new(0, 0.15, 0), Vector3.new(bedDepth, 0.3, len - 0.4), C.soil, Enum.Material.Ground)
	local m = math.floor(len / 0.9)
	for i = 0, m - 1 do
		local bz = -len / 2 + 0.6 + i * (len - 1.2) / math.max(m - 1, 1)
		for k = 0, 1 do
			local x = (k - 0.5) * bedDepth * 0.5 + ctx.rng:NextNumber(-0.15, 0.15)
			local s = ctx.rng:NextNumber(0.55, 0.85)
			part(parent, "BedLeaf", bed * CFrame.new(x, 0.3 + s / 2, bz), Vector3.one * s, jitter(ctx.rng, C.leaf, 0.12))
			if (i + k) % 2 == 0 then
				part(parent, "BedFlower", bed * CFrame.new(x, 0.3 + s + 0.18, bz), Vector3.one * 0.4, FLOWERS[ctx.rng:NextInteger(1, #FLOWERS)])
			end
		end
	end
end

local function outside(ctx: Ctx, shop: Instance, withSign: boolean)
	local at = ctx.at
	local yard = PropKit.folder("ShopYard", shop)
	-- the roof piece: giant hedge shears on a carved wooden medallion on the front slope
	local medal = at * CFrame.new(0, 25.0, -4.6)
	local disc = cyl(yard, "Medallion", medal * CFrame.Angles(math.rad(90), 0, 0), 0.7, 10.2, C.timber, nil, true)
	local _ = disc
	cyl(yard, "MedallionFace", medal * CFrame.new(0, 0, -0.4) * CFrame.Angles(math.rad(90), 0, 0), 0.2, 8.8, C.board)
	cyl(yard, "MedallionRing", medal * CFrame.new(0, 0, -0.45) * CFrame.Angles(math.rad(90), 0, 0), 0.12, 7.4, C.timberDark)
	cyl(yard, "MedallionInner", medal * CFrame.new(0, 0, -0.5) * CFrame.Angles(math.rad(90), 0, 0), 0.1, 7.0, Color3.fromRGB(120, 186, 80), Enum.Material.Grass)
	for k = 0, 11 do
		local a = math.rad(k * 30)
		part(yard, "MedallionStud", medal * CFrame.new(math.cos(a) * 4.7, math.sin(a) * 4.7, -0.45), Vector3.new(0.35, 0.35, 0.2), C.iron)
	end
	part(yard, "MedallionProp", medal * CFrame.new(0, -3.0, 2.2) * CFrame.Angles(math.rad(-40), 0, 0), Vector3.new(0.6, 5.0, 0.6), C.timberDark)
	shears(yard, medal * CFrame.new(0, 0.4, -1.0), 1.85)
	if withSign then
		local sign = part(yard, "RoofSign", medal * CFrame.new(0, -4.1, -1.2), Vector3.new(9.0, 1.9, 0.4), C.plaque, Enum.Material.Wood)
		textOn(sign, "TOOL SHOP", PropKit.TITLE)
	end
	-- the picket fence and flower beds either side of the steps
	-- (in front of the porch deck, which ends at z -16.2; the steps run out to -18.4 between x -5.4 and 5.4)
	picketFence(ctx, yard, 6.2, 13.0, -17.7, 1.1)
	picketFence(ctx, yard, -13.0, -6.2, -17.7, 1.1)
	-- props round the porch
	wheelbarrow(yard, at * CFrame.new(18.6, 0, -13.4) * CFrame.Angles(0, math.rad(-150), 0))
	gnome(yard, at * CFrame.new(-7.4, 0, -19.2) * CFrame.Angles(0, math.rad(-15), 0))
	mailbox(yard, at * CFrame.new(7.6, 0, -19.4))
	bundleStack(yard, at * CFrame.new(-16.8, 0, -10.6) * CFrame.Angles(0, math.rad(180), 0), 3, 1)
	-- a watering can by the gnome
	local can = at * CFrame.new(-8.9, 0, -19.5) * CFrame.Angles(0, math.rad(40), 0)
	part(yard, "CanBody", can * CFrame.new(0, 0.5, 0), Vector3.new(1.1, 1.0, 0.8), Color3.fromRGB(80, 170, 110), Enum.Material.Metal)
	part(yard, "CanSpout", can * CFrame.new(-0.85, 0.75, 0) * CFrame.Angles(0, 0, math.rad(-40)), Vector3.new(0.18, 1.0, 0.18), Color3.fromRGB(66, 146, 94), Enum.Material.Metal)
	part(yard, "CanHandle", can * CFrame.new(0.35, 1.3, 0), Vector3.new(0.8, 0.14, 0.14), Color3.fromRGB(66, 146, 94), Enum.Material.Metal)
end

-------------------------------------------------------------------------------------------------------------
-- The shop's room, displays and yard, in the lodge at `at` (server/RunBuilder, after CampBuildings.shop).
function ShopRoom.build(shop: Instance, at: CFrame, withSign: boolean?)
	local ctx: Ctx = { at = at, rng = Random.new(3010) }
	inside(ctx, shop)
	outside(ctx, shop, withSign == true)
end

return ShopRoom
