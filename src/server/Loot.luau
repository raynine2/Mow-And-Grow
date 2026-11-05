-- Loot on the ground: a cut patch drops its bundle (and sometimes a free gem) next to it. Only the player who cut it
-- can pick it up, by walking within their reach (Loot.reach: Grasp around them, and round a ride-on mower they
-- drive). The server does the pickup itself (there is no remote), so a client can't fake collecting.
-- Drops aren't saved: bundles still on the ground when you leave are lost, like an unfinished swing.
-- (5 Nov, grass toys) Anyone running into a bundle on the ground kicks it a few studs along (Config.GRASS_TOYS.kick):
-- the server moves it (never through a wall, off a terrace edge or far from where it dropped) and bumps its "Kick"
-- attribute, and every client plays a hop-and-roll from the old spot to the new one (client/LootFx).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Net = require(script.Parent.Net)
local Models = require(script.Parent.Models)
local Carry = require(script.Parent.Carry)
local BundleVoxel = require(ReplicatedStorage.MowALawn.BundleVoxel)

local Loot = {}

type Drop = { owner: Player, kind: string, z: number, m: string?, gems: number, pos: Vector3, home: Vector3, kickAt: number, model: Instance?, readyAt: number, dead: boolean? }
type Reach = { pos: Vector3, radius: number }

local drops: { Drop } = {}
local bundlesOf: { [Player]: number } = {}
local folder: Folder? = nil
local rng = Random.new()
local groundRay = RaycastParams.new()
groundRay.FilterType = Enum.RaycastFilterType.Include

-- Set by Run: where each player can pick things up, and what happens when they do.
Loot.reach = function(_player: Player): { Reach }
	return {}
end
Loot.onBundle = function(_player: Player, _z: number, _m: string?) end
Loot.onGem = function(_player: Player, _amount: number, _pos: Vector3) end
Loot.onFull = function(_player: Player) end

-- Bundles `player` still has lying on the ground (they count toward the bag).
function Loot.count(player: Player): number
	return bundlesOf[player] or 0
end

local function noTouch(model: Instance)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
end

local function bundleVisual(pos: Vector3, mut: string?, z: number?): Instance
	local m = Config.mutation(mut or "None")
	local yaw = rng:NextNumber(0, math.pi * 2)
	-- the voxel bundle for its area and mutation (shared/BundleVoxel, 4 Nov: the same as the ones on your back; it
	-- was the ForgeGUI one, shared/BundleArt)
	local vb = BundleVoxel.make(z, m.id, 2.6)
	vb:PivotTo(CFrame.new(pos) * CFrame.Angles(0, yaw, 0))
	vb.Parent = folder
	return vb
end

local function gemVisual(pos: Vector3): Instance
	local cf = CFrame.new(pos + Vector3.new(0, 1.6, 0))
	local placed = Models.place("gem_drop", folder :: Folder, cf, 1, true)
	local model: Instance
	if placed then
		model = placed
	else
		local part = Instance.new("Part")
		part.Name = "Gem"
		part.Anchored = true
		part.Size = Vector3.new(1.2, 1.2, 1.2)
		part.Color = Color3.fromRGB(40, 140, 255)
		part.Material = Enum.Material.Neon
		part.CFrame = cf * CFrame.Angles(math.rad(45), 0, math.rad(45))
		part.Parent = folder
		model = part
	end
	model:SetAttribute("Spin", true) -- the client spins and bobs it (client/LootFx)
	return model
end

