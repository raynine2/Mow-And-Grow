-- CANOPY (30 Oct, owner: "something becomes invisible when you hit, I tried to fix it myself and it didn't work";
-- grass clumps, both views, flickering, for sure with Bare Hands). In first person your eye is 4.7 studs up, and the
-- clumps' tufts start 4.2-5.9 studs up and are 11-16 studs wide: standing at a clump to punch it, your eye was IN the
-- bottom of its tuft. From inside a mesh its faces are culled (you see through them), so the top vanished, and every
-- hit's wobble and squash moved it back and forth across your eye: the flicker. Area 1's meadow tufts are the lowest
-- and Bare Hands make you stand the closest, so that's where it showed most. Two fixes here:
--   * first person: Canopy.dip() is how far your eye goes down so it stays CLEAR under every tuft over you. The
--     camera eases down when you walk under one and back up after (client/CameraView adds it to the camera offset).
--   * third person (mowers, the camps): a tuft the camera is inside or about to enter fades out smoothly instead of
--     blinking (it's see-through from inside anyway).
-- client/HitFx also softens the half of a hit's wobble that swings the tuft down toward you when you're under it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Canopy = {}

local player = Players.LocalPlayer
local CLEAR = 0.4 -- how far under a tuft's underside your eye stays (covers the softened wobble and the head bob)
local PAD = 0.6 -- margin round a tuft's footprint (its voxel edge isn't a box)
local MAX_DIP = 1.6 -- never duck further than this (standing on something tall under a tuft: leave it)
local CELL = 16 -- the lookup grid (studs); clumps within a cell of you are checked
local FADE_IN = 1.6 -- third person: a tuft starts to fade this far before the camera reaches it
local FADE_MAX = 0.85 -- ... to this much see-through with the camera inside it

-- a tuft as fractions of its clump mesh's size: underside height, centre and half widths (from the split meshes
-- in ReplicatedStorage.ClumpCarve that client/ClumpCarve uses)
type Info = { bottom: number, cx: number, cz: number, hx: number, hz: number }
type Clump = { m: Model, src: BasePart, info: Info, rest: CFrame, size: Vector3, key: number }

local templates = ReplicatedStorage:WaitForChild("ClumpCarve", 10)
local infoOf: { [string]: Info | false } = {}

local function infoFor(name: string): Info?
	local got = infoOf[name]
	if got ~= nil then
		return if got then got else nil
	end
	local tpl = templates and templates:FindFirstChild(name)
	local top = tpl and tpl:FindFirstChild("Top")
	local ms = tpl and tpl:GetAttribute("MeshSize")
	local off = top and top:GetAttribute("Offset")
	local res: Info? = nil
	if top and top:IsA("MeshPart") and typeof(ms) == "Vector3" and typeof(off) == "Vector3" then
		local t = top.MeshSize
		res = {
			bottom = (off.Y - t.Y / 2 + ms.Y / 2) / ms.Y,
			cx = off.X / ms.X,
			cz = off.Z / ms.Z,
			hx = t.X / 2 / ms.X,
			hz = t.Z / 2 / ms.Z,
		}
	end
	infoOf[name] = res or false
	return res
end

-------------------------------------------------------------------------------------------------------------
-- the clumps, in a grid
-------------------------------------------------------------------------------------------------------------
local grid: { [number]: { [Model]: Clump } } = {}
local byModel: { [Model]: Clump } = {}

local function keyAt(x: number, z: number): number
	return (math.floor(x / CELL) + 4096) * 8192 + (math.floor(z / CELL) + 4096)
end

local function add(m: Model)
	if byModel[m] then
		return
	end
	local src: BasePart? = nil
	local inf: Info? = nil
	for _, ch in m:GetChildren() do
		if ch:IsA("MeshPart") and ch.Name:sub(1, 6) == "Clump_" then
			inf = infoFor(ch.Name)
			if inf then
				src = ch
				break
			end
		end
	end
	if not src or not inf then
		return
	end
	-- its upright pose, taken now (before any hit leans or squashes it)
	local p = src.Position
	local c: Clump = { m = m, src = src, info = inf, rest = src.CFrame, size = src.Size, key = keyAt(p.X, p.Z) }
	byModel[m] = c
	local cell = grid[c.key]
	if not cell then
		cell = {}
		grid[c.key] = cell
	end
	cell[m] = c
end

local function remove(m: Model)
	local c = byModel[m]
	if c then
		byModel[m] = nil
		local cell = grid[c.key]
		if cell then
			cell[m] = nil
		end
	end
end

local watched: Instance? = nil
local conns: { RBXScriptConnection } = {}
local function watch(folder: Instance?)
	if folder == watched then
		return
	end
	for _, c in conns do
		c:Disconnect()
	end
	table.clear(conns)
	table.clear(grid)
	table.clear(byModel)
	watched = folder
	if not folder then
		return
	end
	local function consider(d: Instance)
		if d:IsA("Model") and d.Name == "Clump" then
			-- (its mesh may stream in a moment after the model)
			if not byModel[d] then
				add(d)
				if not byModel[d] then
					task.delay(0.5, function()
						if d.Parent then
							add(d)
						end
					end)
				end
			end
		elseif d:IsA("MeshPart") and d.Parent and d.Parent:IsA("Model") and d.Parent.Name == "Clump" then
			add(d.Parent)
		end
	end
	for _, d in folder:GetDescendants() do
		consider(d)
	end
	table.insert(conns, folder.DescendantAdded:Connect(consider))
	table.insert(conns, folder.DescendantRemoving:Connect(function(d)
		if d:IsA("Model") and byModel[d] then
			remove(d)
		end
	end))
