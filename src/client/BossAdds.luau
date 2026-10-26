-- The bosses' minions (round 2 of the owner's boss brief, 26 Oct). server/Boss moves an invisible 3-stud "BossAdd"
-- part (attribute Look) after the players; this draws a small cartoon minion on it, client side only, smoothed
-- between the server's steps, hopping (a squash on every landing), leaning into its run and turning to its target:
--   seedling  a dandelion puff on legs (Dandelion King)
--   crow      a black crow flapping low over the floor (Harvest Maw)
--   sprout    a swamp bulb with a toothy mouth (Bog Strangler)
--   pumpkin   a tiny jack-o'-lantern with a flame inside (Hollow Harvest): it runs at you and blows up
--   bee       a big striped bee that flies at you and stings once (Hive Keeper)
local RunService = game:GetService("RunService")

local BossAdds = {}

local C = Color3.fromRGB
local folder = Instance.new("Folder")
folder.Name = "BossAdds"
folder.Parent = workspace

local function bit(m: Model, shape: Enum.PartType, size: Vector3, offset: CFrame, color: Color3, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p:SetAttribute("Off", offset)
	p.Parent = m
	return p
end

local BALL, BLOCK, CYL = Enum.PartType.Ball, Enum.PartType.Block, Enum.PartType.Cylinder

-- each look: parts as offsets from the minion's feet (front = -Z)
local LOOKS: { [string]: (Model) -> () } = {}
LOOKS.seedling = function(m)
	bit(m, CYL, Vector3.new(1.6, 0.35, 0.35), CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.rad(90)), C(80, 160, 60))
	bit(m, BALL, Vector3.one * 2.6, CFrame.new(0, 2.6, 0), C(250, 250, 240), Enum.Material.Sand)
	bit(m, BALL, Vector3.one * 1.2, CFrame.new(0, 2.5, -0.9), C(255, 214, 70))
	for _, x in { -0.35, 0.35 } do
		bit(m, BALL, Vector3.one * 0.35, CFrame.new(x, 2.75, -1.45), C(20, 20, 20))
		bit(m, CYL, Vector3.new(0.9, 0.3, 0.3), CFrame.new(x * 2, 0.45, 0) * CFrame.Angles(0, 0, math.rad(90)), C(70, 140, 50))
	end
end
LOOKS.crow = function(m)
	bit(m, BALL, Vector3.new(1.6, 1.5, 2.4), CFrame.new(0, 2.2, 0), C(30, 30, 38))
	bit(m, BALL, Vector3.one * 1.2, CFrame.new(0, 2.8, -1.1), C(36, 36, 44))
	bit(m, BLOCK, Vector3.new(0.3, 0.3, 0.8), CFrame.new(0, 2.7, -1.9), C(240, 180, 40))
	for _, x in { -1, 1 } do
		bit(m, BALL, Vector3.one * 0.3, CFrame.new(x * 0.35, 3.0, -1.6), C(255, 230, 80), Enum.Material.Neon)
		local w = bit(m, BLOCK, Vector3.new(1.8, 0.15, 1.2), CFrame.new(x * 1.4, 2.4, 0), C(24, 24, 30))
		w:SetAttribute("Wing", x)
	end
end
LOOKS.sprout = function(m)
	bit(m, CYL, Vector3.new(1.4, 0.6, 0.6), CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.rad(90)), C(60, 110, 60))
	bit(m, BALL, Vector3.new(2.4, 2.2, 2.4), CFrame.new(0, 2.2, 0), C(110, 170, 70))
	bit(m, BLOCK, Vector3.new(1.4, 0.35, 0.3), CFrame.new(0, 1.9, -1.15), C(60, 20, 30))
	for _, x in { -0.45, 0, 0.45 } do
		bit(m, BLOCK, Vector3.new(0.18, 0.3, 0.18), CFrame.new(x, 2.1, -1.2), C(250, 250, 240))
	end
	bit(m, BALL, Vector3.one * 0.5, CFrame.new(0, 2.9, -1.0), C(157, 255, 90), Enum.Material.Neon)
end
LOOKS.bee = function(m)
	bit(m, BALL, Vector3.new(1.8, 1.7, 2.4), CFrame.new(0, 2.4, 0.2), C(255, 205, 40))
	for _, z in { -0.3, 0.5 } do
		bit(m, CYL, Vector3.new(0.4, 1.75, 1.75), CFrame.new(0, 2.4, z + 0.2) * CFrame.Angles(0, math.rad(90), 0), C(30, 25, 20))
	end
	bit(m, BALL, Vector3.one * 1.2, CFrame.new(0, 2.6, -1.2), C(30, 25, 20))
	bit(m, BLOCK, Vector3.new(0.15, 0.15, 0.7), CFrame.new(0, 2.2, 1.5), C(40, 30, 20))
	for _, x in { -1, 1 } do
		bit(m, BALL, Vector3.one * 0.35, CFrame.new(x * 0.35, 2.8, -1.7), C(255, 255, 255), Enum.Material.Neon)
		local w = bit(m, BLOCK, Vector3.new(1.4, 0.1, 0.9), CFrame.new(x * 1.1, 3.2, 0), C(220, 240, 255), Enum.Material.Glass)
		w.Transparency = 0.4
		w:SetAttribute("Wing", x)
	end
