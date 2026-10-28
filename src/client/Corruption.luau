-- CORRUPTION (owner, 27 Oct: the ending teases "world 2, a corrupt world with a demon glitch type of enemy"): the
-- world side of it, on this client only, for films. Corruption.new(centre) gives a handle with:
--   fissure(time)            the ground splits: jagged neon cracks race out from the centre, a glowing pit, embers
--   spread(radius, time)     corrupt voxel blocks burst up out of the meadow in a widening ring; some break apart
--                            and drift up like loose data
--   rift(pos, facing, length, time)  a jagged tear in the sky (a dark void with a burning edge), bits falling out
--   cubes(radius, time)      a "3D pixel" glitch: neon cubes blinking in and out round the centre
--   bolt(a, b)               magenta lightning (VFXLib's Lightning when the place has it, else drawn here)
--   canopy(time)             dark violet storm sheets rolling in overhead
--   destroy()                all of it gone
-- Every count goes through `budget` (Potato Mode and phones get fewer blocks). Nothing runs until a film calls it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Device = require(script.Parent.Device)
local IntroCast = require(script.Parent.IntroCast)
local Potato = require(script.Parent.Potato)

local Corruption = {}

local UP = Vector3.yAxis
local MAGENTA = Color3.fromRGB(255, 40, 170)
local HOT = Color3.fromRGB(255, 205, 238)
local CYAN = Color3.fromRGB(60, 240, 255)
local VOIDC = Color3.fromRGB(8, 2, 14)
local BLOCKS = { Color3.fromRGB(22, 8, 30), Color3.fromRGB(38, 12, 56), Color3.fromRGB(64, 20, 92), Color3.fromRGB(30, 10, 40) }

-- VFXLib's procedural lightning (the place's VFX Lab library), if it's there
local Lightning: any = nil
pcall(function()
	local lib = ReplicatedStorage:FindFirstChild("VFXLib")
	local m = lib and lib:FindFirstChild("Lightning")
	if m then
		Lightning = require(m)
	end
end)

local function budget(n: number): number
	local k = if Potato.on then 0.4 elseif Device.touch then 0.6 else 1
	return math.max(1, math.floor(n * k + 0.5))
end

