-- ForgeGUI dressing for the run world (the owner, 26 Oct: "remove the ugly signs and remake the places with
-- forgegui"). Each piece swaps blocky stand-ins and text boards for a ForgeGUI model (shared/ForgeModelIds), and does
-- nothing when that model isn't loaded, so the old look stays as a fallback. Safe to run twice (marks what it did).
--   * gates (World.Gates.Gate<z>): the "MOW ALL OF ... TO OPEN" board, its post, the posts and the stone arch go;
--     the area's own archway stands at the way in, and what opens it floats above as a clean label ("GateInfo",
--     shown only while the gate is shut for you: client/Gates)
--   * drop-off pads (World.Pads.DropOff<z>): the dark disc with DROP-OFF on it becomes a straw-and-grass pad with
--     the grass-clippings bin in the middle (the pad part itself stays: it's where you stand to sell)
-- Run at run start (RunWorld.build) and, for the view in Edit mode, by tools/studio-forge-dress.luau on the saved
-- world. The boss arenas (server/BossArena) and the camp fountain (server/CampFountain) use their models themselves.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zones = require(ReplicatedStorage.MowALawn.Zones)
local Models = require(script.Parent.Models)

local ForgeDress = {}

-- the archway for the way into each area
ForgeDress.GATE_MODEL = {
	[2] = "arena_cornfield", -- (the barn-post gateway, as at the wheat arena: ForgeGUI didn't deliver gate_wheat)
	[3] = "gate_blossom",
	[4] = "arena_ruins", -- (the rune-stone gateway, as at the pine arena: ForgeGUI didn't deliver gate_pine)
	[5] = "gate_swamp",
	[6] = "gate_frost",
	[7] = "gate_ember",
	[8] = "gate_starlight",
}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function anchorPart(parent: Instance, name: string, pos: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.CFrame = CFrame.new(pos)
	p.Parent = parent
	return p
end

-- The floating "what opens this" label: the area's name over a short line, on a soft dark pill.
local function gateInfo(parent: Instance, pos: Vector3, area: string, need: string, accent: Color3)
	local holder = anchorPart(parent, "GateInfoSpot", pos)
	holder:SetAttribute("Area", area)
	holder:SetAttribute("Need", need)
	local bb = Instance.new("BillboardGui")
	bb.Name = "GateInfo"
	bb.Size = UDim2.fromScale(16, 4.2) -- (studs)
	bb.LightInfluence = 0
	bb.MaxDistance = 110
	bb.ResetOnSpawn = false
	bb.Parent = holder
	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.AnchorPoint = Vector2.new(0.5, 0.5)
	pill.Position = UDim2.fromScale(0.5, 0.5)
	pill.Size = UDim2.fromScale(0.96, 0.9)
	pill.BackgroundColor3 = Color3.fromRGB(28, 24, 34)
	pill.BackgroundTransparency = 0.25
	pill.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = pill
	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 2
	stroke.Transparency = 0.2
	stroke.Parent = pill
	local title = Instance.new("TextLabel")
	title.Name = "Area"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.05, 0.06)
	title.Size = UDim2.fromScale(0.9, 0.5)
	title.Font = Enum.Font.LuckiestGuy
	title.TextScaled = true
	title.Text = string.upper(area)
	title.TextColor3 = accent
	title.Parent = pill
	local ts = Instance.new("UIStroke")
	ts.Thickness = 2
	ts.Color = Color3.fromRGB(20, 16, 24)
	ts.Parent = title
	local line = Instance.new("TextLabel")
	line.Name = "Need"
	line.BackgroundTransparency = 1
	line.Position = UDim2.fromScale(0.06, 0.56)
	line.Size = UDim2.fromScale(0.88, 0.34)
	line.Font = Enum.Font.FredokaOne
	line.TextScaled = true
	line.RichText = true
	line.Text = ('Mow all of <font color="#FFD63C">%s</font> to open'):format(need)
	line.TextColor3 = Color3.new(1, 1, 1)
	line.Parent = pill
	local ls = Instance.new("UIStroke")
	ls.Thickness = 1.5
	ls.Color = Color3.fromRGB(20, 16, 24)
	ls.Parent = line
end

-- The words the old board said (area, previous area), so the label says the same.
local function boardText(gate: Instance): { string }
	local out = {}
	local sign = gate:FindFirstChild("Sign")
	local gui = sign and sign:FindFirstChildWhichIsA("SurfaceGui")
	if gui then
		local labels = {}
		for _, c in gui:GetChildren() do
			if c:IsA("TextLabel") then
				table.insert(labels, c)
			end
		end
		table.sort(labels, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		for _, l in labels do
			table.insert(out, l.Text)
		end
	end
	return out
end

local function titleCase(s: string): string
	return (string.gsub(string.lower(s), "(%a)([%w']*)", function(a, b)
		return string.upper(a) .. b
	end))
end

-- One gate. Returns true when it has its archway (now or before). Without the model (not loaded) the board
-- still goes: the label takes its place and the posts / stone arch stay.
function ForgeDress.gate(gate: Instance): boolean
	if gate:GetAttribute("ForgeDressed") then
		return true
	end
	local z = gate:GetAttribute("Zone")
	if typeof(z) ~= "number" then
		return false
	end
	local name = ForgeDress.GATE_MODEL[z]
	local hasModel = name ~= nil and Models.has("forge_" .. name)
	local sign = gate:FindFirstChild("Sign") :: BasePart?
	if not sign and not hasModel then
		return false -- (board already swapped for the label; nothing more to do without the model)
	end
	-- (where the board stood, or the label that took its place: it marks the near end of the way)
	local ref = sign or gate:FindFirstChild("GateInfoSpot") :: BasePart?
	-- where the way starts and which way it runs: the posts by the board (chasm ways) or the stone arch (barriers)
	local near: { BasePart } = {}
	local far: { BasePart } = {}
	local arches: { BasePart } = {}
	for _, p in gate:GetChildren() do
		if p:IsA("BasePart") and p.Name == "Post" then
			table.insert(near, p)
		elseif p:IsA("BasePart") and p.Name == "Arch" and p.Size.Y > p.Size.X then
			table.insert(arches, p)
		end
	end
	local foot: Vector3, along: Vector3, width: number
	local standing = 7 -- (how tall what stays is: the posts, or the stone arch)
	if #near >= 4 and ref then
		local at = ref.Position
		table.sort(near, function(a, b)
			return (a.Position - at).Magnitude < (b.Position - at).Magnitude
		end)
		far = { near[3], near[4] }
		near = { near[1], near[2] }
		local a = (near[1].Position + near[2].Position) / 2
		local b = (far[1].Position + far[2].Position) / 2
		foot = a - Vector3.new(0, near[1].Size.Y / 2, 0)
		along = flat(b - a).Unit
		width = flat(near[1].Position - near[2].Position).Magnitude
	elseif #arches >= 2 then
		local a = (arches[1].Position + arches[2].Position) / 2
		foot = a - Vector3.new(0, arches[1].Size.Y / 2, 0)
		local across = flat(arches[2].Position - arches[1].Position)
		along = Vector3.new(-across.Z, 0, across.X).Unit
		-- (point into the area: away from the side the board stands on)
		if ref and flat(ref.Position - a):Dot(along) > 0 then
			along = -along
		end
		width = across.Magnitude
		standing = arches[1].Size.Y
	else
		return false
	end
	local words = boardText(gate)
	local def = Zones.list[z]
	local spot = gate:FindFirstChild("GateInfoSpot")
	local kept = spot and { area = spot:GetAttribute("Area"), need = spot:GetAttribute("Need") } or {}
	local area = words[1] or kept.area or (def and def.name) or ""
	local need = if words[3] then titleCase(words[3]) else (kept.need or (Zones.list[z - 1] and Zones.list[z - 1].name) or "the last area")
	local accent = def and def.palette and def.palette.accent or Color3.fromRGB(255, 214, 60)
	-- the archway: front toward players coming up, a little wider than the way (more and its pillars stand in the
	-- walls of the narrow passes)
	local m = if hasModel then Models.placeForge(name :: string, gate, CFrame.lookAt(foot, foot - along), { width = width + 4, height = (width + 4) * 1.05 }, true) else nil
	local top = standing
	if m then
		m.Name = "ForgeArch"
		local _, size = m:GetBoundingBox()
		top = size.Y
	end
	-- the old board and its post go; with the archway the posts and their glows and the stone arch go too
	for _, p in gate:GetChildren() do
		if p:IsA("BasePart") and (p.Name == "Sign" or p.Name == "SignPost" or p.Name == "SignGlow") then
			p:Destroy()
		elseif m and p:IsA("BasePart") and (p.Name == "Post" or p.Name == "PostGlow" or p.Name == "Arch" or p.Name == "ArchGlow") then
			p:Destroy()
		end
	end
	local old = gate:FindFirstChild("GateInfoSpot")
	if old then
		old:Destroy()
	end
	gateInfo(gate, foot + Vector3.new(0, top + 3.2, 0) - along * 1.5, area, need, accent)
	if m then
		gate:SetAttribute("ForgeDressed", true)
	end
	return m ~= nil
end

-- One drop-off pad (the top disc `pad`, its steps beside it in `pads`).
function ForgeDress.dropOff(pads: Instance, pad: BasePart): boolean
	-- (by the bin, not an attribute: the area-1 pad is copied from area 2's, attributes and all)
	if pads:FindFirstChild(pad.Name .. "Bin") then
		return true
	end
	if not Models.has("forge_dropoff") then
		return false
	end
	local z = pad:GetAttribute("Zone")
	local def = typeof(z) == "number" and Zones.list[z] or nil
	-- the steps: a warm earth base and a grass ring instead of dark stone and neon
	local steps: { BasePart } = {}
	for _, p in pads:GetChildren() do
		if p:IsA("BasePart") and p.Name == pad.Name .. "Step" and (p.Position - pad.Position).Magnitude < 4 then
			table.insert(steps, p)
		end
	end
	table.sort(steps, function(a, b)
		return a.Position.Y < b.Position.Y
	end)
	for i, s in steps do
		if i == #steps then
			s.Color = Color3.fromRGB(96, 166, 60) -- the thin ring just under the top: grass
			s.Material = Enum.Material.Grass
		else
			s.Color = if i == 1 then Color3.fromRGB(122, 90, 60) else Color3.fromRGB(140, 104, 70)
			s.Material = Enum.Material.Ground
		end
	end
	pad.Color = Color3.fromRGB(214, 178, 104)
	pad.Material = Enum.Material.WoodPlanks
	for _, g in pad:GetChildren() do
		if g:IsA("SurfaceGui") then
			g:Destroy()
		end
	end
	-- the bin in the middle, its ramp toward the area's middle (where players come from)
	local top = pad.Position + Vector3.new(0, pad.Size.X / 2, 0)
	local toward = if def and def.center then Vector3.new(def.center.X, top.Y, def.center.Y) else top + Vector3.zAxis
	local dir = flat(toward - top)
	dir = if dir.Magnitude > 0.5 then dir.Unit else Vector3.zAxis
	local m = Models.placeForge("dropoff", pads, CFrame.lookAt(top, top + dir), { width = 7, height = 8 }, false)
	if m then
		m.Name = pad.Name .. "Bin"
	end
	pad:SetAttribute("ForgeDressed", true)
	return m ~= nil
end

-- Everything in world `w` (the gates and the drop-off pads). Returns how many pieces got their model.
function ForgeDress.world(w: Instance): number
	local n = 0
	local gates = w:FindFirstChild("Gates")
	for _, g in (if gates then gates:GetChildren() else {}) do
		if ForgeDress.gate(g) then
			n += 1
		end
	end
	local pads = w:FindFirstChild("Pads")
	for _, p in (if pads then pads:GetChildren() else {}) do
		if p:IsA("BasePart") and string.match(p.Name, "^DropOff%d+$") and ForgeDress.dropOff(pads, p) then
			n += 1
		end
	end
	return n
end

return ForgeDress
