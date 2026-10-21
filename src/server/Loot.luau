-- Loot on the ground: a cut patch drops its bundle (and sometimes a free gem) next to it. Only the player who cut it
-- can pick it up, by walking within their reach (Loot.reach: Grasp around them, and round a ride-on mower they
-- drive). The server does the pickup itself (there is no remote), so a client can't fake collecting.
-- Drops aren't saved: bundles still on the ground when you leave are lost, like an unfinished swing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Net = require(script.Parent.Net)
local Models = require(script.Parent.Models)
local Carry = require(script.Parent.Carry)

local Loot = {}

type Drop = { owner: Player, kind: string, z: number, m: string?, gems: number, pos: Vector3, model: Instance?, readyAt: number, dead: boolean? }
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

local function bundleVisual(pos: Vector3, mut: string?): Instance
	local m = Config.mutation(mut or "None")
	local cf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local placed = Models.place("bundle", folder :: Folder, cf, 0.9, true)
	if placed then
		if m.color then
			for _, p in placed:GetDescendants() do
				if p:IsA("BasePart") and p.Material == Enum.Material.Grass then
					p.Color = m.color
				end
			end
		end
		return placed
	end
	local part = Instance.new("Part")
	part.Name = "Bundle"
	part.Anchored = true
	part.Size = Vector3.new(2.2, 0.9, 1.4)
	part.Color = m.color or Color3.fromRGB(150, 220, 80)
	part.CFrame = cf * CFrame.new(0, 0.45, 0)
	part.Parent = folder
	return part
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
	local d: Drop = { owner = player, kind = kind, z = z, m = m, gems = gems or 0, pos = pos, model = nil, readyAt = os.clock() + (delay or 0) }
	local function show()
		if d.dead or not folder then
			return
		end
		local model = if kind == "gem" then gemVisual(pos) else bundleVisual(pos, m)
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
