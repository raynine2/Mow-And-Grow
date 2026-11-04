--!strict
-- PackVfxBuild (4 Nov; owner: "remake vfx with this pack ... make it revertable"). Edit mode only:
--   require(game.ServerScriptService.MowALawn.PackVfxBuild).build()
-- makes ReplicatedStorage.PackVFX (the templates client/PackFx plays) from the SoulShroud Ultimate VFX Pack the owner
-- put in ServerStorage.SoulShroudPack. Only the pack's names are here (the pack is paid and the repo is public); the
-- templates themselves live in the place. Running it again rebuilds PackVFX the same way (it holds nothing hand-made:
-- the old one goes to ServerStorage.MowALawnBackups first anyway). Turning the effects off is Config.SOULSHROUD_VFX.
--
-- Each template: `from` = the pack pieces (folder path below SoulShroudPack, the last item's name, and which one
-- when several share the name), laid on the template's root (centred on its emitters; standing on it with base =
-- "bottom"; a beam from the root along -Z with base = "beam").
--   Face   a flat disc stood up to face the way it's played (a portal in the sky)
--   Hold   seconds its emitters run (a burst)       Burst  x the particles of that burst
--   Life   seconds before it's removed              Grow   its mesh shapes grow from GrowFrom x and fade (GrowTime s)
--   Scale  a size it's always played at x           NoTint  layers that keep their colour (smoke, black)
local PackVfxBuild = {}

type Piece = { path: { string }, nth: number? }
type Spec = { from: { Piece }, base: string?, Face: boolean?, Hold: number?, Burst: number?, Life: number?, Grow: boolean?, GrowTime: number?, GrowFrom: number?, Scale: number? }

local function I(n: number): Piece
	return { path = { "Impact", "BZ1 Impact VFX #" .. n } }
end
local function A(n: number): Piece
	return { path = { "Alternate", "SS_AVFX #" .. n } }
end
local function S(name: string, nth: number?): Piece
	return { path = { "Structures", name }, nth = nth }
end

