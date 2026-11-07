--!strict
-- STUD KIT (7 Nov 2026). The building blocks the stud-built ForgeGUI models share (server/StudIsles and the ones after
-- it): studded bricks in the model's own space, smooth roof tiles in rows, gable prisms, rings of bricks round an
-- upright axis (towers, silos, domes), every colour shaded by Config.STUD_FORGE.tone (owner: "donkerder ... het moet
-- niet zo bright zijn", for every stud model). A kit builds one Model; :finish(parent) tags it StudBuilt (so
-- server/StudLook leaves it as built) and parents it.
local StudKit = {}
StudKit.__index = StudKit

local TONE = (function(): number
	local ok, cfg = pcall(function()
		return require(game:GetService("ReplicatedStorage"):WaitForChild("MowALawn"):WaitForChild("Config")) :: any
	end)
	local t = ok and type(cfg.STUD_FORGE) == "table" and tonumber(cfg.STUD_FORGE.tone) or nil
	return math.clamp(t or 0.85, 0.4, 1)
end)()

local STUDS = Enum.SurfaceType.Studs
local INLET = Enum.SurfaceType.Inlet
local SMOOTH = Enum.SurfaceType.Smooth

export type Kit = typeof(setmetatable({} :: { model: Model, origin: CFrame, count: number }, StudKit))

function StudKit.new(name: string, pivot: CFrame): Kit
	local m = Instance.new("Model")
	m.Name = name
	return setmetatable({ model = m, origin = pivot, count = 0 }, StudKit)
end

function StudKit.toned(c: Color3): Color3
	return Color3.new(c.R * TONE, c.G * TONE, c.B * TONE)
end

local function surfaces(p: BasePart, smooth: boolean?)
	local s = if smooth then SMOOTH else STUDS
	p.TopSurface = s
	p.FrontSurface = s
	p.BackSurface = s
	p.LeftSurface = s
	p.RightSurface = s
	p.BottomSurface = if smooth then SMOOTH else INLET
end

-- a brick, `cf` in the model's own space; `smooth`: no studs (tiles, glass, metal)
function StudKit.brick(self: Kit, name: string, size: Vector3, cf: CFrame, color: Color3, smooth: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = self.origin * cf
	p.Color = StudKit.toned(color)
	p.Material = Enum.Material.Plastic
	surfaces(p, smooth)
	p.Parent = self.model
	self.count += 1
	return p
end

function StudKit.box(self: Kit, name: string, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, color: Color3, smooth: boolean?): Part
	return self:brick(name, Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)), CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color, smooth)
end

function StudKit.ball(self: Kit, name: string, d: number, cf: CFrame | Vector3, color: Color3): Part
	local p = self:brick(name, Vector3.one * d, if typeof(cf) == "Vector3" then CFrame.new(cf) else cf, color, true)
	p.Shape = Enum.PartType.Ball
	return p
end

-- an upright cylinder: `cf` its middle, d across, h tall
function StudKit.cyl(self: Kit, name: string, d: number, h: number, cf: CFrame | Vector3, color: Color3): Part
	local at = if typeof(cf) == "Vector3" then CFrame.new(cf) else cf
	local p = self:brick(name, Vector3.new(h, d, d), at * CFrame.Angles(0, 0, math.pi / 2), color, true)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- a cylinder lying along `cf`'s X