end
LOOKS.pumpkin = function(m)
	bit(m, BALL, Vector3.new(2.6, 2.1, 2.6), CFrame.new(0, 1.3, 0), C(240, 120, 30))
	bit(m, CYL, Vector3.new(0.6, 0.35, 0.35), CFrame.new(0, 2.6, 0) * CFrame.Angles(0, 0, math.rad(90)), C(80, 110, 40))
	for _, x in { -0.5, 0.5 } do
		bit(m, BLOCK, Vector3.new(0.45, 0.45, 0.2), CFrame.new(x, 1.6, -1.2) * CFrame.Angles(0, 0, math.rad(45)), C(255, 220, 90), Enum.Material.Neon)
	end
	bit(m, BLOCK, Vector3.new(1.2, 0.3, 0.2), CFrame.new(0, 0.95, -1.25), C(255, 200, 70), Enum.Material.Neon)
end

type Minion = { src: BasePart, model: Model, parts: { BasePart }, cf: CFrame, born: number, seed: number, flies: boolean }
local minions: { [BasePart]: Minion } = {}

local function add(src: BasePart)
	if minions[src] then
		return
	end
	local look = src:GetAttribute("Look") or "seedling"
	local m = Instance.new("Model")
	m.Name = "Minion_" .. tostring(look)
	;(LOOKS[look] or LOOKS.seedling)(m)
	local parts = {}
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") then
			table.insert(parts, p)
		end
	end
	m.Parent = folder
	local feet = src.CFrame * CFrame.new(0, -src.Size.Y / 2, 0)
	minions[src] = { src = src, model = m, parts = parts, cf = feet, born = os.clock(), seed = math.random() * 10, flies = look == "crow" or look == "bee" }
	src.AncestryChanged:Connect(function()
		if not src:IsDescendantOf(workspace) then
			local mi = minions[src]
			minions[src] = nil
			if mi then
				mi.model:Destroy()
			end
		end
	end)
end

workspace.DescendantAdded:Connect(function(d)
	if d:IsA("BasePart") and d.Name == "BossAdd" then
		add(d)
	end
end)
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") and d.Name == "BossAdd" then
		add(d)
	end
end

RunService.RenderStepped:Connect(function(dt)
	for src, mi in minions do
		local want = src.CFrame * CFrame.new(0, -src.Size.Y / 2, 0)
		local moving = (want.Position - mi.cf.Position).Magnitude
		mi.cf = mi.cf:Lerp(want, math.min(1, dt * 10))
		local t = os.clock() - mi.born + mi.seed
		local age = os.clock() - mi.born
		-- pop out of the ground over the first 0.35 s (overshoot), then hop while it runs
		local grow = if age < 0.35 then 1 + 1.7 * (age / 0.35 - 1) ^ 3 + 0.7 * (age / 0.35 - 1) ^ 2 else 1
		grow = math.max(0.05, grow)
		local run = math.clamp(moving * 3, 0, 1)
		local hop, squash, lean
		if mi.flies then
			hop = 1.2 + math.sin(t * 5) * 0.5
			squash = 1
			lean = math.rad(-12) * run
		else
			local ph = (t * 7) % 1
			hop = math.sin(ph * math.pi) * 1.1 * run
			squash = if ph < 0.15 then 1 - (0.15 - ph) * 1.6 * run else 1 + 0.06 * math.sin(ph * math.pi) * run
			lean = math.rad(-14) * run
		end
		local sy = squash * grow
		local sxz = (1 / math.sqrt(math.max(0.3, squash))) * grow
		local base = mi.cf * CFrame.new(0, hop, 0) * CFrame.Angles(lean, 0, 0)
		for _, p in mi.parts do
			local off = p:GetAttribute("Off") :: CFrame
			local wing = p:GetAttribute("Wing")
			if wing then
				off = off * CFrame.Angles(0, 0, math.sin(t * 22) * 0.7 * wing)
			end
			local pos = off.Position
			p.CFrame = base * CFrame.new(pos.X * sxz, pos.Y * sy, pos.Z * sxz) * off.Rotation
		end
	end
end)

-- Get rid of every minion (the fight ended).
function BossAdds.clear()
	for src, mi in minions do
		mi.model:Destroy()
		minions[src] = nil
	end
end

return BossAdds
