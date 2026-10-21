-- Biome lighting (client): every zone has a lighting preset in shared/Zones (time of day, ambient, fog, tint,
-- saturation, bloom, sun rays). As you walk, the look eases toward the zone you're in, blending the two nearest
-- zones near a border, so nothing ever snaps. Only this client's Lighting changes.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Zones = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Zones"))

local BiomeLight = {}
local player = Players.LocalPlayer

local function ensure(className: string, name: string): Instance
	local e = Lighting:FindFirstChild(name)
	if not e then
		e = Instance.new(className)
		e.Name = name
		e.Parent = Lighting
	end
	return e
end

local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or ensure("Atmosphere", "BiomeAtmosphere") :: Atmosphere
local bloom = ensure("BloomEffect", "BiomeBloom") :: BloomEffect
local color = ensure("ColorCorrectionEffect", "BiomeColor") :: ColorCorrectionEffect
local rays = ensure("SunRaysEffect", "BiomeSun") :: SunRaysEffect
bloom.Threshold = 0.92 -- only neon and very bright things glow
bloom.Size = 26
rays.Spread = 0.6

type Look = { [string]: any }

-- the village borrows the meadow's sunny look
local function preset(region: number): Look
	if region == 0 then
		return Zones.list[1].lighting
	end
	return Zones.list[region].lighting
end

local KEYS = { "clock", "ambient", "outdoor", "brightness", "tint", "saturation", "contrast", "fog", "haze", "density", "sunRays", "bloom" }

local function mix(a: Look, b: Look, t: number): Look
	local out = {}
	for _, k in KEYS do
		local x, y = a[k], b[k]
		if typeof(x) == "Color3" then
			out[k] = x:Lerp(y, t)
		else
			out[k] = x + (y - x) * t
		end
	end
	return out
end

-- Where the player is: the nearest region's look, blended toward the second nearest close to a border.
local function target(pos: Vector3): Look
	local p = Vector2.new(pos.X, pos.Z)
	local best, bestD, second, secondD = 0, math.huge, 0, math.huge
	for i = 0, #Zones.list do
		local d = Zones.normDist(i, p)
		if d < bestD then
			second, secondD = best, bestD
			best, bestD = i, d
		elseif d < secondD then
			second, secondD = i, d
		end
	end
	local gap = secondD - bestD
	if gap < 0.3 then
		-- at the border (gap 0) it's half and half, 0.3 in it's all the nearer zone
		return mix(preset(best), preset(second), 0.5 * (1 - gap / 0.3))
	end
	return preset(best)
end

local current: Look? = nil

local function apply(l: Look)
	Lighting.ClockTime = l.clock
	Lighting.Ambient = l.ambient
	Lighting.OutdoorAmbient = l.outdoor
	Lighting.Brightness = l.brightness
	color.TintColor = l.tint
	color.Saturation = l.saturation
	color.Contrast = l.contrast
	atmosphere.Color = l.fog
	atmosphere.Decay = l.fog:Lerp(Color3.new(0, 0, 0), 0.35)
	atmosphere.Haze = l.haze
	atmosphere.Density = l.density
	rays.Intensity = l.sunRays
	bloom.Intensity = l.bloom
end

-- Off while something else owns the lighting (the lobby, the class room, a cutscene): set the attribute
-- "BiomeLightOff" on this script's player to pause it.
local acc = 0
RunService.RenderStepped:Connect(function(dt)
	acc += dt
	if acc < 1 / 15 then
		return
	end
	local step = acc
	acc = 0
	if player:GetAttribute("BiomeLightOff") then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local want = target(root.Position)
	if not current then
		current = want
	else
		current = mix(current, want, 1 - math.exp(-step * 1.1))
	end
	apply(current :: Look)
end)

return BiomeLight
