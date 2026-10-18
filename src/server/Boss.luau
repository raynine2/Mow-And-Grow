-- Zone bosses: a giant weed monster grows out of the cleared field. It slams the ground near a player
-- (red warning circle first, so you can dodge). Hit it with your tool or ram it with a mower.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.MowALawn.Config)
local Net = require(script.Parent.Net)
local PropKit = require(script.Parent.PropKit)
local RunBuilder = require(script.Parent.RunBuilder)
local Models = require(script.Parent.Models)

local BOSS_MODEL = { "boss_dandelion", "boss_thornbush", "boss_flytrap", "boss_vine", "boss_jungle" }

local Boss = {}

local current = nil :: {
	z: number,
	def: any,
	hp: number,
	maxHp: number,
	model: Model,
	root: BasePart,
	radius: number,
	alive: boolean,
}?
local folder: Folder? = nil

Boss.onDefeated = nil :: ((number, { [Player]: number }) -> ())?
Boss.onChanged = nil :: (() -> ())?
local damageBy: { [Player]: number } = {}

function Boss.setup(parent: Instance)
	folder = PropKit.folder("Boss", parent)
end

function Boss.state()
	if not current or not current.alive then
		return nil
	end
	return { name = current.def.name, hp = current.hp, max = current.maxHp, z = current.z }
end

local function build(z: number, def): (Model, BasePart)
	local centre = RunBuilder.zoneCentre(z)
	-- the Blender monster, standing on an invisible root block that the fight logic uses
	local holder = Instance.new("Model")
	holder.Name = def.name
	local placed = Models.place(BOSS_MODEL[z], holder, CFrame.lookAt(centre, centre + Vector3.new(0, 0, -1)), 1 + (z - 1) * 0.12)
	if placed then
		local rootPart = PropKit.brick(holder, Vector3.new(8, 3, 8), CFrame.new(centre + Vector3.new(0, 1.5, 0)), Color3.new(), "Roots")
		rootPart.Transparency = 1
		local _, size = placed:GetBoundingBox()
		local head = PropKit.part({ size = Vector3.one, cf = CFrame.new(centre + Vector3.new(0, size.Y * 0.8, 0)), color = Color3.new(), parent = holder, transparency = 1, collide = false, name = "Head" })
		holder.PrimaryPart = head
		PropKit.billboard(head, def.name, Color3.fromRGB(255, 90, 90), Vector2.new(18, 3.5), Vector3.new(0, size.Y * 0.35, 0), 300)
		holder.Parent = folder
		return holder, rootPart
	end
	local m = Instance.new("Model")
	m.Name = def.name
	local c = def.color
	local stem = Color3.fromRGB(70, 160, 60)
	local root = PropKit.brick(m, Vector3.new(8, 3, 8), CFrame.new(centre + Vector3.new(0, 1.5, 0)), PropKit.shade(Config.ZONES[z].ground, 0.7), "Roots")
	local scale = 1 + z * 0.25
	local y = 3
	for i = 1, 4 do
		local w = (3.4 - i * 0.3) * scale
		PropKit.brick(m, Vector3.new(w, 3 * scale, w), CFrame.new(centre + Vector3.new(0, y + 1.5 * scale, 0)), PropKit.shade(stem, 1 - i * 0.05), "Stem")
		y += 3 * scale
	end
	-- leaves sticking out
	for i = 0, 3 do
		local a = i * math.pi / 2
		PropKit.brick(m, Vector3.new(7 * scale, 0.8, 2.4 * scale), CFrame.new(centre + Vector3.new(0, 5 * scale, 0)) * CFrame.Angles(0, a, math.rad(20)) * CFrame.new(3 * scale, 0, 0), PropKit.shade(stem, 1.1), "Leaf")
	end
	-- head: big flower / bush / jaws by colour
	local head = PropKit.brick(m, Vector3.new(9, 7, 9) * scale, CFrame.new(centre + Vector3.new(0, y + 3.5 * scale, 0)), c, "Head")
	for i = 0, 7 do
		local a = i * math.pi / 4
		PropKit.brick(m, Vector3.new(3, 2, 6) * scale, CFrame.new(centre + Vector3.new(0, y + 3.5 * scale, 0)) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 6 * scale), PropKit.shade(c, 0.85), "Petal")
	end
	-- angry face toward the hub (-Z)
	local face = CFrame.new(centre + Vector3.new(0, y + 3.5 * scale, -4.6 * scale))
	for _, x in { -2, 2 } do
		PropKit.brick(m, Vector3.new(1.6, 1.6, 0.4) * scale, face * CFrame.new(x * scale, 1 * scale, 0), Color3.new(1, 1, 1), "Eye")
		PropKit.brick(m, Vector3.new(0.8, 0.8, 0.5) * scale, face * CFrame.new(x * scale, 1 * scale, -0.1), Color3.new(0, 0, 0), "Pupil")
		PropKit.brick(m, Vector3.new(2.2, 0.5, 0.5) * scale, face * CFrame.new(x * scale, 2.2 * scale, 0) * CFrame.Angles(0, 0, math.rad(if x < 0 then -20 else 20)), Color3.new(0.1, 0.1, 0.1), "Brow")
	end
	PropKit.brick(m, Vector3.new(4, 1, 0.5) * scale, face * CFrame.new(0, -1.6 * scale, 0), Color3.fromRGB(120, 20, 30), "Mouth")
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = p == root
		end
	end
	m.PrimaryPart = head
	PropKit.billboard(head, def.name, Color3.fromRGB(255, 90, 90), Vector2.new(18, 3.5), Vector3.new(0, 8 * scale, 0), 300)
	m.Parent = folder
	return m, root
