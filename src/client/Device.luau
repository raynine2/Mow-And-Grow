-- What the game is played on, decided in one place so every module agrees.
--   Device.touch  a touch screen with no keyboard (phones and tablets): the touch layout and lighter graphics
--   Device.phone  a touch screen whose shorter side is 500 points or less (Roblox's own line between a phone and a
--                 tablet: under it the thumbstick and jump button are drawn small)
--   Device.preview  Studio only: this PC is pretending to be a phone (see below)
--
-- Phone preview (Studio, for testing the phone layout without a phone): set the Workspace attribute PhonePreview
-- to true (or "844x390" for another screen) and press Play. The HUD, windows and films take their phone layout, the
-- phone graphics settings apply (client/PhonePerf), and client/PhonePreview draws where Roblox's thumbstick, jump
-- button and top bar and an iPhone's notch would be. Studio's screen is a little less wide than a modern phone's
-- (about 16:9, like an iPhone SE), so if the layout fits here it fits on every phone. Live servers ignore it.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Device = {}

local function previewSize(v: any): Vector2?
	if v == true then
		return Vector2.new(844, 390) -- an iPhone 14 on its side
	elseif type(v) == "string" then
		local w, h = string.match(v, "^(%d+)%s*[xX]%s*(%d+)$")
		if w and h then
			return Vector2.new(math.max(tonumber(w) :: number, tonumber(h) :: number), math.min(tonumber(w) :: number, tonumber(h) :: number))
		end
		return if v ~= "" and string.lower(v) ~= "off" then Vector2.new(844, 390) else nil
	end
	return nil
end

-- (the place's own setting, so it's there before the first module loads)
Device.previewScreen = if RunService:IsStudio() then previewSize(workspace:GetAttribute("PhonePreview")) else nil
Device.preview = Device.previewScreen ~= nil

Device.touch = Device.preview or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)

local function shortSide(): number
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.zero
	-- (no screen size yet: most touch screens are phones)
	return if vp.X > 100 and vp.Y > 100 then math.min(vp.X, vp.Y) else 0
end
Device.phone = Device.preview or (Device.touch and shortSide() <= 500)

-- Studio pixels per point of the previewed phone (its height fills Studio's screen)
function Device.previewScale(): number
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	return if Device.previewScreen then vp.Y / Device.previewScreen.Y else 1
end

-- Roblox's top bar height on this screen, in pixels (its buttons don't shrink with our UI). The preview's phone gets a
-- 58-point bar, the same height as on a computer.
function Device.topInset(): number
	if Device.preview then
		return 58 * Device.previewScale()
	end
	return game:GetService("GuiService"):GetGuiInset().Y
end

-- How far Roblox's own buttons reach along the top of the screen from the left, in pixels.
function Device.topbarWidth(): number
	if Device.preview then
		return 210 * Device.previewScale()
	end
	local ok, r = pcall(function()
		return game:GetService("GuiService").TopbarInset
	end)
	if ok and typeof(r) == "Rect" and r.Min.X > 0 then
		return r.Min.X
	end
	return 210
end

return Device
