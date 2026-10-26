-- The fighters in a boss fight, as everyone sees them (round 2 of the owner's boss brief, 26 Oct):
--   * an HP bar over EVERY fighter's head (yours too), from the player attributes BossHP / BossMaxHP that
--     server/BossFighters sets; green -> yellow -> red, a white "damage chunk" that drains after a hit
--   * a knocked-out fighter sits dizzy: stars circle their head, a revive ring on the floor fills while a teammate
--     stands next to them (ReviveProgress), and the seconds left show over them
-- Client only, built per character; everything goes when the attributes do.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BossPlayers = {}

local C = Color3.fromRGB
local folder = Instance.new("Folder")
folder.Name = "BossPlayers"
folder.Parent = workspace

type Entry = {
	gui: BillboardGui,
	fill: Frame,
	chunk: Frame,
	label: TextLabel,
	stars: Frame,
	timer: TextLabel,
	ring: Part?,
	ringFill: Part?,
	last: number,
}
local entries: { [Player]: Entry } = {}

local function corner(f: GuiObject, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = f
end

local function make(p: Player): Entry?
	local char = p.Character
	local head = char and char:FindFirstChild("Head") :: BasePart?
	if not head then
		return nil
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "BossHpTag"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(110, 56)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 160
	gui.AlwaysOnTop = true
	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0.5, 1)
	track.Position = UDim2.fromScale(0.5, 1)
	track.Size = UDim2.new(1, 0, 0, 16)
	track.BackgroundColor3 = C(28, 22, 36)
	track.BorderSizePixel = 0
	corner(track, 8)
	local st = Instance.new("UIStroke")
	st.Thickness = 2
	st.Color = C(10, 8, 14)
	st.Parent = track
	track.Parent = gui
	local chunk = Instance.new("Frame")
	chunk.Size = UDim2.fromScale(1, 1)
	chunk.BackgroundColor3 = C(255, 255, 255)
	chunk.BorderSizePixel = 0
	corner(chunk, 8)
	chunk.Parent = track
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = C(90, 220, 90)
	fill.BorderSizePixel = 0
	corner(fill, 8)
	fill.Parent = track
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = C(255, 255, 255)
	label.ZIndex = 3
	local ls = Instance.new("UIStroke")
	ls.Thickness = 1.5
	ls.Parent = label
	label.Parent = track
	-- the dizzy stars and the seconds left, above the bar
	local stars = Instance.new("Frame")
	stars.BackgroundTransparency = 1
	stars.AnchorPoint = Vector2.new(0.5, 1)
	stars.Position = UDim2.new(0.5, 0, 1, -18)
	stars.Size = UDim2.fromOffset(90, 34)
	stars.Visible = false
	stars.Parent = gui
	for i = 1, 3 do
		local s = Instance.new("TextLabel")
		s.Name = "Star" .. i
		s.BackgroundTransparency = 1
		s.AnchorPoint = Vector2.new(0.5, 0.5)
		s.Size = UDim2.fromOffset(24, 24)
		s.Font = Enum.Font.FredokaOne
		s.TextScaled = true
		s.Text = "★"
		s.TextColor3 = C(255, 230, 90)
		local ss = Instance.new("UIStroke")
		ss.Thickness = 1.5
		ss.Color = C(120, 70, 0)
		ss.Parent = s
		s.Parent = stars
	end
	local timer = Instance.new("TextLabel")
	timer.BackgroundTransparency = 1
	timer.AnchorPoint = Vector2.new(0.5, 0.5)
	timer.Position = UDim2.fromScale(0.5, 0.5)
	timer.Size = UDim2.fromOffset(40, 22)
	timer.Font = Enum.Font.FredokaOne
	timer.TextScaled = true
	timer.TextColor3 = C(255, 255, 255)
	local ts = Instance.new("UIStroke")
	ts.Thickness = 2
	ts.Parent = timer
	timer.Parent = stars
	gui.Parent = folder
	return { gui = gui, fill = fill, chunk = chunk, label = label, stars = stars, timer = timer, ring = nil, ringFill = nil, last = 1 }
end

local function dropRing(e: Entry)
	if e.ring then
		e.ring:Destroy()
		e.ring = nil
	end
	if e.ringFill then
		e.ringFill:Destroy()
		e.ringFill = nil
	end
end

local function remove(p: Player)
	local e = entries[p]
	if e then
		dropRing(e)
		e.gui:Destroy()
		entries[p] = nil
	end
end

local function disc(r: number, color: Color3, transparency: number): Part
	local d = Instance.new("Part")
	d.Anchored = true
	d.CanCollide = false
	d.CanQuery = false
	d.CanTouch = false
	d.CastShadow = false
	d.Shape = Enum.PartType.Cylinder
	d.Size = Vector3.new(0.12, r * 2, r * 2)
	d.Material = Enum.Material.Neon
	d.Color = color
	d.Transparency = transparency
	d.Parent = folder
	return d
end

local function update(p: Player)
	local hp, max = p:GetAttribute("BossHP"), p:GetAttribute("BossMaxHP")
	if type(hp) ~= "number" or type(max) ~= "number" then
		remove(p)
		return
	end
	local e = entries[p]
	if e and (not e.gui.Adornee or not e.gui.Adornee:IsDescendantOf(workspace)) then
		remove(p)
		e = nil
	end
	if not e then
		e = make(p)
		if not e then
			return
		end
		entries[p] = e
	end
	local entry = e :: Entry
	local k = math.clamp(hp / math.max(1, max), 0, 1)
	if k < entry.last then
		-- the white chunk drains after the hit
		task.delay(0.35, function()
			if entries[p] == entry then
				TweenService:Create(entry.chunk, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(k, 1) }):Play()
			end
		end)
	else
		entry.chunk.Size = UDim2.fromScale(k, 1)
	end
	entry.last = k
	TweenService:Create(entry.fill, TweenInfo.new(0.15), { Size = UDim2.fromScale(k, 1) }):Play()
	entry.fill.BackgroundColor3 = if k > 0.5 then C(90, 220, 90) elseif k > 0.25 then C(255, 190, 60) else C(240, 60, 60)
	entry.label.Text = tostring(math.ceil(hp))
	local downed = p:GetAttribute("Downed")
	entry.stars.Visible = type(downed) == "number"
	if type(downed) == "number" then
		entry.timer.Text = tostring(math.max(0, math.ceil(downed)))
		if not entry.ring then
			entry.ring = disc(5, C(255, 255, 255), 0.6)
			entry.ringFill = disc(0.1, C(120, 255, 140), 0.25)
		end
	else
		dropRing(entry)
	end
