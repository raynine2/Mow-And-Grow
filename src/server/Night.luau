-- Night in a run (Chop A Forest v2). The clock is server/DayNight's (ReplicatedStorage DayPhase / DayLeft /
-- DayLength). At night Weed Crawlers creep out of the grass near players who are out in the zones (never in the hub) and
-- chase them; one that reaches you stuns you and crumbles. Cut them with your tools (or shoot them) for coins.
-- Peaceful Mode turns the crawlers off; the clock still runs so the sky still changes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Net = require(script.Parent.Net)
local RunBuilder = require(script.Parent.RunBuilder)
local Boss = require(script.Parent.Boss)

local Night = {}
Night.peaceful = false
Night.onKill = nil :: ((Player, Vector3, number) -> ())? -- (killer, position, zone)
Night.onChanged = nil :: (() -> ())?

type Crawler = { model: Model, root: BasePart, hp: number, z: number, target: Player?, born: number }
local crawlers: { Crawler } = {}
local folder: Folder? = nil
local cycleStart = workspace:GetServerTimeNow()
local isNight = false
local rng = Random.new()
local lastSpawn: { [Player]: number } = {}

-- { night, left (seconds until the switch), length, peaceful } for the HUD.
function Night.state()
	local night = ReplicatedStorage:GetAttribute("DayPhase") == "night"
	return {
		night = night,
		left = tonumber(ReplicatedStorage:GetAttribute("DayLeft")) or 0,
		length = tonumber(ReplicatedStorage:GetAttribute("DayLength")) or 0,
		peaceful = Night.peaceful,
	}
end

-- The area a point is in (0 = the hub or outside the map).
local function zoneOf(pos: Vector3): number
	return math.max(0, Config.zoneAt(pos))
end

local function dark(c: Color3): Color3
	return Color3.new(c.R * 0.6, c.G * 0.6, c.B * 0.6)
end

local function build(pos: Vector3): (Model, BasePart)
	local c = Config.CRAWLERS.color
	local m = Instance.new("Model")
	m.Name = Config.CRAWLERS.name
	local function part(size: Vector3, cf: CFrame, color: Color3, neon: boolean?): BasePart
		local p = Instance.new("Part")
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.Parent = m
		return p
	end
	local base = CFrame.new(pos)
	local root = part(Vector3.new(2.6, 1.6, 2.6), base * CFrame.new(0, 0.8, 0), c)
	root.Name = "Root"
	-- leafy tufts on its back
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		part(Vector3.new(0.5, 1.6, 1.1), base * CFrame.new(math.cos(a) * 0.8, 2, math.sin(a) * 0.8) * CFrame.Angles(math.sin(a) * 0.5, 0, -math.cos(a) * 0.5), Color3.fromRGB(60, 110, 50))
	end
	-- glowing eyes and little legs
	for _, x in { -0.55, 0.55 } do
		part(Vector3.new(0.45, 0.45, 0.2), base * CFrame.new(x, 1.1, -1.32), Color3.fromRGB(255, 230, 80), true)
		for _, z in { -0.8, 0.8 } do
			part(Vector3.new(0.35, 0.5, 0.35), base * CFrame.new(x * 2, 0.25, z), dark(c))
		end
	end
	m.PrimaryPart = root
	m.Parent = folder
	return m, root
end
local function remove(i: number, puff: boolean)
	local cr = crawlers[i]
	table.remove(crawlers, i)
	if puff then
		Net.all("Fx", "crawlerPop", { pos = cr.root.Position })
	end
	cr.model:Destroy()
end

function Night.clear()
	for i = #crawlers, 1, -1 do
		remove(i, true)
	end
end

local function rootOf(p: Player): BasePart?
	local char = p.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Cut / shoot crawlers within `radius` of `pos`. Returns how many were hit.
function Night.hit(player: Player, pos: Vector3, radius: number, damage: number): number
	local hits = 0
	for i = #crawlers, 1, -1 do
		local cr = crawlers[i]
		local d = (Vector3.new(cr.root.Position.X - pos.X, 0, cr.root.Position.Z - pos.Z)).Magnitude
		if d <= radius + 1.5 then
			hits += 1
			cr.hp -= damage
			Net.send(player, "Fx", "crawlerHit", { pos = cr.root.Position })
			if cr.hp <= 0 then
				local at, z = cr.root.Position, cr.z
				remove(i, true)
				if Night.onKill then
					Night.onKill(player, at, z)
				end
			end
		end
	end
	return hits