end

local function playersInZone(z: number): { Player }
	local list = {}
	local zs = Config.zoneStartZ(z)
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and root.Position.Z > zs - 20 and root.Position.Z < zs + Config.GRID.rows * Config.GRID.tile + 20 then
			table.insert(list, p)
		end
	end
	return list
end

local function stun(player: Player, from: Vector3)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not root or char:GetAttribute("Stunned") then
		return
	end
	char:SetAttribute("Stunned", true)
	local speed = hum.WalkSpeed
	hum.WalkSpeed = 0
	local dir = root.Position - from
	dir = Vector3.new(dir.X, 0, dir.Z)
	dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.new(0, 0, -1)
	Net.send(player, "Fx", "knock", { dir = dir })
	task.delay(1.2, function()
		if char.Parent then
			char:SetAttribute("Stunned", nil)
			if hum.WalkSpeed == 0 then
				hum.WalkSpeed = speed
			end
		end
	end)
end

local function attackLoop(b)
	while b.alive do
		task.wait(b.def.every)
		if not b.alive then
			break
		end
		local targets = playersInZone(b.z)
		if #targets > 0 then
			local target = targets[math.random(#targets)]
			local root = target.Character and target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local pos = Vector3.new(root.Position.X, 0.4, root.Position.Z)
				local radius = b.def.radius
				local delay = 1.4
				Net.all("Fx", "telegraph", { pos = pos, radius = radius, delay = delay })
				task.wait(delay)
				if b.alive then
					Net.all("Fx", "slam", { pos = pos, radius = radius })
					for _, p in Players:GetPlayers() do
						local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
						if r and (Vector3.new(r.Position.X, 0, r.Position.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude <= radius then
							stun(p, pos)
						end
					end
				end
			end
		end
	end
end

function Boss.spawn(z: number)
	if current and current.alive then
		return
	end
	local def = Config.ZONES[z].boss
	local extra = math.max(0, #Players:GetPlayers() - 1)
	local maxHp = math.floor(def.hp * (1 + extra * Config.BOSS_HP_PER_EXTRA_PLAYER))
	local model, root = build(z, def)
	table.clear(damageBy)
	current = { z = z, def = def, hp = maxHp, maxHp = maxHp, model = model, root = root, radius = 8 + z * 2, alive = true }
	Net.all("Fx", "bossSpawn", { pos = root.Position, name = def.name })
	if Boss.onChanged then
		Boss.onChanged()
	end
	task.spawn(attackLoop, current)
end

-- Is `pos` close enough to hit the boss with reach `reach`?
function Boss.inReach(pos: Vector3, reach: number): boolean
	if not current or not current.alive then
		return false
	end
	local c = current.root.Position
	local d = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(c.X, 0, c.Z)).Magnitude
	return d <= current.radius + reach
end

function Boss.damage(player: Player, amount: number)
	local b = current
	if not b or not b.alive or amount <= 0 then
		return
	end
	b.hp = math.max(0, b.hp - amount)
	damageBy[player] = (damageBy[player] or 0) + amount
	Net.send(player, "Fx", "bossHit", { pos = b.model.PrimaryPart and b.model.PrimaryPart.Position or b.root.Position, amount = amount })
	if Boss.onChanged then
		Boss.onChanged()
	end
	if b.hp <= 0 then
		b.alive = false
		Net.all("Fx", "bossDown", { pos = b.root.Position, name = b.def.name })
		local z = b.z
		local snapshot = table.clone(damageBy)
		task.delay(1.2, function()
			b.model:Destroy()
		end)
		current = nil
		if Boss.onDefeated then
			Boss.onDefeated(z, snapshot)
		end
		if Boss.onChanged then
			Boss.onChanged()
		end
	end
end

function Boss.alive(): boolean
	return current ~= nil and current.alive
end

return Boss
