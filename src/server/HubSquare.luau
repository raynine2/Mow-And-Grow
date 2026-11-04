--!strict
-- THE STARTING HUB'S VILLAGE SQUARE (owner, 1 Nov: "starting hub remake"; direction: a village square, few pieces, all
-- of them purposeful: on 29 Oct the camps' dressing was taken out as "messy and cluttered"). Built at run start into
-- the run's copy of the world (server/RunWorld.build calls HubSquare.dress after the camps), on the open paving west
-- of the TOOL SHOP; nothing in Studio's saved world changes. HubSquare.ON = false turns all of it off.
--   * the centrepiece: the Golden Lawn Gnome (the game's 1-in-10,000 find) as a gold statue (ForgeGUI) on a round
--     stone fountain, water jets arcing in from the rim, gold sparkles round him;
--   * four flower beds round the fountain, petals drifting off them;
--   * six lantern posts in a ring with strings of bunting between them;
--   * the welcome arch over the west path into the square.
-- Particles are the auras' VFX Forge layers (ReplicatedStorage.AuraVFX) recoloured. Every piece stands on the
-- ground under its spot (raycast) and the ring keeps clear of the buildings (checked with the hub's map, 4 Nov).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Models = require(script.Parent.Models)

local HubSquare = {}

-- (4 Nov, ~03:00, owner, standing in it: "the main lobby that ur standing in feels so ass and looks ass idk the bricks
-- and the random lanterns and plants ... remove it or wtf": off. The code stays; true brings the square back. The
-- camp's loose lanterns went with it and its paving was redone: server/CampGround.)
HubSquare.ON = false
HubSquare.CENTRE = Vector3.new(52, 0, 345) -- (x, z: the middle of the open paving; y comes from the ground)
HubSquare.ARCH = Vector3.new(24, 0, 327) -- the west path where it enters the square

local BUNTING = {
	Color3.fromRGB(235, 70, 70),
	Color3.fromRGB(255, 200, 50),
	Color3.fromRGB(70, 150, 235),
	Color3.fromRGB(110, 200, 80),
	Color3.fromRGB(255, 140, 50),
	Color3.fromRGB(170, 100, 220),
}
local STONE = Color3.fromRGB(176, 170, 160)
local WATER = Color3.fromRGB(96, 178, 232)

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = false
	p.Parent = parent
	return p
end

-- the ground's height at (x, z): the first thing a ray from above hits that isn't ours
local function groundAt(w: Instance, x: number, z: number, skip: { Instance }): number
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = skip
	local hit = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -160, 0), rp)
	return if hit then hit.Position.Y else 4
end

-- a copy of one VFX Forge aura layer's emitter, on `holder`, recoloured
local function layer(holder: Instance, template: string, name: string, color: Color3?, rate: number?): ParticleEmitter?
	local av = ReplicatedStorage:FindFirstChild("AuraVFX")
	local t = av and av:FindFirstChild(template)
	local src: Instance? = nil
	if t then
		for _, d in t:GetDescendants() do
			if d:IsA("ParticleEmitter") and d.Name == name then
				src = d
				break
			end
		end
	end
	if not src then
		return nil
	end
	local e = (src :: ParticleEmitter):Clone()
	for _, k in { "Loop", "EmitCount" } do
		e:SetAttribute(k, nil)
	end
	if color then
		e.Color = ColorSequence.new(color)
	end
	if rate then
		e.Rate = rate
	end
	e.Enabled = true
	e.Parent = holder
	return e
end

-- the golden gnome: ServerStorage.HubProps.golden_gnome (ForgeGUI, made 4 Nov), else a plain gold gnome from parts
local function gnome(parent: Instance, base: CFrame, height: number)
	local props = ServerStorage:FindFirstChild("HubProps")
	local t = props and props:FindFirstChild("golden_gnome")
	if t and t:IsA("MeshPart") then
		local m = t:Clone()
		local native = (m:GetAttribute("Native") :: Vector3?) or m.Size
		m.Size = native * (height / native.Y)
		m.CFrame = base * CFrame.new(0, m.Size.Y / 2, 0)
		m.Anchored = true
		m.Parent = parent
		return m
	end
	local gold = Color3.fromRGB(255, 196, 52)
	local body = part(parent, "GnomeBody", Vector3.new(2.6, 3, 2.6), base * CFrame.new(0, 1.5, 0), gold, Enum.Material.Foil)
	body.Shape = Enum.PartType.Ball
	local hat = Instance.new("WedgePart")
	hat.Anchored = true
	hat.Size = Vector3.new(1.8, 3, 1.8)
	hat.CFrame = base * CFrame.new(0, 4.4, 0)
	hat.Color = gold
	hat.Material = Enum.Material.Foil
	hat.Parent = parent
	return body
end

function HubSquare.dress(w: Instance): number
	if not HubSquare.ON then
		return 0
	end
	local hub = w:FindFirstChild("Hub")
	if not hub then
		return 0
	end
	local old = hub:FindFirstChild("HubSquare")
	if old then
		old:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "HubSquare"
	local skip: { Instance } = { f }
	local n = 0
	local C = HubSquare.CENTRE
	local cy = groundAt(w, C.X, C.Z, skip)
	local centre = Vector3.new(C.X, cy, C.Z)

	-- the fountain: a round stone basin, water, the golden gnome on a plinth in the middle
	local basinR = 6.5
	local rim = part(f, "FountainRim", Vector3.new(1.6, basinR * 2, basinR * 2), CFrame.new(centre + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, 0, math.rad(90)), STONE, Enum.Material.Slate)
	rim.Shape = Enum.PartType.Cylinder
	local water = part(f, "FountainWater", Vector3.new(0.3, basinR * 2 - 1.4, basinR * 2 - 1.4), CFrame.new(centre + Vector3.new(0, 1.55, 0)) * CFrame.Angles(0, 0, math.rad(90)), WATER, Enum.Material.Glass)
	water.Shape = Enum.PartType.Cylinder
	water.Transparency = 0.2
	water.Reflectance = 0.15
	water.CanCollide = false
	local plinth = part(f, "Plinth", Vector3.new(2.4, 4.4, 4.4), CFrame.new(centre + Vector3.new(0, 1.2 + 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), STONE, Enum.Material.Slate)
	plinth.Shape = Enum.PartType.Cylinder
	local statue = gnome(f, CFrame.new(centre + Vector3.new(0, 3.6, 0)) * CFrame.Angles(0, math.rad(-90), 0), 7.5)
	n += 4
	-- gold sparkles round him, water arcing in from four jets on the rim
	local glow = Instance.new("Attachment")
	glow.Name = "Sparkles"
	glow.Position = Vector3.new(0, 0, 0)
	glow.Parent = statue
	layer(glow, "Loop_UltimateGardener", "Pollen", Color3.fromRGB(255, 220, 110), 6)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 214, 120)
	light.Range = 14
	light.Brightness = 0.8
	light.Parent = statue
	for k = 0, 3 do
		local a = math.rad(45 + k * 90)
		local p = centre + Vector3.new(math.cos(a) * (basinR - 0.6), 1.7, math.sin(a) * (basinR - 0.6))
		local jet = Instance.new("Attachment")
		jet.Name = "Jet"
		-- (parented first: a world CFrame set on a loose attachment is taken as its local one)
		jet.Parent = rim
		-- the attachment's front (-Z) points up and in toward the statue: the Pour layer emits along it
		jet.WorldCFrame = CFrame.lookAt(p, centre + Vector3.new(0, 10, 0))
		local e = layer(jet, "Loop_UltimateGardener", "Pour", WATER, 22)
		if e then
			-- (the aura's pour only dribbles: a fountain jet arcs up, about 2.5 studs over the rim, and lands on the
			-- statue's feet; checked in Play 4 Nov)
			e.Speed = NumberRange.new(12, 13)
			e.Lifetime = NumberRange.new(1, 1.1)
			e.Acceleration = Vector3.new(0, -24, 0)
			e.SpreadAngle = Vector2.new(3, 3)
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0.2) })
			e.LightEmission = 0.35
		end
	end

	-- four flower beds on the diagonals, facing the fountain, petals drifting off them
	for k = 0, 3 do
		local a = math.rad(45 + k * 90)
		local r = 11
		local x, z = centre.X + math.cos(a) * r, centre.Z + math.sin(a) * r
		local y = groundAt(w, x, z, skip)
		local at = CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(centre.X, y, centre.Z))
		local bed = Models.place("flower_bed", f, at, 1.2)
		if bed then
			n += 1
			local box = bed:FindFirstChildWhichIsA("BasePart", true)
			if box then
				local att = Instance.new("Attachment")
				att.Name = "Petals"
				att.Parent = box
				att.WorldPosition = Vector3.new(x, y + 1.6, z)
				layer(att, "Loop_Gardener", "Petals", nil, 3)
			end
		end
	end

	-- six lantern posts in a ring, bunting strung between neighbours
	local ringR = 17
	local tops: { Vector3 } = {}
	for k = 0, 5 do
		local a = math.rad(30 + k * 60)
		local x, z = centre.X + math.cos(a) * ringR, centre.Z + math.sin(a) * ringR
		local y = groundAt(w, x, z, skip)
		local at = CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(centre.X, y, centre.Z))
		local post = Models.place("lantern_post", f, at, 1)
		local h = 8.5
		if post then
			n += 1
			local _, size = post:GetBoundingBox()
			h = size.Y - 0.6
		else
			part(f, "LampPost", Vector3.new(0.5, 8, 0.5), at * CFrame.new(0, 4, 0), Color3.fromRGB(60, 60, 64), Enum.Material.Metal)
		end
		table.insert(tops, Vector3.new(x, y + h, z))
	end
	local SEGS, FLAGS, SAG = 6, 9, 1.6
	for k = 1, #tops do
		local a, b = tops[k], tops[k % #tops + 1]
		local function at(t: number): Vector3
			return a:Lerp(b, t) - Vector3.new(0, SAG * 4 * t * (1 - t), 0)
		end
		for s = 1, SEGS do
			local p0, p1 = at((s - 1) / SEGS), at(s / SEGS)
			local rope = part(f, "Rope", Vector3.new(0.08, 0.08, (p1 - p0).Magnitude), CFrame.lookAt((p0 + p1) / 2, p1), Color3.fromRGB(245, 240, 225))
			rope.CanCollide = false
			rope.CanQuery = false
		end
		local along = (b - a).Unit
		for i = 1, FLAGS do
			local t = i / (FLAGS + 1)
			local p = at(t)
			-- a pennant: a thin wedge hanging point-down under the rope
			local flag = Instance.new("WedgePart")
			flag.Name = "Flag"
			flag.Anchored = true
			flag.CanCollide = false
			flag.CanQuery = false
			flag.CastShadow = false
			flag.Size = Vector3.new(0.06, 0.95, 0.8)
			flag.Color = BUNTING[(i + k) % #BUNTING + 1]
			flag.Material = Enum.Material.Fabric
			-- (the wedge's depth runs along the rope; turned over so its full edge is on top and its point hangs down)
			local c = p - Vector3.new(0, 0.5, 0)
			flag.CFrame = CFrame.lookAt(c, c + along) * CFrame.Angles(math.rad(180), 0, 0)
			flag.Parent = f
		end
	end

	-- the welcome arch over the west path, facing into the square
	local A = HubSquare.ARCH
	local ay = groundAt(w, A.X, A.Z, skip)
	local arch = Models.place("welcome_arch", f, CFrame.lookAt(Vector3.new(A.X, ay, A.Z), Vector3.new(A.X + 1, ay, A.Z)), 0.75)
	if arch then
		n += 1
		-- its board says where you are: the square's name on the side facing it, a welcome on the path side
		-- (FredokaOne with a dark outline, like the game's other signs)
		local board = arch:FindFirstChild("Board", true)
		if board and board:IsA("BasePart") then
			local function sign(face: Enum.NormalId, text: string)
				local sg = Instance.new("SurfaceGui")
				sg.Name = "Sign"
				sg.Face = face
				sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				sg.PixelsPerStud = 40
				sg.LightInfluence = 0.4
				sg.Parent = board
				local t = Instance.new("TextLabel")
				t.BackgroundTransparency = 1
				t.Size = UDim2.fromScale(0.92, 0.78)
				t.Position = UDim2.fromScale(0.04, 0.11)
				t.Text = text
				t.TextScaled = true
				t.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
				t.TextColor3 = Color3.fromRGB(255, 236, 170)
				t.Parent = sg
				local st = Instance.new("UIStroke")
				st.Color = Color3.fromRGB(30, 25, 45)
				st.Thickness = 3
				st.Parent = t
			end
			-- (the board is thin along its own Z; its front face (-Z) is the one facing the square if it points east)
			local frontIn = board.CFrame.LookVector.X > 0
			sign(if frontIn then Enum.NormalId.Front else Enum.NormalId.Back, "VILLAGE SQUARE")
			sign(if frontIn then Enum.NormalId.Back else Enum.NormalId.Front, "WELCOME!")
		end
	end

	f.Parent = hub
	print(("[HubSquare] village square: %d pieces round the golden gnome fountain"):format(n))
	return n
end

return HubSquare
