-- Bright, sunny, saturated look for both modes, and a clean Workspace to build in.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Look = require(ReplicatedStorage.MowALawn.Look)

local Ground = require(script.Parent.Ground)

local Environment = {}

local function ensure(parent: Instance, className: string, name: string): Instance
	local inst = parent:FindFirstChild(name)
	if not inst then
		inst = Instance.new(className)
		inst.Name = name
		inst.Parent = parent
	end
	return inst :: Instance
end

-- Lighting and post-processing from Config.LOOK: a warm afternoon sun with long soft shadows, haze toward the
-- horizon, gentle bloom on bright things only, a touch more colour, faint sun rays, a soft far blur, and
-- Roblox's built-in clouds. Built-in features only (no image assets). The client blends zone moods on top.
local function lighting()
	local look = Config.LOOK
	Lighting.ClockTime = look.clockTime
	Lighting.GeographicLatitude = look.latitude
	Lighting.EnvironmentDiffuseScale = look.envDiffuse
	Lighting.EnvironmentSpecularScale = look.envSpecular
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = look.shadowSoftness

	ensure(Lighting, "ColorCorrectionEffect", Look.NAMES.color)
	ensure(Lighting, "Atmosphere", Look.NAMES.atmosphere)
	local bloom = ensure(Lighting, "BloomEffect", Look.NAMES.bloom) :: BloomEffect
	bloom.Size = look.bloomSize
	bloom.Threshold = look.bloomThreshold
	ensure(Lighting, "SunRaysEffect", Look.NAMES.rays)
	local dof = ensure(Lighting, "DepthOfFieldEffect", Look.NAMES.depth) :: DepthOfFieldEffect
	dof.FocusDistance = look.dof.focus
	dof.InFocusRadius = look.dof.radius
	dof.FarIntensity = look.dof.far
	dof.NearIntensity = 0
	Look.apply(Look.mood(nil))

	-- a Sky only if the place has none (a hand-made sky is kept); the default skybox with a bigger sun
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if not sky then
		sky = Instance.new("Sky")
		sky.Name = "MowALawnSky"
		sky.Parent = Lighting
	end
	-- the place's own skybox (owner's, 13107344387) has its pale, cloudy side toward the camp spawn's view; turned
	-- half round so a player spawning in sees the blue side (owner, 27 Oct: too much white when you spawn)
	if sky and sky.Name ~= "MowALawnSky" then
		pcall(function()
			sky.SkyboxOrientation = Vector3.new(0, 180, 0)
		end)
	end
	if sky and sky.Name == "MowALawnSky" then
		sky.SunAngularSize = look.sunSize
		-- the sun and moon on, and a sky full of stars for the nights in a run (server/DayNight)
		pcall(function()
			sky.CelestialBodiesShown = true
			sky.StarCount = 3000
			sky.MoonAngularSize = 14
		end)
	end
	workspace.GlobalWind = look.wind
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
		clouds.Cover = look.clouds.cover
		clouds.Density = look.clouds.density
		clouds.Color = look.clouds.color
		local own = Lighting:FindFirstChildOfClass("Sky")
		clouds.Enabled = not (own and own.Name ~= "MowALawnSky") -- a hand-made sky stays visible
		clouds.Parent = terrain
	end
end

function Environment.apply()
	lighting()
	Ground.reset() -- the ground is Terrain; builders fill it after this

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
	-- (unseen: players still spawn on it, but the wooden slab sat on the plaza for nothing and showed in the
	-- films; owner, 29 Oct: "it's ugly and doesn't belong", as server/HubDressing already did for the village)
	s.Transparency = 1
	s.CanCollide = false
	local decal = s:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	s.Parent = parent
	return s
end

return Environment
