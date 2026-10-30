local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.TextStyle
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "12264 1639211097" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[		t.Font = FONT
	end
]======], [======[		t.Font = FONT
	end
	-- the galaxy theme: dark ink turns light (before the outline is decided)
	if inkIn(t, layer) then
		lighten(t)
	end
]======] },
	{ [======[

-- What a text is drawn in: its gui (nil = not drawn, or one to leave alone) and whether it's a button's label.
]======], [======[

-- (30 Oct, the grass-galaxy theme: Config.UI.theme "galaxy") The windows and cards are a night sky now, so the dark
-- ink the garden kit wrote on its cream wood would vanish. In the game's own screen (MowALawnGui) a dark text turns
-- light: near-black and dark brown to the star white, mid browns to the dim lavender (and then gets our outline). It
-- stays light when its code sets the dark colour again. Opt out (a word on something still pale): the attribute
-- KeepInk = true on the text or a frame above it.
TextStyle.KEEP_INK = "KeepInk"
local GALAXY = Config.UI.theme == "galaxy"
local STAR = Config.UI.starText or Color3.fromRGB(240, 234, 255)
local DIM = Config.UI.dimText or Color3.fromRGB(190, 176, 236)
local MAIN_GUI = "MowALawnGui"

local function inkIn(t: Instance, layer: Instance): boolean
	if not GALAXY or layer.Name ~= MAIN_GUI or not layer:IsA("ScreenGui") then
		return false
	end
	local o: Instance? = t
	while o and o ~= layer do
		if o:GetAttribute(TextStyle.KEEP_INK) == true then
			return false
		end
		o = o.Parent
	end
	return true
end

local function lighten(t: any)
	local ref = setmetatable({ t = t }, WEAK_V)
	local function fix()
		local l = ref.t
		if not l then
			return
		end
		local c: Color3 = l.TextColor3
		local lum = luminance(c)
		if lum < 0.42 then
			l.TextColor3 = if lum < 0.22 then STAR else DIM
		end
	end
	fix()
	t:GetPropertyChangedSignal("TextColor3"):Connect(fix)
end

-- What a text is drawn in: its gui (nil = not drawn, or one to leave alone) and whether it's a button's label.
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "13810 1063850367" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
