local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.PartyWindow
local s = m.Source
if string.find(s, [======[Vector2.new(W, 442)]======], 1, true) then
	return m.Name .. " already has this patch"
end
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
local edits = {
	{ [======[	local chip = frame(parent, UDim2.fromOffset(w, 44), pos, NIGHT, 14)]======], [======[	local chip = frame(parent, UDim2.fromOffset(w, 50), pos, NIGHT, 16)]======] },
	{ [======[	UI.icon(chip, pic, 34, UDim2.new(0, 8, 0.5, 0), Vector2.new(0, 0.5))
	text(chip, value, UDim2.new(1, -54, 0, 22), UDim2.fromOffset(48, 4), STAR, 2, Enum.TextXAlignment.Left)
	text(chip, word, UDim2.new(1, -54, 0, 14), UDim2.fromOffset(48, 26), DIM, 0, Enum.TextXAlignment.Left)]======], [======[	UI.icon(chip, pic, 38, UDim2.new(0, 8, 0.5, 0), Vector2.new(0, 0.5))
	text(chip, value, UDim2.new(1, -58, 0, 25), UDim2.fromOffset(52, 4), STAR, 2, Enum.TextXAlignment.Left)
	text(chip, word, UDim2.new(1, -58, 0, 17), UDim2.fromOffset(52, 29), DIM, 0, Enum.TextXAlignment.Left)]======] },
	{ [======[Vector2.new(W, 414), { name = "RunCard", maxScale = 0.32 })]======], [======[Vector2.new(W, 442), { name = "RunCard", maxScale = 0.32 })]======] },
	{ [======[	pic.Size = UDim2.fromOffset(W - 36, 186)]======], [======[	pic.Size = UDim2.fromOffset(W - 36, 206)]======] },
	{ [======[	headshot(card, 76, UDim2.fromOffset(26, 160))
	text(card, "SOLO RUN", UDim2.fromOffset(250, 30), UDim2.fromOffset(112, 212), WHITE, 2.5, Enum.TextXAlignment.Left)
	text(card, "started " .. ago(run.started or now, now), UDim2.fromOffset(250, 18), UDim2.fromOffset(112, 244), DIM, 0, Enum.TextXAlignment.Left)]======], [======[	headshot(card, 76, UDim2.fromOffset(26, 180))
	text(card, "SOLO RUN", UDim2.fromOffset(250, 30), UDim2.fromOffset(112, 232), WHITE, 2.5, Enum.TextXAlignment.Left)
	text(card, "started " .. ago(run.started or now, now), UDim2.fromOffset(250, 18), UDim2.fromOffset(112, 264), DIM, 0, Enum.TextXAlignment.Left)]======] },
	{ [======["clumps cut", UDim2.fromOffset(18, 272), half)]======], [======["clumps cut", UDim2.fromOffset(18, 292), half)]======] },
	{ [======["played", UDim2.fromOffset(28 + half, 272), half)]======], [======["played", UDim2.fromOffset(28 + half, 292), half)]======] },
	{ [======[UDim2.fromOffset(W - 36, 64), UDim2.fromOffset(18, 330), GREEN, function()]======], [======[UDim2.fromOffset(W - 36, 64), UDim2.fromOffset(18, 358), GREEN, function()]======] },
	{ [======[UDim2.new(1, 0, 0, 28), UDim2.fromOffset(0, 428), WHITE)]======], [======[UDim2.new(1, 0, 0, 28), UDim2.fromOffset(0, 460), WHITE)]======] },
	{ [======[	local card = Skin.frame(list, "gg_card", Vector2.new(384, 290), { name = "Empty", maxScale = 0.32 })
	if card:IsA("ImageLabel") then
		card.ImageTransparency = 0.15
	end
	local moon = UI.icon(card, "moon", 118, UDim2.new(0.5, 0, 0, 26), Vector2.new(0.5, 0))
	moon.Rotation = -8
	for i, p in { { -96, 50, 30 }, { 92, 36, 24 }, { 74, 126, 20 }, { -70, 140, 16 } } do]======], [======[	-- (in the middle of the page, so it doesn't look like something's missing below it)
	local card = Skin.frame(list, "gg_card", Vector2.new(384, 360), { name = "Empty", maxScale = 0.32, pos = UDim2.fromOffset(0, 56) })
	if card:IsA("ImageLabel") then
		card.ImageTransparency = 0.15
	end
	local moon = UI.icon(card, "moon", 146, UDim2.new(0.5, 0, 0, 30), Vector2.new(0.5, 0))
	moon.Rotation = -8
	for i, p in { { -104, 60, 34 }, { 100, 42, 26 }, { 84, 150, 22 }, { -84, 166, 18 } } do]======] },
	{ [======[	text(card, "NO SAVED RUNS YET", UDim2.new(1, -60, 0, 34), UDim2.fromOffset(30, 162), WHITE, 3)
	text(card, "Start one on the left - it shows up here.", UDim2.new(1, -70, 0, 20), UDim2.fromOffset(35, 206), DIM, 0)
	text(card, "Your run saves by itself.", UDim2.new(1, -70, 0, 18), UDim2.fromOffset(35, 234), LEAF, 0)]======], [======[	text(card, "NO SAVED RUNS YET", UDim2.new(1, -60, 0, 38), UDim2.fromOffset(30, 200), WHITE, 3)
	text(card, "Start one on the left - it shows up here.", UDim2.new(1, -70, 0, 22), UDim2.fromOffset(35, 252), DIM, 0)
	text(card, "Your run saves by itself.", UDim2.new(1, -70, 0, 20), UDim2.fromOffset(35, 284), LEAF, 0)]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "NOT CHANGED: edit " .. k .. " not found once in " .. m.Name
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
