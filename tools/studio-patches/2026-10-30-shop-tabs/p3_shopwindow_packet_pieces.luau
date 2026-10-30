local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.ShopWindow
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "17239 1319058608" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[	local _art, face = Skin.frame(b, "ui_packet", PACKET, { name = "Art", boost = 1.3, tint = if active then color else color:Lerp(Color3.new(1, 1, 1), 0.5) })
]======], [======[	local tint = if active then color else color:Lerp(Color3.new(1, 1, 1), 0.5)
	local _, face = packetArt(b, PACKET, tint)
	if not face then
		local _frame, standIn = Skin.frame(b, "ui_packet", PACKET, { name = "Art", boost = 1.3, tint = tint })
		face = standIn
	end
	assert(face, "the packet has a face")
]======] },
	{ [======[}
local function sign(parent: Instance, i: number, cat, active: boolean, onClick: () -> ()): TextButton
]======], [======[}
-- The packet picture drawn as three pieces of the one image (the crimped left end, the middle stretched wide, the
-- right end), every piece scaled to the tab's height by the same amount. (30 Oct, owner: "fix broken ui": the picture
-- is drawn slanted, and Roblox's 9-slice of it left a seam and a step at the right end on tabs this small, even with
-- a thin middle row; pieces cut with ImageRectOffset line up exactly.) Returns the holder and its face (the flat
-- inside, where the name goes), or nil when the picture isn't uploaded (then Skin.frame draws its stand-in).
local PACKET_ART = { w = 768, h = 574, left = 170, right = 640, face = { 160, 110, 60, 100 } }
local function packetArt(parent: Instance, size: Vector2, tint: Color3): (Frame?, Frame?)
	local id = Config.ICONS and Config.ICONS.ui_packet
	if not id or id == "" then
		return nil, nil
	end
	local a = PACKET_ART
	local k = size.Y / a.h
	local lw, rw = a.left * k, (a.w - a.right) * k
	local holder = Instance.new("Frame")
	holder.Name = "Art"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(size.X, size.Y)
	local function piece(name: string, x0: number, x1: number, at: number, width: number)
		local img = Instance.new("ImageLabel")
		img.Name = name
		img.BackgroundTransparency = 1
		img.Image = id
		img.ImageColor3 = tint
		img.ImageRectOffset = Vector2.new(x0, 0)
		img.ImageRectSize = Vector2.new(x1 - x0, a.h)
		img.ScaleType = Enum.ScaleType.Stretch
		img.Position = UDim2.fromOffset(at, 0)
		img.Size = UDim2.fromOffset(width, size.Y)
		img.Parent = holder
	end
	-- (the middle first and a little wider, so the two ends sit over its edges: no hairline gap between them)
	piece("Middle", a.left, a.right, lw - 0.5, size.X - lw - rw + 1)
	piece("Left", 0, a.left, 0, lw)
	piece("Right", a.right, a.w, size.X - rw, rw)
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.BackgroundTransparency = 1
	local l, t, r, b = a.face[1] * k, a.face[2] * k, a.face[3] * k, a.face[4] * k
	face.Position = UDim2.fromOffset(l, t)
	face.Size = UDim2.new(1, -(l + r), 1, -(t + b))
	face.Parent = holder
	holder.Parent = parent
	return holder, face
end

local function sign(parent: Instance, i: number, cat, active: boolean, onClick: () -> ()): TextButton
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "19536 733977539" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
