-- The PETS window (P): EGGS tab = Chop A Forest's egg cards (egg on the left, every critter with its % odds,
-- 1 / 3 / 10 buttons; odds shown because eggs are random; a Robux egg only shows where Roblox's policy allows paid
-- random items); PETS tab = your critters, equip up to 3, EQUIP BEST. Drawn with the ForgeGUI kit (client/Skin).
-- Hatching: the window dims, the egg wobbles and cracks, the critter pops out on rays with a rarity-coloured burst.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.MowALawn:WaitForChild("Format"))
local Policy = require(ReplicatedStorage.MowALawn:WaitForChild("Policy"))
local UI = require(script.Parent.UI)
local Skin = require(script.Parent.Skin)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)
local Confetti = require(script.Parent.Confetti)
local PetFollow = require(script.Parent.PetFollow)

local PetsWindow = {}
local C = UI.colors
local W = UI.wood
local BIG = { Legendary = true, Mythic = true, Secret = true }

local function pctText(x: number): string
	local p = x * 100
	return if p >= 10 then string.format("%d%%", math.floor(p + 0.5)) else string.format("%.1f%%", p)
end

local function boostLines(p): string
	local parts = {}
	for _, k in Config.PET_STATS do
		local v = (p :: any)[k]
		if v and v > 0 then
			table.insert(parts, ("+%d%% %s"):format(math.floor(v * 100 + 0.5), k))
		end
	end
	return table.concat(parts, "  ")
end

-- A critter drawn into a ViewportFrame.
local function petView(parent: Instance, look, size: number, pos: UDim2, anchor: Vector2?): ViewportFrame
	-- (also used by client/PetIndex through PetsWindow.petView)
	local vp = Instance.new("ViewportFrame")
	vp.Name = "PetView"
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromOffset(size, size)
	vp.Position = pos
	vp.AnchorPoint = anchor or Vector2.zero
	vp.Ambient = Color3.fromRGB(200, 200, 210)
	vp.LightColor = Color3.fromRGB(255, 255, 240)
	vp.LightDirection = Vector3.new(-1, -2, -1)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 35
	cam.Parent = vp
	vp.CurrentCamera = cam
	local m = PetFollow.build(look)
	m.Parent = vp
	local cf, bsize = m:GetBoundingBox()
	local dist = math.max(bsize.X, bsize.Y, bsize.Z) * 2.1
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(-dist * 0.6, dist * 0.45, -dist * 0.75), cf.Position)
	vp.Parent = parent
	return vp
end

-- An egg's picture: the ForgeGUI garden egg / golden egg, else the old moss egg.
local function eggIcon(egg): string
	if egg.id == "GoldenEgg" and (Config.ICONS.superhatch or "") ~= "" then
		return "superhatch"
	end
	if egg.id ~= "GoldenEgg" and (Config.ICONS.egg_garden or "") ~= "" then
		return "egg_garden"
	end
	return "egg"
end
PetsWindow.eggIcon = eggIcon

-------------------------------------------------------------------------------------------------------------
-- window: EGGS / PETS tabs
-------------------------------------------------------------------------------------------------------------
local TABS = { { label = "Pets", window = "Pets", icon = "paw" }, { label = "Eggs", window = "Eggs", icon = "egg" }, { label = "Index", window = "PetIndex", icon = "book" } }
local eggs = UI.window("Eggs", "Pets", nil, { tabs = TABS, gems = false, size = Vector2.new(860, 560) })
local pets = UI.window("Pets", "Pets", nil, { tabs = TABS, gems = false, size = Vector2.new(860, 560) })
for _, w in { eggs, pets } do
	w.frame.Position = UDim2.new(0.5, -160, 0.55, 0) -- room on the right for the big card
end
PetsWindow.TABS = TABS

