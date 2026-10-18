-- Grass patches: spawning, cutting, hidden mutations, zone clear.
-- A patch is a studded turf brick with a few grass stalks on top (lawn tufts, golf grass, wheat with heads,
-- reeds with cattails, jungle bushes). Stalks shrink as the patch takes damage; at 0 HP the patch becomes
-- short stubble and gives a bundle.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.MowALawn.Config)
local Net = require(script.Parent.Net)
local PropKit = require(script.Parent.PropKit)
local RunBuilder = require(script.Parent.RunBuilder)

local Field = {}

type Stalk = { stem: Part, head: Part?, cap: Part?, baseH: number, headH: number, x: number, z: number }
type Patch = {
	part: Part, -- the turf brick (position used for effects)
	stalks: { Stalk },
	z: number,
	col: number,
	row: number,
	hp: number,
	maxHp: number,
	mut: string?, -- nil until the first hit reveals it
	cut: boolean,
	baseColor: Color3,
}

local patches: { [number]: { [number]: Patch } } = {} -- [zone][index]
Field.remaining = {} :: { [number]: number }
Field.total = Config.GRID.cols * Config.GRID.rows
Field.unlocked = 1 -- zones above this can't be cut yet (gate closed)

local folder: Folder? = nil
local rng = Random.new()
local TURF_H = 0.8
local TURF_TOP = 0.3 + TURF_H

-- Hooks the run sets up.
Field.onCut = nil :: ((Player, Patch) -> boolean)? -- return false to refuse (bag full)
Field.canCut = nil :: ((Player) -> boolean)?
Field.onZoneCleared = nil :: ((number) -> ())?
Field.onProgress = nil :: (() -> ())?

local function index(col: number, row: number): number
	return (row - 1) * Config.GRID.cols + col
end

-- How each zone's grass looks: stalk count, width, height factor, and an optional head on top.
local STYLES = {
	lawn = { count = 3, width = 1.6, height = 1.0 },
	golf = { count = 4, width = 1.4, height = 0.8 },
	wheat = { count = 3, width = 0.9, height = 1.0, head = Vector3.new(1.4, 1.6, 1.4), headColor = Color3.fromRGB(205, 150, 40) },
	reeds = { count = 3, width = 0.8, height = 1.0, head = Vector3.new(1.1, 2, 1.1), headColor = Color3.fromRGB(120, 75, 40) },
	jungle = { count = 2, width = 2.8, height = 0.6, head = Vector3.new(3.6, 1.2, 3.6), headColor = Color3.fromRGB(25, 110, 45) },
}

local function brick(parent: Instance, size: Vector3, cf: CFrame, color: Color3, name: string, material: Enum.Material?): Part
	local part = PropKit.part({ size = size, cf = cf, color = color, parent = parent, collide = false, name = name, material = material })
	part.CanTouch = false
	part.CanQuery = false
	return part
end

-- After the first hit the top is knocked off (Fx flings it) and a lighter fresh-cut top shows; the stalk keeps
-- getting shorter with every hit.
local function layoutStalk(s: Stalk, ratio: number): Part?
	local h = math.max(0.4, s.baseH * (0.3 + 0.7 * ratio))
	s.stem.Size = Vector3.new(s.stem.Size.X, h, s.stem.Size.Z)
	s.stem.CFrame = CFrame.new(s.x, TURF_TOP + h / 2, s.z)
	local knocked = nil
	if s.head then
		knocked = s.head
		s.head = nil
	end
	if not s.cap then
		local w = s.stem.Size.X
		s.cap = brick(s.stem.Parent :: Instance, Vector3.new(w + 0.02, 0.18, w + 0.02), CFrame.new(), PropKit.shade(s.stem.Color, 1.45), "CutTop", Enum.Material.SmoothPlastic)
	end
	local cap = s.cap :: Part
	cap.CFrame = CFrame.new(s.x, TURF_TOP + h + 0.08, s.z)
	return knocked
end

local function stubble(p: Patch)
	for _, s in p.stalks do
		s.stem:Destroy()
		if s.head then
			s.head:Destroy()
		end
		if s.cap then
			s.cap:Destroy()
		end
	end
	table.clear(p.stalks)
	local turf = p.part
	turf.Color = PropKit.shade(Config.ZONES[p.z].grass[2], 0.72)
	turf.Material = Enum.Material.Plastic
	local glow = turf:FindFirstChild("MutationGlow")
	if glow then
		glow:Destroy()
	end
	local sparkle = turf:FindFirstChild("MutationSparkle")
	if sparkle then
		sparkle:Destroy()
	end