local function tween(obj: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

export type Handle = {
	folder: Folder,
	fissure: (time: number) -> (),
	spread: (radius: number, time: number) -> (),
	rift: (pos: Vector3, facing: Vector3, length: number, time: number) -> (),
	cubes: (radius: number, time: number) -> (),
	bolt: (a: Vector3, b: Vector3) -> (),
	canopy: (time: number) -> (),
	destroy: () -> (),
}

function Corruption.new(centre: Vector3): Handle
	local folder = Instance.new("Folder")
	folder.Name = "Corruption"
	folder.Parent = workspace
	local alive = true
	local ground = IntroCast.ground(centre)

	local function part(size: Vector3, cf: CFrame, color: Color3, neon: boolean?, transparency: number?): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
		p.Color = color
		p.Size = size
		p.CFrame = cf
		p.Transparency = transparency or 0
		p.Parent = folder
		return p
	end

	-- a crack segment lying on the ground from a to b: a magenta glow with a white-hot core
	local function crack(a: Vector3, b: Vector3, width: number)
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		local cf = CFrame.lookAt(mid, b) * CFrame.new(0, 0.12, 0)
		local outer = part(Vector3.new(width, 0.25, len + width * 0.5), cf, MAGENTA, true)
		local inner = part(Vector3.new(width * 0.35, 0.3, len), cf * CFrame.new(0, 0.05, 0), HOT, true)
		outer.Size = Vector3.new(0.05, 0.25, len + width * 0.5)
		tween(outer, 0.12, { Size = Vector3.new(width, 0.25, len + width * 0.5) }, Enum.EasingStyle.Back)
		local _ = inner
	end

	local handle = {} :: Handle
	handle.folder = folder

	function handle.fissure(time: number)
		local rng = Random.new()
		local branches = budget(7)
		for b = 1, branches do
			local ang = (b / branches) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
			local p = Vector3.new(centre.X, ground.Y, centre.Z)
			local steps = rng:NextInteger(6, 10)
			for s = 1, steps do
				ang += rng:NextNumber(-0.6, 0.6)
				local q = p + Vector3.new(math.cos(ang), 0, math.sin(ang)) * rng:NextNumber(3, 6.5)
				q = Vector3.new(q.X, IntroCast.ground(q).Y, q.Z)
				local a, w = p, math.max(0.4, 1.8 - s * 0.16)
				task.delay(time * (s / steps) * rng:NextNumber(0.8, 1.1), function()
					if alive then
						crack(a, q, w)
					end
				end)
				p = q
			end
		end
		-- the pit: a dark mouth with light pouring up out of it and embers
		local pit = part(Vector3.new(0.4, 1, 1), CFrame.new(ground + UP * 0.15) * CFrame.Angles(0, 0, math.rad(90)), VOIDC)
		pit.Shape = Enum.PartType.Cylinder
		tween(pit, time, { Size = Vector3.new(0.4, 16, 16) }, Enum.EasingStyle.Quart)
		local light = Instance.new("PointLight")
		light.Color = MAGENTA
		light.Range = 0
		light.Brightness = 4
		light.Parent = pit
		tween(light, time, { Range = 40 })
		local embers = Instance.new("ParticleEmitter")
		embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		embers.Color = ColorSequence.new(MAGENTA, CYAN)
		embers.LightEmission = 1
		embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
		embers.Lifetime = NumberRange.new(1.2, 2.4)
		embers.Speed = NumberRange.new(8, 18)
		embers.SpreadAngle = Vector2.new(25, 25)
		embers.EmissionDirection = Enum.NormalId.Right -- (the cylinder's axis is X, turned to point up)
		embers.Rate = budget(40)
		embers.Parent = pit
	end

	function handle.spread(radius: number, time: number)
		local rng = Random.new()
		local n = budget(150)
		for _ = 1, n do
			local r = math.sqrt(rng:NextNumber(0.02, 1)) * radius
			local a = rng:NextNumber(0, math.pi * 2)
			local at = centre + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			local accent = rng:NextNumber() < 0.16
			local size = if accent then rng:NextNumber(0.6, 1.3) else rng:NextNumber(1.4, 3.6)
			local color = if accent then (if rng:NextNumber() < 0.6 then MAGENTA else CYAN) else BLOCKS[rng:NextInteger(1, #BLOCKS)]
			task.delay(time * (r / radius) * rng:NextNumber(0.85, 1.05), function()
				if not alive then
					return
				end
				local g = IntroCast.ground(at)
				local spin = CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
				local up = g + UP * (size * rng:NextNumber(0.1, 0.9))
				local p = part(Vector3.one * size, CFrame.new(g - UP * size) * spin, color, accent)
				tween(p, 0.35, { CFrame = CFrame.new(up) * spin }, Enum.EasingStyle.Back)
				-- some break loose and drift up, crumbling, like loose data
				if rng:NextNumber() < 0.3 then
					task.delay(rng:NextNumber(0.6, 2.2), function()
						if p.Parent then
							local t = rng:NextNumber(1.6, 3)
							tween(p, t, { CFrame = CFrame.new(up + UP * rng:NextNumber(6, 16)) * spin * CFrame.Angles(rng:NextNumber(-2, 2), rng:NextNumber(-2, 2), 0), Size = Vector3.one * 0.1, Transparency = 1 }, Enum.EasingStyle.Sine)
						end
					end)
				end
			end)
		end
	end

	function handle.rift(pos: Vector3, facing: Vector3, length: number, time: number)
		-- a zig-zag tear, drawn from the middle out; the dark void sits just behind the burning edge
		local look = CFrame.lookAt(pos, pos + facing)
		local rng = Random.new()
		local segs = 9
		local pts = {}
		for i = 0, segs do
			local y = (i / segs - 0.5) * length
			local x = (if i % 2 == 0 then -1 else 1) * rng:NextNumber(1.5, 5) * (1 - math.abs(i / segs - 0.5))
			table.insert(pts, (look * CFrame.new(x, y, 0)).Position)
		end
		local mid = segs // 2
		for i = 1, segs do
			local a, b = pts[i], pts[i + 1]
			local d = math.abs(i - mid - 0.5)
			task.delay(time * d / (segs / 2), function()
				if not alive then
					return
				end
				local c = (a + b) / 2
				local len = (b - a).Magnitude
				local cf = CFrame.lookAt(c, b, look.LookVector) * CFrame.Angles(math.rad(90), 0, 0)
				local w = 3.2 - d * 0.3
				local void = part(Vector3.new(w * 2.2, len, 0.6), cf * CFrame.new(0, 0, 0.8), VOIDC, false)
				local edge = part(Vector3.new(0.1, len + 1, 0.5), cf, MAGENTA, true)
				local core = part(Vector3.new(0.1, len, 0.6), cf * CFrame.new(0, 0, -0.1), HOT, true)
				tween(edge, 0.3, { Size = Vector3.new(w, len + 1, 0.5) }, Enum.EasingStyle.Back)
				tween(core, 0.3, { Size = Vector3.new(w * 0.35, len, 0.6) })
				local _ = void
			end)
		end
		local glow = Instance.new("PointLight")
		glow.Color = MAGENTA
		glow.Range = 60
		glow.Brightness = 3
		local anchor = part(Vector3.one * 0.2, CFrame.new(pos), VOIDC, false, 1)
		glow.Parent = anchor
		-- bits of the world falling out of it
		task.spawn(function()
			local stop = os.clock() + time + 6
			while alive and os.clock() < stop do
				local from = pts[rng:NextInteger(1, #pts)]
				local s = rng:NextNumber(0.6, 1.8)
				local c = if rng:NextNumber() < 0.5 then MAGENTA else BLOCKS[rng:NextInteger(1, #BLOCKS)]
				local p = part(Vector3.one * s, CFrame.new(from), c, c == MAGENTA)
				tween(p, rng:NextNumber(1.2, 2.2), { CFrame = CFrame.new(from - UP * rng:NextNumber(18, 40) + facing * rng:NextNumber(-6, 6)) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				task.delay(2.3, function()
					p:Destroy()
				end)
				task.wait(0.09)
			end
		end)
	end

	function handle.cubes(radius: number, time: number)
		task.spawn(function()
			local rng = Random.new()
			local stop = os.clock() + time
			local colors = { MAGENTA, CYAN, HOT, VOIDC }
			while alive and os.clock() < stop do
				for _ = 1, budget(3) do
					local at = centre + Vector3.new(rng:NextNumber(-radius, radius), rng:NextNumber(2, radius * 0.8), rng:NextNumber(-radius, radius))
					local c = colors[rng:NextInteger(1, #colors)]
					local p = part(Vector3.one * rng:NextNumber(0.5, 2.4), CFrame.new(at), c, c ~= VOIDC)
					task.delay(rng:NextNumber(0.06, 0.25), function()
						p:Destroy()
					end)
				end
				task.wait(0.05)
			end
		end)
	end

	function handle.bolt(a: Vector3, b: Vector3)
		if Lightning then
			local ok = pcall(Lightning.Strike, a, b, { Color = MAGENTA, CoreColor = HOT, Width = 1.4, Duration = 0.4, Flickers = 4, Branches = 3 })
			if ok then
				return
			end
		end
		-- (no VFXLib) a jagged bolt of neon sticks
		local pts = { a }
		for i = 1, 6 do
			local p = a:Lerp(b, i / 7) + Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 7
			table.insert(pts, p)
		end
		table.insert(pts, b)
		local made = {}
		for i = 1, #pts - 1 do
			local c = (pts[i] + pts[i + 1]) / 2
			local len = (pts[i + 1] - pts[i]).Magnitude
			table.insert(made, part(Vector3.new(0.7, 0.7, len), CFrame.lookAt(c, pts[i + 1]), HOT, true))
		end
		task.delay(0.22, function()
			for _, p in made do
				p:Destroy()
			end
		end)
	end

	function handle.canopy(time: number)
		local rng = Random.new()
		for i = 1, budget(5) do
			local at = centre + Vector3.new(rng:NextNumber(-90, 90), 110 + i * 9, rng:NextNumber(-90, 90))
			local sheet = part(Vector3.new(rng:NextNumber(160, 260), 2, rng:NextNumber(160, 260)), CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color3.fromRGB(34, 8, 44), false, 1)
			tween(sheet, time, { Transparency = rng:NextNumber(0.35, 0.6) }, Enum.EasingStyle.Sine)
			tween(sheet, time + 20, { CFrame = sheet.CFrame * CFrame.new(rng:NextNumber(-30, 30), 0, rng:NextNumber(-30, 30)) }, Enum.EasingStyle.Linear)
		end
	end

	function handle.destroy()
		alive = false
		folder:Destroy()
	end

	return handle
end

return Corruption
