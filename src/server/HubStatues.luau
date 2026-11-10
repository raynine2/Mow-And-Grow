--!strict
-- THE TOP 3 AS STATUES (10 Nov 2026; owner picked "2": "a statue of the top 3 players"; remodelled the same day: "make
-- the models with blender ... the stud voxel style", "make it more detailed"; design: the Claude Design canvas "Mow
-- And Grow Hub Remodel"). The Top Mowers stage at the hub's StatuesSpot (server/HubFun), built by shared/HubBricks from
-- the Blender model podium_stage: a stone base and plank stage with a red carpet up to #1, three cream pedestals with
-- gold / silver / bronze tops and stars (#1 in the middle and highest, #2 on its left, #3 on its right), a purple arch
-- on columns with gold bands, pennants, tassels, laurels and a crown, two lamp posts, trophies and flower pots. Each
-- player is their own Roblox avatar turned into a metal statue in a frozen pose; name and score are on the wooden
-- plaque on their pedestal ("This could be YOU!" on an empty one). The players come from Config.HUB_FUN.statueBoard's
-- leaderboard (server/LobbyBoards: all servers, or this server's players in Studio); every 20 s a changed place is
-- rebuilt.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Format = require(ReplicatedStorage.MowALawn.Format)
local HubBricks = require(ReplicatedStorage.MowALawn.HubBricks) :: any

local HubStatues = {}

local C = Color3.fromRGB
local INK = C(30, 26, 40)
local FONT = Config.UI and Config.UI.font or Enum.Font.FredokaOne
-- each place: its metal, the pose (an R15 emote frozen part way through) and the statue's size
local PLACES = {
	{ color = C(255, 196, 40), anim = 507770677, at = 0.55, scale = 1.35 }, -- cheer
	{ color = C(206, 214, 226), anim = 507770239, at = 0.7, scale = 1.25 }, -- wave
	{ color = C(214, 132, 70), anim = 507770453, at = 0.6, scale = 1.25 }, -- point
}

type Slot = { userId: number?, model: Model?, name: TextLabel?, score: TextLabel? }
local slots: { Slot } = {}
local folder: Folder? = nil
local anchors: { [string]: any } = {}
local rot = CFrame.identity
local token = 0

local function textPart(parent: Instance, size: Vector2, cf: CFrame, ppS: number): SurfaceGui
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(size.X, size.Y, 0.05)
	p.CFrame = cf
	p.Parent = parent
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = ppS
	g.LightInfluence = 0
	g.Parent = p
	return g
end

local function label(parent: Instance, text: string, size: UDim2, pos: UDim2, color: Color3, stroke: number): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = size
	t.Position = pos
	t.Font = FONT
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color
	t.Parent = parent
	local s = Instance.new("UIStroke")
	s.Color = INK
	s.Thickness = stroke
	s.Parent = t
	return t
end

local function lightAt(parent: Instance, p: Vector3, target: Vector3)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.lookAt(p, target)
	holder.Parent = parent
	local s = Instance.new("SpotLight")
	s.Face = Enum.NormalId.Front
	s.Angle = 55
	s.Range = 26
	s.Brightness = 2.2
	s.Color = C(255, 228, 170)
	s.Parent = holder
end

-- the stage: the Blender model, the banner's words, the lamps' light, sparkles over #1
local function buildStage(f: Folder, at: CFrame)
	local _, a = HubBricks.build("podium_stage", at, f)
	anchors = a
	rot = at.Rotation
	local banner = textPart(f, Vector2.new(27, 2.8), CFrame.new(a.banner :: Vector3) * rot * CFrame.new(0, 0, -0.06), 40)
	label(banner, "TOP MOWERS", UDim2.fromScale(1, 1), UDim2.new(), C(255, 214, 80), 4)
	local target = (at * CFrame.new(0, 10, 0)).Position
	for _, key in { "lampL", "lampR" } do
		local p = a[key] :: Vector3?
		if p then
			lightAt(f, p, target)
		end
	end
	local top1 = a.top1 :: Vector3
	local sp = Instance.new("Part")
	sp.Anchored = true
	sp.CanCollide = false
	sp.CanQuery = false
	sp.Transparency = 1
	sp.Size = Vector3.new(4, 1, 4)
	sp.CFrame = CFrame.new(top1 + Vector3.new(0, 8, 0))
	sp.Parent = f
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(C(255, 230, 120))
	e.LightEmission = 0.7
	e.Rate = 4
	e.Lifetime = NumberRange.new(1.2, 2)
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	e.Parent = sp
end

-- the plaque on a pedestal: the name over the score
local function plaque(slot: Slot, i: number)
	local p = anchors["plaque" .. i] :: Vector3?
	if not p then
		return
	end
	-- (the plaque's wood is on the half-stud grid, so its face is 0.25 in front of the anchor: the words go just past it)
	local g = textPart(folder :: Folder, Vector2.new(3.8, 1.4), CFrame.new(p) * rot * CFrame.new(0, 0, -0.32), 70)
	slot.name = label(g, "", UDim2.new(0.94, 0, 0.56, 0), UDim2.fromScale(0.03, 0.02), Color3.new(1, 1, 1), 2)
	slot.score = label(g, "", UDim2.new(0.94, 0, 0.38, 0), UDim2.fromScale(0.03, 0.6), C(255, 214, 80), 2)
end

-- a player's avatar as a metal statue in a frozen pose, standing on its place
local function statue(userId: number, i: number): Model?
	local pl = PLACES[i]
	local ok, model = pcall(function()
		local desc = Players:GetHumanoidDescriptionFromUserId(userId)
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		return nil
	end
	local m = model :: Model
	for _, d in m:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("ModuleScript") or d:IsA("Clothing") or d:IsA("ShirtGraphic") or d:IsA("Decal")
			or d:IsA("SurfaceAppearance") or d:IsA("BodyColors") then
			d:Destroy()
		end
	end
	for _, d in m:GetDescendants() do
		if d:IsA("MeshPart") then
			d.TextureID = ""
		elseif d:IsA("SpecialMesh") then
			d.TextureId = ""
		end
		if d:IsA("BasePart") then
			d.Color = pl.color
			d.Material = Enum.Material.Metal
			d.Reflectance = 0.12
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.BreakJointsOnDeath = false
		hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	end
	pcall(function()
		m:ScaleTo(pl.scale)
	end)
	local root = m:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.Anchored = true
		root.Transparency = 1
	end
	-- feet on the pedestal's top, facing out
	local top = anchors["top" .. i] :: Vector3
	local cf, size = m:GetBoundingBox()
	m:PivotTo(CFrame.new(top + Vector3.new(0, m:GetPivot().Position.Y - (cf.Position.Y - size.Y / 2), 0)) * rot)
	m.Name = "Statue" .. i
	m.Parent = folder
	-- the pose: the emote played on the server (it replicates) and frozen part way through
	if hum then
		task.spawn(function()
			local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
			animator.Parent = hum
			local a = Instance.new("Animation")
			a.AnimationId = "rbxassetid://" .. pl.anim
			local okT, track = pcall(function()
				return animator:LoadAnimation(a)
			end)
			if okT and track then
				track.Looped = true
				track.Priority = Enum.AnimationPriority.Action
				track:Play(0)
				task.wait(pl.at)
				track:AdjustSpeed(0)
			end
		end)
	end
	return m
end

local function refresh(t: number)
	if not folder or t ~= token then
		return
	end
	local LobbyBoards = require(script.Parent.LobbyBoards)
	local rows = LobbyBoards.rows(Config.HUB_FUN.statueBoard or "cut")
	for i = 1, 3 do
		local slot = slots[i]
		local row = rows[i]
		local uid = row and row.userId
		if slot.userId ~= uid then
			if slot.model then
				slot.model:Destroy()
				slot.model = nil
			end
			slot.userId = uid
			if uid then
				slot.model = statue(uid, i)
			end
			if t ~= token then
				return
			end
		end
		if slot.name and slot.score then
			slot.name.Text = if row then ("#%d %s"):format(i, row.name) else ("#%d"):format(i)
			slot.score.Text = if row then Format.short(row.value) .. " grass cut" else "This could be YOU!"
		end
	end
end

function HubStatues.start(f: Folder, at: BasePart?)
	HubStatues.stop()
	if not at then
		return
	end
	token += 1
	local my = token
	local sf = Instance.new("Folder")
	sf.Name = "TopStatues"
	sf.Parent = f
	folder = sf
	buildStage(sf, at.CFrame)
	slots = {}
	for i = 1, 3 do
		local slot: Slot = {}
		slots[i] = slot
		plaque(slot, i)
	end
	task.spawn(function()
		task.wait(3) -- the boards read their first rows
		while my == token do
			local ok, err = pcall(refresh, my)
			if not ok then
				warn("[HubStatues] " .. tostring(err))
			end
			task.wait(20)
		end
	end)
end

function HubStatues.stop()
	token += 1
	if folder then
		folder:Destroy()
	end
	folder = nil
	slots = {}
end

return HubStatues