-- Drop loot for `player` near `origin`: kind "bundle" (from zone `z`, mutation `m`) or "gem" (`gems` gems).
-- `delay`: seconds until it shows up and can be picked up (a falling clump's bundles land when it hits the
-- ground); it counts toward the bag right away.
function Loot.drop(player: Player, kind: string, origin: Vector3, z: number, m: string?, gems: number?, delay: number?)
	if not folder then
		return
	end
	local a = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(0.6, Config.LOOT.spread)
	local pos = Vector3.new(origin.X + math.cos(a) * r, 0, origin.Z + math.sin(a) * r)
	-- the generated world has terraces: land on the ground under the spot (the plots map is flat at y = 0)
	local world = workspace:FindFirstChild("World")
	local ground = world and world:FindFirstChild("Ground")
	if ground then
		groundRay.FilterDescendantsInstances = { ground, world:FindFirstChild("Ways") or ground }
		local hit = workspace:Raycast(pos + Vector3.new(0, origin.Y + 12, 0), Vector3.new(0, -60, 0), groundRay)
		pos = Vector3.new(pos.X, if hit then hit.Position.Y else origin.Y, pos.Z)
	end
	local d: Drop = { owner = player, kind = kind, z = z, m = m, gems = gems or 0, pos = pos, home = pos, kickAt = 0, model = nil, readyAt = os.clock() + (delay or 0) }
	local function show()
		if d.dead or not folder then
			return
		end
		local model = if kind == "gem" then gemVisual(pos) else bundleVisual(pos, m, z)
		noTouch(model)
		model:SetAttribute("Owner", player.UserId)
		d.model = model
	end
	if delay and delay > 0 then
		task.delay(delay, show)
	else
		show()
	end
	table.insert(drops, d)
	if kind == "bundle" then
		bundlesOf[player] = (bundlesOf[player] or 0) + 1
	end
end

local function remove(i: number)
	local d = drops[i]
	table.remove(drops, i)
	if d.kind == "bundle" then
		bundlesOf[d.owner] = math.max(0, (bundlesOf[d.owner] or 1) - 1)
	end
	d.dead = true
	if d.model then
		d.model:Destroy()
	end
end

local function within(points: { Reach }, pos: Vector3): boolean
	for _, p in points do
		local flat = Vector3.new(p.pos.X - pos.X, 0, p.pos.Z - pos.Z).Magnitude
		if flat <= p.radius and math.abs(p.pos.Y - pos.Y) < 10 then
			return true
		end
	end
	return false
end

-------------------------------------------------------------------------------------------------------------
-- kicking (Config.GRASS_TOYS): a running player's middle comes near a bundle on the ground
-------------------------------------------------------------------------------------------------------------
local TOYS = Config.GRASS_TOYS
local wallRay = RaycastParams.new()
wallRay.FilterType = Enum.RaycastFilterType.Exclude
wallRay.RespectCanCollide = true -- the map's invisible walls can't be queried, but they do collide

type Kicker = { pos: Vector3, vel: Vector3, feet: number }

-- Everyone who could kick something right now: on foot (not riding), moving fast enough.
local function kickers(): { Kicker }
	local list: { Kicker } = {}
	local chars: { Instance } = {}
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if char then
			table.insert(chars, char)
		end
		if root and hum and hum.Health > 0 and not hum.SeatPart then
			local v = root.AssemblyLinearVelocity
			local flat = Vector3.new(v.X, 0, v.Z)
			if flat.Magnitude >= TOYS.kickMinSpeed then
				table.insert(list, { pos = root.Position, vel = flat, feet = root.Position.Y - hum.HipHeight - root.Size.Y / 2 })
			end
		end
	end
	wallRay.FilterDescendantsInstances = chars
	return list
end

-- Where a kick from `k` sends a bundle at `d.pos`, or nil when it can't go anywhere.
local function kickTarget(d: Drop, k: Kicker): Vector3?
	local away = Vector3.new(d.pos.X - k.pos.X, 0, d.pos.Z - k.pos.Z)
	local dir = k.vel.Unit * 0.7 + (if away.Magnitude > 0.05 then away.Unit * 0.3 else Vector3.zero)
	if dir.Magnitude < 0.05 then
		return nil
	end
	dir = dir.Unit
	local dist = math.clamp(k.vel.Magnitude * 0.25, TOYS.kickMin, TOYS.kickMax)
	-- not through a wall, a clump or a building: stop a stud short of it
	local from = d.pos + Vector3.new(0, 1, 0)
	local wall = workspace:Raycast(from, dir * (dist + 1), wallRay)
	if wall then
		dist = math.max(0, (wall.Position - from).Magnitude - 1)
	end
	local to = d.pos + dir * dist
	-- never far from where it dropped
	local off = Vector3.new(to.X - d.home.X, 0, to.Z - d.home.Z)
	if off.Magnitude > TOYS.kickDrift then
		to = Vector3.new(d.home.X, to.Y, d.home.Z) + off.Unit * TOYS.kickDrift
	end
	if Vector3.new(to.X - d.pos.X, 0, to.Z - d.pos.Z).Magnitude < 1 then
		return nil
	end
	-- on the ground under the new spot, and not off a terrace edge or the map (the plots map is flat at y = 0)
	local world = workspace:FindFirstChild("World")
	local ground = world and world:FindFirstChild("Ground")
	if ground then
		groundRay.FilterDescendantsInstances = { ground, world:FindFirstChild("Ways") or ground }
		local hit = workspace:Raycast(to + Vector3.new(0, TOYS.kickStep + 1, 0), Vector3.new(0, -(TOYS.kickStep * 2 + 2), 0), groundRay)
		if not hit or math.abs(hit.Position.Y - d.pos.Y) > TOYS.kickStep then
			return nil
		end
		return Vector3.new(to.X, hit.Position.Y, to.Z)
	end
	return Vector3.new(to.X, d.pos.Y, to.Z)
