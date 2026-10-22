-- VFX Forge bursts for the menu moments (client): a class card landing / bought (in the class room, round the
-- floating avatar), an egg hatching and a gem upgrade bought (round your character in the world).
-- Each burst is built the way VFX Forge reads one (ParticleEmitters with an EmitCount attribute under one anchor)
-- and played with Forge's emit module; plain Emit() when Forge isn't there. Counts go through VFXLib's Budget
-- (phones get fewer). Kept soft on purpose: LightEmission 0.6 at most, so nothing turns into a white neon blob.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VFX = require(ReplicatedStorage:WaitForChild("VFXLib"))

local MenuFX = {}

local player = Players.LocalPlayer
local Tex = VFX.Assets.Tex
local Budget = VFX.Budget

local function seq(...: number): NumberSequence
	local pts = { ... }
	local kps = {}
	for i = 1, #pts, 2 do
		table.insert(kps, NumberSequenceKeypoint.new(pts[i], pts[i + 1]))
	end
	return NumberSequence.new(kps)
end

local function emitter(parent: Instance, count: number, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0
	e.Enabled = false
	for k, v in props do
		(e :: any)[k] = v
	end
	e:SetAttribute("EmitCount", count)
	e.Parent = parent
	return e
end

export type Opts = {
	size: number?, -- 1 = a character-sized burst
	big: boolean?, -- a rare one: a rising column and more sparks
	flat: boolean?, -- the shock ring lies on the ground (false: it faces the camera, for the floating avatar)
}

-- One burst at `pos` in `color`. Returns nothing; the anchor cleans itself up.
function MenuFX.burst(pos: Vector3, color: Color3, opts: Opts?)
	local o = opts or {}
	local s = o.size or 1
	local light = Color3.new(1, 1, 1):Lerp(color, 0.35)
	local anchor = Instance.new("Part")
	anchor.Name = "MenuBurst"
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = CFrame.new(pos)
	local att = Instance.new("Attachment")
	att.Parent = anchor
	local list: { { e: ParticleEmitter, n: number } } = {}
	local function add(n: number, props: { [string]: any })
		local c = Budget.Count(n)
		table.insert(list, { e = emitter(att, c, props), n = c })
	end
	-- soft flash
	add(1, {
		Texture = Tex.Glow, Color = ColorSequence.new(color), LightEmission = 0.5,
		Size = seq(0, 1 * s, 1, 7 * s), Transparency = seq(0, 0.45, 1, 1), Lifetime = NumberRange.new(0.4), Speed = NumberRange.new(0),
	})
	-- shock ring
	add(1, {
		Texture = Tex.RingShock, Color = ColorSequence.new(light, color), LightEmission = 0.4,
		Orientation = if o.flat then Enum.ParticleOrientation.VelocityPerpendicular else Enum.ParticleOrientation.FacingCamera,
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01),
		Size = seq(0, 0.5 * s, 1, 9 * s), Transparency = seq(0, 0.2, 0.6, 0.5, 1, 1), Lifetime = NumberRange.new(0.55),
	})
	-- star sparks fountain
	add(if o.big then 26 else 16, {
		Texture = Tex.Star4, Color = ColorSequence.new(Color3.new(1, 1, 1), color), LightEmission = 0.6,
		Size = seq(0, 0.55 * s, 1, 0), Transparency = seq(0, 0, 0.7, 0.2, 1, 1), Lifetime = NumberRange.new(0.6, 1.1),
		Speed = NumberRange.new(9 * s, 16 * s), SpreadAngle = Vector2.new(60, 60), EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -18 * s, 0), Drag = 1.5, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-220, 220),
	})
	-- toon smoke puffs round the base (dropped on low-end phones)
	if not Budget.IsLow() then
		add(6, {
			Texture = Tex.SmokePuff4x4, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			Color = ColorSequence.new(Color3.new(1, 1, 1):Lerp(color, 0.2)), LightEmission = 0,
			Size = seq(0, 1.2 * s, 1, 2.6 * s), Transparency = seq(0, 0.25, 1, 1), Lifetime = NumberRange.new(0.6, 0.9),
			Speed = NumberRange.new(4 * s, 7 * s), SpreadAngle = Vector2.new(180, 15), EmissionDirection = Enum.NormalId.Top,
			Drag = 3, Rotation = NumberRange.new(0, 360),
		})
	end
	-- a rare one: a column of glow rising
	if o.big then
		add(10, {
			Texture = Tex.Glow, Color = ColorSequence.new(color, light), LightEmission = 0.5, Shape = Enum.ParticleEmitterShape.Cylinder,
			Size = seq(0, 1.4 * s, 1, 0.4 * s), Transparency = seq(0, 0.5, 1, 1), Lifetime = NumberRange.new(0.8, 1.2),
			Speed = NumberRange.new(10 * s, 16 * s), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(4, 4),
		})
	end
	anchor.Parent = workspace
	if not VFX.Forge.Emit(anchor) then
		for _, x in list do
			x.e:Emit(x.n)
		end
	end
	task.delay(2.5, function()
		anchor:Destroy()
	end)
end

-- A burst round your character, on the ground (an egg hatched, an upgrade bought).
function MenuFX.atCharacter(color: Color3, big: boolean?)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	MenuFX.burst(root.Position - Vector3.new(0, 2.6, 0), color, { size = 1.3, big = big, flat = true }) -- 1.3: daylight washes soft particles out
end

return MenuFX