end

task.spawn(function()
	while true do
		local world = workspace:FindFirstChild("World")
		-- lihfolk-ignore: findfirstchild-chain (guarded by `world and`)
		watch(world and world:FindFirstChild("Grass"))
		task.wait(1)
	end
end)

-------------------------------------------------------------------------------------------------------------
-- per frame
-------------------------------------------------------------------------------------------------------------
local dipNow = 0
-- third person fades: clump -> { now, target, parts we wrote and the value we wrote }
type Fade = { now: number, target: number, wrote: { [BasePart]: number } }
local fades: { [Model]: Fade } = {}

-- `pos` in the clump's upright space, and the tuft's box there
local function local_(c: Clump, pos: Vector3): (Vector3, number, number, number, number, number, number)
	local lp = c.rest:PointToObjectSpace(pos)
	local s, i = c.size, c.info
	local x0, x1 = (i.cx - i.hx) * s.X, (i.cx + i.hx) * s.X
	local z0, z1 = (i.cz - i.hz) * s.Z, (i.cz + i.hz) * s.Z
	local y0, y1 = -s.Y / 2 + i.bottom * s.Y, s.Y / 2
	return lp, x0, x1, y0, y1, z0, z1
end

local function eachNear(pos: Vector3, fn: (Clump) -> ())
	local cx, cz = math.floor(pos.X / CELL), math.floor(pos.Z / CELL)
	for dx = -1, 1 do
		for dz = -1, 1 do
			local cell = grid[(cx + dx + 4096) * 8192 + (cz + dz + 4096)]
			if cell then
				for m, c in cell do
					if m.Parent and c.src.Parent == m then
						fn(c)
					end
				end
			end
		end
	end
end

local function setFade(m: Model, f: Fade, v: number)
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "StalkCollider" then
			local mine = f.wrote[p]
			local cur = p.LocalTransparencyModifier
			-- leave alone a part someone else hid (client/Fx hides a falling clump with 1)
			if (mine == nil and cur < 0.001) or (mine ~= nil and math.abs(cur - mine) < 0.001) then
				p.LocalTransparencyModifier = v
				f.wrote[p] = v
			end
		end
	end
end

local function firstPerson(cam: Camera, head: BasePart): boolean
	return (cam.CFrame.Position - head.Position).Magnitude < 1.5
end

RunService:BindToRenderStep("MowALawnCanopy", Enum.RenderPriority.Camera.Value - 1, function(dt: number)
	local cam = workspace.CurrentCamera
	local char = player.Character
	local head = char and char:FindFirstChild("Head") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local target = 0
	local fp = cam ~= nil and head ~= nil and firstPerson(cam :: Camera, head :: BasePart)
	if cam and head and hum and not hum.SeatPart and fp and cam.CameraType == Enum.CameraType.Custom then
		-- first person: how far your eye must go down to sit CLEAR under every tuft over it
		local eye = (head :: BasePart).Position
		eachNear(eye, function(c)
			local lp, x0, x1, y0, y1, z0, z1 = local_(c, eye)
			if lp.X > x0 - PAD and lp.X < x1 + PAD and lp.Z > z0 - PAD and lp.Z < z1 + PAD and lp.Y < y1 then
				local need = lp.Y - (y0 - CLEAR)
				if need > 0 and need <= MAX_DIP then
					target = math.max(target, need)
				end
			end
		end)
	end
	-- ease: a little quicker going down (into the grass) than coming back up
	local rate = if target > dipNow then 9 else 5
	dipNow += (target - dipNow) * math.min(1, dt * rate)
	if math.abs(dipNow) < 1e-3 then
		dipNow = 0
	end

	-- third person: fade the tufts the camera is in or nearly in
	for _, f in fades do
		f.target = 0
	end
	if cam and not fp then
		local pos = cam.CFrame.Position
		eachNear(pos, function(c)
			local lp, x0, x1, y0, y1, z0, z1 = local_(c, pos)
			local dx = math.max(x0 - lp.X, 0, lp.X - x1)
			local dy = math.max(y0 - lp.Y, 0, lp.Y - y1)
			local dz = math.max(z0 - lp.Z, 0, lp.Z - z1)
			local d = math.sqrt(dx * dx + dy * dy + dz * dz)
			if d < FADE_IN then
				local k = 1 - d / FADE_IN
				local f = fades[c.m]
				if not f then
					f = { now = 0, target = 0, wrote = {} }
					fades[c.m] = f
				end
				f.target = math.max(f.target, FADE_MAX * k * k * (3 - 2 * k))
			end
		end)
	end
	for m, f in fades do
		f.now += (f.target - f.now) * math.min(1, dt * 12)
		if not m.Parent then
			fades[m] = nil
		elseif f.target <= 0 and f.now < 0.01 then
			setFade(m, f, 0)
			fades[m] = nil
		else
			setFade(m, f, f.now)
		end
	end
end)

-- How far (studs) client/CameraView lowers your eye right now.
function Canopy.dip(): number
	return dipNow
end

return Canopy
