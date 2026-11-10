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
-- (4 Nov, owner: "its still goes into the old house when u walk in the buildings and not the new ones"; seen in a play
-- test: from outside, the cabin's doorway showed its own dark red inside, and one step in the whole house turned into
-- the lodge's bright room, a different house) One house now: the lodge's room is there all along, seen through the
-- cabin's doorway from outside, and only the cabin's shell goes when your camera is in (its door tunnel and floor
-- poke into the room). What of the lodge stands outside its room's walls (roof, plinth, barge boards, ridge: the
-- "old house" outside) only shows while your camera is inside, where it's the room's ceiling and the cabin is hidden. The room is only in the world while your camera is near the
-- door side (FPS: from behind or far off you can't see into it anyway); then the invisible walls stand in for its
-- walls as before.
local RunService = game:GetService("RunService")

local ShopShellView = {}

-- each building: its folder in the hub, its voxel building, and what of that shows from outside too (its floor; the
-- garage's work deck at the back, which covers a bit of the ground poking up there)
local UNITS = {
	-- (jamb: the cabin's door tunnel is only x -2.2..1.9 wide in the lodge's 12-wide door, server/ShopShell; the cabin
	-- has no collisions, so without these you walked in through its wall beside the door)
	-- (9 Nov, owner: "THE HOUSE CHANGES FROM INSIDE WHEN WALKING IN") the cabin's door tunnel starts ~3 studs before the
	-- shell's DoorMin: walking through it you saw the cabin's own smooth orange insides, then the lodge's room. `doorOut`
	-- grows the door box out to the tunnel's mouth, so you're "in" (the lodge's room) from the first step through the door.
	{ unit = "TOOL SHOP", building = "ShopBuilding", keep = { FloorBoard = true, FloorFill = true }, jamb = { -2.2, 1.8 }, doorOut = 0.6 }, -- (10 Nov: the cabin at 57 wide; its tunnel x -2.2..1.8 from z -16, server/ShopShell)
	{
		unit = "Garage",
		building = "GarageBuilding",
		-- (4 Nov) seen from outside, the voxel garage's roof, gables and vents (above its tie beams) poked up through the
		-- ForgeGUI garage's roof: from outside they stay hidden
		ceiling = 13.9,
		keep = { FloorSlab = true, FloorFill = true, BayLine = true, OilStain = true, WorkDeck = true, DeckBoard = true },
	},
}

type View = {
	keep: { [string]: boolean },
	shell: Model?,
	lodge: Instance?,
	anchor: BasePart?, -- (the unit's "0Anchor": the building's own frame, wherever the saved map put it)
	inside: boolean?,
	near: boolean?, -- (camera close to the door side: the room is in the world)
	out: { [BasePart]: boolean }, -- (lodge parts outside the room's walls: never shown)
	conns: { RBXScriptConnection },
	walls: Folder?, -- (this screen's invisible walls while the lodge is out)
	jamb: { number }?,
	doorOut: number?,
	ceiling: number?, -- (lodge parts reaching above this, in the anchor's frame, count as outside)
	jambs: Folder?, -- (invisible blocks either side of the cabin's narrow door)
	builtAt: CFrame?, -- (where the anchor was when the walls and jambs were made)
}
local views: { View } = {}
for i, u in UNITS do
	views[i] = { keep = u.keep, shell = nil, lodge = nil, anchor = nil, inside = nil, near = nil, out = {}, conns = {}, jamb = (u :: any).jamb, ceiling = (u :: any).ceiling, doorOut = (u :: any).doorOut }
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

-- Invisible blocks filling the doorway box either side of the cabin's door tunnel.
local function jambsFor(v: View): Folder?
	local s, a, j = v.shell, v.anchor, v.jamb
	if not s or not a or not j then
		return nil
	end
	local dmn, dmx = s:GetAttribute("DoorMin"), s:GetAttribute("DoorMax")
	if typeof(dmn) ~= "Vector3" or typeof(dmx) ~= "Vector3" then
		return nil
	end
	local f = Instance.new("Folder")
	f.Name = "ShopShellJambs"
	for _, xs in { { dmn.X - WALL, j[1] }, { j[2], dmx.X + WALL } } do
		local p = Instance.new("Part")
		p.Name = "Jamb"
		p.Anchored = true
		p.CanCollide = true
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Transparency = 1
		p.Size = Vector3.new(xs[2] - xs[1], dmx.Y - dmn.Y, dmx.Z - dmn.Z)
		p.CFrame = a.CFrame * CFrame.new((xs[1] + xs[2]) / 2, (dmn.Y + dmx.Y) / 2, (dmn.Z + dmx.Z) / 2)
		p.Parent = f
	end
	return f
end

-- where hidden lodge pieces wait (outside the world: not drawn), and where each came from
local hold = Instance.new("Folder")
hold.Name = "ShopShellHidden"
local home: { [BasePart]: Instance } = {}

-- Is lodge part `p` outside its room's walls (any corner beyond the room box grown by a wall, above the room or
-- below the ground)? Asked once per part.
local OUT_GROW = 1.6
local function isOut(v: View, p: BasePart): boolean
	local c = v.out[p]
	if c ~= nil then
		return c
	end
	c = false
	local s, a = v.shell, v.anchor
	local mn, mx = s and s:GetAttribute("RoomMin"), s and s:GetAttribute("RoomMax")
	if a and typeof(mn) == "Vector3" and typeof(mx) == "Vector3" then
		local h = p.Size / 2
		for _, k in { Vector3.new(-1, -1, -1), Vector3.new(1, -1, -1), Vector3.new(-1, 1, -1), Vector3.new(1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(1, -1, 1), Vector3.new(-1, 1, 1), Vector3.new(1, 1, 1) } do
			local l = a.CFrame:PointToObjectSpace(p.CFrame:PointToWorldSpace(h * k))
			if l.X < mn.X - OUT_GROW or l.X > mx.X + OUT_GROW or l.Z < mn.Z - OUT_GROW or l.Z > mx.Z + OUT_GROW or l.Y > (v.ceiling or mx.Y) + 0.5 or l.Y < -2 then
				c = true
				break
			end
		end
	end
	v.out[p] = c
	return c
end

local function setLodge(v: View, p: Instance, show: boolean)
	if not p:IsA("BasePart") or v.keep[p.Name] then
		return
	end
	if show and not v.inside and isOut(v, p) then
		show = false
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

-- (4 Nov, owner: "WHEN I WALK INTO THE BULDING THE FUCKING GROUND CHANGES") The lodge's porch you walk on (Deck,
-- Step, DeckFascia) is invisible, under the cabin's own wooden steps. With your camera inside, the cabin goes and the
-- porch stayed invisible, so the ground in front of the door turned into bare dirt and the lodge's grey footing
-- stones. Now that porch shows while you're inside, in the cabin steps' reddish wood, so the way out looks the same
-- from both sides. (Only this screen; it's invisible again before the outside view sorts the lodge, so it never
-- leaves the world: you walk on it.)
local WALK = { Deck = Color3.fromRGB(156, 80, 48), Step = Color3.fromRGB(128, 62, 38), DeckFascia = Color3.fromRGB(100, 48, 30) }
local walkParts: { [BasePart]: boolean } = {}
local function showPorch(v: View, show: boolean)
	if not v.lodge then
		return
	end
	for _, p in v.lodge:GetDescendants() do
		if p:IsA("BasePart") and WALK[p.Name] and (walkParts[p] or p.Transparency >= 1) then
			walkParts[p] = true
			if show then
				p.Transparency = 0
				p.Material = Enum.Material.WoodPlanks
				p.Color = if p.Name == "Deck" and math.floor(p.Position.X + p.Position.Z) % 2 == 0 then WALK.Deck:Lerp(Color3.new(0, 0, 0), 0.1) else WALK[p.Name]
				p.CastShadow = false
			else
				p.Transparency = 1
			end
		end
	end
end

local function apply(v: View)
	if v.inside ~= true then
		showPorch(v, false) -- (first: a visible porch part would be taken out of the world below)
	end
	if v.lodge then
		local room = v.near == true or v.inside == true
		if room then
			for p, back in home do
				if back:IsDescendantOf(v.lodge) or back == v.lodge then
					setLodge(v, p, true)
				end
			end
		end
		-- (outside pieces still in the world while you're outside, every piece when the room goes; inside, the whole
		-- lodge shows, its roof your ceiling, as the cabin's shell is hidden then)
		for _, p in v.lodge:GetDescendants() do
			if p:IsA("BasePart") and (not room or (not v.inside and isOut(v, p))) then
				setLodge(v, p, false)
			end
		end
	end
	if v.shell then
		for _, p in v.shell:GetDescendants() do
			setShell(p, v.inside ~= true)
		end
	end
	if v.inside == true then
		showPorch(v, true)
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
	if v.jambs then
		v.jambs:Destroy()
		v.jambs = nil
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
	v.near = nil
	v.out = {}
	if s and v.lodge then
		v.walls = wallsFor(v)
		v.jambs = jambsFor(v)
		-- parts streaming in later get the current view
		table.insert(v.conns, v.lodge.DescendantAdded:Connect(function(d)
			if v.inside ~= nil then
				setLodge(v, d, v.near == true or v.inside == true)
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
local NEAR = 70 -- studs from the building's middle: closer, on the door side, the room is in the world
local NEAR_GIVE = 6

-- is `p` in the box (mn, mx) grown by `grow` (shrunk when it's below 0)?
local function within(p: Vector3, mn: any, mx: any, grow: number): boolean
	if typeof(mn) ~= "Vector3" or typeof(mx) ~= "Vector3" then
		return false
	end
	return p.X > mn.X - grow and p.X < mx.X + grow and p.Y > mn.Y - grow and p.Y < mx.Y + grow and p.Z > mn.Z - grow
		and p.Z < mx.Z + grow
end

local function doorMin(s: Model, v: any): any
	local mn = s:GetAttribute("DoorMin")
	if typeof(mn) == "Vector3" and v.doorOut then
		return mn - Vector3.new(0, 0, v.doorOut)
	end
	return mn
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
		-- (4 Nov: the run squares the buildings up after they're built, server/CampGround.squareUp) moved: the walls
		-- and jambs are made again where it stands, and its pieces sorted again
		if v.builtAt ~= a.CFrame then
			if v.builtAt then
				if v.walls then
					v.walls:Destroy()
				end
				if v.jambs then
					v.jambs:Destroy()
				end
				v.walls = wallsFor(v)
				v.jambs = jambsFor(v)
				v.out = {}
				v.inside = nil
				v.near = nil
			end
			v.builtAt = a.CFrame
		end
		local p = a.CFrame:PointToObjectSpace(cam)
		local grow = if v.inside then MARGIN else -MARGIN
		local now = within(p, s:GetAttribute("RoomMin"), s:GetAttribute("RoomMax"), grow)
			or within(p, doorMin(s, v), s:GetAttribute("DoorMax"), grow)
		-- near the door side (in front of the room's back wall, within NEAR of its middle; a bit of give both ways)
		local mx = s:GetAttribute("RoomMax")
		local reach = NEAR + (if v.near then NEAR_GIVE else 0)
		local close = typeof(mx) == "Vector3" and p.Z < mx.Z + (if v.near then NEAR_GIVE else 0) and p.Magnitude < reach
		if now ~= v.inside or close ~= v.near then
			v.inside = now
			v.near = close
			apply(v)
		end
		-- the invisible walls: in the world while the room is out (checked every frame: a film may clear the world's
		-- loose bits; made again if they were destroyed)
		local want = if v.inside or v.near then nil else workspace
		if not v.walls and v.lodge then
			v.walls = wallsFor(v)
		end
		local w = v.walls
		if w and w.Parent ~= want and not pcall(function()
			w.Parent = want
		end) then
			v.walls = nil
		end
		if not v.jambs and v.lodge then
			v.jambs = jambsFor(v)
		end
		local jb = v.jambs
		if jb and jb.Parent ~= workspace and not pcall(function()
			jb.Parent = workspace
		end) then
			v.jambs = nil
		end
	end
end)

return ShopShellView
