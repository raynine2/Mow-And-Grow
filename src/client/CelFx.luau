--!strict
-- CEL FX (6 Nov 2026; owner: "intro and outro need more work use better vfx and fx use the refrence video more ...
-- make it 10000x better"). World-space effects in the flat, cel-shaded anime look of the reference cutscenes: bold
-- flat colours, a dark rim round the bright shapes, fast starts and long fades, debris that flies in real arcs. Every
-- piece is anchored, moved on the film's clock (slow motion and holds slow it too), and cleaned up by itself.
--   CelFx.ring(at, opts)       a shockwave ring racing out flat on the ground (or facing `normal`): a hot core band
--                              inside a dark rim, thinning as it grows
--   CelFx.cracks(at, opts)     the ground split in jagged spokes from a point, glowing in their depths, fading after
--   CelFx.debris(at, opts)     chunks of ground / rock / grass thrown out and up in arcs, spinning, bouncing once
--   CelFx.sparks(at, opts)     needle streaks shot out from a point, stretched along their flight, shrinking
--   CelFx.dust(at, opts)       a cel dust cloud: fat flat puffs billowing out low, rolling, fading
--   CelFx.streaks(from, to, opts)  speed streaks along a dash, round its path, for the frames it takes
--   CelFx.pillar(at, opts)     a column of light / energy: a hot core, a coloured sheath, a rim, rising and fading
--   CelFx.flare(at, opts)      a 3D star-burst flare (crossed blades) that pops and spins out
--   CelFx.impact(at, opts)     the lot for a big hit: ring + cracks + debris + sparks + dust + flare + light
--   CelFx.clear()
-- opts everywhere: color (the hot colour), rim (the dark one), size (scale), life (seconds), normal (Vector3).
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Film = require(script.Parent.Film)
local Device = require(script.Parent.Device)
local Potato = require(script.Parent.Potato)

local CelFx = {}

local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(24, 14, 30)
local UP = Vector3.yAxis

local function lite(): boolean
	return Potato.on or Device.touch
end

local holder: Folder? = nil
local function folder(): Folder
	if holder and holder.Parent then
		return holder
	end
	local f = Instance.new("Folder")
	f.Name = "CelFx"
	f.Parent = workspace
	holder = f
	return f
end

local function part(size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, alpha: number?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.Neon
	p.Transparency = alpha or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = folder()
	return p
end

-- every live effect: a step function on the film's clock (t = seconds since it began); returns false when done
local live: { { t: number, step: (number, number) -> boolean, parts: { BasePart } } } = {}
local conn: RBXScriptConnection? = nil
local function run(step: (number, number) -> boolean, parts: { BasePart })
	table.insert(live, { t = 0, step = step, parts = parts })
	if conn then
		return
	end
	conn = RunService.RenderStepped:Connect(function(dt)
		local s = if Film.playing then Film.scale() else 1
		local d = dt * s
		for i = #live, 1, -1 do
			local e = live[i]
			e.t += d
			local ok, more = pcall(e.step, e.t, d)
			if not ok or not more then
				for _, p in e.parts do
					p:Destroy()
				end
				table.remove(live, i)
			end
		end
		if #live == 0 and conn then
			conn:Disconnect()
			conn = nil
		end
	end)
end

local function outQuad(k: number): number
	return 1 - (1 - k) * (1 - k)
end
local function outExpo(k: number): number
	return if k >= 1 then 1 else 1 - 2 ^ (-10 * k)
end

local function basis(normal: Vector3?): CFrame
	local n = (normal or UP).Unit
	local ref = if math.abs(n.Y) > 0.95 then Vector3.xAxis else UP
	local right = ref:Cross(n).Unit
	local back = right:Cross(n).Unit
	return CFrame.fromMatrix(Vector3.zero, right, n, back)
end

-------------------------------------------------------------------------------------------------------------
-- the shockwave ring
-------------------------------------------------------------------------------------------------------------
function CelFx.ring(at: Vector3, opts: any?)
	local o = opts or {}
	local color = o.color or WHITE
	local rim = o.rim or INK
	local size = o.size or 1
	local life = o.life or 0.45
	local R = (o.radius or 14) * size
	local segs = if lite() then 18 else 30
	local frame = CFrame.new(at) * basis(o.normal)
	local cores, rims = {}, {}
	local parts = {}
	for i = 1, segs do
		local c = part(Vector3.new(1, 0.2, 1), frame, color, Enum.Material.Neon, 0)
		local r = part(Vector3.new(1, 0.18, 1), frame, rim, Enum.Material.SmoothPlastic, 0)
		cores[i], rims[i] = c, r
		table.insert(parts, c)
		table.insert(parts, r)
	end
	run(function(t)
		local k = math.clamp(t / life, 0, 1)
		local rad = R * (0.12 + 0.88 * outExpo(k))
		local band = math.max(0.15, size * 2.4 * (1 - k) ^ 1.3)
		local seg = 2 * math.pi * rad / segs + 0.2
		for i = 1, segs do
			local a = (i / segs) * math.pi * 2
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local cf = frame * CFrame.new(dir * rad) * CFrame.lookAt(Vector3.zero, Vector3.new(-dir.Z, 0, dir.X))
			cores[i].CFrame = cf * CFrame.new(0, 0.05, 0)
			cores[i].Size = Vector3.new(band, 0.2, seg)
			cores[i].Transparency = k ^ 1.6
			rims[i].CFrame = cf * CFrame.new(-(band * 0.5 + band * 0.18), 0, 0) -- (-X is outward here)
			rims[i].Size = Vector3.new(band * 0.36, 0.18, seg)
			rims[i].Transparency = math.min(1, 0.1 + k ^ 1.2)
		end
		return k < 1
	end, parts)
end

-------------------------------------------------------------------------------------------------------------
-- the ground split in spokes
-------------------------------------------------------------------------------------------------------------
function CelFx.cracks(at: Vector3, opts: any?)
	local o = opts or {}
	local color = o.color or Color3.fromRGB(255, 170, 60)
	local size = o.size or 1
	local life = o.life or 2.2
	local spokes = o.spokes or (if lite() then 6 else 9)
	local frame = CFrame.new(at) * basis(o.normal)
	local rng = Random.new()
	local parts = {}
	local segsAll: { { dark: BasePart, glow: BasePart, len: number, at: number } } = {}
	for i = 1, spokes do
		local a = (i / spokes) * math.pi * 2 + rng:NextNumber(-0.25, 0.25)
		local p = Vector3.zero
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local reach = rng:NextNumber(6, 12) * size
		local n = rng:NextInteger(3, 5)
		local w = 0.9 * size
		local dist = 0
		for j = 1, n do
			local turn = rng:NextNumber(-0.6, 0.6)
			dir = (CFrame.Angles(0, turn, 0) * dir).Unit
			local len = reach / n * rng:NextNumber(0.7, 1.3)
			local q = p + dir * len
			local mid = (p + q) / 2
			local cf = frame * CFrame.lookAt(mid, q)
			local dark = part(Vector3.new(w, 0.12, len + w * 0.6), cf * CFrame.new(0, 0.03, 0), INK, Enum.Material.SmoothPlastic, 1)
			local glow = part(Vector3.new(w * 0.4, 0.14, len), cf * CFrame.new(0, 0.05, 0), color, Enum.Material.Neon, 1)
			table.insert(parts, dark)
			table.insert(parts, glow)
			table.insert(segsAll, { dark = dark, glow = glow, len = len, at = dist / reach })
			dist += len
			w *= 0.72
			p = q
			if j == 2 and rng:NextNumber() < 0.5 then
				-- a branch off this spoke
				local bd = (CFrame.Angles(0, rng:NextNumber(0.6, 1.1) * (if rng:NextNumber() < 0.5 then -1 else 1), 0) * dir).Unit
				local bl = len * 0.7
				local bq = p + bd * bl
				local bcf = frame * CFrame.lookAt((p + bq) / 2, bq)
				local bdark = part(Vector3.new(w * 0.8, 0.12, bl), bcf * CFrame.new(0, 0.03, 0), INK, Enum.Material.SmoothPlastic, 1)
				local bglow = part(Vector3.new(w * 0.3, 0.14, bl * 0.9), bcf * CFrame.new(0, 0.05, 0), color, Enum.Material.Neon, 1)
				table.insert(parts, bdark)
				table.insert(parts, bglow)
				table.insert(segsAll, { dark = bdark, glow = bglow, len = bl, at = dist / reach })
			end
		end
	end
	-- (they race out from the middle in 0.12 s, glow, the glow dies, the dark stays a while, then all fades)
	run(function(t)
		for _, sg in segsAll do
			local show = t >= sg.at * 0.12
			sg.dark.Transparency = if show then math.clamp((t - life * 0.7) / (life * 0.3), 0, 1) * 0.9 + 0.05 else 1
			sg.glow.Transparency = if show then math.clamp(0.05 + t / (life * 0.45), 0, 1) else 1
		end
		return t < life
	end, parts)
end

-------------------------------------------------------------------------------------------------------------
-- debris thrown out in arcs
-------------------------------------------------------------------------------------------------------------
function CelFx.debris(at: Vector3, opts: any?)
	local o = opts or {}
	local size = o.size or 1
	local count = o.count or (if lite() then 8 else 16)
	local colors = o.colors or { Color3.fromRGB(96, 76, 58), Color3.fromRGB(70, 104, 54), Color3.fromRGB(120, 110, 100) }
	local speed = (o.speed or 30) * math.sqrt(size)
	local up = o.up or 0.9
	local normal = (o.normal or UP).Unit
	local g = (o.gravity or 90)
	local floorY = at.Y
	local rng = Random.new()
	local parts = {}
	local bits = {}
	for _ = 1, count do
		local s = rng:NextNumber(0.4, 1.3) * size
		local p = part(Vector3.new(s, s * rng:NextNumber(0.5, 1), s * rng:NextNumber(0.6, 1.2)), CFrame.new(at), colors[rng:NextInteger(1, #colors)], Enum.Material.SmoothPlastic, 0)
		p.CastShadow = not lite()
		local side = basis(normal):VectorToWorldSpace(Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)))
		local v = (side.Unit * rng:NextNumber(0.35, 1) + normal * rng:NextNumber(up * 0.6, up * 1.4)).Unit * speed * rng:NextNumber(0.6, 1.2)
		table.insert(parts, p)
		table.insert(bits, { p = p, pos = at + side * 0.5, v = v, spin = Vector3.new(rng:NextNumber(-12, 12), rng:NextNumber(-12, 12), rng:NextNumber(-12, 12)), rot = CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0), bounced = false, rest = false })
	end
	local life = o.life or 2.4
	run(function(t, dt)
		for _, b in bits do
			if not b.rest then
				b.v -= UP * g * dt
				b.pos += b.v * dt
				b.rot = b.rot * CFrame.Angles(b.spin.X * dt, b.spin.Y * dt, b.spin.Z * dt)
				if b.pos.Y < floorY + b.p.Size.Y * 0.4 and b.v.Y < 0 then
					b.pos = Vector3.new(b.pos.X, floorY + b.p.Size.Y * 0.4, b.pos.Z)
					if b.bounced then
						b.rest = true
					else
						b.bounced = true
						b.v = Vector3.new(b.v.X * 0.4, -b.v.Y * 0.3, b.v.Z * 0.4)
						b.spin *= 0.4
					end
				end
			end
			b.p.CFrame = CFrame.new(b.pos) * b.rot
			b.p.Transparency = math.clamp((t - life * 0.75) / (life * 0.25), 0, 1)
		end
		return t < life
	end, parts)
end

-------------------------------------------------------------------------------------------------------------
-- spark needles
-------------------------------------------------------------------------------------------------------------
function CelFx.sparks(at: Vector3, opts: any?)
	local o = opts or {}
	local color = o.color or Color3.fromRGB(255, 220, 120)
	local size = o.size or 1
	local count = o.count or (if lite() then 10 else 22)
	local life = o.life or 0.35
	local spread = o.spread or 1 -- (1 = all round; a cone round `normal` when < 1)
	local normal = (o.normal or UP).Unit
	local rng = Random.new()
	local parts, nd = {}, {}
	for _ = 1, count do
		local dir = rng:NextUnitVector()
		if spread < 1 then
			dir = (normal + dir * spread).Unit
		end
		local p = part(Vector3.new(0.12, 0.12, 1) * size, CFrame.new(at), if rng:NextNumber() < 0.35 then WHITE else color, Enum.Material.Neon, 0)
		table.insert(parts, p)
		table.insert(nd, { p = p, dir = dir, sp = rng:NextNumber(40, 90) * size, len = rng:NextNumber(1.5, 4) * size, d = 0 })
	end
	run(function(t, dt)
		local k = math.clamp(t / life, 0, 1)
		for _, n in nd do
			n.d += n.sp * dt * (1 - k * 0.8)
			local len = n.len * (1 - k)
			local head = at + n.dir * n.d
			n.p.Size = Vector3.new(0.14 * size * (1 - k * 0.6), 0.14 * size * (1 - k * 0.6), math.max(0.05, len))
			n.p.CFrame = CFrame.lookAt(head - n.dir * len / 2, head)
			n.p.Transparency = k ^ 2
		end
		return k < 1
	end, parts)
end

-------------------------------------------------------------------------------------------------------------
-- a cel dust cloud
-------------------------------------------------------------------------------------------------------------
function CelFx.dust(at: Vector3, opts: any?)
	local o = opts or {}
	local color = o.color or Color3.fromRGB(196, 178, 150)
	local shade = (o.shade or color:Lerp(INK, 0.35)) :: Color3
	local size = o.size or 1
	local count = o.count or (if lite() then 7 else 14)
	local life = o.life or 1.6
	local radius = (o.radius or 6) * size
	local rng = Random.new()
	local parts, puffs = {}, {}
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local s = rng:NextNumber(2, 3.6) * size
		local p = part(Vector3.one * s, CFrame.new(at), if i % 3 == 0 then shade else color, Enum.Material.SmoothPlastic, 0.35)
		p.Shape = Enum.PartType.Ball
		p.CastShadow = false
		table.insert(parts, p)
		table.insert(puffs, { p = p, dir = dir, s = s, out = radius * rng:NextNumber(0.7, 1.2), rise = rng:NextNumber(0.5, 2.2) * size })
	end
	run(function(t)
		local k = math.clamp(t / life, 0, 1)
		local e = outExpo(math.min(1, k * 2.2))
		for _, f in puffs do
			local grow = f.s * (0.35 + 0.9 * outQuad(math.min(1, k * 1.8))) * (1 - 0.4 * k)
			-- (6 Nov, seen in Studio: round puffs read as balloons) low, flattened rolls of dust, see-through
			f.p.Size = Vector3.new(grow * 1.4, grow * 0.55, grow * 1.4)
			f.p.CFrame = CFrame.new(at + f.dir * f.out * e + UP * (grow * 0.2 + f.rise * k * 0.5))
			f.p.Transparency = 0.35 + 0.65 * math.clamp((k - 0.2) / 0.8, 0, 1)
		end
		return k < 1
	end, parts)
end

-------------------------------------------------------------------------------------------------------------
-- speed streaks along a dash
-------------------------------------------------------------------------------------------------------------
function CelFx.streaks(from: Vector3, to: Vector3, opts: any?)
	local o = opts or {}
	local color = o.color or WHITE
	local count = o.count or (if lite() then 8 else 18)
	local life = o.life or 0.3
	local radius = o.radius or 3
	local dir = to - from
	local len = dir.Magnitude
	if len < 0.5 then
		return
	end
	local unit = dir.Unit
	local frame = CFrame.lookAt(from, to)
	local rng = Random.new()
	local parts, st = {}, {}
	for _ = 1, count do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0.6, 1) * radius
		local off = frame:VectorToWorldSpace(Vector3.new(math.cos(a) * r, math.sin(a) * r, 0))
		local l = len * rng:NextNumber(0.3, 0.8)
		local p = part(Vector3.new(0.08, 0.08, l), CFrame.new(), color, Enum.Material.Neon, 0)
		table.insert(parts, p)
		table.insert(st, { p = p, off = off, l = l, at = rng:NextNumber(0, 1) })
	end
	run(function(t)
		local k = math.clamp(t / life, 0, 1)
		for _, s in st do
			local head = from + unit * (len * math.clamp(s.at + k * 0.8, 0, 1)) + s.off
			local l = s.l * (1 - k)
			s.p.Size = Vector3.new(0.09, 0.09, math.max(0.05, l))
			s.p.CFrame = CFrame.lookAt(head - unit * l / 2, head)
			s.p.Transparency = 0.15 + k * 0.85
		end
		return k < 1
	end, parts)
end

-------------------------------------------------------------------------------------------------------------
-- a column of light
-------------------------------------------------------------------------------------------------------------
function CelFx.pillar(at: Vector3, opts: any?)
	local o = opts or {}
	local color = o.color or Color3.fromRGB(255, 200, 80)
	local size = o.size or 1
	local life = o.life or 1.2
	local height = (o.height or 60) * size
	local w = (o.width or 5) * size
	local core = part(Vector3.new(w * 0.35, height, w * 0.35), CFrame.new(at + UP * height / 2), WHITE, Enum.Material.Neon, 0)
	local sheath = part(Vector3.new(w, height, w), CFrame.new(at + UP * height / 2), color, Enum.Material.Neon, 0.25)
	sheath.Shape = Enum.PartType.Cylinder
	core.Shape = Enum.PartType.Cylinder
	local rimP = part(Vector3.new(w * 1.25, height, w * 1.25), CFrame.new(at + UP * height / 2), INK, Enum.Material.SmoothPlastic, 0.55)
	rimP.Shape = Enum.PartType.Cylinder
	local up = CFrame.Angles(0, 0, math.pi / 2)
	local parts = { core, sheath, rimP }
	run(function(t)
		local k = math.clamp(t / life, 0, 1)
		local grow = outExpo(math.min(1, k * 5))
		local thin = if k < 0.6 then 1 else 1 - (k - 0.6) / 0.4
		local h = height * grow
		local base = CFrame.new(at + UP * h / 2) * up
		core.CFrame = base
		core.Size = Vector3.new(h, w * 0.35 * thin, w * 0.35 * thin)
		sheath.CFrame = base
		sheath.Size = Vector3.new(h, w * thin * (1 + 0.15 * math.sin(t * 40)), w * thin * (1 + 0.15 * math.sin(t * 40)))
		rimP.CFrame = base
		rimP.Size = Vector3.new(h, w * 1.25 * thin, w * 1.25 * thin)
		sheath.Transparency = 0.25 + k * 0.75
		core.Transparency = k ^ 2
		rimP.Transparency = 0.55 + k * 0.45
		return k < 1
	end, parts)
end

-------------------------------------------------------------------------------------------------------------
-- a 3D star flare
-------------------------------------------------------------------------------------------------------------
function CelFx.flare(at: Vector3, opts: any?)
	local o = opts or {}
	local color = o.color or WHITE
	local size = o.size or 1
	local life = o.life or 0.28
	local blades = {}
	local parts = {}
	for i = 1, 4 do
		local p = part(Vector3.new(0.3, 0.3, 1), CFrame.new(at), if i <= 2 then WHITE else color, Enum.Material.Neon, 0)
		table.insert(parts, p)
		table.insert(blades, p)
	end
	local cam = workspace.CurrentCamera
	local spin = math.random() * math.pi
	run(function(t)
		local k = math.clamp(t / life, 0, 1)
		local camCf = cam and cam.CFrame or CFrame.new()
		local face = CFrame.lookAt(at, camCf.Position)
		local pop = if k < 0.25 then outExpo(k / 0.25) else 1 - (k - 0.25) / 0.75
		for i, b in blades do
			local long = (if i <= 2 then 14 else 8) * size * pop
			local a = spin + (i - 1) * math.pi / 2 + (if i > 2 then math.pi / 4 else 0) + k * 0.6
			b.Size = Vector3.new(0.35 * size * pop + 0.02, 0.35 * size * pop + 0.02, math.max(0.05, long))
			b.CFrame = face * CFrame.Angles(0, 0, a) * CFrame.Angles(math.pi / 2, 0, 0)
			b.Transparency = k ^ 1.5
		end
		return k < 1
	end, parts)
end

-------------------------------------------------------------------------------------------------------------
-- the lot, for a big hit
-------------------------------------------------------------------------------------------------------------
function CelFx.impact(at: Vector3, opts: any?)
	local o = opts or {}
	local size = o.size or 1
	local ground = o.ground
	if ground == nil then
		ground = true
	end
	CelFx.flare(at, { color = o.color, size = size })
	CelFx.sparks(at, { color = o.color, size = size })
	if ground then
		local g = Vector3.new(at.X, o.floorY or (at.Y - 0.2), at.Z)
		CelFx.ring(g + UP * 0.1, { color = o.color, rim = o.rim, size = size, radius = 16 })
		CelFx.cracks(g + UP * 0.05, { color = o.crackColor or o.color, size = size })
		CelFx.debris(g, { size = size, colors = o.debrisColors })
		if o.dust then
			CelFx.dust(g, { size = size, color = o.dustColor })
		end
	else
		CelFx.ring(at, { color = o.color, rim = o.rim, size = size * 0.7, radius = 10, normal = o.normal or (workspace.CurrentCamera and workspace.CurrentCamera.CFrame.LookVector) })
	end
	if o.light ~= false then
		local h = part(Vector3.one * 0.2, CFrame.new(at), WHITE, Enum.Material.SmoothPlastic, 1)
		local l = Instance.new("PointLight")
		l.Color = o.color or WHITE
		l.Range = 30 * size
		l.Brightness = 6
		l.Shadows = false
		l.Parent = h
		run(function(t)
			l.Brightness = 6 * math.max(0, 1 - t / 0.5) ^ 2
			return t < 0.5
		end, { h })
	end
end

function CelFx.clear()
	for _, e in live do
		for _, p in e.parts do
			p:Destroy()
		end
	end
	table.clear(live)
	if holder then
		holder:Destroy()
		holder = nil
	end
end

local _ = Players
return CelFx