-- One wide egg card on the ForgeGUI wood-rimmed card: the egg bobbing on turning rays at the left, every critter
-- with its odds on little rarity tiles, the open buttons along the bottom; mowed-lawn stripes in the egg's colour.
local EGG_CARD = Vector2.new(730, 270)
local function eggCard(list: Instance, order: number, egg, d)
	local card = Instance.new("Frame")
	card.Name = "Egg_" .. egg.id
	card.BackgroundTransparency = 1
	card.Size = UDim2.new(1, -10, 0, EGG_CARD.Y)
	card.LayoutOrder = order
	card.Parent = list
	local art, face = Skin.frame(card, "ui_pcard", EGG_CARD, { name = "Card", boost = 1.25 })
	art.Size = UDim2.fromScale(1, 1)
	local inner = UI.frame({ size = UDim2.fromScale(1, 1), color = egg.color, parent = face, radius = 12, outline = 0, name = "Inner" })
	inner.ClipsDescendants = true
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(UI.shade(egg.color, 1.15), UI.shade(egg.color, 0.55))
	g.Rotation = 90
	g.Parent = inner
	Skin.stripes(inner)
	if egg.exclusive then
		UI.ribbon(card, "EXCLUSIVE", Color3.fromRGB(150, 80, 230))
		Skin.sparkles(inner, 0.45, Color3.fromRGB(255, 240, 160))
	end
	-- the egg itself, on slowly turning rays
	local eggHolder = Instance.new("Frame")
	eggHolder.Name = "EggPic"
	eggHolder.BackgroundTransparency = 1
	eggHolder.Size = UDim2.fromOffset(112, 130)
	eggHolder.Position = UDim2.fromOffset(8, 34)
	eggHolder.Parent = face
	Skin.rays(eggHolder, UI.shade(egg.color, 1.5), 210, nil, 18)
	local pic = UI.icon(eggHolder, eggIcon(egg), 116, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	if pic:IsA("ImageLabel") and eggIcon(egg) == "egg" and egg.id ~= "GardenEgg" then
		pic.ImageColor3 = UI.shade(egg.color, 1.2) -- the old moss egg picture, tinted
	end
	Skin.bob(pic, 4, 1.8)
	UI.text(face, string.upper(egg.name), UDim2.fromOffset(300, 32), { pos = UDim2.fromOffset(16, 2), align = Enum.TextXAlignment.Left, stroke = 3 })
	UI.text(face, egg.desc or ("Hatch a garden critter - %s gems"):format(Format.commas(egg.price or 0)), UDim2.fromOffset(400, 20), { pos = UDim2.fromOffset(250, 10), align = Enum.TextXAlignment.Left, stroke = 1.5, textSize = 15 })

	-- critters + odds (with your hatch luck)
	local luck = d.hatchLuck or 1
	local odds = Config.eggOdds(egg, luck)
	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, -136, 0, 122)
	grid.Position = UDim2.fromOffset(128, 38)
	grid.Parent = face
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(84, 58)
	layout.CellPadding = UDim2.fromOffset(6, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	for i, r in odds do
		local p = Config.pet(r[1])
		if p then
			local rc = Config.RARITY_COLORS[p.rarity]
			local cell = Instance.new("Frame")
			cell.Name = "Pet_" .. p.id
			cell.BackgroundTransparency = 1
			cell.LayoutOrder = i
			cell.Parent = grid
			local tile = Skin.frame(cell, "ui_button", Vector2.new(84, 58), { name = "Art", boost = 1.4, tint = UI.shade(rc, 0.75) })
			tile.Size = UDim2.fromScale(1, 1)
			petView(cell, p.look, 40, UDim2.fromOffset(2, 2))
			local nm = UI.text(cell, p.name, UDim2.new(1, -44, 0, 24), { pos = UDim2.fromOffset(42, 4), align = Enum.TextXAlignment.Left, stroke = 1.5 })
			nm.TextWrapped = true -- scaled, so long names shrink instead of breaking mid-word
			UI.text(cell, pctText(r[2]), UDim2.new(1, -44, 0, 18), { pos = UDim2.fromOffset(42, 28), align = Enum.TextXAlignment.Left, color = UI.shade(rc, 1.5), stroke = 1.5, textSize = 14 })
			if BIG[p.rarity] then
				Skin.sparkles(cell, 0.9, UI.shade(rc, 1.5))
			end
		end
	end
	if luck > 1 then
		UI.text(face, ("Hatch Luck x%s applied"):format(tostring(luck)), UDim2.fromOffset(300, 18), { pos = UDim2.new(1, -12, 0, 12), anchor = Vector2.new(1, 0), align = Enum.TextXAlignment.Right, color = Color3.fromRGB(150, 255, 120), stroke = 1.5, textSize = 14 })
	end

	-- buttons along the bottom
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -32, 0, 46)
	row.Position = UDim2.new(0, 16, 1, -2)
	row.AnchorPoint = Vector2.new(0, 1)
	row.Parent = face
	local rl = Instance.new("UIListLayout")
	rl.FillDirection = Enum.FillDirection.Horizontal
	rl.Padding = UDim.new(0, 12)
	rl.SortOrder = Enum.SortOrder.LayoutOrder
	rl.Parent = row
	if egg.currency == "gems" then
		for i, n in { 1, 3 } do
			local cost = egg.price * n
			local b = UI.button(row, ("OPEN %d  -  %s"):format(n, Format.commas(cost)), if d.gems >= cost then C.purple else W.grey, UDim2.fromOffset(230, 46), function()
				State.fire("Hatch", egg.id, n)
			end, { name = "Open" .. n })
			b.LayoutOrder = i
			local label = b:FindFirstChild("Label") :: TextLabel
			label.Size = UDim2.new(1, -46, 1, -18)
			UI.icon(b, "gem", 30, UDim2.new(1, -38, 0, 4)).ZIndex = b.ZIndex + 1
		end
	else
		for i, pr in egg.products do
			local product = Config.PRODUCTS[pr.key]
			if product then
				local b = UI.robuxButton(row, product.robux, UDim2.fromOffset(190, 46), function()
					State.fire("Prompt", "product", pr.key)
				end, { name = pr.key, prefix = ("%d EGG%s  "):format(pr.count, if pr.count > 1 then "S" else "") })
				b.LayoutOrder = i
				if pr.tag then
					UI.ribbon(b, pr.tag, Color3.fromRGB(255, 140, 40))
				end
			end
		end
	end
	return card
