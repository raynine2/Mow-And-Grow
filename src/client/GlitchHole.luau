-- GLITCH HOLE (owner, 28 Oct: the corrupted demon "coming out of a glitch black hole that's sucking the island up
-- ... and captures the island and the players"): world 2's way in, for the ending's last scene, built on this client
-- only. A black hole torn open in the night sky in the demon's colours: a flat black horizon (black Neon isn't
-- shaded), a burning pink rim, a halo, a tilted accretion disk of pink, white and cyan spirals, sparks falling in from
-- all round, and it GLITCHES: every so often it jumps sideways and splits into red and cyan ghosts while neon
-- "pixels" blink round it. Lumps of the island tear out of the ground and spiral in, shrinking as they fall; whatever
-- it takes (the party, the Mayor) is lifted off its feet, tumbles up and is gone. A huge eye can open in the dark.
-- It is not the camp's CLASSES hole: its own look and code, and nothing here can be jumped into (client/BlackHole only
-- picks up parts named "Singularity").
--   GlitchHole.new(centre, facing, radius, parent?) -> Hole   (facing: roughly toward where it's watched from)
--     hole.open(time)                       bursts open out of a pinprick
--     hole.chunks(around, radius, count, time)  lumps of ground tear out round `around` and spiral in
--     hole.take(get, set, time, delay)      something lifted and pulled in (get: its CFrame now; set: move it)
--     hole.eye(on)                          a huge eye opens in the dark (on = false: it shuts)
--     hole.grow(scale, time)                swell (1 = its size)
--     hole.glitch(time)                     a big glitch right now
--     hole.update(dt)                       every frame
--     hole.horizon, hole.centre, hole.radius
--     hole.destroy()
--   GlitchHole.eyeProp(parent) -> Eye     the demon's eye on its own (client/Intro's peek): place(at, toward, width, open)
-- (29 Oct) GlitchHole.new(..., { bare = true }): the halo, the disk's spirals, the falling sparks and the opening's
-- shock ring are left out: client/Ending plays them as VFX Forge templates (client/FilmVfx) and keeps this hole's
-- horizon, rim, glitches, lumps, lifting and eye. hole.diskCf: the disk's frame (its plane = XZ).
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local IntroCast = require(script.Parent.IntroCast)
local Potato = require(script.Parent.Potato)

local GlitchHole = {}

local UP = Vector3.yAxis
local BLACK = Color3.new(0, 0, 0)
local PINK = Color3.fromRGB(255, 40, 170)
local HOT = Color3.fromRGB(255, 214, 240)
local CYAN = Color3.fromRGB(60, 240, 255)
local GHOST_RED = Color3.fromRGB(255, 40, 70)
local GHOST_CYAN = Color3.fromRGB(40, 230, 255)

-- (the game's own textures, as the CLASSES black hole's stand uses them)
local TEX = {
	glow = "rbxassetid://125552447014366",
	ringThin = "rbxassetid://115339930898563",
	ring = "rbxassetid://12403112662",
	spiral = "rbxassetid://8210105100",
	spark = "rbxassetid://83908233620100",
}

local function light(): boolean
	return Potato.on or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = material or Enum.Material.SmoothPlastic
	p.Color = color
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

local function image(parent: Instance, name: string, tex: string, scale: number, color: Color3, transparency: number, z: number): ImageLabel
	local i = Instance.new("ImageLabel")
	i.Name = name
	i.BackgroundTransparency = 1
	i.Image = tex
	i.ImageColor3 = color
	i.ImageTransparency = transparency
	i.AnchorPoint = Vector2.new(0.5, 0.5)
	i.Position = UDim2.fromScale(0.5, 0.5)
	i.Size = UDim2.fromScale(scale, scale)
	i.ZIndex = z
	i.Parent = parent
	return i
end

