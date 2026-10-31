-- SHOP SHELL VIEW (31 Oct; the owner kept the Tool Shop's room and wanted the house remade with ForgeGUI): the shop's
-- ForgeGUI cabin (server/ShopShell, a Model "ShopShell" in the TOOL SHOP) and the log lodge it stands on take turns:
--   * your camera outside the lodge's room: the cabin shows; of the lodge only its floor (the room and its tool boards
--     stay, so you see them through the cabin's doorway), its walls, roof, windows and door hidden
--   * your camera inside the room: the lodge (dressed inside like the cabin, server/ShopShell), the cabin hidden
-- (31 Oct, owner: "also use this house for the garage model alike") The Garage the same way: its ForgeGUI garage
-- outside, the voxel garage inside.
-- Only this client's view changes. (31 Oct, FPS pass) Hidden pieces leave the world on this screen (moved into a
-- folder outside it, put back when shown): a part hidden by LocalTransparencyModifier or Transparency is still drawn
-- one by one, and the hidden garage alone cost ~420 of the camp's ~1,280 draw calls (measured with Stats). While the
-- lodge is out, plain invisible walls round its room (from the shell's RoomMin/RoomMax, with the doorway left open)
-- keep you out of it; parts that were invisible already (the porch deck and steps you walk on) stay.
-- Checked each frame right after the camera moves, so walking in through the door never shows the wrong one.
-- (31 Oct, owner: "its bugged still when i walk in i see like glitching both") Inside also counts the doorway (the
-- shell's "DoorMin"/"DoorMax" box: the cabin's narrow door tunnel, whose solid insides you'd otherwise walk your camera
-- through), and the switch has some give (MARGIN): in once the camera is a bit inside, out once it's a bit outside,
-- so head bob or a camera popping against the door frame never flips the two back and forth.
local RunService = game:GetService("RunService")

local ShopShellView = {}

-- each building: its folder in the hub, its voxel building, and what of that shows from outside too (its floor; the
-- garage's work deck at the back, which covers a bit of the ground poking up there)
local UNITS = {
	{ unit = "TOOL SHOP", building = "ShopBuilding", keep = { FloorBoard = true, FloorFill = true } },
	{
		unit = "Garage",
		building = "GarageBuilding",
		keep = { FloorSlab = true, FloorFill = true, BayLine = true, OilStain = true, WorkDeck = true, DeckBoard = true },
	},
}

type View = {
	keep: { [string]: boolean },
	shell: Model?,
	lodge: Instance?,
	anchor: BasePart?, -- (the unit's "0Anchor": the building's own frame, wherever the saved map put it)
	inside: boolean?,
	conns: { RBXScriptConnection },
	walls: Folder?, -- (this screen's invisible walls while the lodge is out)
}
local views: { View } = {}
for i, u in UNITS do
	views[i] = { keep = u.keep, shell = nil, lodge = nil, anchor = nil, inside = nil, conns = {} }
end

-- Invisible walls round the room box (the lodge's walls stand just outside it), the doorway left open.
local WALL = 1.4
local function wallsFor(v: View): Folder?
	local s, a = v.shell, v.anchor
	if not s or not a then
		return nil
	end
	local mn, mx = s:GetAttribute("RoomMin"), s:GetAttribute("RoomMax")
	local dmn, dmx = s:GetAttribute("DoorMin"), s:GetAttribute("DoorMax")
	if typeof(mn) ~= "Vector3" or typeof(mx) ~= "Vector3" or typeof(dmn) ~= "Vector3" or typeof(dmx) ~= "Vector3" then
		return nil
	end
	local f = Instance.new("Folder")
	f.Name = "ShopShellWalls"
	local function box(x0: number, x1: number, y0: number, y1: number, z0: number, z1: number)
		if x1 - x0 < 0.05 or y1 - y0 < 0.05 or z1 - z0 < 0.05 then
			return
		end
		local p = Instance.new("Part")
		p.Name = "Wall"
		p.Anchored = true
		p.CanCollide = true
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Transparency = 1
		p.Size = Vector3.new(x1 - x0, y1 - y0, z1 - z0)
		p.CFrame = a.CFrame * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
		p.Parent = f
	end
	local y0, y1 = mn.Y, mx.Y
	box(mn.X - WALL, mn.X, y0, y1, mn.Z - WALL, mx.Z + WALL) -- left
	box(mx.X, mx.X + WALL, y0, y1, mn.Z - WALL, mx.Z + WALL) -- right
	box(mn.X, mx.X, y0, y1, mx.Z, mx.Z + WALL) -- back
	box(mn.X, dmn.X, y0, y1, mn.Z - WALL, mn.Z) -- front, left of the door
	box(dmx.X, mx.X, y0, y1, mn.Z - WALL, mn.Z) -- front, right of the door
	box(dmn.X, dmx.X, dmx.Y, y1, mn.Z - WALL, mn.Z) -- over the door
	return f
end

-- where hidden lodge pieces wait (outside the world: not drawn), and where each came from
local hold = Instance.new("Folder")
hold.Name = "ShopShellHidden"
local home: { [BasePart]: Instance } = {}

local function setLodge(v: View, p: Instance, show: boolean)
	if not p:IsA("BasePart") or v.keep[p.Name] then
		return
	end
	if show then
		local back = home[p]
		if back then
			home[p] = nil
			if p.Parent == hold and back.Parent then
				p.Parent = back
			end
		end
	elseif p.Parent ~= hold and p.Transparency < 1 then
		home[p] = p.Parent :: Instance
		p.Parent = hold
	end
end

local function setShell(p: Instance, show: boolean)
	if p:IsA("BasePart") then
		p.LocalTransparencyModifier = if show then 0 else 1
	end
end

local function apply(v: View)
	if v.lodge then
		if v.inside then
			for p, back in home do
				if back:IsDescendantOf(v.lodge) or back == v.lodge then
					setLodge(v, p, true)
				end
			end
		else
			for _, p in v.lodge:GetDescendants() do
				setLodge(v, p, false)
			end
		end
	end
	if v.shell then
		for _, p in v.shell:GetDescendants() do
			setShell(p, v.inside ~= true)
		end
	end
end

-- the shells and buildings (they stream in, and a new run's world replaces them)
local function find(v: View, u: { unit: string, building: string })
	local world = workspace:FindFirstChild("World")
	local hub = world and world:FindFirstChild("Hub")
	local unit = hub and hub:FindFirstChild(u.unit)
	local s = unit and unit:FindFirstChild("ShopShell") :: Model?
	v.anchor = unit and unit:FindFirstChild("0Anchor") :: BasePart?
	if s == v.shell then
		return
	end
	for _, c in v.conns do
		c:Disconnect()
	end
	table.clear(v.conns)
	if v.walls then
		v.walls:Destroy()
		v.walls = nil
	end
	-- (the old run's lodge pieces: its world is gone)
	for p, back in home do
		if v.lodge and (back == v.lodge or back:IsDescendantOf(v.lodge)) then
			home[p] = nil
		end
	end
	v.shell = s
	v.lodge = if s and unit then unit:FindFirstChild(u.building) else nil
	v.inside = nil
	if s and v.lodge then
		v.walls = wallsFor(v)
		-- parts streaming in later get the current view
		table.insert(v.conns, v.lodge.DescendantAdded:Connect(function(d)
			if v.inside ~= nil then
				setLodge(v, d, v.inside)
			end
		end))
		table.insert(v.conns, s.DescendantAdded:Connect(function(d)
			if v.inside ~= nil then
				setShell(d, not v.inside)
			end
		end))
	end
end

task.spawn(function()
	while true do
		for i, u in UNITS do
			find(views[i], u)
		end
		task.wait(1)
	end
end)

local MARGIN = 0.5

-- is `p` in the box (mn, mx) grown by `grow` (shrunk when it's below 0)?
local function within(p: Vector3, mn: any, mx: any, grow: number): boolean
	if typeof(mn) ~= "Vector3" or typeof(mx) ~= "Vector3" then
		return false
	end
	return p.X > mn.X - grow and p.X < mx.X + grow and p.Y > mn.Y - grow and p.Y < mx.Y + grow and p.Z > mn.Z - grow
		and p.Z < mx.Z + grow
end

RunService:BindToRenderStep("ShopShellView", Enum.RenderPriority.Camera.Value + 1, function()
	local cam = workspace.CurrentCamera.CFrame.Position
	for _, v in views do
		local s, a = v.shell, v.anchor
		if not s or not s.Parent or not a or not a.Parent then
			continue
		end
		if typeof(s:GetAttribute("RoomMin")) ~= "Vector3" then
			continue
		end
		local p = a.CFrame:PointToObjectSpace(cam)
		local grow = if v.inside then MARGIN else -MARGIN
		local now = within(p, s:GetAttribute("RoomMin"), s:GetAttribute("RoomMax"), grow)
			or within(p, s:GetAttribute("DoorMin"), s:GetAttribute("DoorMax"), grow)
		if now ~= v.inside then
			v.inside = now
			apply(v)
		end
		-- the invisible walls: in the world while the lodge is out (checked every frame: a film may clear the world's
		-- loose bits; made again if they were destroyed)
		local want = if v.inside then nil else workspace
		if not v.walls and v.lodge then
			v.walls = wallsFor(v)
		end
		local w = v.walls
		if w and w.Parent ~= want and not pcall(function()
			w.Parent = want
		end) then
			v.walls = nil
		end
	end
end)

return ShopShellView