end

-- ask Roblox's policy once; the Golden Egg card appears when it says paid random items are fine here
task.spawn(function()
	if Policy.paidRandomOk() and UI.isOpen("Eggs") then
		eggs.refresh()
	end
end)

eggs.refresh = function()
	local d = State.data
	UI.clear(eggs.list)
	if not d then
		return
	end
	for i, egg in Config.EGGS do
		-- an egg bought with Robux is a paid random item: only where Roblox's policy allows it (Policy)
		if egg.currency ~= "robux" or Policy.known() == true then
			eggCard(eggs.list, i, egg, d)
		end
	end
	local luck = d.hatchLuck or 1
	local line = UI.text(eggs.list, if luck > 1 then ("Your Hatch Luck: x%s - Epic and rarer critters are more likely"):format(tostring(luck)) else "Hatch Luck passes in the Shop make Epic and rarer critters more likely", UDim2.new(1, -20, 0, 26), { stroke = 2 })
	line.LayoutOrder = 99
end

-- PETS tab, laid out like Chop A Forest's: Equipped x/3 (three slots) and the Team boost on top, Other Pets (your
-- other critters, n / max) below, and the picked critter's big white card on the right, outside the board.
local STAR = "rbxassetid://97457865936415" -- white star with a navy outline, tinted (Store Icons/ClassArt/UIStar.png)
local STARS = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 6 }
local petGrid = pets.list :: ScrollingFrame
local petLayout = Instance.new("UIGridLayout")
petLayout.CellSize = UDim2.fromOffset(104, 124)
petLayout.CellPadding = UDim2.fromOffset(10, 10)
petLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
petLayout.SortOrder = Enum.SortOrder.LayoutOrder
local oldLayout = petGrid:FindFirstChildOfClass("UIListLayout")
if oldLayout then
	oldLayout:Destroy()
end
petLayout.Parent = petGrid
local P = pets.panel

-- a pill title on a section's top edge, with a picture poking out on the left
local function pillHeader(parent: Instance, text: string, color: Color3, icon: string, pos: UDim2, width: number): TextLabel
	return Skin.pill(parent, text, color, icon, pos - UDim2.fromOffset(0, 3), width)
end

