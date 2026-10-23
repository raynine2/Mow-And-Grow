-- Wind in the grass: the clumps near you (the tuft_<style> models in workspace.World.Grass) lean a few
-- degrees around their foot in a slow breeze, with gusts rolling across the field in waves. Client-only.
--
-- Cheap by design: a near list is rebuilt a few times a second, and at most BUDGET clumps are moved per frame
-- (round-robin). Each clump is always put back relative to its own cached upright pivot. If something else
-- moved it since our last write (the server shrinking a hit clump, HitFx's wobble), we leave it alone until it
-- has been still for a moment, then re-read where it really stands and carry on, so we never fight anyone.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Wind = {}
local player = Players.LocalPlayer

local RADIUS = 45 -- clumps further than this stand still
local FADE = 10 -- the sway fades out over the last studs of RADIUS
local BUDGET = 60 -- clumps moved per frame at most (Potato Mode: 25)
local SCAN_EVERY = 0.3 -- seconds between near-list rebuilds
local SETTLE = 0.35 -- seconds a clump must be still (after someone else moved it) before we sway it again
local MAX_TILT = math.rad(4)

type Clump = {
	model: Model,
	ref: BasePart?, -- one part of the model, to notice outside moves cheaply
	pos: Vector3, -- the foot (pivot position; never changes, the clump only turns and scales around it)
	rot: CFrame, -- upright turn (yaw only)
	refOff: CFrame?, -- ref part's rotation relative to `rot`
	last: CFrame?, -- ref.CFrame right after our last write
	seen: CFrame?, -- ref.CFrame when we noticed an outside move
	seenAt: number,
	phase: number,
	top: number, -- height of the clump (for butterflies to land on)
}

local clumps: { [Model]: Clump } = {}
local near: { Clump } = {}
local tilted: { [Clump]: boolean } = {} -- leaned by us: put back upright when they leave the near circle
local cursor = 1
local grass: Instance? = nil
local conns: { RBXScriptConnection } = {}

local function isTuft(inst: Instance): boolean
	-- the toy tufts, and the generated world's voxel clumps (server/Field names their holder "Clump")
	return inst:IsA("Model") and ((inst.Name:sub(1, 5) == "tuft_" and inst.Name:sub(-4) ~= "_cut") or inst.Name == "Clump")
end

local function track(m: Instance)
	if not isTuft(m) or clumps[m :: Model] then
		return
	end
	local model = m :: Model
	clumps[model] = {
		model = model,
		ref = nil,
		pos = Vector3.zero,
		rot = CFrame.identity,
		refOff = nil,
		last = nil,
		seen = nil,
		seenAt = 0,
		phase = math.random() * math.pi * 2,
		top = 0,
	}
end

-- Hook the run's grass folder (the world is rebuilt when a Studio lobby turns into a run).
local function hook()
	if grass and grass:IsDescendantOf(workspace) then
		return
	end
	for _, c in conns do
		c:Disconnect()
	end
	table.clear(conns)
	table.clear(clumps)
	table.clear(near)
	table.clear(tilted)
	local world = workspace:FindFirstChild("World")
	grass = world and world:FindFirstChild("Grass")
	if not grass then
		return
	end
	for _, d in grass:GetDescendants() do
		track(d)
	end
	table.insert(conns, grass.DescendantAdded:Connect(track))
	table.insert(conns, grass.DescendantRemoving:Connect(function(d)
		if clumps[d :: any] then
			clumps[d :: any] = nil
		end
	end))
end

-- Read where a clump stands (once it holds still): its foot, upright yaw, and one part to watch.
local function settle(c: Clump): boolean
	local ref = c.ref
	if not ref or ref.Parent ~= c.model then
		ref = c.model:FindFirstChildWhichIsA("BasePart")
		c.ref = ref
		c.refOff = nil
	end
	if not ref then
		return false
	end
	if c.refOff == nil then
		-- first sight: the pivot is the server's spot (upright, turned around Y)
		local pivot = c.model:GetPivot()
		local look = pivot.LookVector
		c.pos = pivot.Position
		c.rot = CFrame.Angles(0, math.atan2(-look.X, -look.Z), 0)
		c.refOff = c.rot:Inverse() * ref.CFrame.Rotation
	else
		-- after an outside move: line the model's pivot up with where its parts really are
		c.model.WorldPivot = CFrame.new(c.pos) * ref.CFrame.Rotation * (c.refOff :: CFrame):Inverse()
	end
	local _, size = c.model:GetBoundingBox() -- height changes as the clump is cut down
	c.top = size.Y
	c.last = ref.CFrame
	c.seen = nil
	return true
end

-- Was the clump moved by someone else since our last write? Then wait until it's been still for SETTLE.
local function ready(c: Clump, now: number): boolean
	local ref = c.ref
	if not ref or ref.Parent ~= c.model then
		c.refOff = nil
		return settle(c) -- brand new (or its parts changed): read it from scratch
	end
	local cf = ref.CFrame
	if cf == c.last then
		return true
	end
	if cf ~= c.seen then
		c.seen = cf
		c.seenAt = now
		return false
	end
	return now - c.seenAt >= SETTLE and settle(c)
end

local function write(c: Clump, cf: CFrame)
	c.model:PivotTo(cf)
	local ref = c.ref :: BasePart
	c.last = ref.CFrame
end

-- The breeze: a slowly turning wind direction, gusts rolling across the field, and a little flutter.
local function lean(c: Clump, t: number, windDir: Vector3, k: number): CFrame
	local p = c.pos
	local along = p.X * windDir.X + p.Z * windDir.Z
	local across = p.Z * windDir.X - p.X * windDir.Z
	local gust = math.noise(along * 0.03 - t * 0.45, across * 0.03, 3.7) -- -1..1, mostly within ±0.5
	local amount = 0.3 + gust * 1.3 + math.sin(t * 2.1 + c.phase) * 0.12
	local main = math.clamp(amount, -0.6, 1) * MAX_TILT * k
	local side = math.sin(t * 1.3 + c.phase * 1.7) * 0.25 * MAX_TILT * k
	local axis = Vector3.yAxis:Cross(windDir) -- turning around this tips the top downwind
	return CFrame.new(p) * CFrame.fromAxisAngle(axis, main) * CFrame.fromAxisAngle(windDir, side) * c.rot
end

local function focus(): Vector3?
	local cam = workspace.CurrentCamera
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return (root and root.Position) or (cam and cam.CFrame.Position)
end

local scanAt = 0
local hookAt = 0
local function rescan(now: number, at: Vector3)
	-- clumps that left the near circle go back upright
	for c in tilted do
		local d = Vector2.new(c.pos.X - at.X, c.pos.Z - at.Z).Magnitude
		if not c.model.Parent then
			tilted[c] = nil
		elseif d > RADIUS and ready(c, now) then
			write(c, CFrame.new(c.pos) * c.rot)
			tilted[c] = nil
		end
	end
	table.clear(near)
	for _, c in clumps do
		-- clumps we haven't read yet: their pivot is close enough to pick them (settle reads it properly)
		if c.pos == Vector3.zero then
			c.pos = c.model:GetPivot().Position
		end
		local dx, dz = c.pos.X - at.X, c.pos.Z - at.Z
		if dx * dx + dz * dz < RADIUS * RADIUS then
			table.insert(near, c)
		end
	end
	cursor = 1
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - hookAt > 1 then
		hookAt = now
		hook()
	end
	if not grass then
		return
	end
	local at = focus()
	if not at then
		return
	end
	if now - scanAt > SCAN_EVERY then
		scanAt = now
		rescan(now, at)
	end
	local count = #near
	if count == 0 then
		return
	end
	-- blow the way the clouds and pollen drift (workspace.GlobalWind), swinging slowly a little either side
	local gw = Vector3.new(workspace.GlobalWind.X, 0, workspace.GlobalWind.Z)
	local windDir = CFrame.Angles(0, math.sin(now * 0.07) * 0.4, 0) * (if gw.Magnitude > 0.1 then gw.Unit else Vector3.new(0.8, 0, 0.6))
	local budget = if player:GetAttribute("Potato") then 25 else BUDGET
	for _ = 1, math.min(budget, count) do
		if cursor > count then
			cursor = 1
		end
		local c = near[cursor]
		cursor += 1
		if c.model.Parent and ready(c, now) then
			local d = Vector2.new(c.pos.X - at.X, c.pos.Z - at.Z).Magnitude
			local k = math.clamp((RADIUS - d) / FADE, 0, 1)
			write(c, lean(c, now, windDir, k))
			tilted[c] = true
		end
	end
end)

-- A clump near the player for a critter to land on: its top point, or nil when there's none.
function Wind.perch(): Vector3?
	local count = #near
	if count == 0 then
		return nil
	end
	local c = near[math.random(1, count)]
	if not c.refOff or not c.model.Parent then
		return nil
	end
	return c.pos + Vector3.new(0, c.top * 0.9, 0)
end

return Wind