PackVfxBuild.SPEC = {
	-- hits (client/HitFx)
	Hit = { from = { I(46) }, Hold = 0.06, Burst = 2.5, Scale = 1.6 },
	HitBig = { from = { I(34) }, Hold = 0.1 },
	Cut = { from = { I(1) }, Hold = 0.1 },
	Shock = { from = { I(21) }, Hold = 0.05 },
	Reveal = { from = { I(7) }, Hold = 0.15, Burst = 1.5 },
	RevealRing = { from = { I(2) }, Hold = 0.3 },
	-- bosses (client/BossVfx)
	BossHit = { from = { I(35) }, Hold = 0.08 },
	BossDeath = { from = { I(64), S("Explosion") }, Hold = 0.3, Grow = true, GrowTime = 1.6, Life = 3, Scale = 0.3 },
	GoldBurst = { from = { I(43) }, Hold = 0.12 },
	BigBurst = { from = { I(45) }, Hold = 0.12 },
	Star = { from = { I(64) }, Hold = 0.15 },
	PinkBurst = { from = { I(22) }, Hold = 0.12 },
	PurpleBurst = { from = { I(33) }, Hold = 0.15 },
	FireBurst = { from = { A(13) }, Hold = 0.25, Grow = true, GrowTime = 0.9, GrowFrom = 0.3, Life = 1.6 },
	Dome = { from = { S("Dome") }, Grow = true, GrowTime = 0.7, GrowFrom = 0.2, Life = 0.9 },
	Explosion = { from = { S("Explosion") }, Hold = 0.3, Grow = true, GrowTime = 1.1, GrowFrom = 0.15, Life = 2 },
	Rocks = { from = { S("Rocks") }, Hold = 0.15, Grow = true, GrowTime = 1.4, GrowFrom = 0.4, Life = 2 },
	IceSpikes = { from = { S("Ice Impact") }, Grow = true, GrowTime = 1.6, GrowFrom = 0.1, Life = 1.8 },
	IceSplash = { from = { S("Ice Splash / Impact", 1) }, Hold = 0.2, Grow = true, GrowTime = 1, Life = 1.6 },
	Splash = { from = { S("Ice Splash / Impact", 2) }, Hold = 0.2, Grow = true, GrowTime = 1, Life = 1.6 },
	Spikes = { from = { S("Ground Impact ") }, Hold = 0.2, Grow = true, GrowTime = 1.2, GrowFrom = 0.1, Life = 1.8 },
	Slash = { from = { S("Slash Example") }, Grow = true, GrowTime = 0.45, GrowFrom = 0.5, Life = 0.6 },
	Wind = { from = { S("Wind Swirl", 2) }, Grow = true, GrowTime = 1, GrowFrom = 0.3, Life = 1.2 },
	Orb = { from = { A(12) } },
	Bolt = { from = { { path = { "Weather", "Weather I", "Stylized Thunder / Lightning " } } }, Hold = 0.5, Life = 1.6 }, -- (a boss shot's glow, streamed while it flies)
	Beam = { from = { { path = { "KiBlasts", "Ki (気) Blast 1" } } }, base = "beam", Hold = 0.6, Life = 2 },
	-- films (client/FilmVfx)
	Portal = { from = { A(7) }, Hold = 1.5, Life = 3, Face = true },
	BlackHole = { from = { A(16) }, Hold = 3, Life = 5 },
	GoldBeam = { from = { { path = { "KiBlasts", "Ki (気) Blast 2" } } }, base = "beam", Hold = 1.2, Life = 2.5 },
	-- ambience (client/PackAmbience): loops
	Dust = { from = { { path = { "Weather", "Weather I", "Glow Dust" } } } },
	Leaves = { from = { { path = { "Weather", "Leaves", "Leaves" }, nth = 1 } } },
	Fog = { from = { { path = { "Weather", "Weather I", "Stylized Fog" } } } },
	Snow = { from = { { path = { "Weather", "Weather II", "Snow" } } } },
	Sparks = { from = { { path = { "Weather", "Weather I", "Cyberpunk Sparks" } } } },
} :: { [string]: Spec }

local function find(root: Instance, piece: Piece): Instance?
	local at: Instance? = root
	for i, name in piece.path do
		if not at then
			return nil
		end
		if i == #piece.path and piece.nth then
			local n = 0
			local hit: Instance? = nil
			for _, c in at:GetChildren() do
				if c.Name == name then
					n += 1
					if n == piece.nth then
						hit = c
						break
					end
				end
			end
			at = hit
		else
			at = at:FindFirstChild(name)
		end
	end
	return at
end

local function boxOf(inst: Instance): (CFrame, Vector3)
	if inst:IsA("Model") then
		return inst:GetBoundingBox()
	elseif inst:IsA("BasePart") then
		return inst.CFrame, inst.Size
	end
	return CFrame.new(), Vector3.zero
end

local function move(inst: Instance, by: Vector3)
	if inst:IsA("Model") then
		inst:PivotTo(inst:GetPivot() + by)
		return
	end
	-- (a part, and any parts kept inside it: they don't follow it on their own)
	if inst:IsA("BasePart") then
		inst.CFrame += by
	end
	for _, p in inst:GetDescendants() do
		if p:IsA("BasePart") and not p:FindFirstAncestorWhichIsA("Model") then
			p.CFrame += by
		end
	end
end

local function makeOne(pack: Instance, name: string, spec: Spec): (Model?, string?)
	local m = Instance.new("Model")
	m.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root:SetAttribute("Host", true)
	root.CFrame = CFrame.new()
	root.Parent = m
	m.PrimaryPart = root
	for _, piece in spec.from do
		local src = find(pack, piece)
		if not src then
			m:Destroy()
			return nil, table.concat(piece.path, "/") .. " missing"
		end
		local c = src:Clone()
		if spec.base == "beam" then
			-- (a Ki blast runs from its Start part to its End part, sideways and high up in the pack: laid so it starts
			-- at the root and runs along -Z; its length goes in the Length attribute)
			local a, b
			for _, d in c:GetDescendants() do
				if d:IsA("BasePart") then
					local n = string.lower(d.Name)
					if string.find(n, "start") and not a then
						a = d
					elseif string.find(n, "end") and not b then
						b = d
					end
				end
			end
			if a and b and c:IsA("Model") then
				local from, to = (a :: BasePart).Position, (b :: BasePart).Position
				c:PivotTo(CFrame.lookAt(from, to):Inverse() * c:GetPivot())
				m:SetAttribute("Length", (to - from).Magnitude)
			end
		end
		local cf, size = boxOf(c)
		local want = if spec.base == "bottom" then Vector3.new(0, size.Y / 2, 0) else Vector3.zero
		if spec.base ~= "beam" then
			move(c, want - cf.Position)
		end
		-- (a pack effect's emitters often sit on attachments away from their host part: centre on them instead, so the
		-- burst starts where it's played and not under the ground)
		if spec.base == nil and c:IsA("BasePart") then
			local sum, n = Vector3.zero, 0
			for _, d in c:GetDescendants() do
				if d:IsA("Attachment") and d:FindFirstChildWhichIsA("ParticleEmitter") then
					sum += d.WorldPosition
					n += 1
				end
			end
			if n > 0 then
				move(c, want - sum / n)
			end
		end
		for _, d in c:GetDescendants() do
			if d:IsA("LuaSourceContainer") then
				d:Destroy()
			end
		end
		for _, d in (c :: Instance):GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				-- (the weather's emitting volumes are see-through grey boxes: hidden; owner: "a grrey box around me")
				if not d:IsA("MeshPart") and d.Transparency >= 0.5 then
					d.Transparency = 1
				end
				if d.Transparency >= 0.99 then
					d:SetAttribute("Host", true)
				end
			elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
				(d :: any).Enabled = false
				local c0 = (d :: any).Color.Keypoints[1].Value :: Color3
				if c0.R + c0.G + c0.B < 0.25 then
					d:SetAttribute("NoTint", true) -- black smoke / the hole stays black
				end
			end
		end
		if c:IsA("BasePart") then
			c.Anchored = true
			c.CanCollide = false
			if not c:IsA("MeshPart") and c.Transparency >= 0.5 then
				c.Transparency = 1
			end
			if c.Transparency >= 0.99 then
				c:SetAttribute("Host", true)
			end
		end
		c.Parent = m
	end
	for _, k in { "Hold", "Burst", "Life", "Grow", "GrowTime", "GrowFrom", "Scale", "Face" } do
		local v = (spec :: any)[k]
		if v ~= nil then
			m:SetAttribute(k, v)
		end
	end
	return m, nil
end

function PackVfxBuild.build(): string
	local RunService = game:GetService("RunService")
	assert(not RunService:IsRunning(), "PackVfxBuild: run it in edit mode")
	local SS = game:GetService("ServerStorage")
	local RS = game:GetService("ReplicatedStorage")
	local pack = SS:FindFirstChild("SoulShroudPack")
	assert(pack, "PackVfxBuild: ServerStorage.SoulShroudPack is missing (Import Roblox Model: SoulShroudPack_voor_game.rbxm)")
	local out = Instance.new("Folder")
	out.Name = "PackVFX"
	local made, bad = 0, {}
	for name, spec in PackVfxBuild.SPEC do
		local m, err = makeOne(pack, name, spec)
		if m then
			m.Parent = out
			made += 1
		else
			table.insert(bad, name .. ": " .. tostring(err))
		end
	end
	local old = RS:FindFirstChild("PackVFX")
	if old then
		local backups = SS:FindFirstChild("MowALawnBackups") or Instance.new("Folder")
		backups.Name = "MowALawnBackups"
		backups.Parent = SS
		old.Name = "PackVFX_" .. os.date("!%Y%m%d_%H%M%S")
		old.Parent = backups
	end
	out.Parent = RS
	return ("PackVFX: %d templates%s"):format(made, if #bad > 0 then ", missing: " .. table.concat(bad, "; ") else "")
end

return PackVfxBuild