end

local function kick(d: Drop, to: Vector3, now: number)
	local model = d.model
	if not model or not model:IsA("Model") then
		return
	end
	local look = model:GetPivot().LookVector
	local yaw = math.atan2(-look.X, -look.Z) + rng:NextNumber(-1.2, 1.2) -- it lands turned a little
	local from = d.pos
	d.pos = to
	d.kickAt = now
	model:PivotTo(CFrame.new(to) * CFrame.Angles(0, yaw, 0))
	-- (set last: the client reads the other two when Kick changes)
	model:SetAttribute("KickFrom", from)
	model:SetAttribute("KickYaw", yaw)
	model:SetAttribute("Kick", ((model:GetAttribute("Kick") :: number?) or 0) + 1)
end

local function kicks(now: number)
	if not TOYS.kick or #drops == 0 then
		return
	end
	local list = kickers()
	if #list == 0 then
		return
	end
	for _, d in drops do
		if d.kind ~= "bundle" or d.dead or not d.model or now < d.readyAt or now - d.kickAt < TOYS.kickCooldown then
			continue
		end
		for _, k in list do
			local flat = Vector3.new(d.pos.X - k.pos.X, 0, d.pos.Z - k.pos.Z).Magnitude
			if flat <= TOYS.kickRadius and math.abs(k.feet - d.pos.Y) < 3 then
				local to = kickTarget(d, k)
				if to then
					kick(d, to, now)
				end
				break
			end
		end
	end
end

local function tick()
	local reachOf: { [Player]: { Reach } } = {}
	local fullWarned: { [Player]: boolean } = {}
	local now = os.clock()
	for i = #drops, 1, -1 do
		local d = drops[i]
		if now < d.readyAt then
			continue
		end
		local points = reachOf[d.owner]
		if not points then
			points = Loot.reach(d.owner)
			reachOf[d.owner] = points
		end
		if within(points, d.pos) then
			if d.kind == "gem" then
				remove(i)
				Loot.onGem(d.owner, d.gems, d.pos)
				Net.send(d.owner, "Fx", "pickup", { pos = d.pos, kind = "gem", gems = d.gems })
			elseif Carry.add(d.owner, d.z, d.m) then
				remove(i)
				Loot.onBundle(d.owner, d.z, d.m)
				Net.send(d.owner, "Fx", "pickup", { pos = d.pos, kind = "bundle", mut = d.m })
			elseif not fullWarned[d.owner] then
				fullWarned[d.owner] = true
				Loot.onFull(d.owner)
			end
		end
	end
	-- what's still on the ground after the pickups can be kicked
	kicks(now)
end

-- Remove everything (a run restarting in Studio) or one player's loot.
function Loot.clear(player: Player?)
	for i = #drops, 1, -1 do
		if player == nil or drops[i].owner == player then
			remove(i)
		end
	end
end

local started = false
function Loot.start(parent: Instance)
	if folder then
		folder:Destroy()
	end
	table.clear(drops)
	table.clear(bundlesOf)
	folder = Instance.new("Folder")
	;(folder :: Folder).Name = "Loot"
	;(folder :: Folder).Parent = parent
	if started then
		return
	end
	started = true
	Players.PlayerRemoving:Connect(function(p)
		Loot.clear(p)
		bundlesOf[p] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.12)
			local ok, err = pcall(tick)
			if not ok then
				warn("[Loot] " .. tostring(err))
			end
		end
	end)
end

return Loot
