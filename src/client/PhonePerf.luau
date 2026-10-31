-- Phones and tablets only (owner, 26 Oct: "make sure the game runs well on mobile"; the cuts he OK'd: shadows
-- off, bloom and sun rays off, lighter boss effects). A device counts as a phone when it has a touch screen and no
-- keyboard or mouse; PCs, consoles and touch laptops look exactly as before.
--   * Lighting.GlobalShadows off (kept off if the server or a cutscene turns it back on)
--   * every BloomEffect / SunRaysEffect in Lighting off, including ones made later (a run resets Lighting)
--   * client/BossVfx reads PhonePerf.on: about half the particles in boss hits and no thorn / stone spikes
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local PhonePerf = {}

PhonePerf.on = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.MouseEnabled

local function keepOff(inst: Instance)
	if inst:IsA("BloomEffect") or inst:IsA("SunRaysEffect") then
		inst.Enabled = false
		inst:GetPropertyChangedSignal("Enabled"):Connect(function()
			if inst.Enabled then
				inst.Enabled = false
			end
		end)
	end
end

if PhonePerf.on then
	Lighting.GlobalShadows = false
	Lighting:GetPropertyChangedSignal("GlobalShadows"):Connect(function()
		if Lighting.GlobalShadows then
			Lighting.GlobalShadows = false
		end
	end)
	for _, c in Lighting:GetChildren() do
		keepOff(c)
	end
	Lighting.ChildAdded:Connect(keepOff)
end

return PhonePerf