end

local function spawnPatch(zoneFolder: Instance, z: number, col: number, row: number, alreadyCut: boolean): Patch
	local def = Config.ZONES[z]
	local style = STYLES[def.style] or STYLES.lawn
	local t = Config.GRID.tile
	local pos = RunBuilder.patchPosition(z, col, row)
	local colorA = def.grass[1]
	local colorB = def.grass[2]
	local model = Instance.new("Model")
	model.Name = "Patch"
	local turf = brick(model, Vector3.new(t - 0.2, TURF_H, t - 0.2), CFrame.new(pos.X, 0.3 + TURF_H / 2, pos.Z), PropKit.shade(colorB, 0.88), "Turf", Enum.Material.Grass)
	turf.CanQuery = true
	local p: Patch = {
		part = turf,
		stalks = {},
		z = z,
		col = col,
		row = row,
		hp = def.hp,
		maxHp = def.hp,
		mut = nil,
		cut = alreadyCut,
		baseColor = colorA,
	}
	if not alreadyCut then
		-- spread stalks over the tile without overlapping too much
		local spots = { Vector2.new(-1.3, -1.2), Vector2.new(1.3, -0.9), Vector2.new(-0.6, 1.4), Vector2.new(1.2, 1.3) }
		for i = 1, style.count do
			local spot = spots[i]
			local jitter = Vector2.new(rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.4, 0.4))
			local x = pos.X + (spot.X + jitter.X) * (if style.count <= 2 then 0.7 else 1)
			local zz = pos.Z + (spot.Y + jitter.Y) * (if style.count <= 2 then 0.7 else 1)
			local w = style.width * rng:NextNumber(0.9, 1.1)
			local baseH = def.height * style.height * rng:NextNumber(0.75, 1.2)
			local color = if (i + col + row) % 2 == 0 then colorA else colorB
			local stem = brick(model, Vector3.new(w, baseH, w), CFrame.new(x, TURF_TOP + baseH / 2, zz), color, "Stalk", Enum.Material.Grass)
			local head = nil
			local headH = 0
			if style.head then
				headH = style.head.Y
				head = brick(model, style.head, CFrame.new(x, TURF_TOP + baseH + headH / 2, zz), style.headColor, "Head")
			end
			table.insert(p.stalks, { stem = stem, head = head, cap = nil, baseH = baseH, headH = headH, x = x, z = zz })
		end
	else
		stubble(p)
	end
	model.Parent = zoneFolder
	return p
end

local function spawnZone(z: number, alreadyCut: boolean)
	local zoneFolder = PropKit.folder("Grass" .. z, folder :: Folder)
	patches[z] = {}
	Field.remaining[z] = if alreadyCut then 0 else Field.total
	for row = 1, Config.GRID.rows do
		for col = 1, Config.GRID.cols do
			patches[z][index(col, row)] = spawnPatch(zoneFolder, z, col, row, alreadyCut)
		end
	end
end

function Field.build(parent: Instance, startZone: number)
	folder = PropKit.folder("Grass", parent)
	for z = 1, #Config.ZONES do
		spawnZone(z, z < startZone)
	end
	Field.unlocked = startZone
end

-- Patches near a point, nearest first. Only zones that are unlocked.
local function query(pos: Vector3, radius: number): { Patch }
	local found = {}
	local t = Config.GRID.tile
	local half = Config.GRID.cols * t / 2
	for z = 1, Field.unlocked do
		local zs = Config.zoneStartZ(z)
		local zoneEnd = zs + Config.GRID.rows * t
		if pos.Z + radius >= zs and pos.Z - radius <= zoneEnd and patches[z] then
			local c0 = math.max(1, math.floor((pos.X - radius + half) / t) + 1)
			local c1 = math.min(Config.GRID.cols, math.floor((pos.X + radius + half) / t) + 1)
			local r0 = math.max(1, math.floor((pos.Z - radius - zs) / t) + 1)
			local r1 = math.min(Config.GRID.rows, math.floor((pos.Z + radius - zs) / t) + 1)
			for row = r0, r1 do
				for col = c0, c1 do
					local p = patches[z][index(col, row)]
					if p and not p.cut then
						local pp = RunBuilder.patchPosition(z, col, row)
						local dx, dz = pp.X - pos.X, pp.Z - pos.Z
						-- count a patch if any part of it is inside the circle
						local d = math.sqrt(dx * dx + dz * dz) - t * 0.5
						if d <= radius then
							table.insert(found, { p = p, d = d })
						end
					end
				end
			end
		end
	end
	table.sort(found, function(a, b)
		return a.d < b.d
	end)
	local out = {}
	for i, f in found do
		out[i] = f.p
	end
	return out
