-- Bright, sunny, saturated look for both modes, and a clean Workspace to build in.
local Lighting = game:GetService("Lighting")

local Environment = {}

function Environment.apply()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(120, 115, 130)
	Lighting.OutdoorAmbient = Color3.fromRGB(165, 160, 170)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3

	local function ensure(className: string, name: string)
		local inst = Lighting:FindFirstChild(name)
		if not inst then
			inst = Instance.new(className)
			inst.Name = name
			inst.Parent = Lighting
		end
		return inst
	end
	local cc = ensure("ColorCorrectionEffect", "MowALawnColor") :: ColorCorrectionEffect
	cc.Saturation = 0.18
	cc.Contrast = 0.06
	cc.Brightness = 0.02
	local atmo = ensure("Atmosphere", "MowALawnAtmosphere") :: Atmosphere
	atmo.Density = 0.18
	atmo.Haze = 0
	atmo.Color = Color3.fromRGB(200, 225, 255)
	atmo.Decay = Color3.fromRGB(150, 190, 255)
	local bloom = ensure("BloomEffect", "MowALawnBloom") :: BloomEffect
	bloom.Intensity = 0.4
	bloom.Size = 20
	bloom.Threshold = 1.6

	-- The default Baseplate place has a grey baseplate and spawn; our maps replace them at runtime only
	-- (the place file keeps them).
	local base = workspace:FindFirstChild("Baseplate")
	if base and base:IsA("BasePart") then
		base:Destroy()
	end
	for _, inst in workspace:GetChildren() do
		if inst:IsA("SpawnLocation") then
			inst:Destroy()
		end
	end
	local old = workspace:FindFirstChild("World")
	if old then
		old:Destroy()
	end
	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace
	return world
end

function Environment.spawn(parent: Instance, cf: CFrame)
	local s = Instance.new("SpawnLocation")
	s.Size = Vector3.new(10, 1, 10)
	s.CFrame = cf
	s.Anchored = true
	s.Neutral = true
	s.Duration = 0
	s.Color = Color3.fromRGB(196, 150, 100)
	s.TopSurface = Enum.SurfaceType.Smooth
	s.Material = Enum.Material.WoodPlanks
	local decal = s:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	s.Parent = parent
	return s
end

return Environment
