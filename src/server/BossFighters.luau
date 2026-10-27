-- The players in a boss fight (the owner's boss brief, 26 Oct): everyone on the arena floor when the gate closes
-- fights with 100 HP (player attributes BossHP / BossMaxHP; client/BossHud draws the bar).
--   * a boss attack takes HP and knocks you back with a short stun
--   * at 0 HP you're downed (sitting dizzy, stars over your head, can't move) for Config.BOSS_DOWN_TIME s: a
--     teammate standing next to you for
--     Config.BOSS_REVIVE_TIME s picks you up with half HP (attribute ReviveProgress 0..1); otherwise you get up at
--     the arena entrance with full HP
--   * juice boxes the boss sheds (Config.BOSS_HEAL, +30): walk over one to heal
--   * the phase-2 cutscene freezes everyone (BossFighters.freeze); who never got hit wins the no-hit bonus
--   * when every fighter is down (or gone), server/Boss resets the fight
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local BossMoves = require(ReplicatedStorage.MowALawn.BossMoves)
local Net = require(script.Parent.Net)

local BossFighters = {}

type Fighter = {
	hp: number,
	downAt: number?, -- os.clock() when downed
	revive: number, -- seconds of revive help so far
	safeUntil: number, -- no damage until then (after getting up)
	speed: number?,
	jump: number?,
	hits: number, -- boss hits taken this fight (0 = the no-hit bonus)
	frozen: { speed: number, jump: number }?,
}

local fighters: { [Player]: Fighter } = {}
local arena: any = nil -- server/BossArena's Arena
local heals: { BasePart } = {}
local healFolder: Folder? = nil
local rng = Random.new()
local running = false

local function rootOf(p: Player): BasePart?
	return p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humOf(p: Player): Humanoid?
	return p.Character and p.Character:FindFirstChildOfClass("Humanoid")
end

local function publish(p: Player, f: Fighter?)
	if f then
		p:SetAttribute("BossHP", math.ceil(f.hp))
		p:SetAttribute("BossMaxHP", Config.BOSS_PLAYER_HP)
		p:SetAttribute("Downed", if f.downAt then f.downAt + Config.BOSS_DOWN_TIME - os.clock() else nil)
		p:SetAttribute("ReviveProgress", if f.downAt then f.revive / Config.BOSS_REVIVE_TIME else nil)
	else
		p:SetAttribute("BossHP", nil)
		p:SetAttribute("BossMaxHP", nil)
		p:SetAttribute("Downed", nil)
		p:SetAttribute("ReviveProgress", nil)
	end
end