local function smooth(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

-- The demon's eye (here, and in a tear in the sky in client/Intro's peek): an almond of pink light, a hot iris, a
-- slit pupil, opening like an eyelid. eye.place(at, toward, width, open 0..1) every frame; eye.destroy().
export type Eye = { place: (at: Vector3, toward: Vector3, width: number, open: number) -> (), destroy: () -> () }

function GlitchHole.eyeProp(parent: Instance): Eye
	local parts: { Part } = {}
	-- (ellipsoids: a ball can't be stretched, a sphere mesh on a block can)
	for _, e in { { "Eye", PINK }, { "Iris", HOT }, { "Pupil", BLACK } } do
		local p = part(parent, e[1], Vector3.one, CFrame.new(), e[2], Enum.Material.Neon)
		p.Transparency = 1
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		table.insert(parts, p)
	end
	return {
		place = function(at: Vector3, toward: Vector3, width: number, open: number)
			local look = CFrame.lookAt(at, at + toward)
			local h = width * 0.42 * math.clamp(open, 0, 1.2) + 0.01
			parts[1].Size = Vector3.new(width, h, 0.3)
			parts[1].CFrame = look
			parts[2].Size = Vector3.new(width * 0.36, math.min(h * 0.92, width * 0.36), 0.32)
			parts[2].CFrame = look * CFrame.new(0, 0, -0.08)
			parts[3].Size = Vector3.new(width * 0.07, math.min(h * 0.86, width * 0.33), 0.34)
			parts[3].CFrame = look * CFrame.new(0, 0, -0.16)
			local hide = if open < 0.02 then 1 else 0
			for _, p in parts do
				p.Transparency = hide
			end
		end,
		destroy = function()
			for _, p in parts do
				p:Destroy()
			end
		end,
	}
end

export type Hole = {
	horizon: Part,
	centre: Vector3,
	radius: number,
	diskCf: CFrame,
	open: (time: number) -> (),
	chunks: (around: Vector3, radius: number, count: number, time: number) -> (),
	take: (get: () -> CFrame, set: (CFrame) -> (), time: number, delay: number?) -> (),
	eye: (on: boolean) -> (),
	grow: (scale: number, time: number) -> (),
	glitch: (time: number?) -> (),
	update: (dt: number) -> (),
	destroy: () -> (),
}

type Lump = { parts: { BasePart }, rel: { CFrame }, sizes: { Vector3 }, start: Vector3, t: number, len: number, a0: number, side: number, spin: Vector3, s: number, gone: boolean }
type Taken = { get: () -> CFrame, set: (CFrame) -> (), t: number, len: number, from: CFrame?, a0: number, side: number, axis: Vector3, gone: boolean }

function GlitchHole.new(centre: Vector3, facing: Vector3, radius: number, parent: Instance?, opts: { bare: boolean? }?): Hole
	local bare = opts ~= nil and opts.bare == true
	local folder = Instance.new("Folder")
	folder.Name = "GlitchHole"
	local R = radius
	local D = radius * 3.1 -- the disk's outer edge
	local rng = Random.new()
	local flatFacing = Vector3.new(facing.X, 0, facing.Z)
	local face = if flatFacing.Magnitude > 0.01 then flatFacing.Unit else Vector3.zAxis
	local side = face:Cross(UP)
	-- the disk leans toward the viewer (we look up at it from the ground: we see its underside as a wide ellipse)
	local diskCf = CFrame.lookAt(centre, centre + face) * CFrame.Angles(math.rad(-16), 0, 0)

	local horizon = part(folder, "Horizon", Vector3.one * 2 * R, CFrame.new(centre), BLACK, Enum.Material.Neon, Enum.PartType.Ball)
	local rim = part(folder, "Rim", Vector3.one * 2.16 * R, CFrame.new(centre), PINK, Enum.Material.ForceField, Enum.PartType.Ball)
	local ghostR = part(folder, "GhostRed", Vector3.one * 2 * R, CFrame.new(centre), GHOST_RED, Enum.Material.Neon, Enum.PartType.Ball)
	local ghostC = part(folder, "GhostCyan", Vector3.one * 2 * R, CFrame.new(centre), GHOST_CYAN, Enum.Material.Neon, Enum.PartType.Ball)
	ghostR.Transparency = 1
	ghostC.Transparency = 1
	local glowLight = Instance.new("PointLight")
	glowLight.Color = PINK
	glowLight.Range = 0
	glowLight.Brightness = 4
	glowLight.Shadows = false
	glowLight.Parent = horizon

	-- the halo (always faces you): a soft pink glow, the lensed far side of the disk, the photon ring
	local lens = Instance.new("BillboardGui")
	lens.Name = "Lens"
	lens.Size = UDim2.fromScale(R * 5.4, R * 5.4)
	lens.LightInfluence = 0
	lens.Brightness = 2.6
	lens.MaxDistance = 100000
	lens.ResetOnSpawn = false
	lens.Adornee = horizon
	lens.Parent = horizon
	local spins: { { img: ImageLabel, speed: number } } = {}
	if not bare then
		image(lens, "Halo", TEX.glow, 1, PINK, 0.25, 1)
		table.insert(spins, { img = image(lens, "Swirl", TEX.spiral, 0.86, Color3.fromRGB(255, 120, 210), 0.45, 2), speed = 70 })
		table.insert(spins, { img = image(lens, "Arc", TEX.ring, 0.62, Color3.fromRGB(255, 90, 190), 0.15, 3), speed = -28 })
		image(lens, "Photon", TEX.ringThin, 0.47, HOT, 0, 4)
	end

	-- the accretion disk: spirals and a hot inner ring, seen from above and below
	local disk = part(folder, "Disk", Vector3.new(D * 2, 0.05, D * 2), diskCf, BLACK)
	disk.Transparency = 1
	for _, f in if bare then {} else { Enum.NormalId.Top, Enum.NormalId.Bottom } do
		local sg = Instance.new("SurfaceGui")
		sg.Name = "Disk" .. f.Name
		sg.Face = f
		sg.LightInfluence = 0
		sg.Brightness = 2.2
		sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		sg.CanvasSize = Vector2.new(1024, 1024)
		sg.Parent = disk
		local dir = if f == Enum.NormalId.Bottom then -1 else 1
		table.insert(spins, { img = image(sg, "Haze", TEX.glow, 1.05, Color3.fromRGB(150, 20, 110), 0.35, 1), speed = -8 * dir })
		table.insert(spins, { img = image(sg, "Outer", TEX.spiral, 1, PINK, 0.12, 2), speed = -22 * dir })
		table.insert(spins, { img = image(sg, "Mid", TEX.spiral, 0.72, CYAN, 0.2, 3), speed = -55 * dir })
		image(sg, "Inner", TEX.ringThin, 0.5, HOT, 0, 4)
		table.insert(spins, { img = image(sg, "Hot", TEX.ring, 0.42, Color3.fromRGB(255, 150, 220), 0.2, 5), speed = -130 * dir })
	end
	-- sparks falling in from all round (a shell emitting inward)
	local shell = part(folder, "Infall", Vector3.one * R * 4.4, CFrame.new(centre), BLACK, nil, Enum.PartType.Ball)
	shell.Transparency = 1
	local infall: ParticleEmitter? = if bare then nil else Instance.new("ParticleEmitter")
	if infall then
		infall.Texture = TEX.spark
		infall.Color = ColorSequence.new(PINK, HOT)
		infall.LightEmission = 1
		local ps = R / 10 -- (sparks sized to the hole: they're seen from far away)
		infall.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * ps), NumberSequenceKeypoint.new(0.6, 1.4 * ps), NumberSequenceKeypoint.new(1, 0.2 * ps) })
		infall.Squash = NumberSequence.new(-2.5)
		infall.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.1), NumberSequenceKeypoint.new(0.85, 0.2), NumberSequenceKeypoint.new(1, 1) })
		infall.Lifetime = NumberRange.new(0.95, 1.05)
		infall.Speed = NumberRange.new(R * 2.1, R * 2.3)
		infall.Orientation = Enum.ParticleOrientation.VelocityParallel
		infall.Shape = Enum.ParticleEmitterShape.Sphere
		infall.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		infall.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
		infall.Rate = 0
		infall.Parent = shell
	end
	folder.Parent = parent or workspace

	local size = 0.001 -- everything's scale (0..1, more to swallow)
	local sizeFrom, sizeTo, sizeStart, sizeLen = size, size, 0, 0
	local glitchUntil, nextGlitch = 0, os.clock() + 0.8
	local offset = Vector3.zero
	local lumps: { Lump } = {}
	local taken: { Taken } = {}
	local eyeProp: Eye? = nil
	local eyeOpen, eyeGoal = 0, 0
	local alive = true
	local t = 0

	local function setSize(k: number)
		size = k
		local s = math.max(k, 0.001)
		local at = centre + offset
		horizon.Size = Vector3.one * 2 * R * s
		horizon.CFrame = CFrame.new(at)
		rim.Size = Vector3.one * 2.16 * R * s
		rim.CFrame = CFrame.new(at)
		lens.Size = UDim2.fromScale(R * 5.4 * s, R * 5.4 * s)
		disk.Size = Vector3.new(D * 2 * s, 0.05, D * 2 * s)
		disk.CFrame = diskCf + offset
		shell.Size = Vector3.one * R * 4.4 * math.max(s, 0.05)
		shell.CFrame = CFrame.new(at)
	end
	setSize(size)

	local function pixels(n: number)
		local s = math.max(size, 0.05)
		local colors = { PINK, CYAN, HOT, BLACK }
		for _ = 1, n do
			local dir = rng:NextUnitVector()
			local at = centre + dir * R * s * rng:NextNumber(1.05, 2.3)
			local c = colors[rng:NextInteger(1, #colors)]
			local p = part(folder, "Pixel", Vector3.one * R * s * rng:NextNumber(0.06, 0.2), CFrame.new(at), c, if c == BLACK then Enum.Material.SmoothPlastic else Enum.Material.Neon)
			task.delay(rng:NextNumber(0.05, 0.22), function()
				p:Destroy()
			end)
		end
	end

	local hole = {} :: Hole
	hole.horizon = horizon
	hole.centre = centre
	hole.radius = R
	hole.diskCf = diskCf

	function hole.grow(scale: number, time: number)
		sizeFrom, sizeTo, sizeStart, sizeLen = size, scale, os.clock(), math.max(time, 0.01)
	end

	function hole.open(time: number)
		hole.grow(1, time)
		if infall then
			infall.Rate = if light() then 30 else 60
		end
		TweenService:Create(glowLight, TweenInfo.new(time, Enum.EasingStyle.Quad), { Range = 60 }):Play()
		-- a shock ring bursting out of the pinprick (bare: client/Ending's VFX Forge one)
		if not bare then
			local ring = part(folder, "Shock", Vector3.new(0.4, R, R), diskCf * CFrame.Angles(0, 0, math.rad(90)), HOT, Enum.Material.Neon, Enum.PartType.Cylinder)
			ring.Transparency = 0.1
			TweenService:Create(ring, TweenInfo.new(0.7, Enum.EasingStyle.Quart), { Size = Vector3.new(0.4, D * 3.2, D * 3.2), Transparency = 1 }):Play()
			task.delay(0.75, function()
				ring:Destroy()
			end)
		end
		hole.glitch(0.25)
	end

	function hole.glitch(time: number?)
		glitchUntil = os.clock() + (time or 0.12)
		offset = side * R * rng:NextNumber(-0.3, 0.3)
		pixels(if light() then 8 else 16)
	end

	function hole.chunks(around: Vector3, radius: number, count: number, time: number)
		local n = if light() then math.max(4, math.floor(count * 0.5)) else count
		for _ = 1, n do
			local r = math.sqrt(rng:NextNumber(0.03, 1)) * radius
			local a = rng:NextNumber(0, math.pi * 2)
			local g = IntroCast.ground(around + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
			local s = rng:NextNumber(2.2, 6) * (if light() then 1.25 else 1)
			local stone = rng:NextNumber() < 0.25
			local body = Vector3.new(s, s * 0.7, s * rng:NextNumber(0.8, 1.25))
			local dirt = part(folder, "Lump", body, CFrame.new(g), if stone then Color3.fromRGB(120, 116, 112) else Color3.fromRGB(104, 72, 46), if stone then Enum.Material.Slate else Enum.Material.Ground)
			local topSize = Vector3.new(body.X, s * 0.2, body.Z)
			local top = part(folder, "Turf", topSize, CFrame.new(g), if stone then Color3.fromRGB(90, 140, 60) else Color3.fromRGB(76, 150, 50), Enum.Material.Grass)
			table.insert(lumps, {
				parts = { dirt, top },
				rel = { CFrame.new(), CFrame.new(0, body.Y / 2 + topSize.Y / 2 - 0.02, 0) },
				sizes = { body, topSize },
				start = g - UP * (body.Y * 0.55),
				t = -rng:NextNumber(0, time * 0.75),
				len = rng:NextNumber(2.4, 3.6),
				a0 = math.atan2(g.Z - centre.Z, g.X - centre.X),
				side = if rng:NextNumber() < 0.5 then 1 else -1,
				spin = Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-3, 3), rng:NextNumber(-3, 3)),
				s = s,
				gone = false,
			})
		end
	end

	function hole.take(get: () -> CFrame, set: (CFrame) -> (), time: number, delay: number?)
		local axis = rng:NextUnitVector()
		table.insert(taken, {
			get = get,
			set = set,
			t = -(delay or 0),
			len = math.max(time, 0.3),
			from = nil,
			a0 = rng:NextNumber(0, math.pi * 2),
			side = if rng:NextNumber() < 0.5 then 1 else -1,
			axis = axis,
			gone = false,
		})
	end

	-- the eye: an almond of pink light on the black, a hot iris, a slit pupil; it looks at the camera
	function hole.eye(on: boolean)
		eyeGoal = if on then 1 else 0
		if on and not eyeProp then
			eyeProp = GlitchHole.eyeProp(folder)
		end
	end

	-- a point on the disk's plane at radius r, angle a round the middle
	local function onDisk(r: number, a: number): Vector3
		return centre + offset + disk.CFrame.RightVector * (math.cos(a) * r) + disk.CFrame.LookVector * (math.sin(a) * r)
	end

	local moveParts: { BasePart } = {}
	local moveCfs: { CFrame } = {}

	function hole.update(dt: number)
		if not alive then
			return
		end
		t += dt
		local now = os.clock()
		-- size
		if sizeLen > 0 then
			local k = math.clamp((now - sizeStart) / sizeLen, 0, 1)
			local e = if sizeTo > sizeFrom then 1 - (1 - k) ^ 3 else k * k
			setSize(sizeFrom + (sizeTo - sizeFrom) * e)
			if k >= 1 then
				sizeLen = 0
			end
		end
		-- glitches: a jump sideways and red / cyan ghosts, now and then
		if now >= nextGlitch and size > 0.2 then
			nextGlitch = now + rng:NextNumber(0.4, 1.5)
			hole.glitch(rng:NextNumber(0.05, 0.13))
		end
		local glitching = now < glitchUntil
		if not glitching and offset ~= Vector3.zero then
			offset = Vector3.zero
		end
		local s = math.max(size, 0.001)
		ghostR.Transparency = if glitching then 0.5 else 1
		ghostC.Transparency = if glitching then 0.5 else 1
		ghostR.Size = horizon.Size
		ghostC.Size = horizon.Size
		ghostR.CFrame = CFrame.new(centre + offset - side * R * s * 0.14)
		ghostC.CFrame = CFrame.new(centre + offset + side * R * s * 0.14)
		horizon.CFrame = CFrame.new(centre + offset)
		rim.CFrame = horizon.CFrame
		disk.CFrame = diskCf + offset
		for _, sp in spins do
			sp.img.Rotation += sp.speed * dt * (if glitching then -3 else 1)
		end
		if math.random() < dt * 6 and size > 0.2 then
			pixels(1)
		end
		-- the eye (on the black, looking at the camera)
		local ep = eyeProp
		if ep then
			eyeOpen += (eyeGoal - eyeOpen) * math.min(1, dt * (if eyeGoal > eyeOpen then 9 else 14))
			local cam = workspace.CurrentCamera
			local toCam = if cam then (cam.CFrame.Position - (centre + offset)).Unit else face
			ep.place(centre + offset + toCam * R * s * 1.02, toCam, R * s * 1.15, eyeOpen)
		end
		-- the lumps: torn out, flung up, round and round, smaller and smaller, gone
		table.clear(moveParts)
		table.clear(moveCfs)
		for _, L in lumps do
			if not L.gone then
				L.t += dt
				local u = L.t / L.len
				local cf: CFrame
				if u < 0 then
					cf = CFrame.new(L.start)
				elseif u < 0.14 then
					local k = u / 0.14
					cf = CFrame.new(L.start + UP * (L.s * 0.7 * k) + Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 0.3)
				else
					local v = (u - 0.14) / 0.86
					local lifted = L.start + UP * (L.s * 0.7)
					local r = D * 0.95 + (R * 0.6 - D * 0.95) * (v ^ 1.3)
					local a = L.a0 + L.side * v * math.pi * 4.5
					local p = lifted:Lerp(onDisk(r * s, a), smooth(v * 2.2))
					cf = CFrame.new(p) * CFrame.Angles(L.spin.X * L.t, L.spin.Y * L.t, L.spin.Z * L.t)
					if v > 0.7 then
						local shrink = 1 - 0.8 * ((v - 0.7) / 0.3)
						for i, pt in L.parts do
							pt.Size = L.sizes[i] * shrink
						end
					end
					if v >= 1 then
						L.gone = true
						for _, pt in L.parts do
							pt.Transparency = 1
						end
					end
				end
				for i, pt in L.parts do
					table.insert(moveParts, pt)
					table.insert(moveCfs, cf * L.rel[i])
				end
			end
		end
		if #moveParts > 0 then
			workspace:BulkMoveTo(moveParts, moveCfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
		-- whatever it takes: lifted off its feet, then pulled in on a swirl, tumbling
		for _, T in taken do
			if not T.gone then
				T.t += dt
				if T.t >= 0 then
					local from = T.from
					if not from then
						from = T.get()
						T.from = from
					end
					assert(from)
					local u = math.clamp(T.t / T.len, 0, 1)
					local liftK = smooth(u / 0.22)
					local lifted = from.Position + UP * (3 * liftK)
					local v = math.clamp((u - 0.22) / 0.78, 0, 1)
					local e = v * v
					local a = T.a0 + T.side * v * math.pi * 2.6
					local swirl = (disk.CFrame.RightVector * math.cos(a) + disk.CFrame.LookVector * math.sin(a)) * (R * s * 1.6 * (1 - e) * math.sin(math.min(1, v * 3) * math.pi / 2))
					local p = lifted:Lerp(centre + offset, e) + swirl
					local turnAmt = (u * 0.6 + e * 5) * math.pi
					local rot = from.Rotation * CFrame.fromAxisAngle(T.axis, turnAmt)
					T.set(CFrame.new(p) * rot)
					if u >= 1 then
						T.gone = true
					end
				end
			end
		end
	end

	function hole.destroy()
		alive = false
		folder:Destroy()
	end

	return hole
end

return GlitchHole