local eqBox = UI.section(P, UDim2.fromOffset(392, 170), UDim2.fromOffset(22, 46))
local eqTitle = pillHeader(P, "Equipped 0/3", C.orange, "paw", UDim2.fromOffset(150, 28), 190)
local slots: { Frame } = {}
for i = 1, Config.PET_EQUIP do
	local slot = UI.frame({ size = UDim2.fromOffset(108, 108), pos = UDim2.fromOffset(18 + (i - 1) * 124, 42), color = UI.shade(W.inset, 0.88), parent = eqBox, radius = 12, outline = 3, name = "Slot" .. i })
	-- the HUD's wooden hotbar tile; the ring only lights up (in the rarity colour) when a critter sits here
	slot.BackgroundTransparency = 1
	local tile = Skin.frame(slot, "ui_tile", Vector2.new(108, 108), { name = "Tile", stretch = false })
	tile.Size = UDim2.fromScale(1, 1)
	local ring = slot:FindFirstChildOfClass("UIStroke") :: UIStroke
	ring.Transparency = 1
	ring.Thickness = 4
	UI.text(slot, "EMPTY", UDim2.new(1, -20, 0, 22), { pos = UDim2.new(0, 10, 0.5, -11), color = Color3.fromRGB(150, 104, 62), stroke = 0, name = "Empty" })
	local holder = Instance.new("Frame")
	holder.Name = "Pet"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = slot
	table.insert(slots, slot)
end
local boostBox = UI.section(P, UDim2.fromOffset(372, 170), UDim2.fromOffset(426, 46))
UI.text(boostBox, "Team boost", UDim2.new(1, -20, 0, 26), { pos = UDim2.fromOffset(10, 12), color = W.cream, stroke = 2 })
local boostText = UI.text(boostBox, "+0%", UDim2.new(1, -20, 0, 66), { pos = UDim2.fromOffset(10, 46), color = Color3.fromRGB(110, 230, 80), stroke = 4 })
UI.text(boostBox, ("Up to %d pets at once"):format(Config.PET_EQUIP), UDim2.new(1, -20, 0, 20), { pos = UDim2.new(0, 10, 1, -32), color = W.cream, stroke = 1.5 })
local otherBox = UI.section(P, UDim2.fromOffset(776, 280), UDim2.fromOffset(22, 238))
local _ = otherBox
pillHeader(P, "Other Pets", W.blue, "egg", UDim2.fromOffset(330, 220), 180)
local countChip = UI.frame({ size = UDim2.fromOffset(120, 32), pos = UDim2.fromOffset(34, 222), color = Color3.fromRGB(60, 36, 20), parent = P, radius = 10, outline = 3, name = "Count" })
UI.icon(countChip, "egg", 28, UDim2.fromOffset(4, 2))
local countText = UI.text(countChip, "0/60", UDim2.new(1, -40, 1, -8), { pos = UDim2.fromOffset(36, 4), align = Enum.TextXAlignment.Left, stroke = 1.5 })
UI.raise(countChip, 5)
local bestBtn = UI.button(P, "EQUIP BEST", C.green, UDim2.fromOffset(160, 38), function()
	State.fire("Pet", "best")
end, { pos = UDim2.new(1, -54, 0, 218), anchor = Vector2.new(1, 0), name = "Best" })
UI.raise(bestBtn, 5)
petGrid.Size = UDim2.fromOffset(756, 232)
petGrid.Position = UDim2.fromOffset(34, 272)
petGrid.ZIndex = 3

