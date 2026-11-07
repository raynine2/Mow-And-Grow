-- FINISHER (7 Nov 2026; owner, after a TikTok of a Roblox fight animation: "Kan je ook zo animated?", then
-- "Films en boss finish"). The boss's death becomes a short anime finisher with YOUR avatar in it: you dash in and
-- grab it, heave it into the sky, leap after it and hammer it back down (a red impact frame), land on it and pound
-- it, one last punch (a black impact frame and a hit-stop), hop off and walk away while it bursts behind you.
-- Our own move (no copy of any game's character or move), cut like the reference: hard cuts, a close-up on the face,
-- a low angle up at the throw, short single-colour impact frames, a walk-away with the explosion behind.
--   Finisher.plan(d) -> plan?     whether this client plays it for a "bossDeath" event (the same answer every call:
--                                 client/BossKill and client/BossCine both ask). plan.onPop(fn(pos)): fn runs when the
--                                 boss bursts (the old death effects hang on it); plan.height: the boss's height.
--   Finisher.boss(d, ctx) -> plan?  start it (client/BossCine: ctx = { arena = centre, z = zone })
-- The server waits for it (shared/BossMoves.DEATH_TIME, Config.FINISHER.deathTime) before the rewards. SKIP ends it.
-- Cosmetic only: anything that fails puts everything back and the boss still bursts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("MowALawn")
local Config = require(Shared:WaitForChild("Config")) :: any
local BossMoves = require(Shared:WaitForChild("BossMoves")) :: any
local Film = require(script.Parent.Film)
local IntroUi = require(script.Parent.IntroUi)
local IntroCast = require(script.Parent.IntroCast)
local AnimeFx = require(script.Parent.AnimeFx)
local CelFx = require(script.Parent.CelFx)
local Puppet = require(script.Parent.Puppet)
local PackFx = require(script.Parent.PackFx)
local BossView = require(script.Parent.BossView)

local Finisher = {}
local player = Players.LocalPlayer

local UP = Vector3.yAxis
local WHITE = Color3.new(1, 1, 1)
local RED = Color3.fromRGB(255, 50, 60)
local STEP = "BossFinisher" -- (the film's render step)
-- the screens that come back at the burst (the defeated card, the rays, the flash), while the film still runs
local POP_GUIS = { "BossFxHud", "BossKillRays", "BossKillFlash" }

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end
local function flat(p: Vector3): Vector3
	return Vector3.new(p.X, 0, p.Z)
end
local function clamp01(k: number): number
	return math.clamp(k, 0, 1)
end
local function out(k: number): number
	return 1 - (1 - clamp01(k)) ^ 3
end
local function inn(k: number): number
	k = clamp01(k)
	return k * k
end

-------------------------------------------------------------------------------------------------------------
-- the moves (client/Puppet poses: degrees per joint, +X forward / bowing / nodding; rh / lh where the wrists go in
-- the chest's space: x right, y up, -z ahead; rf / lf the feet from where they stand; hip = the body's drop)
-------------------------------------------------------------------------------------------------------------
local P = {}
-- coiled to burst forward: low, leaning in, one arm forward, one back
P.coil = {
	Root = v(14, 0, 0), Waist = v(12, 0, 0), Neck = v(-26, 0, 0),
	rh = v(0.95, -0.55, 0.75), rpole = v(1, 0, -1), lh = v(-0.55, 0.05, -1.0), lpole = v(-1, -1, 0),
	lf = v(-0.05, 0, -0.95), rf = v(0.1, 0, 0.85), hip = v(0, -1.0, 0),
}
-- in the air on its chest: the right hand fisted in it, the left fist cocked at the hip, legs hanging
P.grab = {
	Waist = v(-8, 6, 0), Neck = v(-10, -4, 0),
	rh = v(0.3, 0.45, -1.5), rpole = v(1, -1, 0.3),
	lh = v(-0.9, -0.35, 0.55), lpole = v(-1, -0.4, 1),
	LeftHip = v(36, 0, -8), LeftKnee = v(-70, 0, 0), RightHip = v(18, 0, 8), RightKnee = v(-46, 0, 0),
}
-- dropped to its feet, low, the right fist down by the knee: the throw coming
P.heaveLow = {
	Waist = v(22, -30, 0), Neck = v(-22, 26, 0),
	rh = v(1.0, -0.95, 0.25), rpole = v(1, 0, 1),
	lh = v(-0.75, 0.15, -1.0), lpole = v(-1, -1, 0),
	lf = v(-0.1, 0, -0.85), rf = v(0.2, 0, 0.7), hip = v(0, -1.15, 0),
}
-- the throw: an uppercut straight up, the body stretched up off the front foot, eyes on it
P.heave = {
	Waist = v(-14, 26, 0), Neck = v(-30, -20, 0),
	rh = v(0.4, 2.0, -0.3), rpole = v(1, 0, 0.5),
	lh = v(-0.9, -0.6, 0.45), lpole = v(-1, -0.5, 1),
	lf = v(-0.05, 0, -0.6), rf = v(0.15, 0.25, 0.7), hip = v(0, 0.15, -0.1),
}
-- jumping after it: knees tucked, arms swept down and back
P.leap = {
	Waist = v(-8, 0, 0), Neck = v(-26, 0, 0),
	rh = v(0.95, -0.85, 0.65), rpole = v(1, 0, -1), lh = v(-0.95, -0.85, 0.65), lpole = v(-1, 0, -1),
	LeftHip = v(70, 0, -6), LeftKnee = v(-100, 0, 0), RightHip = v(40, 0, 6), RightKnee = v(-90, 0, 0),
}
-- over it: both fists locked together high over the head, back arched
P.hammerUp = {
	Waist = v(-22, 0, 0), Neck = v(8, 0, 0),
	rh = v(0.15, 1.95, 0.25), rpole = v(1, 0, 0), lh = v(-0.15, 1.95, 0.25), lpole = v(-1, 0, 0),
	LeftHip = v(60, 0, -8), LeftKnee = v(-110, 0, 0), RightHip = v(30, 0, 8), RightKnee = v(-80, 0, 0),
}
-- the hammer: both fists driven down through it, the body folded over them, legs kicked back
P.hammerDown = {
	Waist = v(40, 0, 0), Neck = v(-10, 0, 0),
	rh = v(0.15, -0.85, -1.05), rpole = v(1, 0, 0), lh = v(-0.15, -0.85, -1.05), lpole = v(-1, 0, 0),
	LeftHip = v(-30, 0, -6), LeftKnee = v(-40, 0, 0), RightHip = v(-20, 0, 6), RightKnee = v(-60, 0, 0),
}
-- dropping after it: arms up, eyes down
P.fall = {
	Waist = v(-6, 0, 0), Neck = v(18, 0, 0),
	rh = v(0.95, 1.3, 0.2), rpole = v(1, 0, 0), lh = v(-0.95, 1.3, 0.2), lpole = v(-1, 0, 0),
	LeftHip = v(12, 0, -6), LeftKnee = v(-24, 0, 0), RightHip = v(-6, 0, 6), RightKnee = v(-12, 0, 0),
}
-- on top of it: crouched, the left hand pinning it down, the right fist up
P.mount = {
	Waist = v(34, -16, 0), Neck = v(-12, 14, 0),
	lh = v(-0.5, -1.35, -0.75), lpole = v(-1, 0, 1),
	rh = v(0.95, 0.5, 0.35), rpole = v(1, -0.5, 1),
	lf = v(-0.2, 0, -0.5), rf = v(0.25, 0, 0.6), hip = v(0, -1.3, 0),
}
P.poundR = {
	Waist = v(44, 18, 0), Neck = v(-16, -14, 0),
	rh = v(0.3, -1.35, -0.95), rpole = v(1, 0, 0.6),
	lh = v(-0.5, -1.3, -0.75), lpole = v(-1, 0, 1),
	lf = v(-0.2, 0, -0.5), rf = v(0.25, 0, 0.6), hip = v(0, -1.45, -0.1),
}
P.poundL = {
	Waist = v(44, -18, 0), Neck = v(-16, 14, 0),
	lh = v(-0.3, -1.35, -0.95), lpole = v(-1, 0, 0.6),
	rh = v(0.9, 0.4, 0.4), rpole = v(1, -0.5, 1),
	lf = v(-0.2, 0, -0.5), rf = v(0.25, 0, 0.6), hip = v(0, -1.45, -0.1),
}
-- the last one: the right fist pulled up high and back, the body twisted away, the left hand still pinning
P.windDown = {
	Waist = v(10, -40, 0), Neck = v(-8, 36, 0),
	rh = v(0.7, 1.4, 0.8), rpole = v(1, 0, 1),
	lh = v(-0.5, -1.35, -0.75), lpole = v(-1, 0, 1),
	lf = v(-0.2, 0, -0.5), rf = v(0.25, 0, 0.6), hip = v(0, -1.1, 0.1),
}
-- and through: the right arm driven straight down, everything behind it, the left arm thrown back
P.finalDown = {
	Waist = v(52, 30, 0), Neck = v(-20, -24, 0),
	rh = v(0.1, -1.5, -1.0), rpole = v(1, 0, 0.5),
	lh = v(-0.9, -0.2, 0.6), lpole = v(-1, -0.3, 1),
	lf = v(-0.2, 0, -0.5), rf = v(0.25, 0, 0.6), hip = v(0, -1.6, -0.2),
}
-- walking off: hands loose, chin up (the walk cycle goes on top)
P.walkOff = {
	Waist = v(-3, 0, 0), Neck = v(-6, 0, 0),
	LeftShoulder = v(2, 0, -8), RightShoulder = v(2, 0, 8), LeftElbow = v(14, 0, 0), RightElbow = v(14, 0, 0),
}
Finisher.POSES = P

-- the beats, in film seconds (slow motion stretches the hang; the impact frames stop the clock for a moment)
local TL = {
	dash = 0.24, grab = 0.36, drop = 0.86, heave = 1.06, leap = 1.30, hang = 1.58, hammer = 1.80, crash = 2.10,
	land = 2.36, p1 = 2.62, p2 = 2.80, p3 = 2.98, wind = 3.16, final = 3.40, rise = 3.74, hop = 3.92, touch = 4.18,
	walk = 4.46, pop = 4.95, done = 5.9,
}
Finisher.TL = TL

-------------------------------------------------------------------------------------------------------------
-- small helpers
-------------------------------------------------------------------------------------------------------------
local function enabled(): boolean
	local f = Config.FINISHER
	return f ~= nil and f.on == true
end

-- a one-shot (the films' sounds or the game's), without taking the music over: the boss music plays on
local function sfx(key: string, volume: number?, pitch: number?)
	local def = (Config.FILM_SOUNDS and Config.FILM_SOUNDS[key]) or (Config.SOUNDS and Config.SOUNDS[key])
	if not def or not def.id or def.id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.Name = "Finisher_" .. key
	s.SoundId = def.id
	s.Volume = (def.volume or 0.5) * (volume or 1)
	s.PlaybackSpeed = (def.pitch or 1) * (pitch or 1)
	local g = SoundService:FindFirstChild("MowALawnSfx")
	if g and g:IsA("SoundGroup") then
		s.SoundGroup = g
	end
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, (def.len or 4) / math.max(s.PlaybackSpeed, 0.1) + 1)
end

local function fx(name: string, at: Vector3, opts: any?)
	local o = opts or {}
	o.force = true
	o.soft = if o.soft == nil then true else o.soft
	pcall(PackFx.play, name, at, o)
end

local function controls(on: boolean)
	local scripts = player:FindFirstChild("PlayerScripts")
	local module = scripts and scripts:FindFirstChild("PlayerModule")
	if not module then
		return
	end
	pcall(function()
		local c = (require(module :: any) :: any):GetControls()
		if on then
			c:Enable()
		else
			c:Disable()
		end
	end)
end

local function zoneColor(z: number?): Color3
	local ok, c = pcall(function()
		return Color3.fromHex(BossMoves.get(z or 1).ring or "FFE66E")
	end)
	return if ok and typeof(c) == "Color3" then c else Color3.fromRGB(255, 230, 110)
end

-- the player's own body, copied for the film (R15 only: client/Puppet poses R15 joints)
local function avatar(): Model?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not hum or hum.RigType ~= Enum.HumanoidRigType.R15 or not char:FindFirstChild("HumanoidRootPart") then
		return nil
	end
	local was = char.Archivable
	char.Archivable = true
	local ok, m = pcall(function()
		return char:Clone()
	end)
	char.Archivable = was
	if not ok or not m then
		return nil
	end
	for _, x in m:GetDescendants() do
		if x:IsA("BaseScript") or x:IsA("Sound") or x:IsA("Tool") or x:IsA("ForceField") or x:IsA("BillboardGui") or x:IsA("Highlight") or x:IsA("ParticleEmitter") or x:IsA("Beam") or x:IsA("Trail") or x:IsA("Light") or x.Name == "BundleStack" then
			x:Destroy()
		end
	end
	return m
end

local function isR15(): boolean
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.RigType == Enum.HumanoidRigType.R15 and char:FindFirstChild("HumanoidRootPart") ~= nil
end

local function myPos(): Vector3?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

-------------------------------------------------------------------------------------------------------------
-- the plan (one per death; every caller gets the same one)
-------------------------------------------------------------------------------------------------------------
local plans: { [any]: any } = {}

local function firePops(plan: any, pos: Vector3)
	if plan.popped then
		return
	end
	plan.popped = true
	for _, fn in plan.pops do
		task.spawn(function()
			local ok, err = pcall(fn, pos)
			if not ok then
				warn("[Finisher] pop: " .. tostring(err))
			end
		end)
	end
end

function Finisher.plan(d: any): any?
	if type(d) ~= "table" then
		return nil
	end
	local key = d.at
	if key ~= nil and plans[key] ~= nil then
		return plans[key] or nil
	end
	local ok = enabled() and typeof(d.cf) == "CFrame" and type(d.len) == "number" and not Film.playing and isR15()
	local left = 0
	if ok then
		local at = if type(d.at) == "number" then d.at else workspace:GetServerTimeNow()
		left = d.len - (workspace:GetServerTimeNow() - at)
		local me = myPos()
		local reach = (Config.BOSS_ARENA_RADIUS or 70) + 80
		ok = left >= 4.5 and me ~= nil and (me - d.cf.Position).Magnitude <= reach and BossView.get() ~= nil
	end
	if not ok then
		if key ~= nil then
			plans[key] = false
		end
		return nil
	end
	local plan: any = { d = d, left = left, pops = {}, popped = false, started = false, height = BossView.height() }
	function plan.onPop(fn: (Vector3) -> ())
		if plan.popped then
			task.spawn(pcall, fn, plan.popAt or d.cf.Position)
		else
			table.insert(plan.pops, fn)
		end
	end
	if key ~= nil then
		plans[key] = plan
	end
	-- a safety net: whatever happens, the boss bursts by the time the server is done with it
	task.delay(left + 0.2, function()
		firePops(plan, plan.popAt or d.cf.Position)
	end)
	return plan
end

-------------------------------------------------------------------------------------------------------------
-- the film
-------------------------------------------------------------------------------------------------------------
-- The boss as it stands now: a copy we can throw around (the real view is put away), its parts placed round its
-- middle each frame. Returns the copy and its sizes in its own frame (H tall, depth front to back, width).
local function takeBoss(view: any, F: Vector3): any
	local src: Model = view.model
	local was = src.Archivable
	src.Archivable = true
	local m = src:Clone()
	src.Archivable = was
	m.Name = "FinisherBoss"
	local base: CFrame = view.base
	local look = flat(base.LookVector)
	look = if look.Magnitude > 0.05 then look.Unit else F
	local frame = CFrame.lookAt(base.Position, base.Position + look)
	local lo, hi = v(math.huge, math.huge, math.huge), v(-math.huge, -math.huge, -math.huge)
	local parts: { BasePart } = {}
	for _, x in m:GetDescendants() do
		if x:IsA("BasePart") then
			x.Anchored = true
			x.CanCollide = false
			x.CanTouch = false
			x.CanQuery = true -- (the camera keeps out of it)
			if x.Transparency < 0.98 then
				local p = frame:PointToObjectSpace(x.Position)
				local r = math.min(x.Size.Magnitude * 0.5, 6)
				lo = lo:Min(p - Vector3.one * r * 0.6)
				hi = hi:Max(p + Vector3.one * r * 0.6)
			end
			table.insert(parts, x)
		elseif x:IsA("BillboardGui") or x:IsA("Sound") or x:IsA("BaseScript") then
			x:Destroy()
		end
	end
	if lo.X == math.huge then
		lo, hi = v(-4, 0, -4), v(4, 8, 4)
	end
	local size = hi - lo
	local mid = (lo + hi) * 0.5
	local H = math.max(view.height or size.Y, 4)
	local centre0 = frame * mid
	-- every part relative to the middle, the boss facing -Z (its own front)
	local c0 = CFrame.lookAt(centre0, centre0 + look)
	local rels: { CFrame } = table.create(#parts)
	for i, p in parts do
		rels[i] = c0:ToObjectSpace(p.CFrame)
	end
	local cfs: { CFrame } = table.create(#parts, CFrame.identity)
	local face = CFrame.lookAt(Vector3.zero, F)
	local victim = {
		model = m, parts = parts, H = H,
		depth = math.clamp(size.Z, H * 0.3, H * 1.1), width = math.clamp(size.X, H * 0.3, H * 1.4),
		centre0 = centre0, floorDrop = H * 0.5,
	}
	function victim.place(centre: Vector3, rot: CFrame)
		local b = CFrame.new(centre) * rot * face
		for i, r in rels do
			cfs[i] = b * r
		end
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
	return victim
end

-- the boss bursts: every block flashes white and fades
local function burstBoss(victim: any)
	for _, p in victim.parts do
		if p.Transparency < 0.98 then
			p.Material = Enum.Material.Neon
			p.Color = WHITE
			TweenService:Create(p, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
		end
	end
	for _, x in victim.model:GetDescendants() do
		if x:IsA("Decal") or x:IsA("Texture") then
			x:Destroy()
		elseif x:IsA("ParticleEmitter") then
			x.Enabled = false
		end
	end
end

local function run(plan: any, ctx: any)
	local d = plan.d
	local view = BossView.get()
	local me = myPos()
	if not view or not view.model or not me then
		error("no boss or no character")
	end
	local folder = Instance.new("Folder")
	folder.Name = "Finisher"
	folder.Parent = workspace
	local color = zoneColor(ctx and ctx.z or d.z)
	local arena: Vector3? = ctx and ctx.arena
	local gy = d.cf.Position.Y
	local bossAt = view.base.Position
	-- which way it all faces: from the boss to you
	local F = flat(me - bossAt)
	F = if F.Magnitude > 0.5 then F.Unit else flat(d.cf.LookVector).Unit
	local D = -F -- (from you to the boss)
	local side = F:Cross(UP).Unit
	local victim = takeBoss(view, F)
	victim.model.Parent = folder
	BossView.hide()
	local H, depth = victim.H, victim.depth
	local Cs = Vector3.new(victim.centre0.X, gy + H * 0.5, victim.centre0.Z) -- its middle, standing
	local Bg = Vector3.new(Cs.X, gy, Cs.Z)
	local Cl = Bg + UP * (depth * 0.5) + D * (H * 0.3) -- its middle, lying on its back
	local Bc = Vector3.new(Cl.X, gy, Cl.Z) -- where it lands
	local Capex = Cs + UP * (H * 1.3 + 12) -- the top of the throw
	local pitchAxis = F:Cross(UP).Unit -- (turning about it: its front goes up, its head goes away from you)
	local function pitch(deg: number): CFrame
		return CFrame.fromAxisAngle(pitchAxis, math.rad(deg))
	end
	-- where you hang over it in the air (checked in Studio: half its size above its middle left you a speck far over it)
	local hangOff = UP * (H * 0.35 + 3) + F * (depth * 0.1)
	plan.popAt = Bc
	plan.height = H

	-- you
	local src = avatar()
	if not src then
		error("no avatar")
	end
	local A = Puppet.new(src, { name = "FinisherHero", parent = folder })
	src:Destroy()
	for _, x in A.model:GetDescendants() do
		if x:IsA("BasePart") or x:IsA("Decal") then
			(x :: any).LocalTransparencyModifier = 0
		end
	end
	local S = Bg + F * (depth * 0.5 + 12 + H * 0.15) + UP * 3 -- where you start (the root, 3 over the ground)
	local G = Cs + F * (depth * 0.5) + UP * (H * 0.12) -- where your hand grips its chest
	local Agrab = G + F * 1.55 - UP * 1.35
	local Gg = Vector3.new(Cs.X, gy + 3, Cs.Z) + F * (depth * 0.5 + 2.4) -- at its feet, for the throw
	local chest = Cl + D * (H * 0.15) + UP * (depth * 0.5) -- its chest, lying (the top of it)
	local Amount = chest + UP * 3 + F * 0.6
	local hitAt = chest + D * 0.9 + UP * 0.15
	local Gf = Vector3.new(Cs.X, gy + 3, Cs.Z) + F * (depth * 0.5 + 8) -- where you land when you hop off

	-- take the screen
	local done = false
	local t0 = 0
	local function now(): number
		return Film.now() - t0
	end
	local function finish()
		if done then
			return
		end
		done = true
		firePops(plan, Bc)
		if Film.playing and Film.owner == STEP then
			Film.stop(STEP)
		end
		pcall(IntroUi.close)
		pcall(IntroCast.hideCharacters, false)
		controls(true)
		pcall(function()
			A:destroy()
		end)
		task.delay(0.5, function()
			folder:Destroy()
		end)
	end
	plan.finish = finish
	IntroUi.open(function()
		finish()
	end)
	IntroUi.fade(1, 0)
	IntroUi.letterbox(true, 0.18)
	IntroCast.hideCharacters(true)
	controls(false)
	Film.start(STEP)
	Film.hand(0.35)
	Film.refreshSight({ A.model }) -- (the boss's copy stays solid to the camera: it mustn't end up inside it)
	t0 = Film.now()
	-- the real clock: whatever the slow motion did, it ends before the server moves on
	local deadline = os.clock() + plan.left - 0.35
	task.delay(math.max(0.5, plan.left - 0.35), finish)

	-- the camera: keep inside the arena and out of walls (looking past `safe`, the point it mustn't lose)
	local function cam(pos: Vector3, look: Vector3, mm: number, roll: number?, safe: Vector3?, view0: any?): (CFrame, number, Vector3)
		if arena then
			local dd = flat(pos - arena)
			local maxD = (Config.BOSS_ARENA_RADIUS or 70) - 4
			if dd.Magnitude > maxD then
				dd = dd.Unit * maxD
				pos = Vector3.new(arena.X + dd.X, pos.Y, arena.Z + dd.Z)
			end
		end
		pos = Vector3.new(pos.X, math.max(pos.Y, gy + 0.6), pos.Z)
		if safe and view0 then
			pos = Film.clear(pos, safe, view0)
		end
		return Film.look(pos, look, roll), Film.mm(mm), look
	end
	local function vc(): Vector3
		return victim.centreNow or Cs
	end

	-- where everything is, every frame
	local theta, vcentre = 0, Cs
	local lastGhost = 0
	Film.every(function(dt: number)
		local t = now()
		-- the boss
		if t < TL.heave then
			-- reeling, leaning in toward the grab
			local lean = if t >= TL.grab then 8 * out((t - TL.grab) / 0.3) else 0
			theta = -lean
			vcentre = Cs + v(0, math.sin(t * 9) * 0.15, 0)
		elseif t < TL.hang then
			local k = (t - TL.heave) / (TL.hang - TL.heave)
			theta = 200 * out(k)
			vcentre = Cs:Lerp(Capex, 1 - (1 - clamp01(k)) ^ 2.2)
		elseif t < TL.hammer + 0.03 then
			local k = (t - TL.hang) / (TL.hammer + 0.03 - TL.hang)
			theta = 200 + 45 * clamp01(k)
			vcentre = Capex + UP * (H * 0.06 * clamp01(k))
		elseif t < TL.crash then
			local k = (t - TL.hammer - 0.03) / (TL.crash - TL.hammer - 0.03)
			theta = 245 + 205 * inn(k)
			vcentre = (Capex + UP * (H * 0.06)):Lerp(Cl, inn(k))
		else
			theta = 450
			local j = 0
			if t > TL.final and t < TL.final + 0.25 then
				j = -0.6 * (1 - (t - TL.final) / 0.25) -- (the last punch drives it into the ground)
			end
			vcentre = Cl + UP * j
		end
		victim.centreNow = vcentre
		if not plan.popped then
			victim.place(vcentre, pitch(theta))
		end
		-- you
		local pos: Vector3
		local face = D
		local tilt = 0
		if t < TL.dash then
			pos = S
		elseif t < TL.grab then
			local k = (t - TL.dash) / (TL.grab - TL.dash)
			pos = S:Lerp(Agrab, out(k))
			if os.clock() - lastGhost > 0.035 then
				lastGhost = os.clock()
				A:ghost(WHITE, 0.7, 0.18)
			end
		elseif t < TL.drop then
			pos = Agrab + (vcentre - Cs) -- (riding its lean)
		elseif t < TL.drop + 0.12 then
			pos = Agrab:Lerp(Gg, inn((t - TL.drop) / 0.12))
		elseif t < TL.leap then
			pos = Gg
		elseif t < TL.hang then
			local k = clamp01((t - TL.leap) / (TL.hang - TL.leap))
			local goal = vcentre + hangOff
			pos = Gg:Lerp(goal, out(k)) + F * (math.sin(k * math.pi) * 3) + UP * (math.sin(k * math.pi) * 2)
			tilt = -40 * k
			if os.clock() - lastGhost > 0.05 then
				lastGhost = os.clock()
				A:ghost(WHITE, 0.78, 0.16)
			end
		elseif t < TL.hammer + 0.06 then
			pos = vcentre + hangOff
			tilt = -40
		elseif t < TL.land then
			local k = clamp01((t - TL.hammer - 0.06) / (TL.land - TL.hammer - 0.06))
			local from = Capex + UP * (H * 0.06) + hangOff
			pos = from:Lerp(Amount, inn(k))
			tilt = -40 * (1 - k)
		elseif t < TL.hop then
			pos = Amount
		elseif t < TL.touch then
			local k = clamp01((t - TL.hop) / (TL.touch - TL.hop))
			pos = Amount:Lerp(Gf, k) + UP * (math.sin(k * math.pi) * 3.5)
			-- (turning round in the air, from facing it to facing away)
			face = CFrame.fromAxisAngle(UP, math.rad(180 * out(k * 1.3))):VectorToWorldSpace(D)
		elseif t < TL.walk then
			pos = Gf
			face = F
		else
			pos = Gf + F * (A:stride() * (t - TL.walk))
			face = F
		end
		A.root = CFrame.lookAt(pos, pos + face) * CFrame.Angles(math.rad(tilt), 0, 0)
		A:update(dt)
	end)

	-- the moves, on the film's clock
	local function at(time: number, fn: () -> ())
		Film.at(time, function()
			if not done then
				local ok, err = pcall(fn)
				if not ok then
					warn("[Finisher] " .. tostring(err))
				end
			end
		end)
	end
	A:pose("stand", 0)
	A:pose(P.coil, 0.2, "inOut")
	A:look(Cs + UP * (H * 0.2), 0.8)
	sfx("jjkCharge", 0.5, 1.3)
	local stopLines: (() -> ())? = nil
	at(TL.dash, function()
		A:look(nil)
		A:pose(P.grab, 0.1, "snap")
		sfx("speedWhoosh", 1, 1)
		sfx("jjkWhoosh", 0.8, 1.1)
		pcall(CelFx.streaks, S, Agrab, { color = WHITE, size = 1.2 })
		stopLines = AnimeFx.lines(WHITE, 0.45)
		fx("Dust", Vector3.new(S.X, gy, S.Z), { scale = 1.2 })
	end)
	at(TL.grab, function()
		if stopLines then
			stopLines()
		end
		A:shake(0.6)
		sfx("hardPunch", 0.9, 0.85)
		sfx("jjkImpact", 0.9, 0.9)
		Film.shake(0.45, 2)
		Film.punch(5)
		CelFx.ring(G, { color = WHITE, rim = Color3.fromRGB(30, 20, 40), size = 0.8, radius = 9, life = 0.3, normal = F })
		CelFx.sparks(G, { color = color, size = 1, count = 18 })
		A:look(G + UP * 3, 0.6)
	end)
	at(TL.drop, function()
		A:look(nil)
		A:pose(P.heaveLow, 0.14, "out")
		sfx("thud", 0.8, 0.9)
	end)
	at(TL.drop + 0.12, function()
		fx("Dust", Vector3.new(Gg.X, gy, Gg.Z), { scale = 1.4 })
		CelFx.dust(Vector3.new(Gg.X, gy, Gg.Z), { size = 0.9 })
	end)
	at(TL.heave, function()
		A:pose(P.heave, 0.06, "snap")
		A:smear({ "RightHand" }, true, WHITE)
		task.delay(0.25, function()
			A:smear({ "RightHand" }, false)
		end)
		sfx("jjkPunch", 1, 0.9)
		sfx("boom", 0.4, 1.2)
		sfx("rumble", 0.8, 1)
		Film.shake(0.7, 1.6)
		Film.punch(6)
		Film.blur(10)
		CelFx.impact(Bg, { color = color, size = math.clamp(H / 14, 0.9, 2.4), floorY = gy, dust = true })
		AnimeFx.hit(G, color, 7, true)
	end)
	at(TL.leap, function()
		A:pose(P.leap, 0.1, "out")
		sfx("speedWhoosh", 0.8, 1.25)
		fx("Dust", Vector3.new(Gg.X, gy, Gg.Z), { scale = 1.1 })
		CelFx.ring(Vector3.new(Gg.X, gy + 0.1, Gg.Z), { color = WHITE, size = 0.7, radius = 8, life = 0.3 })
	end)
	at(TL.hang - 0.08, function()
		A:pose(P.hammerUp, 0.16, "out")
		Film.speed(0.3, 0.08)
		sfx("jjkRise", 0.6, 1.4)
	end)
	at(TL.hammer, function()
		Film.speed(1, 0.05)
		A:pose(P.hammerDown, 0.05, "snap")
		A:smear({ "RightHand", "LeftHand" }, true, RED)
		task.delay(0.3, function()
			A:smear({ "RightHand", "LeftHand" }, false)
		end)
		sfx("jjkSlam", 1.1, 1)
		sfx("hardPunch", 1, 0.7)
		Film.shake(0.95, 1.4)
		local contact = vcentre + hangOff * 0.6
		task.defer(function()
			AnimeFx.impact({ A.model, victim.model }, "red", { hold = 0.14, at = contact })
		end)
		CelFx.flare(contact, { color = RED, size = 2.2 })
		CelFx.sparks(contact, { color = color, size = 1.6, count = 30 })
	end)
	at(TL.hammer + 0.18, function()
		A:pose(P.fall, 0.2, "out")
		sfx("speedWhoosh", 0.6, 0.8)
	end)
	at(TL.crash, function()
		sfx("jjkBoom", 1.1, 0.9)
		sfx("slam", 1.2, 0.8)
		sfx("rumble", 1, 0.8)
		Film.shake(1, 1.0)
		Film.punch(7)
		Film.flash(WHITE, 0.35, 0.25)
		local size = math.clamp(H / 10, 1.2, 3.2)
		CelFx.impact(Bc + UP * 0.5, { color = color, size = size, floorY = gy, dust = true })
		CelFx.ring(Bc + UP * 0.15, { color = WHITE, rim = Color3.fromRGB(30, 20, 40), size = size, radius = 22, life = 0.6 })
		fx("GroundSlam", Bc, { scale = size })
		fx("Dust", Bc, { scale = size * 1.3 })
	end)
	at(TL.land, function()
		A:pose(P.mount, 0.06, "snap")
		A:look(hitAt, 0.6)
		sfx("thud", 1, 0.8)
		sfx("jjkImpact", 0.7, 0.8)
		Film.shake(0.4, 2)
		CelFx.ring(chest + UP * 0.1, { color = WHITE, size = 0.6, radius = 6, life = 0.25 })
	end)
	local function pound(pose: any, hand: string, pitchOf: number)
		A:pose(pose, 0.05, "snap")
		A:smear({ hand }, true, WHITE)
		task.delay(0.12, function()
			A:smear({ hand }, false)
		end)
		Film.at(0.1, function()
			if not done then
				A:pose(P.mount, 0.1, "out")
			end
		end)
		sfx("hardPunch", 0.75, pitchOf)
		sfx("jjkImpact", 0.6, pitchOf)
		Film.shake(0.45, 2.5)
		Film.punch(3)
		local at2 = hitAt + side * (if hand == "RightHand" then 0.4 else -0.4)
		CelFx.sparks(at2, { color = color, size = 0.9, count = 14 })
		CelFx.ring(at2, { color = WHITE, size = 0.45, radius = 5, life = 0.2, normal = UP })
		AnimeFx.hit(at2, color, 4, false)
	end
	at(TL.p1, function()
		pound(P.poundR, "RightHand", 1.0)
	end)
	at(TL.p2, function()
		pound(P.poundL, "LeftHand", 1.12)
	end)
	at(TL.p3, function()
		pound(P.poundR, "RightHand", 1.05)
	end)
	at(TL.wind, function()
		A:pose(P.windDown, 0.2, "inOut")
		sfx("jjkCharge", 0.6, 1.6)
	end)
	at(TL.final, function()
		A:pose(P.finalDown, 0.04, "snap")
		A:smear({ "RightHand" }, true, WHITE)
		task.delay(0.3, function()
			A:smear({ "RightHand" }, false)
		end)
		sfx("jjkPunch", 1.2, 0.8)
		sfx("bigHit", 0.9, 0.9)
		sfx("boom", 0.6, 0.9)
		Film.shake(1, 1.2)
		task.defer(function()
			AnimeFx.impact({ A.model, victim.model }, "neg", { hold = 0.1, at = hitAt })
		end)
		local size = math.clamp(H / 12, 1, 2.6)
		CelFx.flare(hitAt, { color = WHITE, size = 2 })
		CelFx.ring(Vector3.new(hitAt.X, gy + 0.15, hitAt.Z), { color = color, rim = Color3.fromRGB(30, 20, 40), size = size, radius = 26, life = 0.7 })
		CelFx.cracks(Vector3.new(Bc.X, gy + 0.05, Bc.Z), { color = color, size = size * 1.2 })
		CelFx.debris(Vector3.new(Bc.X, gy, Bc.Z), { size = size })
	end)
	at(TL.rise, function()
		A:look(nil)
		A:pose("heroRise", 0.22, "inOut")
	end)
	at(TL.hop, function()
		A:pose(P.leap, 0.1, "out")
		sfx("swipe", 0.6, 1.1)
	end)
	at(TL.touch, function()
		A:pose("heroLand", 0.05, "snap")
		sfx("thud", 1.1, 0.9)
		Film.shake(0.35, 2)
		CelFx.dust(Vector3.new(Gf.X, gy, Gf.Z), { size = 0.8 })
		CelFx.ring(Vector3.new(Gf.X, gy + 0.1, Gf.Z), { color = WHITE, size = 0.6, radius = 7, life = 0.3 })
	end)
	at(TL.walk - 0.2, function()
		A:pose("heroRise", 0.2, "inOut")
	end)
	at(TL.walk, function()
		A:pose(P.walkOff, 0.25, "inOut")
		A:walk(1, 1.0, "cool")
	end)
	local function pop()
		if plan.popped or done then
			return
		end
		IntroUi.keep(POP_GUIS)
		burstBoss(victim)
		local size = math.clamp(H / 10, 1.2, 3.2)
		CelFx.flare(Cl, { color = WHITE, size = size * 1.6, life = 0.5 })
		CelFx.ring(Bc + UP * 0.2, { color = color, size = size, radius = 30, life = 0.8 })
		Film.shake(0.6, 1.2)
		firePops(plan, Bc)
	end
	at(TL.pop, pop)
	task.delay(math.max(0.3, deadline - os.clock() - 0.8), pop)

	-- the shots
	local view1 = Film.view()
	local function shot(untilT: number, fn: (number, number) -> (CFrame, number, Vector3?), opts: any?): boolean
		local len = untilT - now()
		if len <= 0.01 then
			return not done
		end
		return Film.run(len, fn, opts) and not done
	end
	-- 1. low behind you: the giant ahead, reeling; you coil and vanish
	if not shot(TL.grab, function(k, t)
		local push = if now() > TL.dash then 3 * out((now() - TL.dash) / 0.15) else 0
		return cam(S + F * 6.2 + side * 2.4 - UP * 1.6 + D * push, Cs + UP * (H * 0.12), 20, 2)
	end, { hand = 0.3 }) then
		return finish()
	end
	-- 2. the reverse angle from its chest: your face, your fist in the foreground (checked in Studio: from your side the
	-- frame was the back of your head)
	if not shot(TL.drop, function(k)
		local head = A.root.Position + UP * 1.5
		local look = head + UP * 0.05
		local p = G + side * 1.6 + F * 0.2 + UP * 1.0
		p += (look - p).Unit * (k * 0.3)
		return cam(p, look, 26, -5, head, view1)
	end, { cut = "smash", hand = 0.25 }) then
		return finish()
	end
	-- 3. from the ground, up: the throw (checked: from 5 studs its legs filled the frame; now you and it rising)
	local view3 = Film.view()
	if not shot(TL.leap, function()
		local foot = Vector3.new(Gg.X, gy, Gg.Z)
		local look = (Gg + UP * 1.0):Lerp(vc(), 0.45)
		return cam(foot + side * 10 + F * 9 + UP * 0.8, look, 18, -6, Gg, view3)
	end, { hand = 0.5 }) then
		return finish()
	end
	-- 4. in the air beside you both: the leap, the hang, the hammer coming
	if not shot(TL.hammer, function()
		local mid = A.root.Position:Lerp(vc(), 0.35)
		local push = clamp01((now() - TL.hang) / (TL.hammer - TL.hang)) * 3
		local p = mid + side * (H * 0.45 + 9 - push) + F * (H * 0.15) + UP * 1.0
		return cam(p, mid, 26, 3)
	end, { hand = 0.3 }) then
		return finish()
	end
	-- 5. wide from the ground: it comes down (following it more: it hung off the top of the frame)
	if not shot(TL.land, function()
		local look = vc():Lerp(Bc + UP * (depth * 0.5), 0.35)
		return cam(Bc + side * (H * 0.8 + 14) + F * (H * 0.5 + 6) + UP * 2.0, look, 22, 0)
	end, { hand = 0.4 }) then
		return finish()
	end
	-- 6. from above, in front of you on top of it: the pounding, its body under your fists (checked: from beside and
	-- behind you the frame was your back and the grass)
	local view6 = Film.view()
	if not shot(TL.wind, function()
		local look = Amount - UP * 1.4 + D * 0.4
		return cam(Amount + D * 4.5 + side * 3.6 + UP * 2.8, look, 28, -4, Amount, view6)
	end, { cut = "smash", hand = 0.9 }) then
		return finish()
	end
	-- 7. from above, past its head: the last one
	if not shot(TL.rise, function(k)
		local look = Amount - UP * 1.2 + D * 0.5
		return cam(Amount + D * 4.2 + UP * (4.4 - k * 0.6) - side * 1.2, look, 26, -10)
	end, { cut = "smash", hand = 0.5 }) then
		return finish()
	end
	-- 8. low in front: you hop off and walk at the lens; it bursts behind you
	local view8 = Film.view()
	shot(TL.done, function()
		local walked = math.max(0, now() - TL.walk) * A:stride()
		local look = A.root.Position + UP * 0.9
		return cam(Gf + F * (10 + walked * 0.85) + side * 1.6 - UP * 1.9, look, 30, 0, look, view8)
	end, { hand = 0.4 })
	finish()
end

-- Start it for this death (the first call; later calls get the same plan). nil: it doesn't play here.
function Finisher.boss(d: any, ctx: any?): any?
	local plan = Finisher.plan(d)
	if not plan then
		return nil
	end
	if plan.started then
		return plan
	end
	plan.started = true
	task.spawn(function()
		local ok, err = pcall(run, plan, ctx)
		if not ok then
			warn("[Finisher] " .. tostring(err))
			if plan.finish then
				pcall(plan.finish)
			end
			firePops(plan, plan.popAt or d.cf.Position)
		end
	end)
	return plan
end

-- Studio: play it on the boss that's out now (DevHook "boss" "fight" first), without killing it. `len`: seconds the
-- "server" gives it (a long one to step through it with the IntroTestSpeed attribute).
function Finisher.test(z: number?, len: number?)
	local v = BossView.get()
	if not v then
		return "no boss shown"
	end
	local d = { z = z or 1, at = workspace:GetServerTimeNow(), len = len or 7.4, cf = v.base }
	local plan = Finisher.boss(d, { z = z or 1 })
	return if plan then "playing" else "not played"
end
-- (Studio only: the test is started from outside the game's scripts by setting the Workspace attribute
-- FinisherTest = len; while a finisher plays, FinisherClock is its film time)
if game:GetService("RunService"):IsStudio() then
	workspace:GetAttributeChangedSignal("FinisherTest"):Connect(function()
		local len = workspace:GetAttribute("FinisherTest")
		if type(len) == "number" and len > 0 then
			workspace:SetAttribute("FinisherTest", nil)
			workspace:SetAttribute("FinisherResult", Finisher.test(nil, len))
		end
	end)
	game:GetService("RunService").Heartbeat:Connect(function()
		if Film.playing and Film.owner == STEP then
			workspace:SetAttribute("FinisherClock", Film.now())
		elseif workspace:GetAttribute("FinisherClock") ~= nil then
			workspace:SetAttribute("FinisherClock", nil)
		end
	end)
end

return Finisher
