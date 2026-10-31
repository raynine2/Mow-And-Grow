-- First-person hands, like Chop A Forest's: your avatar's OWN arms (copies of its arm parts, with its skin and
-- shirt sleeves) held up from the bottom corners of the screen, holding the current tool. Each frame they're laid
-- out to where the hands should be (idle sway, walk bob, a swing on every hit, jabs with bare hands, a buzz for auto
-- tools). Only this client sees them.
-- Every avatar's arms are shrunk to the same thickness (bulky packages and scaled rigs would fill the screen), turned
-- knuckles-up, and the upper arm stretches back to the screen corner so there's never a floating stump. Brick
-- fists in the avatar's colours are the fallback for a rig without arms.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local State = require(script.Parent.State)
-- (28 Oct) keyframed swings (jabs, hooks, uppercuts, fidgets: client/ViewAnims) and the effect textures
local ViewAnims = require(script.Parent.ViewAnims)
-- (28 Oct) the auto tools' life in your hands: the mowers' rumble, push bob and jolt, the laser mower's hover, the
-- weed whacker's sweep and spinning head (client/AutoFeel)
local AutoFeel = require(script.Parent.AutoFeel)
local FxTex = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("FxTex"))
-- (28 Oct) your body's matching third-person swing on every one of these (what other players see): client/BodyAnims
require(script.Parent.BodyAnims)

local ViewModel = {}
local player = Players.LocalPlayer

local SKIN = Color3.fromRGB(204, 142, 105) -- until the avatar's colours are known
local WOOD = Color3.fromRGB(205, 160, 100)
local STEEL = Color3.fromRGB(205, 210, 220)
local DARK = Color3.fromRGB(45, 45, 55)

local root = Instance.new("Model")
root.Name = "ViewModel"

-- Proportions. The arm and tool pieces below are drawn at their old (big) size and shrunk by HAND / TOOL; the poses
-- are pulled toward the camera by DIST. A fist ends up ~13 degrees across: clearly there, never in the way, and
-- close enough that it doesn't dip into grass clumps and walls.
local HAND = 0.55
local TOOL = 0.62
local DIST = 0.66
local function scaled(cf: CFrame, k: number): CFrame
	return CFrame.new(cf.Position * k) * cf.Rotation
end