-- the big white card on the right (tilted a little, like a trading card held up)
local function bigCard(parent: Instance): { [string]: any }
	local card = UI.frame({ size = UDim2.fromOffset(300, 520), pos = UDim2.new(1, 36, 0, 0), color = Color3.new(1, 1, 1), parent = parent, radius = 26, outline = 5, name = "PetCard" })
	card.Rotation = 2
	;(card:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.fromRGB(40, 40, 60)
	local hasArt = Skin.has("ui_pcard")
	if hasArt then
		-- the ForgeGUI wood-rimmed collector card
		card.BackgroundTransparency = 1
		;(card:FindFirstChildOfClass("UIStroke") :: UIStroke).Enabled = false
		Skin.frame(card, "ui_pcard", Vector2.new(300, 520), { name = "Art", boost = 1.1 })
	end
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.fromRGB(255, 255, 250), Color3.fromRGB(196, 212, 236))
	g.Rotation = 90
	g.Parent = card
	local inner = UI.frame({ size = UDim2.new(1, -20, 1, -20), pos = UDim2.fromOffset(10, 10), color = Color3.new(1, 1, 1), parent = card, radius = 18, outline = 2, name = "Inner" })
	inner.BackgroundTransparency = 1
	inner.Visible = not hasArt
	;(inner:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.fromRGB(200, 210, 230)
	for _, sp in { { 0.82, 0.2, 34 }, { 0.2, 0.62, 26 }, { 0.75, 0.8, 40 } } do
		local st = Instance.new("ImageLabel")
		st.BackgroundTransparency = 1
		st.Image = "rbxassetid://116900531496449"
		st.ImageColor3 = Color3.new(1, 1, 1)
		st.Size = UDim2.fromOffset(sp[3], sp[3])
		st.Position = UDim2.fromScale(sp[1], sp[2])
		st.AnchorPoint = Vector2.new(0.5, 0.5)
		st.Parent = card
		TweenService:Create(st, TweenInfo.new(1 + sp[1], Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { ImageTransparency = 0.8 }):Play()
	end
	local title = UI.text(card, "", UDim2.new(1, -40, 0, 46), { pos = UDim2.fromOffset(20, 22), stroke = 3.5, name = "Title" })
	local starBar = UI.frame({ size = UDim2.fromOffset(236, 40), pos = UDim2.new(0.5, 0, 0, 74), anchor = Vector2.new(0.5, 0), color = Color3.fromRGB(150, 150, 165), parent = card, radius = 20, outline = 0, name = "Stars" })
	starBar.BackgroundTransparency = 0.35
	local stars: { ImageLabel } = {}
	for i = 1, 6 do
		local im = Instance.new("ImageLabel")
		im.BackgroundTransparency = 1
		im.Image = STAR
		im.Size = UDim2.fromOffset(32, 32)
		im.Position = UDim2.fromOffset(8 + (i - 1) * 37, 4)
		im.Parent = starBar
		table.insert(stars, im)
	end
	local view = Instance.new("Frame")
	view.Name = "View"
	view.BackgroundTransparency = 1
	view.Size = UDim2.fromOffset(240, 200)
	view.Position = UDim2.new(0.5, 0, 0, 122)
	view.AnchorPoint = Vector2.new(0.5, 0)
	view.Parent = card
	local rarity = UI.frame({ size = UDim2.fromOffset(138, 34), pos = UDim2.new(0.5, -58, 0, 330), anchor = Vector2.new(0.5, 0), color = Color3.new(1, 1, 1), parent = card, radius = 12, outline = 3, name = "Rarity" })
	rarity.Rotation = -2
	local rarityText = UI.text(rarity, "", UDim2.new(1, -10, 1, -8), { pos = UDim2.fromOffset(5, 4), stroke = 2 })
	local state = UI.frame({ size = UDim2.fromOffset(122, 34), pos = UDim2.new(0.5, 70, 0, 334), anchor = Vector2.new(0.5, 0), color = Color3.fromRGB(80, 80, 92), parent = card, radius = 12, outline = 3, name = "State" })
	state.Rotation = 3
	local stateText = UI.text(state, "", UDim2.new(1, -10, 1, -8), { pos = UDim2.fromOffset(5, 4), stroke = 2 })
	local info = UI.frame({ size = UDim2.new(1, -36, 0, 128), pos = UDim2.fromOffset(18, 374), color = Color3.fromRGB(110, 114, 132), parent = card, radius = 14, outline = 0, name = "Info" })
	info.BackgroundTransparency = 0.45
	local empty = UI.text(card, "", UDim2.new(1, -40, 0, 50), { pos = UDim2.new(0, 20, 0.5, -60), stroke = 3.5, name = "Empty" })
	return { card = card, title = title, stars = stars, view = view, rarity = rarity, rarityText = rarityText, state = state, stateText = stateText, info = info, empty = empty }
end
PetsWindow.bigCard = bigCard
local side = bigCard(pets.frame)
local sideBtn = UI.button(side.card, "EQUIP", C.green, UDim2.fromOffset(220, 48), function() end, { pos = UDim2.new(0.5, 0, 1, -28), anchor = Vector2.new(0.5, 1), name = "Equip" })
local pickedUid: number? = nil

-- Show one critter on a big card (`found` false = a black silhouette with ???).
local function fillCard(c, p, found: boolean)
	local show = p ~= nil
	for _, k in { c.title, c.rarity, c.state, c.info } do
		k.Visible = show
	end
	for _, st in c.stars do
		st.Parent.Visible = show
	end
	c.empty.Visible = not show
	for _, k in c.view:GetChildren() do
		k:Destroy()
	end
	if not p then
		return
	end
	local rc = Config.RARITY_COLORS[p.rarity]
	c.title.Text = if found then p.name else "???"
	for i, st in c.stars do
		st.ImageColor3 = if i <= (STARS[p.rarity] or 1) then Color3.fromRGB(255, 205, 50) else Color3.fromRGB(110, 100, 90)
	end
	if found then
		Skin.rays(c.view, rc, 280, nil, 16)
	end
	local vp = petView(c.view, p.look, 200, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	if not found then
		vp.ImageColor3 = Color3.new(0, 0, 0)
	end
	c.rarity.BackgroundColor3 = UI.shade(rc, 0.8)
	c.rarityText.Text = string.upper(p.rarity)
	c.rarityText.TextColor3 = Color3.new(1, 1, 1)
end
PetsWindow.fillCard = fillCard

pets.refresh = function()
	local d = State.data
	UI.clear(petGrid)
	for _, slot in slots do
		UI.clear(slot:FindFirstChild("Pet") :: Frame)
		;(slot:FindFirstChild("Empty") :: TextLabel).Visible = true
		;(slot:FindFirstChildOfClass("UIStroke") :: UIStroke).Transparency = 1
	end
	if not d then
		return
	end
	local list = d.pets or {}
	local on, rest = {}, {}
	for _, e in list do
		table.insert(if e.on then on else rest, e)
	end
	eqTitle.Text = ("Equipped %d/%d"):format(#on, Config.PET_EQUIP)
	countText.Text = ("%d/%d"):format(#list, Config.PET_MAX)
	local total = 0
	for i, e in on do
		local p = Config.pet(e.id)
		if p then
			for _, k in Config.PET_STATS do
				total += (p :: any)[k] or 0
			end
			local slot = slots[i]
			if slot then
				local emptyLabel = slot:FindFirstChild("Empty") :: TextLabel
				emptyLabel.Visible = false
				local ring = slot:FindFirstChildOfClass("UIStroke") :: UIStroke
				ring.Color = Config.RARITY_COLORS[p.rarity]
				ring.Transparency = 0
				local holder = slot:FindFirstChild("Pet") :: Frame
				petView(holder, p.look, 96, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
				local b = Instance.new("TextButton")
				b.BackgroundTransparency = 1
				b.Text = ""
				b.Size = UDim2.fromScale(1, 1)
				b.Parent = holder
				UI.clicky(b)
				b.MouseButton1Click:Connect(function()
					pickedUid = e.uid
					pets.refresh()
				end)
			end
		end
	end
	boostText.Text = ("+%d%%"):format(math.floor(total * 100 + 0.5))
	if #rest == 0 then
		local t = UI.text(petGrid, if #list == 0 then "Open eggs to hatch more pets!" else "Every critter you have is equipped", UDim2.fromOffset(500, 34), { stroke = 2, color = W.cream })
		t.Size = UDim2.fromOffset(500, 34)
	end
	table.sort(rest, function(a, b)
		local pa, pb = Config.pet(a.id), Config.pet(b.id)
		local ra = pa and table.find({ "Secret", "Mythic", "Legendary", "Epic", "Rare", "Uncommon", "Common" }, pa.rarity) or 9
		local rb = pb and table.find({ "Secret", "Mythic", "Legendary", "Epic", "Rare", "Uncommon", "Common" }, pb.rarity) or 9
		if ra ~= rb then
			return ra < rb
		end
		return a.uid < b.uid
	end)
	for i, e in rest do
		local p = Config.pet(e.id)
		if not p then
			continue
		end
		local rc = Config.RARITY_COLORS[p.rarity]
		local card = Skin.tile(rc, e.uid == pickedUid, Vector2.new(104, 124))
		card.Name = "Pet_" .. e.uid
		card.LayoutOrder = i
		petView(card, p.look, 80, UDim2.new(0.5, 0, 0, 4), Vector2.new(0.5, 0))
		UI.text(card, p.name, UDim2.new(1, -10, 0, 26), { pos = UDim2.fromOffset(5, 84), stroke = 2, textSize = 14 })
		if BIG[p.rarity] and e.uid ~= pickedUid then
			Skin.sparkles(card, 0.8, UI.shade(rc, 1.5))
		end
		card.MouseButton1Click:Connect(function()
			pickedUid = e.uid
			pets.refresh()
		end)
		card.Parent = petGrid
	end
	-- the big card: the picked critter (or the first equipped one)
	local picked = nil
	for _, e in list do
		if e.uid == pickedUid then
			picked = e
		end
	end
	picked = picked or on[1] or rest[1]
	local p = picked and Config.pet(picked.id)
	fillCard(side, p, true)
	side.empty.Text = "No pets yet"
	sideBtn.Visible = p ~= nil
	UI.clear(side.info)
	if picked and p then
		side.stateText.Text = if picked.on then "EQUIPPED" else "OWNED"
		side.state.BackgroundColor3 = if picked.on then C.green else Color3.fromRGB(80, 80, 92)
		local y = 8
		for _, k in Config.PET_STATS do
			local v = (p :: any)[k]
			if v and v > 0 then
				UI.text(side.info, ("+%d%% %s"):format(math.floor(v * 100 + 0.5), k), UDim2.new(1, -20, 0, 26), { pos = UDim2.fromOffset(10, y), align = Enum.TextXAlignment.Left, color = Color3.fromRGB(170, 255, 140), stroke = 2 })
				y += 28
			end
		end
		UI.setButton(sideBtn, if picked.on then "UNEQUIP" else "EQUIP", if picked.on then Color3.fromRGB(200, 80, 70) else C.green)
		local uid, isOn = picked.uid, picked.on
		sideBtn:SetAttribute("Uid", uid)
		sideBtn:SetAttribute("On", isOn)
	end
end
sideBtn.MouseButton1Click:Connect(function()
	local uid = sideBtn:GetAttribute("Uid")
	if type(uid) == "number" then
		State.fire("Pet", if sideBtn:GetAttribute("On") then "unequip" else "equip", uid)
	end
end)

-------------------------------------------------------------------------------------------------------------
-- hatching: dim, egg wobbles + cracks, the critter pops out (one after another for 3 / 10)
-------------------------------------------------------------------------------------------------------------
local hatching = false
local function hatchShow(eggId: string, ids: { string })
	local egg = Config.egg(eggId)
	if not egg then
		return
	end
	hatching = true
	-- like Chop A Forest, the menu gets out of the way while the egg hatches, and comes back after
	local reopen = nil
	for _, w in { "Eggs", "Pets", "Store" } do
		if UI.isOpen(w) then
			reopen = w
		end
	end
	UI.close()
	local root = Instance.new("Frame")
	root.Name = "Hatch"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(1280, 720)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.ZIndex = 60
	root.Parent = UI.gui
	-- dark navy backdrop that fades in (45% black was too faint over a sunny lobby)
	local dim = UI.frame({ size = UDim2.fromScale(4, 4), pos = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), color = Color3.fromRGB(10, 8, 24), parent = root, radius = 0, outline = 0, name = "Dim" })
	dim.BackgroundTransparency = 1
	TweenService:Create(dim, TweenInfo.new(0.25), { BackgroundTransparency = 0.2 }):Play()
	local many = #ids > 1
	local cols = math.min(#ids, 5)
	local cellW = if many then 220 else 0
	for i, id in ids do
		local p = Config.pet(id)
		if not p then
			continue
		end
		local rc = Config.RARITY_COLORS[p.rarity]
		local col, rowI = (i - 1) % cols, (i - 1) // cols
		local cx = if many then 640 + (col - (cols - 1) / 2) * cellW else 640
		local cy = if many then 300 + rowI * 250 else 330
		local scale = if many then 0.7 else 1
		-- the egg's picture wobbles, then bursts
		local shell = UI.icon(root, eggIcon(egg), 200 * scale, UDim2.fromOffset(cx, cy), Vector2.new(0.5, 0.5))
		shell.Name = "Shell" .. i
		task.delay((i - 1) * 0.35, function()
			-- wobble
			for k = 1, 4 do
				local tw = TweenService:Create(shell, TweenInfo.new(0.09, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Rotation = if k % 2 == 0 then 14 else -14 })
				tw:Play()
				tw.Completed:Wait()
			end
			TweenService:Create(shell, TweenInfo.new(0.08), { Rotation = 0 }):Play()
			Sound.play("chip")
			task.wait(0.1)
			-- crack: the shell bursts into bits, the critter appears
			for b = 1, 8 do
				local bit = UI.frame({ size = UDim2.fromOffset(26 * scale, 22 * scale), pos = UDim2.fromOffset(cx, cy), anchor = Vector2.new(0.5, 0.5), color = UI.shade(egg.color, 1.35), parent = root, radius = 6, outline = 2 })
				local ang = b / 8 * math.pi * 2
				TweenService:Create(bit, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(cx + math.cos(ang) * 150 * scale, cy + math.sin(ang) * 110 * scale + 40), Rotation = math.random(-180, 180), BackgroundTransparency = 1 }):Play()
				task.delay(0.5, function()
					bit:Destroy()
				end)
			end
			shell:Destroy()
			Skin.rays(root, rc, 460 * scale, UDim2.fromOffset(cx, cy - 10), if BIG[p.rarity] then 6 else 12)
			local burst = UI.frame({ size = UDim2.fromOffset(20, 20), pos = UDim2.fromOffset(cx, cy), anchor = Vector2.new(0.5, 0.5), color = rc, parent = root, radius = 999, outline = 0, name = "Burst" })
			burst.BackgroundTransparency = 0.2
			TweenService:Create(burst, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(420 * scale, 420 * scale), BackgroundTransparency = 1 }):Play()
			-- a soft glow in the rarity colour stays behind the critter
			local halo = UI.frame({ size = UDim2.fromOffset(230 * scale, 230 * scale), pos = UDim2.fromOffset(cx, cy - 10), anchor = Vector2.new(0.5, 0.5), color = rc, parent = root, radius = 999, outline = 0, name = "Halo" })
			halo.BackgroundTransparency = 0.6
			local core = UI.frame({ size = UDim2.fromScale(0.62, 0.62), pos = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), color = UI.shade(rc, 1.3), parent = halo, radius = 999, outline = 0, name = "Core" })
			core.BackgroundTransparency = 0.55
			local haloGrad = Instance.new("UIGradient")
			haloGrad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
			haloGrad.Parent = halo
			local view = petView(root, p.look, 200 * scale, UDim2.fromOffset(cx, cy - 10), Vector2.new(0.5, 0.5))
			UI.bounce(view)
			local name = UI.text(root, p.name, UDim2.fromOffset(260 * scale, 40 * scale), { pos = UDim2.fromOffset(cx, cy + 90 * scale), anchor = Vector2.new(0.5, 0), stroke = 3 })
			local rar = UI.text(root, string.upper(p.rarity), UDim2.fromOffset(200 * scale, 26 * scale), { pos = UDim2.fromOffset(cx, cy + 130 * scale), anchor = Vector2.new(0.5, 0), color = UI.shade(rc, 1.3), stroke = 2.5 })
			UI.bounce(name)
			if BIG[p.rarity] then
				Sound.play("reveal")
				Confetti.burst(60)
				local flash = UI.frame({ size = UDim2.fromScale(4, 4), pos = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), color = Color3.new(1, 1, 1), parent = root, radius = 0, outline = 0 })
				TweenService:Create(flash, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			else
				Sound.play("upgrade")
			end
			local _ = rar
		end)
	end
	local hint = UI.text(root, "Click to continue", UDim2.fromOffset(300, 24), { pos = UDim2.new(0.5, 0, 1, -40), anchor = Vector2.new(0.5, 1), color = Color3.fromRGB(230, 230, 235), stroke = 1.5 })
	hint.Visible = false
	local done = Instance.new("TextButton")
	done.Text = ""
	done.BackgroundTransparency = 1
	done.Size = UDim2.fromScale(4, 4)
	done.Position = UDim2.fromScale(0.5, 0.5)
	done.AnchorPoint = Vector2.new(0.5, 0.5)
	done.ZIndex = 61
	done.Parent = root
	local total = (#ids - 1) * 0.35 + 1.2
	task.delay(total, function()
		hint.Visible = true
	end)
	done.MouseButton1Click:Connect(function()
		if os.clock() - (root:GetAttribute("t0") :: number) < total then
			return
		end
		root:Destroy()
		hatching = false
		if reopen then
			UI.open(reopen)
		end
	end)
	root:SetAttribute("t0", os.clock())
end

State.on("fx", function(kind, d)
	if kind == "hatch" and type(d) == "table" and d.pets then
		if hatching then
			local old = UI.gui:FindFirstChild("Hatch")
			if old then
				old:Destroy()
			end
		end
		hatchShow(d.egg, d.pets)
	end
end)

function PetsWindow.open()
	UI.open("Pets")
end

PetsWindow.petView = petView

return PetsWindow
