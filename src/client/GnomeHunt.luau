-- GOLDEN GNOME HUNT, the client side (server/Gnomes, Config.GNOMES):
--   * a gnome you've picked up vanishes on your screen with a little burst (the server marks it Found_<userId>;
--     the others still see it). Watched by tag, so a gnome that streams back in stays hidden.
--   * GnomeHunt.toast(d): the gold strip at the top that everyone in the server sees when someone finds one
--     (client/Fx's "gnome" handler; the finder gets the big banner there instead)
--   * GnomeHunt.view(...): a gnome in a ViewportFrame, dark as a silhouette when it's still to find (Index window)
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local GnomeLook = require(ReplicatedStorage.MowALawn:WaitForChild("GnomeLook"))
local UI = require(script.Parent.UI)
local Sound = require(script.Parent.Sound)

local GnomeHunt = {}
local player = Players.LocalPlayer
local myKey = "Found_" .. player.UserId

-------------------------------------------------------------------------------------------------------------
-- found gnomes vanish for you
-------------------------------------------------------------------------------------------------------------
local function puff(pos: Vector3, color: Color3)
	local a = Instance.new("Attachment")
	a.Position = pos
	a.Parent = workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(6, 12)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 4
	e.Parent = a
	e:Emit(24)
	task.delay(1.5, function()
		a:Destroy()
	end)
end

local function hide(m: Instance, animate: boolean)
	if not m:IsA("Model") then
		return
	end
	if animate then
		local def = Config.gnome(m:GetAttribute("Gnome") or "")
		puff(m:GetPivot().Position + Vector3.new(0, 1.4, 0), if def and def.diamond then Color3.fromRGB(190, 245, 255) else Color3.fromRGB(255, 220, 90))
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = 1
		elseif d:IsA("ParticleEmitter") then
			d.Enabled = false
		elseif d:IsA("ProximityPrompt") then
			d.Enabled = false
		end
	end
end

local function watch(m: Instance)
	if m:GetAttribute(myKey) then
		hide(m, false)
		return
	end
	local conn: RBXScriptConnection
	conn = m:GetAttributeChangedSignal(myKey):Connect(function()
		if m:GetAttribute(myKey) then
			conn:Disconnect()
			hide(m, true)
		end
	end)
end
CollectionService:GetInstanceAddedSignal("MowGnome"):Connect(watch)
for _, m in CollectionService:GetTagged("MowGnome") do
	task.spawn(watch, m)
end

-------------------------------------------------------------------------------------------------------------
-- pictures
-------------------------------------------------------------------------------------------------------------
-- Gnome `id` drawn in a ViewportFrame `size` px square; `locked` draws it as a dark silhouette.
function GnomeHunt.view(parent: Instance, id: string, size: number, pos: UDim2?, anchor: Vector2?, locked: boolean?): ViewportFrame
	local vp = Instance.new("ViewportFrame")
	vp.Name = "GnomeView"
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromOffset(size, size)
	vp.Position = pos or UDim2.new()
	vp.AnchorPoint = anchor or Vector2.zero
	vp.Ambient = Color3.fromRGB(200, 196, 190)
	vp.LightColor = Color3.fromRGB(255, 250, 235)
	vp.LightDirection = Vector3.new(-1, -2, -1.5)
	if locked then
		vp.ImageColor3 = Color3.fromRGB(22, 18, 16) -- a dark shape on the card: you can tell it's a gnome, not which
	end
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = vp
	vp.CurrentCamera = cam
	local m = GnomeLook.build(id)
	if m then
		m.Parent = vp
		local cf, bsize = m:GetBoundingBox()
		local dist = math.max(bsize.X, bsize.Y, bsize.Z) * 2.2
		-- the model faces -Z: look at its front, a little from the side and above
		cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(dist * 0.35, dist * 0.2, -dist * 0.92), cf.Position)
	end
	vp.Parent = parent
	return vp
end

-------------------------------------------------------------------------------------------------------------
-- the announcement strip everyone sees
-------------------------------------------------------------------------------------------------------------
local queue: { any } = {}
local showing = false

local function showToast(d)
	local def = Config.gnome(d.id)
	if not def then
		return
	end
	local gold = if def.diamond then Color3.fromRGB(120, 210, 245) else Color3.fromRGB(240, 178, 40)
	local strip = UI.frame({ size = UDim2.fromOffset(560, 70), pos = UDim2.new(0.5, 0, 0, -90), anchor = Vector2.new(0.5, 0), color = gold, parent = UI.gui, radius = 35, outline = 4, name = "GnomeToast" })
	strip.ZIndex = 38
	UI.gradient(strip, gold)
	GnomeHunt.view(strip, d.id, 86, UDim2.new(0, 12, 0.5, -4), Vector2.new(0, 0.5))
	local line = ("%s found the %s!"):format(d.name or "Someone", def.name)
	local t = UI.text(strip, line, UDim2.new(1, -118, 0, 38), { pos = UDim2.fromOffset(104, 6), align = Enum.TextXAlignment.Left, stroke = 3 })
	t.ZIndex = 39
	local sub = if d.set then "THEY FOUND EVERY GNOME!" elseif d.first then ("A new one for their collection (%d / %d)"):format(d.have or 0, d.total or #Config.GNOMES.list) else "Can you find one too?"
	local s = UI.text(strip, sub, UDim2.new(1, -118, 0, 22), { pos = UDim2.fromOffset(104, 42), align = Enum.TextXAlignment.Left, stroke = 2, textSize = 18 })
	s.ZIndex = 39
	Sound.play(if def.diamond then "rareChime" else "pickup", 0.05, 0.6)
	local inPos = UDim2.new(0.5, 0, 0, 74)
	TweenService:Create(strip, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = inPos }):Play()
	task.wait(4.2)
	TweenService:Create(strip, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0, -90) }):Play()
	task.wait(0.4)
	strip:Destroy()
end

-- Someone in the server found a gnome: their name and the gnome slide in at the top (one after another).
function GnomeHunt.toast(d)
	if #queue >= 4 then
		return
	end
	table.insert(queue, d)
	if showing then
		return
	end
	showing = true
	task.spawn(function()
		while #queue > 0 do
			local ok, err = pcall(showToast, table.remove(queue, 1))
			if not ok then
				warn("[GnomeHunt] " .. tostring(err))
			end
		end
		showing = false
	end)
end

return GnomeHunt