local function part(parent: Instance, size: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- An arm is a list of {part, offset from the hand's CFrame}. `role` says which avatar colour it takes:
-- "arm" (the forearm: LowerArm), "hand" (the fist: Hand), "shade" (finger creases: the hand a bit darker).
type Piece = { part: BasePart, offset: CFrame, role: string? }
local function shade(c: Color3, k: number): Color3
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end
-- `side` 1 = right, -1 = left (the thumb sits on the inside).
local function arm(side: number): { Piece }
	local pieces = {}
	local function add(size: Vector3, offset: CFrame, role: string)
		table.insert(pieces, { part = part(root, size * HAND, SKIN), offset = scaled(offset, HAND), role = role })
	end
	add(Vector3.new(1.35, 1.35, 3.2), CFrame.new(0, -0.05, 2.1), "arm") -- forearm back toward the camera
	add(Vector3.new(1.6, 1.5, 1.55), CFrame.new(0, 0, 0), "hand") -- the fist
	add(Vector3.new(1.62, 0.42, 0.5), CFrame.new(0, 0.4, -0.58), "shade") -- top row of knuckles
	add(Vector3.new(1.62, 0.42, 0.5), CFrame.new(0, -0.08, -0.62), "hand") -- curled fingers
	add(Vector3.new(1.62, 0.36, 0.45), CFrame.new(0, -0.5, -0.56), "shade") -- bottom row
	add(Vector3.new(0.5, 0.55, 1.05), CFrame.new(-0.78 * side, 0.15, -0.15), "hand") -- thumb
	add(Vector3.new(1.55, 1.55, 1.2), CFrame.new(0, -0.05, 4.2), "sleeve") -- the cuff of the sleeve
	add(Vector3.new(1.7, 1.7, 3), CFrame.new(0, -0.05, 6.3), "sleeve") -- the sleeve, out of view
	return pieces
end
local rightArm = arm(1)
local leftArm = arm(-1)

-- A soft light just in front of the camera, so the hands are lit the same everywhere (they're tiny and close,
-- and the world's light alone leaves them dark on their camera side).
local lamp = part(root, Vector3.new(0.2, 0.2, 0.2), Color3.new(1, 1, 1))
lamp.Name = "HandLight"
lamp.Transparency = 1
local handLight = Instance.new("PointLight")
handLight.Color = Color3.fromRGB(255, 240, 220)
handLight.Brightness = 1.4 -- (was 5: light sleeves and skin burned to flat white and filled the bottom of the screen)
handLight.Range = 4.5 -- reaches the hands, not the ground below them
handLight.Shadows = false
handLight.Parent = lamp

-- (28 Oct, brief: "a soft white smear on the fast frames") a soft streak behind a fist that moves fast: a Beam from
-- where the fist was a moment ago (kept relative to the camera, so turning doesn't stretch it) to where it is now
type Smear = { beam: Beam, a0: Attachment, a1: Attachment, hist: { { rel: Vector3, t: number } } }
local smears: { [string]: Smear } = {}
for _, side in { "R", "L" } do
	local a0 = Instance.new("Attachment")
	a0.Name = "Smear" .. side .. "Tail"
	a0.Parent = lamp
	local a1 = Instance.new("Attachment")
	a1.Name = "Smear" .. side .. "Head"
	a1.Parent = lamp
	local b = Instance.new("Beam")
	b.Name = "Smear" .. side
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Texture = FxTex.smear
	b.TextureMode = Enum.TextureMode.Stretch
	b.FaceCamera = true
	b.Segments = 1
	b.Width0 = 0.1
	b.Width1 = 0.5
	b.LightEmission = 0.25
	b.LightInfluence = 0
	b.Color = ColorSequence.new(Color3.fromRGB(255, 252, 244))
	b.Enabled = false
	b.Parent = lamp
	smears[side] = { beam = b, a0 = a0, a1 = a1, hist = {} }
end

local function smear(side: string, pos: Vector3, cam: Camera, on: boolean)
	local s = smears[side]
	local now = os.clock()
	local rel = cam.CFrame:PointToObjectSpace(pos)
	table.insert(s.hist, 1, { rel = rel, t = now })
	if #s.hist > 8 then
		table.remove(s.hist)
	end
	-- where the fist was ~40 ms ago
	local tail = s.hist[#s.hist]
	for _, h in s.hist do
		if now - h.t >= 0.04 then
			tail = h
			break
		end
	end
	local dist = (rel - tail.rel).Magnitude
	local speed = dist / math.max(1e-3, now - tail.t)
	if not on or speed < 10 or dist < 0.3 then
		s.beam.Enabled = false
		return
	end
	local k = math.clamp((speed - 10) / 16, 0, 1)
	s.a0.WorldPosition = cam.CFrame:PointToWorldSpace(tail.rel)
	s.a1.WorldPosition = pos
	s.beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.6, 1 - 0.45 * k),
		NumberSequenceKeypoint.new(1, 1 - 0.6 * k),
	})
	s.beam.Enabled = true
end

-- (28 Oct, brief: the sickle's "thin silver crescent trail that fades fast") the arc a blade's edge sweeps through
-- while it strikes (client/ViewAnims' trail window): a chain of camera-facing beams (FxTex.trail, a thin bright core
-- in a soft halo) through the edge's last spots, kept relative to the camera so turning or walking never smears it,
-- thinning and fading as each spot ages. Each beam bends toward its neighbours (Catmull-Rom as Bezier), so even a
-- fast swing at 60 fps draws a smooth crescent. `at`: the edge, in the tool's own units from its grip.
-- (`atModel`: the same spot on the uploaded tool model, in its own pivot's space: its sickle's blade curls up out of
-- the handle, the brick fallback's lies flat)
type TrailDef = { at: Vector3, atModel: Vector3, width: number, life: number, color: Color3 }
local TRAIL: { [string]: TrailDef } = {
	Sickle = { at = Vector3.new(-1.0, 0.1, -3.35), atModel = Vector3.new(0, 0.85, -1.5), width = 0.32, life = 0.13, color = Color3.fromRGB(228, 238, 255) },
	-- the scythe's blade high over the shaft: a wide lavender sweep that lingers a little longer
	-- (30 Oct: the blade sweeps back from the end of the shaft, server/PartModels/tool_scythe; its inner edge's middle)
	-- (31 Oct: the ForgeGUI scythe, server/Models FORGE_TOOLS: the middle of its crystal blade, template (0, 4.3, -3.8)
	-- at TOOL scale)
	MegaScythe = { at = Vector3.new(-1.5, 0.2, -5.5), atModel = Vector3.new(0, 2.65, -2.35), width = 0.75, life = 0.2, color = Color3.fromRGB(210, 170, 255) },
}
local TRAIL_N = 10 -- spots kept (a beam between each pair)
local trailSpots: { { rel: Vector3, t: number } } = {}
local trailLastEdge = -10 -- when the blade's edge was last given (a new strike starts its own trail)
local trailAtt: { Attachment } = {}
local trailBeam: { Beam } = {}
for i = 1, TRAIL_N do
	local a = Instance.new("Attachment")
	a.Name = "TrailSpot" .. i
	a.Parent = lamp
	trailAtt[i] = a
end
for i = 1, TRAIL_N - 1 do
	local b = Instance.new("Beam")
	b.Name = "Trail" .. i
	b.Attachment0 = trailAtt[i]
	b.Attachment1 = trailAtt[i + 1]
	b.Texture = FxTex.trail
	b.TextureMode = Enum.TextureMode.Stretch
	b.FaceCamera = true
	b.Segments = 8
	b.LightEmission = 1
	b.LightInfluence = 0
	b.Brightness = 1.3
	b.Enabled = false
	b.Parent = lamp
	trailBeam[i] = b
end

local function clearTrail()
	table.clear(trailSpots)
	for _, b in trailBeam do
		b.Enabled = false
	end
end

-- `edge`: where the blade's edge is now (nil when it isn't striking: the trail just fades)
local function swingTrail(cam: Camera, edge: Vector3?, def: TrailDef?)
	if not def then
		if #trailSpots > 0 then
			clearTrail()
		end
		return
	end
	local now = os.clock()
	if edge then
		local rel = cam.CFrame:PointToObjectSpace(edge)
		-- a new strike starts its own trail, never joined onto the tail of the last one
		if now - trailLastEdge > 0.1 then
			table.clear(trailSpots)
		end
		trailLastEdge = now
		-- a new spot only once the edge has moved (on a hit-stop the trail just fades)
		local last = trailSpots[1]
		if not last or (last.rel - rel).Magnitude > 0.02 then
			table.insert(trailSpots, 1, { rel = rel, t = now })
		end
	end
	for i = #trailSpots, 1, -1 do
		if i > TRAIL_N or now - trailSpots[i].t > def.life then
			table.remove(trailSpots, i)
		end
	end
	local n = #trailSpots
	for i, b in trailBeam do
		b.Enabled = i < n
	end
	if n < 2 then
		return
	end
	local pos = table.create(n)
	for i = 1, n do
		pos[i] = cam.CFrame:PointToWorldSpace(trailSpots[i].rel)
	end
	-- each spot's tangent runs from the newer spot toward the older one (the way the beams run); a beam's control
	-- points sit a third of the tangent out from its ends (CurveSize0 along Attachment0's X, CurveSize1 back along
	-- Attachment1's X)
	local len = table.create(n)
	for i = 1, n do
		local a, c = pos[math.max(1, i - 1)], pos[math.min(n, i + 1)]
		local m = (c - a) * (if i > 1 and i < n then 0.5 else 1)
		len[i] = m.Magnitude
		local dir = if len[i] > 1e-4 then m.Unit else cam.CFrame.RightVector
		local up = dir:Cross(cam.CFrame.LookVector)
		up = if up.Magnitude > 1e-4 then up.Unit else cam.CFrame.UpVector
		trailAtt[i].WorldCFrame = CFrame.fromMatrix(pos[i], dir, up)
	end
	local life = def.life
	local function fade(t: number): number
		return 0.12 + 0.88 * math.clamp((now - t) / life, 0, 1) ^ 1.3
	end
	local function thick(t: number): number
		return def.width * (1 - math.clamp((now - t) / life, 0, 1)) ^ 0.8
	end
	local color = ColorSequence.new(def.color)
	for i = 1, n - 1 do
		local b = trailBeam[i]
		local t0, t1 = trailSpots[i].t, trailSpots[i + 1].t
		b.CurveSize0 = len[i] / 3
		b.CurveSize1 = len[i + 1] / 3
		b.Width0 = thick(t0)
		b.Width1 = thick(t1)
		b.Transparency = NumberSequence.new(fade(t0), fade(t1))
		b.Color = color
	end
end

-- The avatar's own colours: R15 hands / lower arms, R6 arms, else Body Colors.
local function avatarColors(char: Model): (Color3?, Color3?, Color3?)
	local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	local lower = char:FindFirstChild("RightLowerArm") or hand
	-- the sleeve: the torso's colour when it differs from the skin and there's no shirt texture over it (a shirt's
	-- colours can't be read, so a shirt gets a friendly blue)
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	local shirt = if torso and torso:IsA("BasePart") and not char:FindFirstChildOfClass("Shirt") then torso.Color else nil
	if shirt and hand and hand:IsA("BasePart") and shirt == hand.Color then
		shirt = nil
	end
	if hand and hand:IsA("BasePart") and lower and lower:IsA("BasePart") then
		return hand.Color, lower.Color, shirt
	end
	local bc = char:FindFirstChildOfClass("BodyColors")
	if bc then
		return bc.RightArmColor3, bc.RightArmColor3, nil
	end
	return nil, nil, nil
end

local lastSkin: Color3? = nil
local function paintArms(handColor: Color3, armColor: Color3, sleeveColor: Color3?)
	local sleeve = sleeveColor or Color3.fromRGB(70, 130, 220)
	for _, pieces in { rightArm, leftArm } do
		for _, pc in pieces do
			pc.part.Color = if pc.role == "sleeve" then sleeve
				elseif pc.role == "arm" then armColor
				elseif pc.role == "shade" then shade(handColor, 0.88)
				else handColor
		end
	end
end

-- The avatar's look loads after the character spawns (and can change), so check its colours now and then.
task.spawn(function()
	while true do
		local char = player.Character
		if char then
			local handColor, armColor, sleeveColor = avatarColors(char)
			if handColor and armColor and handColor ~= lastSkin then
				lastSkin = handColor
				paintArms(handColor, armColor, sleeveColor)
			end
		end
		task.wait(1)
	end
end)

-- tool models, keyed by tool id; offsets are from the right hand
local tools: { [string]: { Piece } } = {}
local function tool(id: string, build: (add: (Vector3, CFrame, Color3, Enum.Material?) -> Part) -> ())
	local pieces = {}
	build(function(size, offset, color, material)
		local p = part(root, size * TOOL, color, material)
		table.insert(pieces, { part = p, offset = scaled(offset, TOOL) })
		return p
	end)
	tools[id] = pieces
end
-- (28 Oct, brief: "blades visibly open and close") the garden shears in two halves that pivot on the bolt, built
-- like the Blender model (red grips with black caps, grey blades with a lighter cutting edge): client/ViewAnims'
-- T channel opens and shuts them. Laid out in the shears' own frame (blades along -Z, opening about +Y); the frame
-- itself is rolled in the hand (SCISSOR_ROLL) so the blades open on a slant you can see.
local SCISSOR_PIVOT = CFrame.new(0, 0, -0.85)
local SCISSOR_ROLL = CFrame.Angles(0, 0, math.rad(45)) -- (28 Oct) the blades' faces to the camera: at -40 they opened edge-on
tool("Scissors", function(add)
	local blade = Color3.fromRGB(150, 156, 168)
	local edge = Color3.fromRGB(212, 216, 226)
	local shank = Color3.fromRGB(82, 86, 96)
	local red = Color3.fromRGB(226, 52, 46)
	local black = Color3.fromRGB(38, 38, 44)
	local pv = SCISSOR_PIVOT.Position
	for _, h in { 1, -1 } do
		local y = 0.085 * h -- the two halves slide over each other
		local function half(size: Vector3, at: Vector3, color: Color3, material: Enum.Material?, turn: number?)
			local p = add(size, CFrame.new(pv + at) * CFrame.Angles(0, math.rad(turn or 0), 0), color, material)
			p:SetAttribute("Half", h)
		end
		half(Vector3.new(0.5, 0.16, 2.3), Vector3.new(0, y, -1.1), blade, Enum.Material.Metal) -- blade
		half(Vector3.new(0.16, 0.1, 2.15), Vector3.new(0.17 * h, y + 0.03 * h, -1.15), edge, Enum.Material.Metal) -- its cutting edge
		half(Vector3.new(0.34, 0.16, 0.34), Vector3.new(0, y, -2.3), blade, Enum.Material.Metal, 45) -- the point
		half(Vector3.new(0.26, 0.16, 0.6), Vector3.new(-0.1 * h, y, 0.3), shank, Enum.Material.Metal, -8 * h) -- shank
		half(Vector3.new(0.34, 0.34, 1.25), Vector3.new(-0.26 * h, y, 1.15), red, nil, -10 * h) -- grip
		half(Vector3.new(0.4, 0.4, 0.2), Vector3.new(-0.38 * h, y, 1.85), black, nil, -10 * h) -- end cap
	end
	local bolt = add(Vector3.new(0.38, 0.3, 0.3), SCISSOR_PIVOT * CFrame.Angles(0, 0, math.rad(90)), shank, Enum.Material.Metal)
	bolt.Shape = Enum.PartType.Cylinder
end)
tool("Sickle", function(add)
	add(Vector3.new(0.35, 0.35, 1.8), CFrame.new(0, 0, -0.6), WOOD, Enum.Material.Wood)
	add(Vector3.new(0.15, 0.35, 1.5), CFrame.new(0, 0.1, -2.1), STEEL, Enum.Material.Metal)
	add(Vector3.new(0.15, 0.35, 1.4), CFrame.new(-0.55, 0.1, -3.0) * CFrame.Angles(0, math.rad(55), 0), STEEL, Enum.Material.Metal)
	add(Vector3.new(0.15, 0.35, 1.1), CFrame.new(-1.4, 0.1, -3.1) * CFrame.Angles(0, math.rad(115), 0), STEEL, Enum.Material.Metal)
end)
tool("PushMower", function(add)
	-- a push bar running down and away; the mower deck itself is on the ground in the world
	add(Vector3.new(3.2, 0.3, 0.3), CFrame.new(-1.2, 0, -0.2), Color3.fromRGB(255, 140, 30))
	add(Vector3.new(0.25, 0.25, 4), CFrame.new(0, -1, -2) * CFrame.Angles(math.rad(35), 0, 0), DARK)
	add(Vector3.new(0.25, 0.25, 4), CFrame.new(-2.4, -1, -2) * CFrame.Angles(math.rad(35), 0, 0), DARK)
end)
tool("WeedWhacker", function(add)
	add(Vector3.new(0.4, 0.4, 1.4), CFrame.new(0, 0, 0), Color3.fromRGB(60, 200, 80))
	add(Vector3.new(0.22, 0.22, 5), CFrame.new(0, -1.1, -2.8) * CFrame.Angles(math.rad(25), 0, 0), DARK)
	add(Vector3.new(1, 0.6, 1), CFrame.new(0, -2.2, -5.1), Color3.fromRGB(60, 200, 80))
	local line = add(Vector3.new(2.6, 0.08, 0.12), CFrame.new(0, -2.55, -5.1), Color3.new(1, 1, 1))
	line:SetAttribute("Spin", true)
end)
tool("MegaScythe", function(add)
	add(Vector3.new(0.35, 0.35, 5), CFrame.new(0, 0, -1.8), Color3.fromRGB(80, 55, 100), Enum.Material.Wood)
	add(Vector3.new(0.18, 0.6, 3.4), CFrame.new(-1.5, 0.2, -4.2) * CFrame.Angles(0, math.rad(80), 0), Color3.fromRGB(170, 110, 255), Enum.Material.Neon)
end)
tool("LaserMower", function(add)
	add(Vector3.new(3.2, 0.3, 0.3), CFrame.new(-1.2, 0, -0.2), Color3.fromRGB(60, 230, 255), Enum.Material.Neon)
	add(Vector3.new(0.25, 0.25, 4), CFrame.new(0, -1, -2) * CFrame.Angles(math.rad(35), 0, 0), DARK)
	add(Vector3.new(0.25, 0.25, 4), CFrame.new(-2.4, -1, -2) * CFrame.Angles(math.rad(35), 0, 0), DARK)
end)

-- Blender tool models (uploaded ones), held at their grip (their origin); working end points forward
-- (28 Oct: not the scissors any more: the uploaded model is one piece, so its blades can't open and shut; the shears
-- above are built like it and do)
local TOOL_MODEL = { Sickle = "tool_sickle", WeedWhacker = "tool_whacker", MegaScythe = "tool_scythe" }
-- (28 Oct) how far up the scythe's shaft its second grip is (the model's own units): the other fist holds it there
local SCYTHE_GRIP = 3.0 -- (30 Oct, Rivals: the left fist well up the snath, near the head; was 2.25)
-- (30 Oct) the scythe's rest grip, camera space (see the MegaScythe branch below): the right fist, the way the snath
-- runs from it toward the head, the way the blade stands out from the head, and the ways back from each fist to its
-- elbow (length 0..1: how strongly the forearm comes up from below rather than straight from the shoulder)
-- (30 Oct, owner: "I'm holding it like I'm looking at it instead of using it as a weapon": the snath ran across the
-- view and the blade stood up over it, face to you, like a trophy) now it's held ready, like Rivals' and every combat
-- game's: the snath points out ahead into the world, up and to the left past the crosshair (which stays clear), and
-- the blade hangs from the head out to the left and down toward the grass, edge in, ready to reap
-- (30 Oct, owner: "copy the position and angle of the scythe in the arms ... study this video", Rivals' Bat Scythe /
-- Cryo Scythe, youtube.com/shorts/LEhSHMiq9cE) Rivals' rest, measured off the video frame by frame and solved for the
-- same angles from the eye: the right fist low right of the middle at the bottom of the view, the snath running out
-- from it to the left and away (rising ~25 deg on screen) through the left fist, the head out at the left of the view
-- and the blade coming back from it flat and level toward the middle, under the crosshair, edge forward
local HOLD_POS = Vector3.new(0.46, -1.6, -2.4)
local HOLD_DIR = Vector3.new(-0.837, 0.149, -0.526)
local HOLD_UP = Vector3.new(0.547, 0.204, -0.812)
local HOLD_BEND_R = Vector3.new(-0.3, -0.85, 0.25)
local HOLD_BEND_L = Vector3.new(-0.1, -0.9, 0.3)
local heldModel: Model? = nil
local heldId: string? = nil
local function modelFor(id: string?): Model?
	if id == heldId then
		return heldModel
	end
	if heldModel then
		heldModel:Destroy()
		heldModel = nil
	end
	heldId = id
	local folder = ReplicatedStorage:FindFirstChild("MowALawnModels")
	local template = folder and id and TOOL_MODEL[id] and folder:FindFirstChild(TOOL_MODEL[id])
	if template and template:IsA("Model") then
		local m = template:Clone()
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
				p.CastShadow = false
			end
		end
		m:ScaleTo(TOOL)
		m.Parent = root
		heldModel = m
	end
	return heldModel
end

-- (28 Oct, brief: "spinning head blur") the weed whacker's head: its line (the long thin white piece) whirls about
-- the head's axis and a soft disc blurs round it, so it reads as a spinning string. tool_whacker's head spins about
-- this axis (its own space).
local WHACK_AXIS = Vector3.new(0, 0.81, 0.59).Unit
local whack: { model: Model, line: BasePart, rel: CFrame, hub: Vector3, len: number }? = nil
local blur: Part? = nil
local function whackHead(m: Model?, t: number)
	if not m then
		if blur then
			blur.Transparency = 1
		end
		return
	end
	if not whack or whack.model ~= m then
		whack = nil
		local piv = m:GetPivot()
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") and p.Size.Y > p.Size.X * 10 and p.Color.R > 0.9 and p.Color.G > 0.9 and p.Color.B > 0.9 then
				whack = { model = m, line = p, rel = piv:ToObjectSpace(p.CFrame), hub = piv:PointToObjectSpace(p.Position), len = p.Size.Y }
			end
		end
		if not whack then
			return
		end
	end
	local w = whack :: any
	local piv = m:GetPivot()
	local axis = piv:VectorToWorldSpace(WHACK_AXIS)
	local hub = piv:PointToWorldSpace(w.hub)
	w.line.CFrame = CFrame.new(hub) * CFrame.fromAxisAngle(axis, AutoFeel.spin(t)) * CFrame.new(-hub) * piv * w.rel
	if not blur then
		local b = Instance.new("Part")
		b.Name = "WhackerBlur"
		b.Shape = Enum.PartType.Cylinder
		b.Anchored = true
		b.CanCollide = false
		b.CanQuery = false
		b.CanTouch = false
		b.CastShadow = false
		b.Material = Enum.Material.SmoothPlastic
		b.Color = Color3.fromRGB(232, 240, 224)
		b.Parent = root
		blur = b
	end
	local b = blur :: Part
	b.Size = Vector3.new(0.012, w.len * 1.02, w.len * 1.02)
	local side = axis:Cross(Vector3.yAxis)
	side = if side.Magnitude > 1e-3 then side.Unit else Vector3.xAxis
	-- (a cylinder's axis is its X: the disc lies in the line's plane, just behind it)
	b.CFrame = CFrame.fromMatrix(hub - axis * 0.01, axis, axis:Cross(side))
	b.Transparency = 0.8 + 0.03 * math.sin(t * 47)
end

-- First-person push mower: Roblox fades your whole character out in first person, mower included, so you'd push
-- thin air. Instead a local copy of the mower you're pushing (server/Tools puts it on the character) rides low in
-- front of the view, its push bar in your fists. Its grip (the top of the bar) is found from its shape, so the
-- Blender mower and the brick fallback both line up.
local PUSH_SCALE = 0.42
local PUSH_TILT = math.rad(38) -- nose tipped up a little, so you look down onto the deck
type PushCopy = { model: Model, src: Instance, grip: Vector3, width: number }
local push: PushCopy? = nil

local function pushCopyFor(char: Model): PushCopy?
	local src = char:FindFirstChild("PushMowerModel")
	if push and push.src == src and push.model.Parent then
		return push
	end
	if push then
		push.model:Destroy()
		push = nil
	end
	if not (src and src:IsA("Model")) then
		return nil
	end
	local was = src.Archivable
	src.Archivable = true
	local m = src:Clone()
	src.Archivable = was
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			d.LocalTransparencyModifier = 0
			d:SetAttribute("VT", d.Transparency)
		elseif d:IsA("Constraint") or d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	m:ScaleTo(m:GetScale() * (root:GetAttribute("PushScale") :: number? or PUSH_SCALE))
	-- the grip: the highest point of the mower (the top of its push bar), and how wide the bar is up there
	local piv = m:GetPivot()
	local corners: { Vector3 } = {}
	local topY = -math.huge
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and (d:GetAttribute("VT") :: number) < 1 then
			local h = d.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local c = piv:PointToObjectSpace(d.CFrame:PointToWorldSpace(Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)))
						table.insert(corners, c)
						topY = math.max(topY, c.Y)
					end
				end
			end
		end
	end
	local zSum, n, xMin, xMax = 0, 0, math.huge, -math.huge
	for _, c in corners do
		if c.Y > topY - 0.35 then
			zSum += c.Z
			n += 1
			xMin = math.min(xMin, c.X)
			xMax = math.max(xMax, c.X)
		end
	end
	if n == 0 then
		m:Destroy()
		return nil
	end
	m.Parent = root
	push = { model = m, src = src, grip = Vector3.new((xMin + xMax) / 2, topY - 0.12, zSum / n), width = math.max(0.6, xMax - xMin) }
	return push
end

local function showPush(p: PushCopy?, visible: boolean)
	if not p then
		return
	end
	for _, d in p.model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = if visible then (d:GetAttribute("VT") :: number? or 0) else 1
		end
	end
end

-- Blender gardening-glove hands (hand_right / hand_left), when uploaded, replace the brick arms. Their origin is
-- the grip in the fist, the same spot as the brick glove's centre. The server loads models after the client
-- starts, so keep looking until they're there.
local function handModel(name: string): Model?
	local folder = ReplicatedStorage:FindFirstChild("MowALawnModels")
	local template = folder and folder:FindFirstChild(name)
	if not (template and template:IsA("Model")) then
		return nil
	end
	local m = template:Clone()
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
		end
	end
	m.Parent = root
	return m
end
-- (the Blender glove models aren't used any more: the fists are the avatar's own colours, like Chop A Forest)
local handR: Model? = nil
local handL: Model? = nil
local _ = handModel

-------------------------------------------------------------------------------------------------------------
-- the real arms
-------------------------------------------------------------------------------------------------------------
-- Avatars now use physics joints (AnimationConstraint) whose C0 can't be set, and a joint aimed from here would
-- lag a frame behind the camera. So, like most first-person games, we copy the avatar's own arm parts (meshes,
-- skin colour, shirt) into a little model with a Humanoid (so the shirt still draws on them) and place the copies
-- in front of the camera every frame. The real arms stay hidden by Roblox's first-person fade as usual.
type ArmSet = { model: Model, right: { BasePart }, left: { BasePart }, char: Model, size: { [BasePart]: Vector3 } }
local arms: ArmSet? = nil
local nextArmBuild = 0
-- where the shoulders sit relative to the camera: low and a little behind, so the arms come up from the corners
-- (Chop A Forest's arms are chunky and close: they fill the bottom corners and the fists sit low, near the middle)
-- (owner, 28 Oct: "the hands dont cover the screen as much" in Chop A Forest: the shoulders sit far behind the
-- fists now, so the arms run straight back out of view and only the fists show, low and wide; was (1.75, -2.7, 0.2))
local SHOULDER_R = Vector3.new(2.5, -3.0, 2.5)
local SHOULDER_L = Vector3.new(-2.5, -3.0, 2.5)
local ARM_WIDTH = 0.7 -- how thick the arms are in view (studs, at ~2.4 studs away; was 0.82, a bit much on screen)
local KEEP = { SpecialMesh = true, SurfaceAppearance = true, Decal = true, Texture = true }

local function copyPart(src: Instance): BasePart?
	if not src:IsA("BasePart") then
		return nil
	end
	local was = src.Archivable
	src.Archivable = true
	local p = src:Clone()
	src.Archivable = was
	for _, d in p:GetChildren() do
		if not KEEP[d.ClassName] then
			d:Destroy()
		end
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Transparency = 1
	p.LocalTransparencyModifier = 0
	return p
end

local function buildArms(char: Model): ArmSet?
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return nil
	end
	local r15 = hum.RigType == Enum.HumanoidRigType.R15
	local model = Instance.new("Model")
	model.Name = "Arms"
	local h = Instance.new("Humanoid")
	h.RigType = hum.RigType
	h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	h.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	h.BreakJointsOnDeath = false
	h.EvaluateStateMachine = false
	h.Parent = model
	local shirt = char:FindFirstChildOfClass("Shirt")
	if shirt then
		shirt:Clone().Parent = model
	end
	local set: ArmSet = { model = model, right = {}, left = {}, char = char, size = {} }
	for _, side in { "Right", "Left" } do
		local list = if side == "Right" then set.right else set.left
		local names = if r15 then { side .. "UpperArm", side .. "LowerArm", side .. "Hand" } else { side .. " Arm" }
		for _, n in names do
			local src = char:FindFirstChild(n)
			local part = src and copyPart(src)
			if not part then
				model:Destroy()
				return nil
			end
			part.Parent = model
			table.insert(list, part)
		end
	end
	-- the same thickness for every avatar: the forearm (R15) or arm (R6) ARM_WIDTH studs across
	local ref = set.right[math.min(2, #set.right)]
	local k = ARM_WIDTH / math.max(0.2, math.min(ref.Size.X, ref.Size.Z))
	for _, list in { set.right, set.left } do
		for _, part in list do
			part.Size *= k
			for _, d in part:GetChildren() do
				if d:IsA("SpecialMesh") then
					d.Scale *= k
				end
			end
			set.size[part] = part.Size
		end
	end
	model.Parent = root
	return set
end

-- The arm copies for the current character (rebuilt when it changes or its look finishes loading).
local function armsFor(char: Model): ArmSet?
	local a = arms
	if a and a.char == char and a.model.Parent then
		return a
	end
	if a then
		a.model:Destroy()
		arms = nil
	end
	if os.clock() < nextArmBuild then
		return nil
	end
	nextArmBuild = os.clock() + 1
	arms = buildArms(char)
	return arms
end

player.CharacterAppearanceLoaded:Connect(function()
	if arms then
		arms.model:Destroy()
		arms = nil
	end
	nextArmBuild = 0
end)

-- Lay one arm out: the hand's centre on `target`, the forearm behind it, and the upper arm (or R6's one-piece arm)
-- stretched back to the shoulder point off the screen's corner. Knuckles up, the fists rolled a little inward.
local function poseArm(set: ArmSet, parts: { BasePart }, shoulder: Vector3, target: Vector3, cam: Camera, side: number, bend: Vector3?, roll: number?)
	local toward = target - shoulder
	local d = if toward.Magnitude > 0.01 then toward.Unit else cam.CFrame.LookVector
	-- (28 Oct) an elbow: with a `bend` (client/ViewAnims, world space: the way from the fist back to the elbow; its
	-- length 0..1 is how much it wins over the straight arm) the forearm and fist run along it and the upper arm
	-- bridges back to the shoulder: a hook's level forearm, an uppercut's upright one. `roll` turns the fist.
	local n = #parts
	local fore = d
	if bend and n > 1 then
		local w = math.min(1, bend.Magnitude)
		if w > 1e-3 then
			local f = d * (1 - w) - bend.Unit * w
			fore = if f.Magnitude > 1e-3 then f.Unit else d
		end
	end
	local function axes(dir: Vector3, extra: number): (Vector3, Vector3)
		local up = cam.CFrame.UpVector
		up -= dir * up:Dot(dir)
		if up.Magnitude < 0.01 then
			up = dir:Cross(cam.CFrame.RightVector)
		end
		up = CFrame.fromAxisAngle(dir, math.rad(-22) * side + extra):VectorToWorldSpace(up.Unit)
		local yAxis = -dir -- each part's top points back toward the shoulder
		return yAxis:Cross(up), yAxis -- and its back (+Z) points up: knuckles up
	end
	local edge = target -- the front end of the next part to place
	for i = n, 1, -1 do
		local part = parts[i]
		local base = set.size[part] or part.Size
		local len = base.Y
		local dir = fore
		if i == 1 and n > 1 then
			-- the upper arm: from the elbow back to the shoulder point off the screen's corner, stretched to reach it
			local back = edge - shoulder
			dir = if back.Magnitude > 0.01 then back.Unit else d
			len = math.max(base.Y, back.Magnitude + 0.3)
			if part.Size.Y ~= len then
				part.Size = Vector3.new(base.X, len, base.Z)
			end
		elseif i == 1 then
			-- reach all the way back to the shoulder, so the arm runs off the screen
			len = math.max(base.Y, (edge - shoulder):Dot(d) + 0.3)
			if part.Size.Y ~= len then
				part.Size = Vector3.new(base.X, len, base.Z)
			end
		end
		local centre
		if i == n and n > 1 then
			centre = target -- the hand
		elseif n == 1 then
			centre = target - d * (len / 2 - base.X * 0.5) -- R6: the arm's end is the fist
		else
			centre = edge - dir * (len / 2) * 0.92
		end
		local xAxis, yAxis = axes(dir, if i == 1 and n > 1 then 0 else (roll or 0))
		part.CFrame = CFrame.fromMatrix(centre, xAxis, yAxis)
		if part.Transparency ~= 0 then
			part.Transparency = 0
		end
		edge = centre - dir * (len / 2)
	end
end

-- where the hands rest, relative to the camera
-- fists a little further off and tipped up, so you see the knuckles and the forearms run down to the screen's
-- bottom corners (like Chop A Forest), not the flat tops of the forearms
-- (with the real arms only the position matters: the arm points from the shoulder at it)
-- (28 Oct: lower and wider, at the bottom of the screen like Chop A Forest's, so the middle of the view stays clear;
-- was (1.2, -1.6, -3.6) / (-1.25, -1.65, -3.65))
local REST_R = scaled(CFrame.new(2.15, -2.3, -3.3) * CFrame.Angles(math.rad(24), math.rad(14), 0), DIST)
local REST_L = scaled(CFrame.new(-2.2, -2.35, -3.35) * CFrame.Angles(math.rad(20), math.rad(-14), 0), DIST)
local PUSH_R = scaled(CFrame.new(1.25, -1.7, -2.6) * CFrame.Angles(math.rad(-25), 0, 0), DIST)
local PUSH_L = scaled(CFrame.new(-1.25, -1.7, -2.6) * CFrame.Angles(math.rad(-25), 0, 0), DIST)
local TWO_HANDED = { PushMower = true, LaserMower = true, WeedWhacker = true, MegaScythe = true }

local stepPhase = 0
local swayYaw, swayPitch = 0, 0
local lastCamRot: CFrame? = nil
local lastFrame: number? = nil

local swingStart = -10
local SWING_TIME = 0.32
local punchSide = 1 -- bare hands alternate: 1 = right, -1 = left
State.on("swing", function()
	-- (28 Oct) a tool with keyframed swings plays the next clip of its combo (client/ViewAnims)
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	if ViewAnims.swing(tool and tool:GetAttribute("ToolId") :: string?) then
		return
	end
	swingStart = os.clock()
	punchSide = -punchSide
end)
-- Hit-stop: the swing freezes for a few frames on contact, which sells the weight of the blow.
local frozenUntil = 0
local recoilAt = -10
State.on("hitstop", function(duration: number)
	local now = os.clock()
	frozenUntil = now + duration
	swingStart += duration -- resume exactly where it stopped
	recoilAt = now + duration -- then the hand bounces back off the clump
end)

-- After a hit lands: the hand knocks back toward you and up a little, then springs back (a damped spring).
local function recoilOffset(now: number): CFrame
	local u = now - recoilAt
	if u < 0 or u > 0.45 then
		return CFrame.new()
	end
	local r = math.exp(-u * 10) * math.cos(u * 20)
	return CFrame.new(0, 0.1 * r, 0.5 * r) * CFrame.Angles(math.rad(12 * r), 0, 0)
end

-- A jab: cock the fist back, whip it forward (speeding up into the hit), a corkscrew turn of the wrist as it
-- lands just past the target, settle, hold, come back. `side` mirrors it for the left hand. Contact is at
-- t = 0.34 (HitFx's STRIKE_DELAY / SWING_TIME).
local function punchOffset(t: number, side: number): CFrame
	local wind = CFrame.new(0.2 * side, -0.2, 0.6) * CFrame.Angles(math.rad(-18), math.rad(-8 * side), math.rad(8 * side))
	local over = CFrame.new(-0.68 * side, 0.45, -2.05) * CFrame.Angles(math.rad(12), math.rad(14 * side), math.rad(-26 * side))
	local strike = CFrame.new(-0.6 * side, 0.4, -1.8) * CFrame.Angles(math.rad(10), math.rad(12 * side), math.rad(-20 * side))
	if t < 0.16 then
		local k = t / 0.16
		return CFrame.new():Lerp(wind, 1 - (1 - k) * (1 - k))
	elseif t < 0.34 then
		local k = (t - 0.16) / 0.18
		return wind:Lerp(over, k * k)
	elseif t < 0.44 then
		local k = (t - 0.34) / 0.1
		return over:Lerp(strike, 1 - (1 - k) * (1 - k))
	elseif t < 0.52 then
		return strike
	end
	local k = (t - 0.52) / 0.48
	return strike:Lerp(CFrame.new(), k * k * (3 - 2 * k))
end

-- The other fist while one punches: drawn in and down a touch (the body turning into the punch).
local function guardOffset(t: number, side: number): CFrame
	local e = math.sin(math.pi * math.clamp(t, 0, 1))
	return CFrame.new(0.08 * side * e, -0.06 * e, 0.3 * e) * CFrame.Angles(math.rad(-8 * e), 0, 0)
end

local function equippedId(): string?
	local char = player.Character
	local t = char and char:FindFirstChildOfClass("Tool")
	return t and t:GetAttribute("ToolId") :: string?
end

local function inFirstPerson(): boolean
	local char = player.Character
	local head = char and char:FindFirstChild("Head") :: BasePart?
	local cam = workspace.CurrentCamera
	if not head or not cam then
		return false
	end
	return (cam.CFrame.Position - head.Position).Magnitude < 2
end

-- (29 Oct, phones: this runs every frame) Each model's parts, listed once (tools and view models don't change), and
-- Transparency written only when it changes: writing it every frame on every part cost hundreds of property sets.
local partLists: { [Instance]: { BasePart } } = setmetatable({}, { __mode = "k" }) :: any
local function partsOf(inst: Instance): { BasePart }
	local list = partLists[inst]
	if not list then
		list = {}
		for _, d in inst:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(list, d)
			end
		end
		partLists[inst] = list
		-- (a part added later, a tool's model dressing it after it arrives: list again)
		local c: RBXScriptConnection
		c = inst.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") then
				partLists[inst] = nil
				c:Disconnect()
			end
		end)
	end
	return list
end
local function vis(p: BasePart, v: number)
	if p.Transparency ~= v then
		p.Transparency = v
	end
end
local pieceAttr: { [BasePart]: { half: number?, spin: boolean } } = setmetatable({}, { __mode = "k" }) :: any
local function attrsOf(p: BasePart): { half: number?, spin: boolean }
	local a = pieceAttr[p]
	if not a then
		a = { half = p:GetAttribute("Half") :: number?, spin = p:GetAttribute("Spin") ~= nil and p:GetAttribute("Spin") ~= false }
		pieceAttr[p] = a
	end
	return a
end

local function hideAll()
	handLight.Enabled = false
	for _, sm in smears do
		sm.beam.Enabled = false
	end
	clearTrail()
	for _, p in root:GetDescendants() do
		if p:IsA("BasePart") then
			p.Transparency = 1
		end
	end
	if push then
		push.model:Destroy()
		push = nil
	end
end

local function place(pieces: { Piece }, base: CFrame)
	for _, pc in pieces do
		pc.part.CFrame = base * pc.offset
		vis(pc.part, 0)
	end
end

local function placeHand(model: Model?, pieces: { Piece }, cf: CFrame)
	if not model then
		place(pieces, cf)
		return
	end
	for _, pc in pieces do
		vis(pc.part, 1)
	end
	model:PivotTo(cf)
	for _, p in partsOf(model) do
		vis(p, 0)
	end
end

-- (28 Oct) ViewAnims poses as CFrames: the body turns about the shoulders' pivot (behind and below the camera); a
-- hand's offset is in camera axes on top of its rest spot, its turn on top of the rest turn
local PIVOT = Vector3.new(0, -1.6, 0.6)
local function bodyCf(p: ViewAnims.Pose): CFrame
	return CFrame.new(PIVOT + p.p * DIST) * CFrame.Angles(math.rad(p.r.X), math.rad(p.r.Y), math.rad(p.r.Z)) * CFrame.new(-PIVOT)
end
local function handCf(rest: CFrame, p: ViewAnims.Pose): CFrame
	return CFrame.new(rest.Position + p.p * DIST) * rest.Rotation * CFrame.Angles(math.rad(p.r.X), math.rad(p.r.Y), math.rad(p.r.Z))
end

-- swing curve, like Chop A Forest's: cock the tool high on the right, then whip it down and right across the
-- screen to the lower left (speeding up into the hit at t = 0.34, HitFx's STRIKE_DELAY / SWING_TIME), hang there a
-- beat, and come back.
local SWING_WIND = CFrame.new(0.55, 0.85, 0.45) * CFrame.Angles(math.rad(48), math.rad(-14), math.rad(18))
local SWING_HIT = CFrame.new(-1.15, -0.55, -0.7) * CFrame.Angles(math.rad(-58), math.rad(30), math.rad(-34))
local SWING_END = CFrame.new(-1.6, -0.95, -0.55) * CFrame.Angles(math.rad(-72), math.rad(38), math.rad(-42))
local function swingOffset(t: number): CFrame
	if t < 0.2 then
		local k = t / 0.2
		return CFrame.new():Lerp(SWING_WIND, 1 - (1 - k) * (1 - k))
	elseif t < 0.34 then
		local k = (t - 0.2) / 0.14
		return SWING_WIND:Lerp(SWING_HIT, k * k)
	elseif t < 0.46 then
		local k = (t - 0.34) / 0.12
		return SWING_HIT:Lerp(SWING_END, 1 - (1 - k) * (1 - k))
	end
	local k = (t - 0.46) / 0.54
	return SWING_END:Lerp(CFrame.new(), k * k * (3 - 2 * k))
end

-- The server-side tool in our own hand: hidden in first person (it would poke through the camera), shown in third.
-- Only the character's Tools are walked, not the whole character.
-- (31 Oct, owner: "when i hit there are random white things above me") the real tool's own swing trail
-- (server/Tools ReapTrail) has no LocalTransparencyModifier, so it swept round your head in first person: hidden with
-- the tool (this client only; the first-person trail above draws the swing)
local trailOf: { [Tool]: Trail | false } = setmetatable({}, { __mode = "k" }) :: any
local trailLook: { [Trail]: NumberSequence } = setmetatable({}, { __mode = "k" }) :: any
local trailHid: { [Trail]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local HIDDEN_TRAIL = NumberSequence.new(1)
local function realTools(char: Model, modifier: number)
	for _, tool in char:GetChildren() do
		if tool:IsA("Tool") then
			for _, d in partsOf(tool) do
				if d.LocalTransparencyModifier ~= modifier then
					d.LocalTransparencyModifier = modifier
				end
			end
			local trail = trailOf[tool]
			if trail == nil then
				local t = tool:FindFirstChild("ReapTrail", true)
				trail = if t and t:IsA("Trail") then t else false
				trailOf[tool] = trail
			end
			if trail then
				if not trailLook[trail] then
					trailLook[trail] = trail.Transparency
				end
				local hide = modifier >= 1
				if trailHid[trail] ~= hide then
					trailHid[trail] = hide
					trail.Transparency = if hide then HIDDEN_TRAIL else trailLook[trail]
				end
			end
		end
	end
end

-- (29 Oct, bug hunt) The boss guns had no first-person model: the real gun is hidden in first person (realTools),
-- so you shot the boss with empty fists. Now a copy of the gun you hold sits in your hands (the other hand under it)
-- and kicks back on every shot.
local gunCopy: Model? = nil
local gunFor: Tool? = nil
local gunKickAt = -10
local gunLong = false
local GUN_R = scaled(CFrame.new(1.55, -1.95, -3.1) * CFrame.Angles(math.rad(3), math.rad(5), 0), DIST)
State.on("Shoot", function()
	gunKickAt = os.clock()
	ViewAnims.cancelInspect() -- (a shot cuts an inspect short)
end)
local function gunModel(tool: Tool?): Model?
	if tool == gunFor and (not gunCopy or gunCopy.Parent) then
		return gunCopy
	end
	if gunCopy then
		gunCopy:Destroy()
		gunCopy = nil
	end
	gunFor = tool
	local handle = tool and tool:FindFirstChild("Handle")
	if not tool or not handle or not handle:IsA("BasePart") then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = "GunCopy"
	local length = 0
	for _, d in tool:GetDescendants() do
		if d:IsA("BasePart") then
			local c = d:Clone()
			for _, x in c:GetChildren() do
				if not (x:IsA("DataModelMesh") or x:IsA("Decal") or x:IsA("Texture")) then
					x:Destroy()
				end
			end
			c.Anchored = true
			c.CanCollide = false
			c.CanQuery = false
			c.CanTouch = false
			c.CastShadow = false
			c.LocalTransparencyModifier = 0
			c.CFrame = d.CFrame
			c.Parent = m
			if d == handle then
				m.PrimaryPart = c
			end
			length = math.max(length, -handle.CFrame:PointToObjectSpace(d.Position).Z + d.Size.Z / 2)
		end
	end
	gunLong = length > 2
	m:ScaleTo(TOOL)
	m.Parent = root
	gunCopy = m
	return m
end

local thirdPerson = false
local inspectTool: string? = nil -- (29 Oct) the item an inspect started on: switching away cancels it
-- (30 Oct) the draw (see the RenderStepped below): the item in hand last frame, when it came out, how long it takes
local drawnId: string? = nil
local drawStart = -10
local DRAW_TIME = 0.34
local DRAW_SOUND: { [string]: string } = { Hands = "swingHand", Scissors = "swingBlade", Sickle = "swingBlade", MegaScythe = "swingBlade" }
local SoundMod: any = nil
-- 0 -> 1 with a small overshoot (about 8 %) before it settles: the snap of a quick draw
local function drawEase(x: number): number
	local c1, c3 = 1.2, 2.2
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end
RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not cam or not hum or hum.Health <= 0 or hum.SeatPart or not inFirstPerson() then
		-- (29 Oct) no first-person view (on a mower, third person): no inspect either
		-- (30 Oct) except the Mega Scythe's, which your character plays in third person too (client/RiderPose): its
		-- animation clock keeps running here
		local tpId = if hum and hum.Health > 0 and not hum.SeatPart then equippedId() else nil
		if tpId == "MegaScythe" then
			local now = os.clock()
			ViewAnims.update(math.min(0.1, now - (lastFrame or now)), tpId, false)
			lastFrame = now
			if ViewAnims.inspecting() then
				if inspectTool ~= nil and inspectTool ~= tpId then
					ViewAnims.cancelInspect()
				end
				inspectTool = inspectTool or tpId
			else
				inspectTool = nil
			end
		elseif inspectTool then
			inspectTool = nil
			ViewAnims.cancelInspect()
		end
		-- hide the first-person hands once, not every frame (that walked every view model each frame)
		if not thirdPerson then
			thirdPerson = true
			hideAll()
		end
		-- third person: show the real tool in the character's hand again (not while a film hides the characters:
		-- client/IntroCast's CastHidden)
		if char and not player:GetAttribute("CastHidden") then
			realTools(char, 0)
		end
		return
	end
	thirdPerson = false
	if root.Parent ~= cam then
		root.Parent = cam
	end
	local t = os.clock()
	-- (tuning: set Tune = true on the ViewModel model in a playtest and the HandX/Y/Z and ShX/Y/Z attributes move
	-- the fists and shoulders live)
	if root:GetAttribute("Tune") then
		local hx, hy, hz = root:GetAttribute("HandX") :: number? or 2.15, root:GetAttribute("HandY") :: number? or -2.3, root:GetAttribute("HandZ") :: number? or -3.3
		REST_R = scaled(CFrame.new(hx, hy, hz) * CFrame.Angles(math.rad(24), math.rad(14), 0), DIST)
		REST_L = scaled(CFrame.new(-hx - 0.05, hy - 0.05, hz - 0.05) * CFrame.Angles(math.rad(20), math.rad(-14), 0), DIST)
		local sx, sy, sz = root:GetAttribute("ShX") :: number? or 2.5, root:GetAttribute("ShY") :: number? or -3.0, root:GetAttribute("ShZ") :: number? or 2.5
		SHOULDER_R = Vector3.new(sx, sy, sz)
		SHOULDER_L = Vector3.new(-sx, sy, sz)
	end
	local rootPart = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local speed = if rootPart then Vector3.new(rootPart.AssemblyLinearVelocity.X, 0, rootPart.AssemblyLinearVelocity.Z).Magnitude else 0
	local walk = math.clamp(speed / 16, 0, 1.4)
	local dt = math.min(0.1, t - (lastFrame or t))
	lastFrame = t
	-- step rhythm: the hands bob in a figure-eight with your steps, and breathe a little when standing
	if walk > 0.05 then
		stepPhase += dt * (5.5 + speed * 0.3)
	end
	local bob = CFrame.new(math.sin(stepPhase) * 0.07 * walk, -math.abs(math.cos(stepPhase)) * 0.09 * walk + math.sin(t * 1.6) * 0.03, 0)
		* CFrame.Angles(0, 0, math.sin(stepPhase) * 0.02 * walk)
	-- sway: the hands lag behind your mouse look (a spring toward the turn speed), so they feel weighty
	local rel = (lastCamRot or cam.CFrame.Rotation):ToObjectSpace(cam.CFrame.Rotation)
	lastCamRot = cam.CFrame.Rotation
	local rx, ry = rel:ToEulerAnglesYXZ()
	if dt > 0 then
		local k = math.min(1, dt * 12)
		swayYaw += (math.clamp(-ry / dt * 0.012, -0.14, 0.14) - swayYaw) * k
		swayPitch += (math.clamp(-rx / dt * 0.012, -0.1, 0.1) - swayPitch) * k
	end
	local sway = CFrame.new(swayYaw * 1.4, swayPitch * 1.2, 0) * CFrame.Angles(swayPitch, swayYaw, swayYaw * 0.6)
	-- (30 Oct, owner: "an equip animation for each weapon", snappy like Rivals) the draw: a new item comes up from
	-- below the screen, tipped forward, and settles with a small overshoot (client/ViewAnims plays its flourish on top)
	local nowId = equippedId()
	if nowId ~= drawnId then
		drawnId = nowId
		if nowId then
			drawStart = t
			ViewAnims.equip(nowId)
			local cue = DRAW_SOUND[nowId]
			if cue then
				SoundMod = SoundMod or require(script.Parent.Sound)
				SoundMod.play(cue, 0.06)
			end
		end
	end
	local draw = CFrame.new()
	local dk = (t - drawStart) / DRAW_TIME
	if dk < 1 then
		local e = 1 - drawEase(math.max(0, dk))
		draw = scaled(CFrame.new(0.3 * e, -2.4 * e, 0.7 * e), DIST) * CFrame.Angles(math.rad(-40) * e, math.rad(10) * e, math.rad(-18) * e)
	end
	local base = cam.CFrame * bob * sway * draw
	lamp.CFrame = cam.CFrame * CFrame.new(0, 0.5, -1.2) -- above the hands: lights the tops you see
	handLight.Enabled = not player:GetAttribute("Potato")

	local id = equippedId()
	local heldTool = char:FindFirstChildOfClass("Tool")
	local gunTool: Tool? = if heldTool and heldTool:GetAttribute("GunId") then heldTool else nil
	local twoHanded = id ~= nil and TWO_HANDED[id] == true
	local auto = id == "PushMower" or id == "LaserMower" or id == "WeedWhacker"
	-- (28 Oct) a smooth rumble (two fast sines), not random jitter: that flickered at the frame rate
	local buzz = if auto then CFrame.new(math.sin(t * 83.6) * 0.006, math.sin(t * 54.7 + 0.8) * 0.005, 0) else CFrame.new()
	-- (28 Oct) the keyframed swings (client/ViewAnims): advance their clock (it stops during a hit-stop)
	-- (proof shots: DebugClip / DebugFrame attributes on this model hold one clip on one frame)
	local dbg = root:GetAttribute("DebugClip")
	ViewAnims.setDebug(if type(dbg) == "string" and dbg ~= "" then dbg else nil, root:GetAttribute("DebugFrame") :: number? or 0)
	ViewAnims.update(dt, id, walk < 0.15)
	local animated = ViewAnims.hasClip(id)
	-- (29 Oct) inspect (Y): the whole rig, hands and item together, turned about the clip's pivot (client/ViewAnims)
	if ViewAnims.inspecting() then
		if inspectTool ~= nil and inspectTool ~= (id or "") then
			ViewAnims.cancelInspect() -- switched to another item
		end
		inspectTool = inspectTool or id or ""
	else
		inspectTool = nil
	end
	local ip = ViewAnims.pose("I")
	local toolSpin: CFrame? = nil
	if ip.p.Magnitude > 1e-4 or ip.r.Magnitude > 1e-4 then
		local turn = CFrame.Angles(math.rad(ip.r.X), math.rad(ip.r.Y), math.rad(ip.r.Z))
		if id == "MegaScythe" then
			-- (31 Oct, owner: "make the animation NOT break my arm, so make it realistic") the scythe's inspects turn
			-- the scythe alone, about the right fist (the MegaScythe branch below): turning the whole rig swung each
			-- elbow round its fist and folded the arm back on itself
			toolSpin = turn
		else
			local pivot = ViewAnims.inspectPivot()
			base = base * CFrame.new(pivot + ip.p * DIST) * turn * CFrame.new(-pivot)
		end
	end
	local bendR: Vector3?, bendL: Vector3? = nil, nil
	local rollR, rollL = 0, 0

	-- during a hit-stop, hold the pose the swing had when it froze
	-- (swingStart was pushed back by the freeze, so frozenUntil - swingStart is the pose it froze at)
	local st = (math.min(t, frozenUntil) - swingStart) / SWING_TIME
	if t >= frozenUntil then
		st = (t - swingStart) / SWING_TIME
	end
	local recoil = scaled(recoilOffset(t), DIST)
	local swing = if st >= 0 and st <= 1 and not auto then scaled(swingOffset(st), DIST) * recoil else CFrame.new()

	local rightCf, leftCf
	local pushing = if id == "PushMower" or id == "LaserMower" then pushCopyFor(char) else nil
	if not pushing and push then
		push.model:Destroy()
		push = nil
	end
	if pushing then
		-- the mower rides low in front of you, its bar between the fists; it rumbles while it runs and rocks with
		-- your steps
		-- (attributes on the ViewModel model override these, for tuning in a playtest)
		-- (28 Oct, brief: "push bob + engine rumble, jolts when it chews a clump"; the laser mower hovers instead:
		-- client/AutoFeel moves it at the grip, and dresses the copy: the grass trickle, the laser's light curtain)
		local laser = id == "LaserMower"
		local hands = base * scaled(CFrame.new(0, root:GetAttribute("PushY") :: number? or -2.5, root:GetAttribute("PushZ") :: number? or -3.6), DIST)
		local gripCf = CFrame.new(hands.Position) * cam.CFrame.Rotation * CFrame.Angles(math.rad(root:GetAttribute("PushTilt") :: number? or math.deg(PUSH_TILT)), 0, 0)
			* AutoFeel.push(t, walk, stepPhase, laser)
		pushing.model:PivotTo(gripCf * CFrame.new(-pushing.grip))
		AutoFeel.dress(pushing.model, laser)
		AutoFeel.tend(pushing.model, t, walk, laser)
		showPush(pushing, true)
		local half = math.min(pushing.width * 0.42, 0.75)
		rightCf = gripCf * CFrame.new(half, 0, 0)
		leftCf = gripCf * CFrame.new(-half, 0, 0)
	elseif id == "PushMower" or id == "LaserMower" then
		rightCf = base * PUSH_R * buzz
		leftCf = base * PUSH_L * buzz
	elseif id == "MegaScythe" then
		-- (owner, 29 Oct: "fix the angle of the scythe, make it feel real like a real weapon on how you hold it,
		-- dynamic") At rest it's held like a real scythe: both hands on the snath, the right fist low by your hip, the
		-- left one further up it, the shaft running forward and across to the left and the blade out at its far end,
		-- flat over the grass and facing you (a mower's ready stance). It's heavy: it lags behind your look, dips with
		-- your steps and breathes. A swing blends from there into the reaping grip the reaps were made for (the
		-- "swing grip": one fist low on the right, the blade hooked over the top of the view), and back after.
		-- (30 Oct, owner: "it's like holding a knife the wrong way", "the end of the scythe isn't outward like it's
		-- supposed to be") the blade now stands out from the end of the shaft (server/PartModels/tool_scythe), and both
		-- grips are built from it, posed in play with the blade's flat face to the camera (the crescent always
		-- readable, never edge-on) and its glowing inner edge facing in: at rest the snath rises from your right fist
		-- up and across to the left, the blade out at its far end sweeping down; at the contact frame the shaft stands
		-- up from your fists and the blade reaches left, flat through the crosshair (its inner edge's middle on it)
		-- (30 Oct, owner: "fix this animation", reference: Roblox Rivals' scythe in first person) both grips now as
		-- Rivals holds it: the fists low in the middle of the screen, the snath standing up from them, the head near the
		-- top of the view and the blade out to the left, curving back down, its flat face to you; a reap carries that
		-- whole shape flat across the screen (the body turning, client/ViewAnims)
		-- (30 Oct, owner's screenshots: "still looks like a torch ... like I'm holding a pen", "make it look organic,
		-- like a grim reaper") the snath ran on along the forearm, so the fist held it like a pen. Now it runs ACROSS
		-- both forearms, the way two hands really hold a pole: from the right fist low on the right, through the left
		-- fist in the middle, out to the head low on the left; the blade rises from there and arches back over the
		-- crosshair toward you, its flat face to you (the grim reaper's silhouette)
		local tilt = root:GetAttribute("ReaperTilt") :: number? or 21.8
		local reaperPos = scaled(CFrame.new(root:GetAttribute("ReaperX") :: number? or 0.935, root:GetAttribute("ReaperY") :: number? or -0.425, root:GetAttribute("ReaperZ") :: number? or -1.859), DIST)
		local reaperRot = CFrame.Angles(math.rad(tilt), math.rad(root:GetAttribute("ReaperYaw") :: number? or 51.07), math.rad(root:GetAttribute("ReaperRoll") :: number? or -32.29))
		local swingGrip = reaperPos * reaperRot
		-- (30 Oct, owner: "you didn't fix anything" -> research + an LLM council) the pen look was the arms, not the
		-- angles: each forearm ran from its shoulder (behind the camera, low on that side) straight to the fist, and so
		-- along the snath on screen. The rest grip is now built from directions (camera space, attributes HoldPos /
		-- HoldDir / HoldUp / HoldBendR / HoldBendL override them in a playtest): the right fist low right above the
		-- hotbar, the snath running from it up and across to the left (~22 deg on screen, barely forward) through the
		-- left fist under the crosshair, the head off to the left and the blade rising from it with its flat face tipped
		-- toward you; each forearm comes UP into its fist from an elbow below it (bendR / bendL), so it crosses the
		-- snath (~75 deg on screen) the way two hands really grip a pole
		local hp = root:GetAttribute("HoldPos") :: Vector3? or HOLD_POS
		local hd = (root:GetAttribute("HoldDir") :: Vector3? or HOLD_DIR).Unit
		local hu = root:GetAttribute("HoldUp") :: Vector3? or HOLD_UP
		hu = hu - hd * hu:Dot(hd)
		local holdGrip = CFrame.lookAt(hp, hp + hd, if hu.Magnitude > 1e-3 then hu.Unit else Vector3.yAxis)
		-- the weight: the blade end trails your turns, dips on each step, and the shaft breathes
		local heavy = CFrame.Angles(
			swayPitch * 0.9 + math.sin(stepPhase * 2) * 0.035 * walk + math.sin(t * 1.1) * 0.012,
			swayYaw * 1.1,
			swayYaw * 0.7 + math.sin(t * 1.3) * 0.02 + math.sin(stepPhase) * 0.03 * walk
		)
		local w = if animated then ViewAnims.swingWeight() else 0
		-- (30 Oct, weapon-ready hold) the reaps swing the ready grip itself (the body turning, client/ViewAnims B), no
		-- longer morphing into the old reaping grip (whose arms ran along the snath again: the pen)
		local grip = holdGrip * heavy:Lerp(CFrame.new(), w)
		local _ = swingGrip
		local sway = CFrame.Angles(0, 0, math.sin(t * 1.3) * 0.02 * w)
		if animated then
			-- (28 Oct, brief: "a big wide two-handed reap (~180 deg) with a slow heavy wind-up") keyframed reaps
			-- (client/ViewAnims): the body turns the whole scythe round (B), the grip hand lowers and turns it (R), and
			-- the other fist rides the shaft at its second grip
			-- (30 Oct, Rivals) the R channel moves the right fist (camera axes, studs / DIST) and turns the whole scythe
			-- about it, in camera axes: a roll about the view swings the head round like a windscreen wiper (the
			-- reaps), a yaw sweeps it across
			local body = base * bodyCf(ViewAnims.pose("B"))
			local rp = ViewAnims.pose("R")
			rightCf = body * CFrame.new(grip.Position + rp.p * DIST)
				* CFrame.Angles(math.rad(rp.r.X), math.rad(rp.r.Y), math.rad(rp.r.Z)) * grip.Rotation * sway
			if toolSpin then
				-- (31 Oct) the inspect's spin (I, camera axes): the scythe turning in the fingers of a fist that stays put
				local camRot = base.Rotation
				rightCf = CFrame.new(rightCf.Position) * camRot * toolSpin * camRot:Inverse() * rightCf.Rotation
			end
			leftCf = rightCf * CFrame.new(0, 0.1 * HAND, -0.2 * HAND - SCYTHE_GRIP * TOOL)
			-- (31 Oct, the new inspect) the left hand can let go (client/ViewAnims.letGo): it drops from its spot on the
			-- snath at rest to the L channel's p (camera axes, studs / DIST), out of the view, while the right hand
			-- twirls the scythe on its own. (A spot fixed to the camera: the inspect's spin (I) doesn't carry it round.)
			local away = ViewAnims.letGo()
			if away > 0.001 then
				local restLeft = CFrame.new(grip.Position) * grip.Rotation * CFrame.new(0, 0.1 * HAND, -0.2 * HAND - SCYTHE_GRIP * TOOL)
				local lp = ViewAnims.pose("L")
				local goal = cam.CFrame * CFrame.new(restLeft.Position + lp.p * DIST) * restLeft.Rotation
				leftCf = leftCf:Lerp(goal, away * away * (3 - 2 * away))
			end
			-- the elbows below the fists, through the swings too
			local br = root:GetAttribute("HoldBendR") :: Vector3? or HOLD_BEND_R
			local bl = root:GetAttribute("HoldBendL") :: Vector3? or HOLD_BEND_L
			bendR = body:VectorToWorldSpace(br.Unit * math.min(1, br.Magnitude))
			bendL = body:VectorToWorldSpace(bl.Unit * math.min(1, bl.Magnitude))
			rollR = math.rad(rp.roll) -- (31 Oct) the wrist's own turn (R's roll): it works the inspect's spin
		else
			rightCf = base * reaperPos * swing * reaperRot * sway
			leftCf = base * REST_L * scaled(guardOffset(math.clamp(st, 0, 1), -1), DIST)
		end
	elseif id == "WeedWhacker" then
		-- (28 Oct, brief: "side-to-side sweep, spinning head blur, kicks back on a hit") held low like a real one: the
		-- rear grip by your right hip, the left fist on the loop handle, the head down in front over the grass, swept
		-- from side to side about your hands (client/AutoFeel); the head spins below (whackHead)
		local rest = scaled(CFrame.new(root:GetAttribute("WhackX") :: number? or 1.7, root:GetAttribute("WhackY") :: number? or -2.8, root:GetAttribute("WhackZ") :: number? or -2.6), DIST)
			* CFrame.Angles(math.rad(root:GetAttribute("WhackPitch") :: number? or -6), math.rad(root:GetAttribute("WhackYaw") :: number? or 25.9), 0)
		rightCf = base * rest * AutoFeel.whacker(t, walk)
		-- the left fist on the loop handle's top bar, its forearm reaching back across to your left shoulder
		local loop = (rightCf * CFrame.new(0, 0.54, -1.04)).Position
		leftCf = CFrame.lookAt(loop, loop + (loop - cam.CFrame:PointToWorldSpace(SHOULDER_L)), cam.CFrame.UpVector)
	elseif gunTool then
		-- the gun: aimed down the middle, the other hand under the grip (a long gun: under the barrel); each shot kicks
		local kick = math.max(0, 1 - (t - gunKickAt) / 0.12)
		rightCf = base * GUN_R * CFrame.new(0, 0.03 * kick, 0.14 * kick) * CFrame.Angles(math.rad(7 * kick), 0, 0)
		leftCf = if gunLong then rightCf * CFrame.new(-0.18 * DIST, -0.32 * DIST, -1.5 * DIST)
			else rightCf * CFrame.new(-0.42 * DIST, -0.2 * DIST, 0.05 * DIST)
	elseif twoHanded then
		rightCf = base * REST_R * swing * buzz
		leftCf = rightCf * CFrame.new(-1.3 * DIST, -0.2 * DIST, 0.9 * DIST)
	elseif animated then
		-- (28 Oct) keyframed: the body turns about the shoulders, each hand plays its own track (client/ViewAnims)
		local body = base * bodyCf(ViewAnims.pose("B"))
		local pr, pl = ViewAnims.pose("R"), ViewAnims.pose("L")
		rightCf = body * handCf(REST_R, pr)
		leftCf = body * handCf(REST_L, pl)
		bendR, bendL = body:VectorToWorldSpace(pr.b), body:VectorToWorldSpace(pl.b)
		rollR, rollL = math.rad(pr.roll), math.rad(pl.roll)
	elseif id == "Hands" then
		-- bare hands: left and right jabs in turn, the other fist stays up like a boxer
		local active = st >= 0 and st <= 1
		local jab = if active then scaled(punchOffset(st, punchSide), DIST) * recoil else CFrame.new()
		local guard = if active then scaled(guardOffset(st, -punchSide), DIST) else CFrame.new()
		rightCf = base * REST_R * (if punchSide == 1 then jab else guard)
		leftCf = base * REST_L * (if punchSide == -1 then jab else guard)
	else
		rightCf = base * REST_R * swing
		leftCf = base * REST_L
	end
	local set = armsFor(char)
	if set then
		-- the real arms: hide the brick fists and lay the avatar's own arms out to the fist spots
		for _, pieces in { rightArm, leftArm } do
			for _, pc in pieces do
				vis(pc.part, 1)
			end
		end
		for _, m in { handR, handL } do
			if m then
				for _, d in partsOf(m) do
					vis(d, 1)
				end
			end
		end
		poseArm(set, set.right, cam.CFrame:PointToWorldSpace(SHOULDER_R), rightCf.Position, cam, 1, bendR, rollR)
		poseArm(set, set.left, cam.CFrame:PointToWorldSpace(SHOULDER_L), leftCf.Position, cam, -1, bendL, rollL)
	else
		placeHand(handR, rightArm, rightCf)
		placeHand(handL, leftArm, leftCf)
	end
	-- the soft smear behind a fast fist (bare hands)
	smear("R", rightCf.Position, cam, id == "Hands")
	smear("L", leftCf.Position, cam, id == "Hands")

	-- (28 Oct) the T channel moves a keyframed tool in the hand (the sickle tossed and caught, turned about its middle)
	local toolT = CFrame.new()
	if animated and id ~= "Scissors" then
		local tp = ViewAnims.pose("T")
		if tp.p.Magnitude > 1e-4 or tp.r.Magnitude > 1e-4 then
			local mid = CFrame.new(0, 0, -1.6 * TOOL)
			toolT = CFrame.new(tp.p * DIST) * mid * CFrame.Angles(math.rad(tp.r.X), math.rad(tp.r.Y), math.rad(tp.r.Z)) * mid:Inverse()
		end
	end
	local held: Model?
	if gunTool then
		modelFor(nil) -- (puts the last tool's model away)
		held = gunModel(gunTool)
	else
		if gunFor then
			gunModel(nil) -- put the gun copy away
		end
		held = modelFor(id)
	end
	if held then
		held:PivotTo(rightCf * toolT * CFrame.new(0, 0.1 * HAND, -0.2 * HAND))
		for _, part in partsOf(held) do
			vis(part, 0)
		end
	end
	whackHead(if id == "WeedWhacker" then held else nil, t)
	for toolId, pieces in tools do
		if toolId == id and not held and not pushing and id == "Scissors" then
			-- (28 Oct) the shears open and shut (T channel: r.X = opening, r.Y = a twirl about the finger)
			local tp = ViewAnims.pose("T")
			local open = math.rad(math.max(0, tp.r.X)) * 0.5
			local frame = rightCf * CFrame.new(0, 0, -0.3 * HAND) * CFrame.Angles(math.rad(tp.r.Y), 0, 0) * SCISSOR_ROLL
			local pivot = scaled(SCISSOR_PIVOT, TOOL)
			for _, pc in pieces do
				local h = attrsOf(pc.part).half
				pc.part.CFrame = if h then frame * pivot * CFrame.Angles(0, open * h, 0) * pivot:Inverse() * pc.offset else frame * pc.offset
				vis(pc.part, 0)
			end
		elseif toolId == id and not held and not pushing then
			local grip = if id == "PushMower" or id == "LaserMower" then rightCf * CFrame.new(0, 0, -0.1 * HAND) else rightCf * toolT * CFrame.new(0, 0, -0.3 * HAND)
			for _, pc in pieces do
				local cf = grip * pc.offset
				if attrsOf(pc.part).spin then
					cf = cf * CFrame.Angles(0, t * 40, 0)
				end
				pc.part.CFrame = cf
				vis(pc.part, 0)
			end
		else
			for _, pc in pieces do
				vis(pc.part, 1)
			end
		end
	end

	-- (28 Oct) the blade's crescent while it strikes
	local tdef = if id then TRAIL[id] else nil
	local edge = nil
	if tdef and ViewAnims.trailOn() then
		edge = if held then (rightCf * toolT * CFrame.new(0, 0.1 * HAND, -0.2 * HAND)):PointToWorldSpace(tdef.atModel)
			else (rightCf * toolT * CFrame.new(0, 0, -0.3 * HAND)):PointToWorldSpace(tdef.at * TOOL)
	end
	swingTrail(cam, edge, tdef)

	-- the server-side tool in our own hand would poke through the camera; hide it locally
	realTools(char, 1)
end)

return ViewModel