function StudKit.rod(self: Kit, name: string, d: number, len: number, cf: CFrame, color: Color3): Part
	local p = self:brick(name, Vector3.new(len, d, d), cf, color, true)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- a wedge (Roblox's: its slope rises toward +Z), `cf` its middle; studs on its sides and back
function StudKit.wedge(self: Kit, name: string, size: Vector3, cf: CFrame, color: Color3, smooth: boolean?): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = self.origin * cf
	p.Color = StudKit.toned(color)
	p.Material = Enum.Material.Plastic
	surfaces(p, smooth)
	p.TopSurface = SMOOTH
	p.FrontSurface = SMOOTH
	p.Parent = self.model
	self.count += 1
	return p
end

-- a gable prism: `cf` at the middle of its base, ridge along cf's X (`len` long), `w` across, `h` tall
function StudKit.prism(self: Kit, name: string, cf: CFrame, len: number, w: number, h: number, color: Color3)
	self:wedge(name, Vector3.new(len, h, w / 2), cf * CFrame.new(0, h / 2, -w / 4), color)
	self:wedge(name, Vector3.new(len, h, w / 2), cf * CFrame.new(0, h / 2, w / 4) * CFrame.Angles(0, math.pi, 0), color)
end

-- One roof slope in rows of smooth tiles. `base`: the frame of the slope's eave line, X along the eave, -Z pointing
-- outward-down the slope is NOT used: give `p0` (the eave line's middle), `r` (unit, along the eave), `inward`
-- (unit, horizontal, toward the ridge), `rise`, `run`; the rows span r-coordinates a..b. `trim`: a bargeboard on both
-- ends in that colour.
function StudKit.slope(self: Kit, p0: Vector3, r: Vector3, inward: Vector3, rise: number, run: number, a: number, b: number, colA: Color3, colB: Color3, trim: Color3?)
	local L = math.sqrt(rise * rise + run * run)
	local u = (inward * run + Vector3.new(0, rise, 0)).Unit
	local n = u:Cross(r)
	if n.Y < 0 then
		n = -n
	end
	local rr = r
	if rr:Cross(n):Dot(u) < 0 then
		rr = -rr
	end
	local rows = math.max(2, math.ceil(L / 1.4))
	local step = L / rows
	local w = step + 0.35
	for k = 0, rows - 1 do
		local sd = (k + 0.5) * step
		local pos = p0 + r * ((a + b) / 2) + u * sd + n * 0.25
		local cf = CFrame.fromMatrix(pos, rr, n, u) * CFrame.new(0, 0, w / 2) * CFrame.Angles(math.rad(4), 0, 0) * CFrame.new(0, 0, -w / 2)
		self:brick("Shingles", Vector3.new(b - a, 0.5, w), cf, if k % 2 == 0 then colA else colB, true)
	end
	if trim then
		for _, e in { a - 0.18, b + 0.18 } do
			local pos = p0 + r * e + u * (L / 2) + n * 0.55
			self:brick("Barge", Vector3.new(0.35, 0.8, L + 0.5), CFrame.fromMatrix(pos, rr, n, u), trim, true)
		end
	end
end

-- A ring of `sides` bricks round the upright axis at `c` (model space): outer apothem `a`, from y0 to y0 + h,
-- `t` deep; colours cycle through `cols`. `skip`: sides to leave out.
function StudKit.ring(self: Kit, name: string, c: Vector3, sides: number, a: number, y0: number, h: number, t: number, cols: { Color3 }, skip: { [number]: boolean }?, smooth: boolean?)
	local step = math.pi * 2 / sides
	local s = 2 * a * math.tan(step / 2) + 0.04
	for i = 0, sides - 1 do
		if not (skip and skip[i]) then
			local cf = CFrame.new(c) * CFrame.Angles(0, (i + 0.5) * step, 0) * CFrame.new(0, y0 + h / 2, -(a - t / 2))
			self:brick(name, Vector3.new(s, h, t), cf, cols[i % #cols + 1], smooth)
		end
	end
end

-- A stepped dome or cone: rings from radius r0 at y0 shrinking to r1 at y1 in `n` steps.
function StudKit.dome(self: Kit, name: string, c: Vector3, sides: number, r0: number, r1: number, y0: number, y1: number, n: number, cols: { Color3 }, round: boolean?)
	local h = (y1 - y0) / n
	for k = 0, n - 1 do
		local f = k / n
		local r = if round then r1 + (r0 - r1) * math.cos(f * math.pi / 2) else r0 + (r1 - r0) * f
		self:ring(name, c, sides, r, y0 + k * h, h, math.min(r, 2.2), { cols[k % #cols + 1] })
	end
	self:cyl(name .. "Core", math.max(0.4, r0 * 1.4), (y1 - y0) * 0.9, CFrame.new(c + Vector3.new(0, (y0 + y1) / 2 - (y1 - y0) * 0.05, 0)), cols[1])
end

-- a glowing bit (a lantern's glass, lava, a crystal): Neon, no studs, a light if `range`
function StudKit.glow(self: Kit, name: string, size: Vector3, cf: CFrame, color: Color3, range: number?): Part
	local p = self:brick(name, size, cf, color, true)
	p.Material = Enum.Material.Neon
	p.Color = color -- (glows at its own colour, not shaded)
	if range then
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = range
		l.Brightness = 1.2
		l.Parent = p
	end
	return p
end

function StudKit.finish(self: Kit, parent: Instance): Model
	local m = self.model
	m:SetAttribute("Bricks", self.count)
	m:SetAttribute("StudBuilt", true) -- (server/StudLook leaves it as built)
	m.WorldPivot = self.origin
	m.Parent = parent
	return m
end

return StudKit