end

-- The crawler nearest to the line from `origin` along `dir` (within `range` and a narrow cone), for guns.
function Night.aimed(origin: Vector3, dir: Vector3, range: number): Vector3?
	local best, bestDot = nil, 0.97
	for _, cr in crawlers do
		local to = cr.root.Position - origin
		if to.Magnitude <= range then
			local dot = to.Unit:Dot(dir)
			if dot > bestDot then
				best, bestDot = cr.root.Position, dot
			end
		end
	end
	return best
end

local function spawnFor(p: Player, z: number, at: Vector3)
	-- somewhere around the player, kept inside their area's fence
	local centre = Config.zoneCentre(z)
	local half = Config.zoneHalf() - Config.MAP.margin
	local a = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(22, 34)
	local x = math.clamp(at.X + math.cos(a) * r, centre.X - half, centre.X + half)
	local zz = math.clamp(at.Z + math.sin(a) * r, centre.Z - half, centre.Z + half)
	local model, root = build(Vector3.new(x, 0, zz))
	local grass = Config.ZONES[z]
	table.insert(crawlers, { model = model, root = root, hp = grass.hp * Config.CRAWLERS.hpHits, z = z, target = p, born = os.clock() })
	Net.all("Fx", "crawlerSpawn", { pos = root.Position })
end

local function step(dt: number)
	local st = Night.state()
	if st.night ~= isNight then
		isNight = st.night
		Net.all("Fx", if isNight then "nightFalls" else "dayBreaks", { peaceful = Night.peaceful })
		if not isNight then
			Night.clear()
		end
		if Night.onChanged then
			Night.onChanged()
		end
	end
	if not isNight or Night.peaceful then
		return
	end
	-- spawn near players out in the zones
	local count: { [Player]: number } = {}
	for _, cr in crawlers do
		if cr.target then
			count[cr.target] = (count[cr.target] or 0) + 1
		end
	end
	for _, p in Players:GetPlayers() do
		local root = rootOf(p)
		local z = if root then zoneOf(root.Position) else 0
		if root and z > 0 and (count[p] or 0) < Config.CRAWLERS.maxPerPlayer and #crawlers < Config.CRAWLERS.maxTotal and os.clock() - (lastSpawn[p] or 0) > Config.CRAWLERS.every then
			lastSpawn[p] = os.clock()
			spawnFor(p, z, root.Position)
		end
	end
	-- chase
	for i = #crawlers, 1, -1 do
		local cr = crawlers[i]
		local target = cr.target
		local troot = target and target.Parent and rootOf(target)
		if not troot or zoneOf(troot.Position) == 0 then
			-- its player went home (or left): it burrows back into the grass
			remove(i, true)
			continue
		end
		local from = cr.root.Position
		local flatTo = Vector3.new(troot.Position.X, from.Y, troot.Position.Z)
		local to = flatTo - from
		if to.Magnitude < 2.6 then
			Boss.stun(target :: Player, from)
			remove(i, true)
			continue
		end
		local move = math.min(to.Magnitude, Config.CRAWLERS.speed * dt)
		local nextPos = from + to.Unit * move
		local hop = math.abs(math.sin((os.clock() - cr.born) * 10)) * 0.4
		cr.model:PivotTo(CFrame.lookAt(nextPos, nextPos + to.Unit) * CFrame.new(0, hop - (cr.model:GetAttribute("Hop") or 0), 0))
		cr.model:SetAttribute("Hop", hop)
	end
end

local started = false
function Night.start(parent: Instance, peaceful: boolean)
	Night.peaceful = peaceful
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	;(folder :: Folder).Name = "Crawlers"
	;(folder :: Folder).Parent = parent
	table.clear(crawlers)
	cycleStart = workspace:GetServerTimeNow()
	isNight = false
	if started then
		return
	end
	started = true
	Players.PlayerRemoving:Connect(function(p)
		lastSpawn[p] = nil
	end)
	task.spawn(function()
		while true do
			local dt = task.wait(0.1)
			local ok, err = pcall(step, dt)
			if not ok then
				warn("[Night] " .. tostring(err))
			end
		end
	end)
end

-- Studio test helper: jump to night (or day) on server/DayNight's clock.
function Night.skipTo(night: boolean)
	if Night.state().night ~= night then
		require(script.Parent.DayNight).skip()
	end
end

return Night
