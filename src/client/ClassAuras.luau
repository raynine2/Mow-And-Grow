-- Class auras (owner, 31 Oct: "revamp all the effects of every class ... make the animations match the rarity, the
-- higher the rarity, the higher and more detailed the quality ... as high quality as SOLS RNG, yet still matching our
-- games design style ... smooth, cool and really be unique", and "make the effects match their icon, abilities,
-- functions etc ... it has to be around what each class does").
--
-- client/RarityFx calls this with its building blocks (`K`); this module adds the revamp's own blocks (`H`) and loads
-- one child module per class (each returns its aura builder). RarityFx still places everything every frame, parks far
-- auras, hides the body pieces in your own first-person view and dims the ground pieces while you run and in boss
-- fights. Every aura is built round its class card's picture and its gimmick, and shows the gimmick working:
--   Weed Puller        uprooted dandelions circling you; 6 sprouts light up swing by swing to the Root Rip
--   Gardener           red pruning shears snipping round you; a vine ring at your Green Thumb reach
--   Groundskeeper      a sickle sweeping a mown circle in chalk lines; 2 grass bundles (the 2 Tidy Up free hits)
--   Lawn Baron         a top hat over your head spilling coins; 12 coins light up to the next Courier
--   Hedge Reaper       a vine-wrapped spectral scythe that sweeps round you, dark brambles; 8 soul flames light up to
--                      the Reap Wave
--   Mower Specialist   the mower blade under you, the mower's orange engine on your back; Turbo Deck when you ride
--                      (client/ClassFx)
--   Grass Titan        mossy boulder boots on your feet (they glow when the Titan Stomp is ready), the stomp's reach
--   Ultimate Gardener  a golden watering can pouring gold round you (Midas Touch), a sunflower halo, golden wings
--   Lawn Legend        the crown of leaves and roses, its leaves catching fire with the Hot Streak, the same wreath as a
--                      great halo behind you, flame wings, fire that grows with the streak
--   Goat Man           golden ram horns and sunglasses, a meadow emblem the size of your Graze, grass streaming in
--                      to be eaten (a bite every 0.75 s as you walk), giant spirit horns of light, a golden column
-- "Detail" pieces switch off for other players' auras past 60 studs, on phones and in Potato Mode.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local function id(n: number): string
	return "rbxassetid://" .. tostring(n)
end
-- our own aura textures (made for this game, 31 Oct; uploaded by bbrrbrrbrbrb). White ones are tinted per class;
-- the c* sigils are baked in their class's colours. A class's colours come from what it is and does (its tool, its
-- gimmick), never from its rarity: the cards' backgrounds are the rarity's colour, so they're not copied.
local T = {
	cSoil = id(128187869447191), -- Weed Puller: soil, cracks, sprouts and dandelions
	cVine = id(94749266091710), -- Gardener: a vine wreath with pink and yellow flowers
	cLawn = id(124697402510269), -- Groundskeeper: a mown circle in a crisp chalk-white frame (like a pitch's lines)
	cThorn = id(104838248033200), -- Hedge Reaper: a dark pool, a ring of dark bramble thorns, mint reaping crescents
	cSun = id(78008373227585), -- Ultimate Gardener: sun rays, leaves, a sunflower heart
	cLegend = id(130476954683032), -- Lawn Legend: a wreath of leaves and red roses, a clover jewel, a heart of fire
	cGoat = id(138039686087147), -- Goat Man: a meadow, two golden ram horns round a gold-edged grass tuft, a gold rim
	chain = id(87379465799383), -- a chainsaw chain strip (beams)
	sigSun = id(99680872451783),
	sigCoin = id(124502312757293),
	saw = id(99657883820812),
	gear = id(80046414636454),
	sigRune = id(117798502139772),
	sunflower = id(90798513299543),
	galaxy = id(98177835238703),
	blackhole = id(114511131215296),
	wingVineL = id(115950898616383),
	wingVineR = id(129538988492701),
	wingBladeL = id(93803597532260),
	wingBladeR = id(78709893752408),
	flame = id(121208167011523), -- 4x4 flipbook
	wisp = id(126327675942159),
	coin = id(128871336135848),
	bill = id(127957675489853), -- a green banknote, white border, clover seal
	energy = id(101387044982652),
	vineStrip = id(89987547908830),
	runeStrip = id(127097074602119),
	ringCrisp = id(98405192233320),
	flash = id(87243885184203), -- (LihFolk Asset Pack)
	crescent = id(127095313671439), -- 4x4 flipbook (LihFolk)
	glint = id(93030574875002), -- 4x4 flipbook (LihFolk)
	streak = id(81969979283442), -- (LihFolk)
	stripBody = id(73446398119013), -- (LihFolk)
}

local WHITE = Color3.new(1, 1, 1)
local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end
local function ns(...: number): NumberSequence
	local v = { ... }
	local kps = {}
	for i = 1, #v, 2 do
		table.insert(kps, NumberSequenceKeypoint.new(v[i], v[i + 1]))
	end
	return NumberSequence.new(kps)
end
local function ease(k: number): number -- out-back: overshoots a touch and settles (formations)
	k = math.clamp(k, 0, 1)
	local c = 1.70158
	return 1 + (c + 1) * (k - 1) ^ 3 + c * (k - 1) ^ 2
end
local function smooth(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

local player = Players.LocalPlayer
local potato = false
local phone = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
pcall(function()
	local Potato = require(script.Parent:WaitForChild("Potato", 5) :: ModuleScript) :: any
	potato = Potato.on == true
	Potato.changed(function(on)
		potato = on == true
	end)
end)
pcall(function()
	local PhonePerf = require(script.Parent:WaitForChild("PhonePerf", 5) :: ModuleScript) :: any
	phone = phone or PhonePerf.on == true
end)

-- the gimmicks the server announces ("classFx": rootRip, tidy, courier, reapWave, stomp, midas, graze): each aura
-- that cares registers here and hears the ones that land near its owner
local listeners = setmetatable({}, { __mode = "k" }) :: { [any]: (string, any) -> () }
local swingCount = 0 -- your own swings (client/Input emits "swing" locally)
pcall(function()
	local State = require(script.Parent:WaitForChild("State", 5) :: ModuleScript) :: any
	State.on("swing", function()
		swingCount += 1
	end)
	State.on("fx", function(kind: string, d: any)
		if kind ~= "classFx" or type(d) ~= "table" then
			return
		end
		for _, fn in listeners do
			task.spawn(fn, d.kind, d)
		end
	end)
end)

return function(K: any): { [string]: () -> any }
	local H: any = {
		K = K,
		T = T,
		rgb = rgb,
		ns = ns,
		ease = ease,
		smooth = smooth,
		WHITE = WHITE,
		RANK = K.RANK,
		FX = K.FX,
		BFX = K.BFX,
		player = player,
		UPRIGHT = CFrame.Angles(math.rad(90), 0, 0),
	}

	-- an aura with the revamp's extras: per-frame jobs, detail (LOD) list, formation hook, born time
	function H.aura(rank: number, color: Color3): any
		local a = K.newAura(rank, color)
		a.born = os.clock()
		a.jobs = {}
		a.detail = {}
		a.lowNow = false
		a.glowFades = {} -- { img, base }: ground images that dim while you run / fight
		a.hueImgs = {} -- images that cycle through the rainbow
		a.glowGround = -1
		a.rootPos = Vector3.zero
		a.tick = function(self, f)
			self.rootPos = f.root.Position
			self.owner = f.player
			-- the ground images stay half-lit while you run (they used to all but vanish), and dim in boss fights
			local fighting = f.player ~= nil and f.player:GetAttribute("BossHP") ~= nil
			local g = if fighting then f.ground else 0.5 + 0.5 * f.calm
			if math.abs(g - self.glowGround) > 0.03 then
				self.glowGround = g
				for _, gf in self.glowFades do
					gf.img.ImageTransparency = 1 - (1 - gf.base) * g
				end
			end
			if #self.hueImgs > 0 then
				local c = Color3.fromHSV(f.hue, 0.75, 1)
				for _, img in self.hueImgs do
					img.ImageColor3 = c
				end
			end
			local cam = workspace.CurrentCamera
			local far = f.player ~= player and cam ~= nil and (cam.CFrame.Position - f.root.Position).Magnitude > 60
			local low = potato or phone or far
			if low ~= self.lowNow then
				self.lowNow = low
				for _, inst in self.detail do
					if inst:IsA("BasePart") then
						inst.LocalTransparencyModifier = if low then 1 else 0
					else
						(inst :: any).Enabled = not low
					end
				end
			end
			for _, job in self.jobs do
				job(self, f)
			end
		end
		return a
	end
	function H.detail(a: any, ...: Instance)
		for _, inst in { ... } do
			table.insert(a.detail, inst)
		end
	end
	function H.job(a: any, fn: (any, any) -> ())
		table.insert(a.jobs, fn)
	end
	-- hear this aura's owner's gimmick (within `range` studs of them)
	function H.gimmick(a: any, kinds: { [string]: boolean }, range: number, fn: (any, any) -> ())
		listeners[a] = function(kind: string, d: any)
			if kinds[kind] and typeof(d.pos) == "Vector3" and (d.pos - a.rootPos).Magnitude < range then
				fn(a, d)
			end
		end
	end
	-- your own swings so far (nil for other players: their swings aren't sent to us)
	function H.swings(f: any): number?
		if f.player ~= nil and f.player == player then
			return swingCount
		end
		return nil
	end

	-- K.emitter plus flipbooks, own curves, inward flow, attachments as parents
	function H.E(parent: Instance, o: any): ParticleEmitter
		local e = K.emitter(parent, o)
		if o.flip then
			e.FlipbookLayout = if o.flip == 8 then Enum.ParticleFlipbookLayout.Grid8x8 else Enum.ParticleFlipbookLayout.Grid4x4
			e.FlipbookMode = o.flipMode or Enum.ParticleFlipbookMode.OneShot
		end
		if o.trans then
			e.Transparency = o.trans
		end
		if o.sizeSeq then
			e.Size = o.sizeSeq
		end
		if o.lock then
			e.LockedToPart = true
		end
		if o.inward then
			e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
		end
		if o.surface then
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		end
		if o.orient then
			e.Orientation = o.orient
		end
		if o.squash then
			e.Squash = o.squash
		end
		if o.rot then
			e.Rotation = NumberRange.new(o.rot[1], o.rot[2])
		end
		return e
	end
	local E = H.E

	function H.att(parent: Instance, pos: Vector3): Attachment
		local at = Instance.new("Attachment")
		at.Position = pos
		at.Parent = parent
		return at
	end
	local att = H.att

	function H.beam(a0: Attachment, a1: Attachment, o: any): Beam
		local b = Instance.new("Beam")
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.FaceCamera = o.face ~= false
		b.Width0 = o.w0 or 0.3
		b.Width1 = o.w1 or o.w0 or 0.3
		b.Color = o.colors or ColorSequence.new(WHITE)
		b.Transparency = o.trans or NumberSequence.new(0)
		b.LightEmission = o.light or 1
		b.LightInfluence = 0
		b.Segments = o.segments or 1
		if o.tex then
			b.Texture = o.tex
			b.TextureMode = o.texMode or Enum.TextureMode.Wrap
			b.TextureLength = o.texLen or 2
			b.TextureSpeed = o.texSpeed or 0
		end
		if o.curve0 then
			b.CurveSize0 = o.curve0
			b.CurveSize1 = o.curve1 or 0
		end
		b.ZOffset = o.zoff or 0
		K.bright(b, o.bright or 1.6)
		b.Parent = a0.Parent
		return b
	end
	-- a chain of beams through points: widths taper from w0 to w1
	function H.chain(holder: BasePart, pts: { Vector3 }, o: any): { Beam }
		local atts = {}
		for i, p in pts do
			atts[i] = att(holder, p)
		end
		local list = {}
		local w0, w1 = o.w0 or 0.3, o.w1 or 0.05
		for i = 1, #pts - 1 do
			local k0, k1 = (i - 1) / (#pts - 1), i / (#pts - 1)
			list[i] = H.beam(atts[i], atts[i + 1], { colors = o.colors, w0 = w0 + (w1 - w0) * k0, w1 = w0 + (w1 - w0) * k1, trans = o.trans, light = o.light, bright = o.bright, tex = o.tex, texLen = o.texLen, texSpeed = o.texSpeed, zoff = o.zoff })
		end
		return list
	end

	-- a plate standing up behind you facing back (its underside faces forward), spun in its own plane
	function H.facing(pos: Vector3, f: any, spin: number): CFrame
		return CFrame.new(pos) * f.yaw * H.UPRIGHT * CFrame.Angles(0, spin, 0)
	end

	-- limbs (R15 names, R6 fallbacks), cached per character
	local R6 = { RightHand = "Right Arm", LeftHand = "Left Arm", UpperTorso = "Torso", RightFoot = "Right Leg", LeftFoot = "Left Leg", Head = "Head" }
	local limbCache = setmetatable({}, { __mode = "k" })
	function H.limb(f: any, name: string): BasePart?
		local char = f.char
		if not char then
			return nil
		end
		local c = limbCache[char]
		if not c then
			c = {}
			limbCache[char] = c
		end
		local p = c[name]
		if p == nil or (p and not p.Parent) then
			p = char:FindFirstChild(name) or char:FindFirstChild(R6[name] or "") or false
			c[name] = p
		end
		return p or nil
	end

	-- solid pieces (props built from parts): a part, a ball/ellipsoid, a cylinder along its X axis
	function H.solid(parent: Instance, size: Vector3, color: Color3, material: Enum.Material?, reflect: number?): Part
		local p = K.piece(parent, size, color, 0)
		p.Material = material or Enum.Material.SmoothPlastic
		p.Reflectance = reflect or 0
		return p
	end
	function H.ellipsoid(parent: Instance, size: Vector3, color: Color3, material: Enum.Material?): Part
		local p = H.solid(parent, size, color, material)
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = p
		return p
	end
	function H.cyl(parent: Instance, length: number, dia: number, color: Color3, material: Enum.Material?, reflect: number?): Part
		local p = H.solid(parent, Vector3.new(length, dia, dia), color, material, reflect)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	-- a group of parts that moves as one: `base(f)` places the group, each part sits at its own offset
	function H.rig(a: any, base: (any) -> CFrame, pieces: { { BasePart | CFrame } })
		for _, pc in pieces do
			local part, off = pc[1] :: BasePart, pc[2] :: CFrame
			K.move(a, part, function(f)
				return base(f) * off
			end)
		end
	end

	-- a ground piece that follows your feet, turning
	function H.feetPiece(a: any, size: Vector3, lift: number?, spin: number?): BasePart
		local p = K.piece(a.model, size)
		local y = lift or 0.2
		local s = spin or 0
		K.move(a, p, function(f)
			return CFrame.new(f.feet + Vector3.new(0, y, 0)) * CFrame.Angles(0, f.t * s, 0)
		end)
		return p
	end

	-- a flat plate whose image GLOWS (a SurfaceGui that ignores the light; decals are lit like paint and vanish on
	-- sunny grass). `both`: the underside too. Brightness stays near 1 so the colours don't bleach to pastel.
	function H.plate(parent: Instance, size: number, tex: string, color: Color3, transparency: number, both: boolean?, glow: number?): (BasePart, { ImageLabel }, { SurfaceGui })
		local p = K.piece(parent, Vector3.new(size, 0.05, size))
		local imgs, guis = {}, {}
		for _, face in if both then { Enum.NormalId.Top, Enum.NormalId.Bottom } else { Enum.NormalId.Top } do
			local g = Instance.new("SurfaceGui")
			g.Face = face
			g.LightInfluence = 0
			g.Brightness = glow or 1.15
			g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
			g.CanvasSize = Vector2.new(512, 512)
			g.MaxDistance = 150
			g.ResetOnSpawn = false
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Size = UDim2.fromScale(1, 1)
			img.Image = tex
			img.ImageColor3 = color
			img.ImageTransparency = transparency
			img.Parent = g
			g.Parent = p
			table.insert(imgs, img)
			table.insert(guis, g)
		end
		return p, imgs, guis
	end
	-- a glowing image on the ground under you, turning at `spin` rad/s
	function H.glowDisc(a: any, size: number, tex: string, color: Color3, transparency: number, spin: number, lift: number?, glow: number?): (BasePart, { ImageLabel }, { SurfaceGui })
		local p, imgs, guis = H.plate(a.model, size, tex, color, transparency, false, glow)
		for _, img in imgs do
			table.insert(a.glowFades, { img = img, base = transparency })
		end
		local y = lift or 0.1
		K.move(a, p, function(f)
			return CFrame.new(f.feet + Vector3.new(0, y, 0)) * CFrame.Angles(0, f.t * spin, 0)
		end)
		return p, imgs, guis
	end
	-- a smooth glowing ring on the ground of radius r (the ringCrisp texture's ring sits at 92% of its half-width)
	function H.glowRing(a: any, r: number, color: Color3, transparency: number, spin: number?, lift: number?, glow: number?): (BasePart, { ImageLabel }, { SurfaceGui })
		return H.glowDisc(a, r * 2 / 0.92, T.ringCrisp, color, transparency, spin or 0, lift or 0.14, glow or 1.4)
	end
	-- the class sigil: grows in from nothing when the aura forms (out-back ease), then turns
	function H.sigil(a: any, size: number, tex: string, color: Color3, transparency: number, spin: number, lift: number?, grow: number?, glow: number?): (BasePart, { ImageLabel })
		local p, imgs = H.glowDisc(a, size, tex, color, transparency, spin, lift or 0.12, glow or 1.2)
		local dur = grow or 0.7
		p.Size = Vector3.new(0.1, 0.05, 0.1)
		local done = false
		H.job(a, function(self, f)
			if done then
				return
			end
			local k = (f.t - self.born) / dur
			local s = math.max(0.1, size * ease(k))
			p.Size = Vector3.new(s, 0.05, s)
			done = k >= 1
		end)
		return p, imgs
	end

	-- the aura itself: a soft coloured bloom held round the body, a glowing haze, upright wisps rising off the whole
	-- body and (Rare and up) twinkling stars; all bigger, denser and brighter the rarer the aura. The wisps are half
	-- additive so they keep their colour against a bright sky instead of washing out to white.
	function H.shell(a: any, colors: ColorSequence, rate: number, size: number?): (ParticleEmitter, ParticleEmitter)
		local s = size or 1
		local r = a.rank or 3
		local box = K.bodyBox(a, Vector3.new(2.4, 4.8, 1.6), -0.3)
		local core = K.bodyBox(a, Vector3.new(0.4, 0.4, 0.4), 0)
		-- (council r3: the bloom washed the avatar out at the top rarities, so it stays soft and a touch dimmer as it grows)
		local bloom = E(core, { tex = K.FX.glow, colors = colors, rate = 1.4 + r * 0.2, life = { 1.5, 2 }, speed = { 0, 0 }, size = s * (3.4 + r * 0.4), spread = 0, light = 1, bright = 1, lock = true, trans = ns(0, 1, 0.35, 0.86, 0.7, 0.9, 1, 1) })
		local haze = E(box, { tex = K.FX.glow, colors = colors, rate = rate * 0.6, life = { 0.8, 1.2 }, speed = { 0.4, 1 }, size = s * 2.2, grow = true, spread = 20, light = 1, bright = 1.4, trans = ns(0, 1, 0.3, 0.55, 1, 1) })
		local wisps = E(box, { tex = T.wisp, colors = colors, rate = rate * (0.9 + r * 0.12), life = { 0.6, 1 }, speed = { 1.5, 2.8 }, size = s * 1.35, accel = Vector3.new(0, 2, 0), spread = 8, light = 0.7, bright = 1.6, orient = Enum.ParticleOrientation.FacingCameraWorldUp, trans = ns(0, 1, 0.25, 0.2, 1, 1), sizeSeq = ns(0, s * 0.7, 0.4, s * 1.5, 1, s * 0.35) })
		K.addEmitter(a, bloom)
		K.addEmitter(a, haze)
		K.addEmitter(a, wisps)
		H.detail(a, haze, bloom)
		if r >= 3 then
			local field = K.bodyBox(a, Vector3.new(3.2 + r * 0.25, 5.2, 3.2 + r * 0.25), 0)
			local stars = E(field, { tex = T.glint, flip = 4, colors = ColorSequence.new(WHITE), rate = r * 1.6, life = { 0.5, 0.9 }, speed = { 0, 0.3 }, size = 0.35 + r * 0.06, spread = 180, light = 1, bright = 2.2 })
			K.addEmitter(a, stars)
			H.detail(a, stars)
		end
		return haze, wisps
	end
	-- a pair of wings on your back, the same seen from behind and in front: each wing is two one-sided plates back to
	-- back (a SurfaceGui is only drawn on its own side), the back one showing the wing as it is, the front one showing
	-- its mirror art so the root still meets your shoulder. `wingCF(f, side)` places the wing (side -1 left, 1 right)
	-- as a plate standing up at your back; texL / texR are the left and right wings as seen from behind.
	local FRONT = CFrame.Angles(math.rad(-90), 0, 0) * CFrame.Angles(0, math.pi, 0)
	function H.wings(a: any, texL: string, texR: string, color: Color3, size: number, glow: number?, wingCF: (any, number) -> CFrame): { BasePart }
		local list = {}
		for _, side in { -1, 1 } do
			local back = H.plate(a.body, size, if side > 0 then texR else texL, color, 0, false, glow)
			local front = H.plate(a.body, size, if side > 0 then texL else texR, color, 0, false, glow)
			K.move(a, back, function(f)
				return wingCF(f, side) * H.UPRIGHT
			end)
			K.move(a, front, function(f)
				return wingCF(f, side) * CFrame.new(0, 0, -0.03) * FRONT
			end)
			table.insert(list, back)
			table.insert(list, front)
		end
		return list
	end
	-- a solid blade along a polyline (a sickle, a scythe, shear blades, a chainsaw bar...): one block per segment,
	-- its width tapering from w0 to w1, `thick` thick, lying in the plane its points make with `up` (default local Y);
	-- an optional glowing edge strip runs along one side. Returns pieces for H.rig (offsets in the rig's frame).
	function H.blade(parent: Instance, pts: { Vector3 }, w0: number, w1: number, thick: number, color: Color3, material: Enum.Material?, edge: Color3?, up: Vector3?): { { BasePart | CFrame } }
		local pieces = {}
		local n = #pts - 1
		local upv = up or Vector3.yAxis
		for i = 1, n do
			local p0, p1 = pts[i], pts[i + 1]
			local mid = (p0 + p1) / 2
			local len = (p1 - p0).Magnitude + 0.03
			local w = w0 + (w1 - w0) * ((i - 0.5) / n)
			local cf = CFrame.lookAt(mid, p1, upv) -- (local -Z along the blade, local Y = up, local X = across)
			table.insert(pieces, { H.solid(parent, Vector3.new(w, thick, len), color, material or Enum.Material.Metal, 0.25), cf })
			if edge then
				table.insert(pieces, { H.solid(parent, Vector3.new(math.max(0.05, w * 0.18), thick * 1.25, len), edge, Enum.Material.Neon), cf * CFrame.new(w * 0.45, 0, 0) })
			end
		end
		return pieces
	end
	-- a loop of `n` short blocks round a circle of radius r in the rig's XY plane (a handle loop, a crown ring...)
	function H.loop(parent: Instance, r: number, thick: number, n: number, color: Color3, material: Enum.Material?, at: CFrame?): { { BasePart | CFrame } }
		local pieces = {}
		local base = at or CFrame.identity
		for i = 1, n do
			local th = (i - 0.5) / n * math.pi * 2
			local len = 2 * math.pi * r / n + 0.04
			table.insert(pieces, { H.solid(parent, Vector3.new(len, thick, thick), color, material), base * CFrame.Angles(0, 0, th) * CFrame.new(0, r, 0) })
		end
		return pieces
	end
	-- a rounded rock: three overlapping stone lumps (real balls, so the stone texture shows), a mossy cap, and
	-- (optionally) thin glowing cracks running across it. Returns its pieces (for H.rig) and the cracks (the first one
	-- is returned on its own too).
	function H.rock(parent: Instance, s: number, stone: Color3, dark: Color3, moss: Color3?, crack: Color3?): ({ { BasePart | CFrame } }, BasePart?, { BasePart })
		local function lump(d: number, color: Color3): Part
			local p = H.solid(parent, Vector3.one * d, color, Enum.Material.Slate)
			p.Shape = Enum.PartType.Ball
			return p
		end
		local pieces = {
			{ lump(s, stone), CFrame.new() },
			{ lump(s * 0.8, dark), CFrame.new(s * 0.3, -s * 0.08, -s * 0.12) },
			{ lump(s * 0.72, stone), CFrame.new(-s * 0.26, s * 0.06, s * 0.16) },
		}
		if moss then
			local cap = H.solid(parent, Vector3.one * s * 0.78, moss, Enum.Material.Grass)
			cap.Shape = Enum.PartType.Ball
			table.insert(pieces, { cap, CFrame.new(s * 0.02, s * 0.2, 0) })
		end
		local cracks = {}
		if crack then
			for k, ang in { { 0.3, 0.6, 0.25 }, { -0.5, 1.9, -0.4 } } do
				local c = H.solid(parent, Vector3.new(s * 1.12, s * 0.05, s * 0.07), crack, Enum.Material.Neon)
				table.insert(pieces, { c, CFrame.Angles(ang[1], ang[2], ang[3]) * CFrame.new(0, (k - 1.5) * s * 0.12, 0) })
				table.insert(cracks, c)
			end
		end
		return pieces, cracks[1], cracks
	end
	-- light rising off the ground ring (streaks), the column of an aura without a solid wall
	function H.updraft(a: any, r: number, colors: ColorSequence, rate: number, tex: string?, size: number?): ParticleEmitter
		local ringPart = H.feetPiece(a, Vector3.new(r * 2, 0.2, r * 2), 0.3)
		local s = size or 0.9
		local e = E(ringPart, { tex = tex or T.streak, colors = colors, rate = rate, life = { 0.8, 1.3 }, speed = { 3, 5.5 }, size = s, spread = 0, light = 1, bright = 2, shape = Enum.ParticleEmitterShape.Cylinder, surface = true, orient = Enum.ParticleOrientation.VelocityParallel, trans = ns(0, 1, 0.15, 0.2, 1, 1), sizeSeq = ns(0, s * 0.2, 0.3, s, 1, 0) })
		e.ShapePartial = 0
		K.addEmitter(a, e)
		return e
	end
	-- an orbiting piece's trail
	function H.trailed(p: BasePart, colors: ColorSequence, life: number, w: number?): Trail
		local half = (w or 0.25) / 2
		return K.trail(p, Vector3.new(0, half, 0), Vector3.new(0, -half, 0), colors, life, 1)
	end
	-- something every `period` seconds
	function H.every(a: any, period: number, fn: (any, any) -> ())
		local nextAt = 0
		H.job(a, function(self, f)
			if f.t < nextAt then
				return
			end
			nextAt = f.t + period
			fn(self, f)
		end)
	end
	-- the light swells on cue (self.lightKick) and flickers by `wobble`
	function H.lightJob(a: any, wobble: number?)
		H.job(a, function(self, f)
			local l = self.light
			if not l then
				return
			end
			self.lightKick = math.max(1, (self.lightKick or 1) * 0.92)
			l.Brightness = self.lightBase * self.lightKick * (1 + (wobble or 0) * math.noise(f.t * 3, 0.5))
		end)
	end
	-- `n` little lights round the ground at radius r: `count(f)` of them lit (a gimmick's charge)
	function H.pips(a: any, n: number, r: number, offColor: Color3, onColor: Color3, size: number, count: (any) -> number?): { BasePart }
		local list = {}
		for i = 1, n do
			local p = K.piece(a.model, Vector3.one * size, offColor, 0.6)
			p.Shape = Enum.PartType.Ball
			local th = (i - 1) / n * math.pi * 2
			K.move(a, p, function(f)
				return CFrame.new(f.feet + Vector3.new(math.cos(th) * r, 0.35, math.sin(th) * r))
			end)
			list[i] = p
		end
		local last = -1
		H.job(a, function(self, f)
			local c = count(f)
			if c == nil then
				c = -1
			end
			if c == last then
				return
			end
			last = c
			for i, p in list do
				local on = c >= 0 and i <= c
				p.Color = if on then onColor else offColor
				p.Transparency = if c < 0 then 0.75 elseif on then 0 else 0.55
				p.Size = Vector3.one * (if on then size * 1.35 else size)
			end
		end)
		return list
	end

	-- a VFX Forge burst (ReplicatedStorage.AuraVFX.<name>, built by ServerStorage.MowALawnTools.BuildAuraVfx) played
	-- at `at` by client/FilmVfx through the plugin's Emit Module; false when it can't play (the caller's own effect
	-- still plays). Nothing for bursts far from the camera. The aura lab (Studio) asks client/FilmVfx to play it by an
	-- attribute instead, so the Emit Module is only ever loaded by the game's own scripts.
	local FilmVfx: any = nil
	function H.forge(name: string, at: Vector3, scale: number?): boolean
		local cam = workspace.CurrentCamera
		if cam and (cam.CFrame.Position - at).Magnitude > 120 then
			return false
		end
		if _G.AuraLabForge then
			workspace:SetAttribute("FilmVfxPlayAt", string.format("%s;%.2f,%.2f,%.2f;%.2f;%d", name, at.X, at.Y, at.Z, scale or 1, math.floor(os.clock() * 1000) % 1000000))
			return true
		end
		if FilmVfx == nil then
			local ok, m = pcall(function()
				return require(script.Parent:WaitForChild("FilmVfx", 2) :: ModuleScript)
			end)
			FilmVfx = if ok and type(m) == "table" then m else false
		end
		if not FilmVfx then
			return false
		end
		local ok, clone = pcall(FilmVfx.play, name, at, { scale = scale })
		return ok and clone ~= nil
	end

	-- each class's builder; when its aura forms, its VFX Forge formation burst (Form_<Class>) plays with it
	local builders = {}
	for _, child in script:GetChildren() do
		if child:IsA("ModuleScript") then
			local ok, res = pcall(require, child)
			if ok and type(res) == "function" then
				local build = res(H)
				local formName = "Form_" .. child.Name
				builders[child.Name] = function()
					local a = build()
					local own = a.onForm
					a.onForm = function(self, feet, w)
						H.forge(formName, feet)
						if own then
							own(self, feet, w)
						end
					end
					return a
				end
			else
				warn("[ClassAuras] " .. child.Name .. " failed to load:", res)
			end
		end
	end
	return builders
end
