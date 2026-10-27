-- GOLDEN GNOME HUNT (owner, 27 Oct): gnomes hidden in the grass of every area, a server-wide announcement when
-- someone finds one, and a collection to fill (Config.GNOMES; the Index window shows it).
--   * Gnomes.build(world) stands Config.GNOMES.perArea gnomes in each area of the run, at the foot of random clumps
--     (Field.hideSpots), each with a faint glint so a sharp eye can spot it. Any of them may be the rare Diamond
--     Gnome instead (at most one per run).
--   * Everyone can pick up each gnome once (E). The finder's own copy disappears on their screen (client/GnomeHunt
--     reads the Found_<userId> attribute); the others still see it and can find it too.
--   * The first of a kind pays its gems, later copies a little, the full set a big bonus once.
--   * Everyone in the server sees "<name> found the <gnome>!" (Fx "gnome").
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local GnomeLook = require(ReplicatedStorage.MowALawn.GnomeLook)
local Net = require(script.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)
local Field = require(script.Parent.Field)
local PropKit = require(script.Parent.PropKit)

local Gnomes = {}

local G = Config.GNOMES
local SCALE = 0.85 -- a little smaller than the pet: easy to miss in the grass
local rng = Random.new()
local found: { [Model]: { [number]: boolean } } = {} -- who picked up each gnome (user ids)

-- How many different gnomes `data` has, and how many there are.
function Gnomes.count(data): (number, number)
	local have = 0
	for _, def in G.list do
		if (data.gnomes[def.id] or 0) > 0 then
			have += 1
		end
	end
	return have, #G.list
end

local function pickUp(player: Player, model: Model, id: string)
	local who = found[model]
	if not who or who[player.UserId] then
		return
	end
	local data = PlayerData.get(player)
	local def = Config.gnome(id)
	if not data or not def then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - model:GetPivot().Position).Magnitude > G.reach + 6 then
		return
	end
	who[player.UserId] = true
	model:SetAttribute("Found_" .. player.UserId, true)
	data.gnomes = data.gnomes or {}
	local before = data.gnomes[id] or 0
	data.gnomes[id] = before + 1
	local first = before == 0
	local gems = if first then def.gems else G.againGems
	local have, total = Gnomes.count(data)
	local set = false
	if first and have >= total and not data.gnomeSet then
		data.gnomeSet = true
		set = true
		gems += G.setGems
	end
	data.gems += gems
	PlayerData.changed(player)
	Net.all("Fx", "gnome", {
		by = player.UserId,
		name = player.DisplayName,
		id = id,
		first = first,
		gems = gems,
		set = set,
		have = have,
		total = total,
		pos = model:GetPivot().Position,
	})
end

-- Stand `cf` on the ground right under it (the ground is stepped: a spot past the edge of a clump's step would
-- float). Looks a little above, so a spot just under a higher step climbs onto it.
local function onGround(cf: CFrame, skip: { Instance }): CFrame
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = skip
	local hit = workspace:Raycast(cf.Position + Vector3.new(0, 3, 0), Vector3.new(0, -14, 0), params)
	if hit and hit.Normal.Y > 0.7 then
		return cf.Rotation + Vector3.new(cf.X, hit.Position.Y, cf.Z)
	end
	return cf
end

local function place(parent: Instance, id: string, at: CFrame, n: number)
	local m = GnomeLook.build(id)
	if not m then
		return
	end
	local skip: { Instance } = { parent }
	local grass = parent.Parent and parent.Parent:FindFirstChild("Grass")
	if grass then
		table.insert(skip, grass)
	end
	local cf = onGround(at, skip)
	m.Name = "Gnome" .. n
	m:ScaleTo(SCALE)
	m:PivotTo(cf)
	m:SetAttribute("Gnome", id)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	-- the prompt and the glint live on an invisible block at its middle
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = Vector3.new(1.4, 2.6, 1.4)
	core.CFrame = cf * CFrame.new(0, 1.4, 0)
	core.Transparency = 1
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.Parent = m
	m.PrimaryPart = core
	local def = Config.gnome(id)
	local prompt = PropKit.prompt(core, "Pick up", if def then def.name else "Gnome", nil, G.reach)
	prompt.HoldDuration = 0.25
	prompt.Triggered:Connect(function(player)
		pickUp(player, m, id)
	end)
	local glint = Instance.new("ParticleEmitter")
	glint.Name = "Glint"
	glint.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	glint.Color = ColorSequence.new(if def and def.diamond then Color3.fromRGB(190, 245, 255) else Color3.fromRGB(255, 226, 110))
	glint.LightEmission = 1
	glint.LightInfluence = 0
	glint.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(1, 0) })
	glint.Lifetime = NumberRange.new(0.8, 1.3)
	glint.Rate = if def and def.diamond then 4 else 1.6
	glint.Speed = NumberRange.new(0.4, 1)
	glint.SpreadAngle = Vector2.new(180, 180)
	glint.Parent = core
	found[m] = {}
	CollectionService:AddTag(m, "MowGnome")
	m.Parent = parent
end

-- Hide the run's gnomes in `world` (after Field.build). Safe to call again: the old ones go.
function Gnomes.build(world: Instance)
	local old = world:FindFirstChild("Gnomes")
	if old then
		old:Destroy()
	end
	table.clear(found)
	local folder = PropKit.folder("Gnomes", world)
	local diamondLeft = true
	local n = 0
	for _, def in G.list do
		if def.zone >= 1 and def.zone <= #Config.ZONES then
			for _, cf in Field.hideSpots(def.zone, G.perArea) do
				n += 1
				local id = def.id
				if diamondLeft and rng:NextNumber() < G.diamondChance then
					id = "Diamond"
					diamondLeft = false
				end
				place(folder, id, cf, n)
			end
		end
	end
	print(("[Gnomes] %d gnomes hidden%s"):format(n, if diamondLeft then "" else " (one is the Diamond Gnome!)"))
end

-- Studio helper (DevPanel / tests): pick up the nearest gnome for `player`.
function Gnomes.devFind(player: Player): string?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local best, bestD = nil, math.huge
	for m in found do
		if m.Parent and not found[m][player.UserId] then
			local d = if root then (root.Position - m:GetPivot().Position).Magnitude else 0
			if d < bestD then
				best, bestD = m, d
			end
		end
	end
	if not best then
		return nil
	end
	if root then
		root.CFrame = best:GetPivot() * CFrame.new(0, 3, 4)
	end
	pickUp(player, best, best:GetAttribute("Gnome"))
	return best:GetAttribute("Gnome")
end

return Gnomes