-- a knock back (also server/Night's crawlers, through Boss.stun). No stun any more (owner, 27 Oct: "remove the
-- stun on hit"): you keep moving and can act at once; a hit only pushes you away and shakes the camera. At most one
-- push every 0.4 s so several hits landing together don't stack.
local lastKnock: { [Player]: number } = {}
function BossFighters.stun(player: Player, from: Vector3, power: number?)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or os.clock() < (lastKnock[player] or 0) then
		return
	end
	lastKnock[player] = os.clock() + 0.4
	local dir = root.Position - from
	dir = Vector3.new(dir.X, 0, dir.Z)
	dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.new(0, 0, -1)
	Net.send(player, "Fx", "knock", { dir = dir, power = power or 1 })
end

local function layDown(p: Player, f: Fighter)
	local hum, root = humOf(p), rootOf(p)
	if not hum or not root then
		return
	end
	f.speed = if hum.WalkSpeed > 0 then hum.WalkSpeed else (f.speed or 16)
	f.jump = hum.JumpPower
	hum.WalkSpeed = 0
	hum.JumpPower = 0
	-- sitting dizzy on the spot (owner, round 2): client/BossCine adds the stars and the revive ring
	local look = root.CFrame.LookVector
	look = Vector3.new(look.X, 0, look.Z)
	look = if look.Magnitude > 0.1 then look.Unit else Vector3.zAxis
	local floorY = if arena then arena.centre.Y else root.Position.Y - hum.HipHeight - root.Size.Y / 2
	local y = floorY + hum.HipHeight * 0.55 + root.Size.Y / 2
	root.Anchored = true
	root.CFrame = CFrame.lookAt(Vector3.new(root.Position.X, y, root.Position.Z), Vector3.new(root.Position.X, y, root.Position.Z) + look)
	hum.Sit = true
end

local function standUp(p: Player, f: Fighter, at: Vector3?, hp: number)
	local hum, root = humOf(p), rootOf(p)
	f.downAt = nil
	f.revive = 0
	f.hp = hp
	f.safeUntil = os.clock() + 1.6
	if root then
		local pos = at or root.Position + Vector3.new(0, 2.5, 0)
		local look = if arena then -arena.facing else Vector3.zAxis
		root.CFrame = CFrame.lookAt(pos, pos + look)
		root.Anchored = false
	end
	if hum then
		hum.Sit = false
		hum.WalkSpeed = f.speed or 16
		hum.JumpPower = f.jump or 50
	end
	publish(p, f)
end

-- Start a fight in `a` (server/BossArena) with these players.
function BossFighters.begin(a: any, players: { Player })
	BossFighters.stop()
	arena = a
	running = true
	for _, p in players do
		BossFighters.add(p)
	end
	local folder = Instance.new("Folder")
	folder.Name = "Heals"
	folder.Parent = a.model
	healFolder = folder
end

-- A player who walks in during the join window.
function BossFighters.add(p: Player)
	if fighters[p] or not running then
		return
	end
	local f = { hp = Config.BOSS_PLAYER_HP, revive = 0, safeUntil = 0, hits = 0 }
	fighters[p] = f
	publish(p, f)
end

function BossFighters.isFighter(p: Player): boolean
	return fighters[p] ~= nil
end

-- Can this player be hurt / hurt the boss right now? (a fighter, standing)
function BossFighters.standing(p: Player): boolean
	local f = fighters[p]
	return f ~= nil and f.downAt == nil
end

function BossFighters.list(): { Player }
	local out = {}
	for p in fighters do
		table.insert(out, p)
	end
	return out
end

-- A boss attack lands on `p` for `amount` from `from`. `soft` (hazard ticks, minion bites): no knock back.
function BossFighters.hit(p: Player, amount: number, from: Vector3, soft: boolean?)
	local f = fighters[p]
	if not f or f.downAt or os.clock() < f.safeUntil or f.frozen then
		return
	end
	-- Studio tests: a player with the attribute BossGod takes no damage (the knock back still shows)
	if p:GetAttribute("BossGod") and game:GetService("RunService"):IsStudio() then
		if not soft then
			BossFighters.stun(p, from)
		end
		return
	end
	f.hits += 1
	f.hp = math.max(0, f.hp - amount)
	Net.send(p, "Fx", "bossHurt", { amount = amount, hp = f.hp, max = Config.BOSS_PLAYER_HP, from = from })
	if f.hp <= 0 then
		f.downAt = os.clock()
		f.revive = 0
		layDown(p, f)
		Net.all("Fx", "fighterDown", { userId = p.UserId, name = p.DisplayName })
	elseif not soft then
		BossFighters.stun(p, from)
	end
	publish(p, f)
end

-- The phase-2 cutscene: everyone standing is frozen in place (on), then let go (off) - server/Boss knocks them back
-- right after.
function BossFighters.freeze(on: boolean)
	for p, f in fighters do
		local hum = humOf(p)
		if not hum or f.downAt then
			continue
		end
		if on and not f.frozen then
			f.frozen = { speed = if hum.WalkSpeed > 0 then hum.WalkSpeed else (f.speed or 16), jump = hum.JumpPower }
			hum.WalkSpeed = 0
			hum.JumpPower = 0
		elseif not on and f.frozen then
			hum.WalkSpeed = f.frozen.speed
			hum.JumpPower = f.frozen.jump
			f.frozen = nil
		end
	end
end

-- Fighters still in the fight whom the boss never hit (the no-hit bonus).
function BossFighters.noHit(): { [Player]: boolean }
	local out = {}
	for p, f in fighters do
		if p.Parent and f.hits == 0 then
			out[p] = true
		end
	end
	return out
end

-- Every fighter down or gone from the arena?
function BossFighters.wiped(): boolean
	if not running or not arena then
		return false
	end
	for p, f in fighters do
		if p.Parent and not f.downAt then
			local root = rootOf(p)
			if root and Vector2.new(root.Position.X - arena.centre.X, root.Position.Z - arena.centre.Z).Magnitude <= arena.radius + 4 then
				return false
			end
		end
	end
	return true
end

local function spawnHeal()
	if not arena or not healFolder then
		return
	end
	local a = rng:NextNumber(0, math.pi * 2)
	local d = rng:NextNumber(0.25, 0.8) * (arena.radius - 8)
	local pos = arena.centre + Vector3.new(math.cos(a) * d, 2, math.sin(a) * d)
	-- a juice box (owner, round 2): the box is this part, client/BossVfx adds the straw, label, glow and bob
	local flower = Instance.new("Part")
	flower.Name = "HealFlower"
	flower.Size = Vector3.new(1.8, 2.4, 1.2)
	flower.Anchored = true
	flower.CanCollide = false
	flower.CanQuery = false
	flower.Material = Enum.Material.SmoothPlastic
	flower.Color = Color3.fromRGB(255, 150, 60)
	flower.CFrame = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	flower:SetAttribute("Heal", Config.BOSS_HEAL.amount)
	flower:SetAttribute("Born", workspace:GetServerTimeNow())
	flower.Parent = healFolder
	table.insert(heals, flower)
	task.delay(Config.BOSS_HEAL.life, function()
		if flower.Parent then
			flower:Destroy()
		end
	end)
end

-- Shed `count` heal flowers now (server/Boss: every Config.BOSS_HEAL.every s, and at the phase change).
function BossFighters.shedHeals(count: number)
	for _ = 1, count do
		spawnHeal()
	end
end

local function step(dt: number)
	if not running or not arena then
		return
	end
	local now = os.clock()
	-- downed: helpers revive, or get up at the entrance when time runs out
	for p, f in fighters do
		if not p.Parent then
			fighters[p] = nil
		elseif f.downAt then
			local root = rootOf(p)
			local helping = false
			if root then
				for q, g in fighters do
					local r2 = rootOf(q)
					if q ~= p and not g.downAt and r2 and (r2.Position - root.Position).Magnitude <= Config.BOSS_REVIVE_RADIUS then
						helping = true
						break
					end
				end
			end
			f.revive = if helping then f.revive + dt else math.max(0, f.revive - dt * 0.5)
			if f.revive >= Config.BOSS_REVIVE_TIME then
				standUp(p, f, nil, Config.BOSS_PLAYER_HP * 0.5)
				Net.all("Fx", "fighterUp", { userId = p.UserId, revived = true })
			elseif now - f.downAt >= Config.BOSS_DOWN_TIME then
				standUp(p, f, arena.entry, Config.BOSS_PLAYER_HP)
				Net.all("Fx", "fighterUp", { userId = p.UserId, revived = false })
			else
				publish(p, f)
			end
		end
	end
	-- heal flowers
	for i = #heals, 1, -1 do
		local h = heals[i]
		if not h.Parent then
			table.remove(heals, i)
		else
			for p, f in fighters do
				local root = rootOf(p)
				if not f.downAt and f.hp < Config.BOSS_PLAYER_HP and root and (root.Position - h.Position).Magnitude <= Config.BOSS_HEAL.radius + 2 then
					f.hp = math.min(Config.BOSS_PLAYER_HP, f.hp + Config.BOSS_HEAL.amount)
					publish(p, f)
					Net.all("Fx", "bossHeal", { pos = h.Position, userId = p.UserId })
					h:Destroy()
					table.remove(heals, i)
					break
				end
			end
		end
	end
end

-- End the fight: downed players get up, HP bars go, flowers go.
function BossFighters.stop()
	BossFighters.freeze(false)
	for p, f in fighters do
		if f.downAt and p.Parent then
			standUp(p, f, if arena then arena.entry else nil, Config.BOSS_PLAYER_HP)
		end
		publish(p, nil)
	end
	table.clear(fighters)
	for _, h in heals do
		h:Destroy()
	end
	table.clear(heals)
	if healFolder then
		healFolder:Destroy()
		healFolder = nil
	end
	running = false
	arena = nil
end

task.spawn(function()
	while true do
		local dt = task.wait(0.2)
		local ok, err = pcall(step, dt)
		if not ok then
			warn("[BossFighters] " .. tostring(err))
		end
	end
end)

Players.PlayerRemoving:Connect(function(p)
	fighters[p] = nil
end)

return BossFighters
