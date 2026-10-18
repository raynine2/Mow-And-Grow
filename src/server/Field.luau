-- Grass patches: spawning, cutting, hidden mutations, zone clear.
-- A patch is one studded block. It shrinks as it takes damage; at 0 HP it becomes stubble and gives a bundle.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.MowALawn.Config)
local Net = require(script.Parent.Net)
local PropKit = require(script.Parent.PropKit)
local RunBuilder = require(script.Parent.RunBuilder)

local Field = {}

type Patch = {
	part: Part,
	z: number,
	col: number,
	row: number,
	hp: number,
	maxHp: number,
	height: number,
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

-- Hooks the run sets up.
Field.onCut = nil :: ((Player, Patch) -> boolean)? -- return false to refuse (bag full)
Field.canCut = nil :: ((Player) -> boolean)?
Field.onZoneCleared = nil :: ((number) -> ())?
Field.onProgress = nil :: (() -> ())?

local function index(col: number, row: number): number
	return (row - 1) * Config.GRID.cols + col
end

local function stubble(p: Patch)
	local part = p.part
	part.Size = Vector3.new(part.Size.X, 0.3, part.Size.Z)
	local pos = RunBuilder.patchPosition(p.z, p.col, p.row)
	part.CFrame = CFrame.new(pos.X, 0.3 + 0.15, pos.Z)
	part.Color = PropKit.shade(Config.ZONES[p.z].grass[2], 0.75)
	part.Material = Enum.Material.Plastic
	part.CanQuery = false
	local fx = part:FindFirstChild("MutationSparkle")
	if fx then
		fx:Destroy()
	end
end

local function spawnZone(z: number, alreadyCut: boolean)
	local def = Config.ZONES[z]
	local zoneFolder = PropKit.folder("Grass" .. z, folder :: Folder)
	patches[z] = {}
	Field.remaining[z] = if alreadyCut then 0 else Field.total
	local t = Config.GRID.tile
	for row = 1, Config.GRID.rows do
		for col = 1, Config.GRID.cols do
			local pos = RunBuilder.patchPosition(z, col, row)
			local h = def.height * rng:NextNumber(0.85, 1.15)
			local color = def.grass[(col + row) % 2 + 1]
			local part = PropKit.part({
				size = Vector3.new(t - 0.2, h, t - 0.2),
				cf = CFrame.new(pos.X, 0.3 + h / 2, pos.Z),
				color = color,
				parent = zoneFolder,
				collide = false,
				name = "Grass",
			})
			part.CanTouch = false
			part:SetAttribute("Zone", z)
			local p: Patch = {
				part = part,
				z = z,
				col = col,
				row = row,
				hp = def.hp,
				maxHp = def.hp,
				height = h,
				mut = nil,
				cut = alreadyCut,
				baseColor = color,
			}
			patches[z][index(col, row)] = p
			if alreadyCut then
				stubble(p)
			end
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
	if mut ~= "None" then
		local m = Config.mutation(mut)
		p.part.Color = m.color
		p.part.Material = if p.mut == "Diamond" then Enum.Material.Glass else Enum.Material.SmoothPlastic
		local sparkle = Instance.new("Sparkles")
		sparkle.Name = "MutationSparkle"
		sparkle.SparkleColor = m.color
		sparkle.Parent = p.part
		p.part:SetAttribute("Mutation", p.mut)
		Net.all("Fx", "reveal", { pos = p.part.Position, mut = p.mut })
	end
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
		Net.all("Fx", "cut", { pos = p.part.Position, color = p.baseColor, mut = p.mut, z = p.z })
		Field.remaining[p.z] -= 1
		if Field.onProgress then
			Field.onProgress()
		end
		if Field.remaining[p.z] <= 0 and Field.onZoneCleared then
			Field.onZoneCleared(p.z)
		end
	else
		-- shrink with damage
		local ratio = p.hp / p.maxHp
		local h = math.max(0.6, p.height * (0.35 + 0.65 * ratio))
		local pos = RunBuilder.patchPosition(p.z, p.col, p.row)
		p.part.Size = Vector3.new(p.part.Size.X, h, p.part.Size.Z)
		p.part.CFrame = CFrame.new(pos.X, 0.3 + h / 2, pos.Z)
		Net.send(player, "Fx", "chip", { pos = p.part.Position, color = p.part.Color })
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