end

local function watch(p: Player)
	for _, a in { "BossHP", "BossMaxHP", "Downed", "ReviveProgress" } do
		p:GetAttributeChangedSignal(a):Connect(function()
			update(p)
		end)
	end
	p.CharacterAdded:Connect(function()
		remove(p)
		task.defer(update, p)
	end)
	update(p)
end

for _, p in Players:GetPlayers() do
	watch(p)
end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(remove)

-- the stars turn, the revive ring follows the fighter's feet and fills
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for p, e in entries do
		if e.stars.Visible then
			for i = 1, 3 do
				local s = e.stars:FindFirstChild("Star" .. i) :: TextLabel?
				if s then
					local a = t * 4 + i * (math.pi * 2 / 3)
					s.Position = UDim2.new(0.5, math.cos(a) * 34, 0.5, math.sin(a) * 9)
					s.Rotation = math.deg(t * 3 + i)
					s.ZIndex = if math.sin(a) > 0 then 4 else 1
				end
			end
		end
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if e.ring and root then
			local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			local floor = root.Position - Vector3.new(0, (if hum then hum.HipHeight else 2) * 0.55 + root.Size.Y / 2 - 0.08, 0)
			local cf = CFrame.new(floor) * CFrame.Angles(0, 0, math.rad(90))
			e.ring.CFrame = cf
			local prog = math.clamp(p:GetAttribute("ReviveProgress") or 0, 0, 1)
			local r = math.max(0.1, prog * 5)
			if e.ringFill then
				e.ringFill.Size = Vector3.new(0.14, r * 2, r * 2)
				e.ringFill.CFrame = cf
			end
		end
	end
end)

return BossPlayers
