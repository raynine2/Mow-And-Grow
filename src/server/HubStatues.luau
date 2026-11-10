--!strict
-- THE TOP 3 AS STATUES (10 Nov 2026; owner picked "2": "a statue of the top 3 players"). On a podium at the hub's
-- StatuesSpot (server/HubFun): #1 in the middle and highest in gold, #2 on its left in silver, #3 on its right in
-- bronze, each the player's own Roblox avatar turned into a metal statue in a frozen pose, with their name and score
-- over it; TOP MOWERS on a board behind. The players come from Config.HUB_FUN.statueBoard's leaderboard
-- (server/LobbyBoards: all servers, or this server's players in Studio); every 20 s a changed place is rebuilt. An
-- empty place shows "This could be YOU!".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Format = require(ReplicatedStorage.MowALawn.Format)

local HubStatues = {}

local C = Color3.fromRGB
local INK = C(30, 26, 40)
local CREAM = C(245, 236, 214)
-- place: offset from the spot (x = to the viewer's left), podium height, metal colour, the pose (an R15 emote frozen
-- part way through)
local PLACES = {
	{ x = 0, h = 5, color = C(255, 196, 40), label = "1", anim = 507770677, at = 0.55, scale = 1.35 }, -- cheer
	{ x = 6.6, h = 3.6, color = C(206, 214, 226), label = "2", anim = 507770239, at = 0.7, scale = 1.25 }, -- wave
	{ x = -6.6, h = 2.6, color = C(214, 132, 70), label = "3", anim = 507770453, at = 0.6, scale = 1.25 }, -- point
}
local W, D = 5.6, 5.4 -- each block's width and depth

type Slot = { userId: number?, model: Model?, tag: TextLabel?, sub: TextLabel?, empty: BillboardGui? }
local slots: { Slot } = {}
local folder: Folder? = nil
local spot: BasePart? = nil
local token = 0

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
	p.Parent = parent
	return p
end

local function faceText(p: BasePart, text: string, color: Color3, size: number)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	g.LightInfluence = 0
	g.Parent = p
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Config.UI and Config.UI.font or Enum.Font.FredokaOne
	t.Text = text
	t.TextColor3 = color
	t.TextSize = size
	t.Parent = g
	local s = Instance.new("UIStroke")
	s.Color = INK
	s.Thickness = 4
	s.Parent = t
end

-- the podium, the board and the "could be you" tags
local function buildStage(f: Folder, at: CFrame)
	for i, pl in PLACES do
		local base = at * CFrame.new(pl.x, pl.h / 2, 0)
		local block = part(f, "Podium" .. i, Vector3.new(W, pl.h, D), base, CREAM)
		part(f, "Band" .. i, Vector3.new(W + 0.3, 0.7, D + 0.3), at * CFrame.new(pl.x, pl.h - 0.35, 0), pl.color, Enum.Material.SmoothPlastic)
		local num = part(f, "Number" .. i, Vector3.new(W - 1, pl.h - 1, 0.1), at * CFrame.new(pl.x, (pl.h - 0.7) / 2, -D / 2 - 0.06), CREAM)
		num.Transparency = 1
		num.CanCollide = false
		faceText(num, pl.label, pl.color, math.floor((pl.h - 1) * 30))
		block:SetAttribute("Place", i)
	end
	-- the board behind: TOP MOWERS
	local board = part(f, "Board", Vector3.new(15, 3.2, 0.6), at * CFrame.new(0, 13.2, 3.2), C(120, 78, 46), Enum.Material.WoodPlanks)
	for _, x in { -6.2, 6.2 } do
		part(f, "Post", Vector3.new(0.8, 13, 0.8), at * CFrame.new(x, 6.5, 3.4), C(96, 62, 38), Enum.Material.WoodPlanks)
	end
	faceText(board, "TOP MOWERS", C(255, 214, 80), 92)
	local sub = part(f, "BoardSub", Vector3.new(15, 1, 0.1), at * CFrame.new(0, 11.1, 2.86), CREAM)
	sub.Transparency = 1
	sub.CanCollide = false
	faceText(sub, "most grass cut  ·  all servers", C(255, 255, 255), 30)
	-- sparkles over #1
	local sp = part(f, "Sparkles", Vector3.new(4, 1, 4), at * CFrame.new(0, PLACES[1].h + 4, 0), CREAM)
	sp.Transparency = 1
	sp.CanCollide = false
	sp.CanQuery = false
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

-- a name tag over a place: the name, and the score under it
local function tagFor(slot: Slot, i: number, at: CFrame)
	local pl = PLACES[i]
	local anchor = part(folder :: Folder, "Tag" .. i, Vector3.new(1, 1, 1), at * CFrame.new(pl.x, pl.h, 0), CREAM)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 64)
	bb.StudsOffset = Vector3.new(0, 9.4, 0)
	bb.MaxDistance = 90
	bb.LightInfluence = 0
	bb.Parent = anchor
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0.58, 0)
	name.Font = Config.UI and Config.UI.font or Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = pl.color
	name.Text = ""
	name.Parent = bb
	local ns = Instance.new("UIStroke")
	ns.Color = INK
	ns.Thickness = 3
	ns.Parent = name
	local sub = name:Clone()
	sub.Position = UDim2.fromScale(0, 0.58)
	sub.Size = UDim2.new(1, 0, 0.42, 0)
	sub.TextColor3 = C(255, 255, 255)
	sub.Parent = bb
	slot.tag, slot.sub = name, sub
end

-- a player's avatar as a metal statue in a frozen pose, standing on its place
local function statue(userId: number, i: number, at: CFrame): Model?
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
	-- feet on the block's top, facing out
	local cf, size = m:GetBoundingBox()
	local top = (at * CFrame.new(pl.x, pl.h, 0)).Position
	local base = at * CFrame.new(pl.x, 0, 0)
	m:PivotTo(CFrame.new(top + Vector3.new(0, m:GetPivot().Position.Y - (cf.Position.Y - size.Y / 2), 0)) * base.Rotation)
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

local function scoreText(v: number): string
	return Format.short(v) .. " grass cut"
end

local function refresh(t: number)
	local f, s = folder, spot
	if not f or not s or t ~= token then
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
				slot.model = statue(uid, i, s.CFrame)
			end
			if t ~= token then
				return
			end
		end
		if slot.tag and slot.sub then
			slot.tag.Text = if row then ("#%d  %s"):format(i, row.name) else ""
			slot.sub.Text = if row then scoreText(row.value) else "This could be YOU!"
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
	folder, spot = sf, at
	buildStage(sf, at.CFrame)
	slots = {}
	for i = 1, 3 do
		local slot: Slot = {}
		slots[i] = slot
		tagFor(slot, i, at.CFrame)
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
	folder, spot = nil, nil
	slots = {}
end

return HubStatues