end

local function reveal(p: Patch, luck: number)
	local mut = Config.rollMutation(rng, luck)
	p.mut = mut
	if mut == "None" then
		return
	end
	local m = Config.mutation(mut)
	for _, s in p.stalks do
		s.stem.Color = m.color
		s.stem.Material = if mut == "Diamond" then Enum.Material.Glass elseif mut == "Galaxy" or mut == "Toxic" then Enum.Material.Neon else Enum.Material.SmoothPlastic
		if s.head then
			s.head.Color = PropKit.shade(m.color, 0.8)
		end
	end
	local glow = Instance.new("PointLight")
	glow.Name = "MutationGlow"
	glow.Color = m.color
	glow.Range = 10
	glow.Brightness = 1.5
	glow.Parent = p.part
	local sparkle = Instance.new("ParticleEmitter") -- default texture is the engine's sparkle
	sparkle.Name = "MutationSparkle"
	sparkle.Color = ColorSequence.new(m.color)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new(0.5, 0)
	sparkle.Lifetime = NumberRange.new(0.6, 1)
	sparkle.Rate = 8
	sparkle.Speed = NumberRange.new(2, 4)
	sparkle.SpreadAngle = Vector2.new(40, 40)
	sparkle.EmissionDirection = Enum.NormalId.Top
	sparkle.Parent = p.part
	p.part:SetAttribute("Mutation", mut)
	Net.all("Fx", "reveal", { pos = p.part.Position, mut = mut })
end

local function damagePatch(player: Player, p: Patch, amount: number, luck: number): boolean
	if p.mut == nil then
		reveal(p, luck)
	end
	p.hp = math.max(0, p.hp - amount)
	if p.hp <= 0 then
		local ok = if Field.onCut then Field.onCut(player, p) else true
		if not ok then
			p.hp = math.max(1, p.maxHp * 0.02) -- bag full: stays nearly cut until you empty your bag
			return false
		end
		p.cut = true
		stubble(p)
		Net.all("Fx", "cut", { pos = p.part.Position, color = p.baseColor, mut = p.mut, z = p.z, by = player.UserId })
		Field.remaining[p.z] -= 1
		if Field.onProgress then
			Field.onProgress()
		end
		if Field.remaining[p.z] <= 0 and Field.onZoneCleared then
			Field.onZoneCleared(p.z)
		end
	else
		-- stalks shrink with damage
		local ratio = p.hp / p.maxHp
		for _, s in p.stalks do
			local knocked = layoutStalk(s, ratio)
			if knocked then
				-- the top flies off (drawn by every client), then the server copy goes
				Net.all("Fx", "topOff", { pos = knocked.Position, size = knocked.Size, color = knocked.Color })
				knocked:Destroy()
			end
		end
		local first = p.stalks[1]
		Net.send(player, "Fx", "chip", { pos = p.part.Position, color = if first then first.stem.Color else p.baseColor })
	end
	return true
end

-- Hit up to `maxTargets` patches within `radius` of `pos`. Returns how many were hit.
function Field.hit(player: Player, pos: Vector3, radius: number, damage: number, maxTargets: number?, luck: number): number
	if Field.canCut and not Field.canCut(player) then
		return 0
	end
	local list = query(pos, radius)
	local n = 0
	for _, p in list do
		if maxTargets and n >= maxTargets then
			break
		end
		if not damagePatch(player, p, damage, luck) then
			break -- bag full; stop for this hit
		end
		n += 1
	end
	return n
end

function Field.unlock(z: number)
	Field.unlocked = math.max(Field.unlocked, z)
end

function Field.remainingIn(z: number): number
	return Field.remaining[z] or 0
end

return Field
