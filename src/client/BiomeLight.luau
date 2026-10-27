-- Biome lighting (client): every zone has a lighting preset in shared/Zones (time of day, ambient, fog, tint,
-- saturation, bloom, sun rays). As you walk, the look eases toward the zone you're in, blending the two nearest
-- zones near a border, so nothing ever snaps. Only this client's Lighting changes.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Zones = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Zones"))
local Config = require(ReplicatedStorage.MowALawn:WaitForChild("Config"))
local State = require(script.Parent.State)

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

-- the effects server/WorldGen puts in Lighting (made here if missing). Looked up again whenever the server
-- replaces them (a run starting resets Lighting).
local atmosphere: Atmosphere, bloom: BloomEffect, color: ColorCorrectionEffect, rays: SunRaysEffect
local function effects()
	if atmosphere and atmosphere.Parent and bloom.Parent and color.Parent and rays.Parent then
		return
	end
	atmosphere = (Lighting:FindFirstChildOfClass("Atmosphere") or ensure("Atmosphere", "Atmosphere")) :: Atmosphere
	bloom = ensure("BloomEffect", "Glow") :: BloomEffect
	color = ensure("ColorCorrectionEffect", "Grade") :: ColorCorrectionEffect
	rays = ensure("SunRaysEffect", "Rays") :: SunRaysEffect
	bloom.Threshold = 0.8 -- neon and very bright things glow
	bloom.Size = 36
	rays.Spread = 0.7
end

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

-- The grade every preset goes through (owner, 27 Oct: "the lighting is sloppy, it should be like Chop A Forest").
-- What makes Chop A Forest's light read well: a strong warm sun against cool, darker shade (warm key, cool fill)
-- so every block shows its form; crisp shadows; colour that's rich but not neon; real depth haze toward the horizon
-- in the area's own colour (the old grade cut the haze to 15% under the place's sky, so everything looked flat);
-- bloom only on lights, fire and neon. The presets (shared/Zones) give each area its time of day, fog colour and
-- tint; this turns them into that look.
local STYLE = {
	coolFill = Color3.fromRGB(104, 122, 156), -- the shade's colour (sky bounce)
	ambientMix = 0.4, -- how far the shade is pulled to it
	ambientScale = 0.72, -- darker shade = more form
	outdoorScale = 0.84,
	brightnessScale = 1.22, -- a stronger sun
	sunTint = Color3.fromRGB(255, 232, 196), -- ColorShift_Top: warm light on the lit faces
	bounce = Color3.fromRGB(70, 80, 96), -- ColorShift_Bottom: a cool bounce under things
	saturation = 0.55, -- of the preset's
	contrast = 0.6,
	hazeOwnSky = 0.55, -- of the preset's haze when the place has its own sky (the depth fog)
	densityOwnSky = 0.85,
	glare = 0.25,
	bloom = 0.55,
	bloomThreshold = 0.92,
	bloomSize = 30,
	shadowSoftness = 0.16,
	specular = 0.55,
}
local function apply(l: Look)
	effects()
	Lighting.ClockTime = l.clock
	Lighting.Ambient = l.ambient:Lerp(STYLE.coolFill, STYLE.ambientMix):Lerp(Color3.new(0, 0, 0), 1 - STYLE.ambientScale)
	Lighting.OutdoorAmbient = l.outdoor:Lerp(STYLE.coolFill, STYLE.ambientMix * 0.75):Lerp(Color3.new(0, 0, 0), 1 - STYLE.outdoorScale)
	Lighting.Brightness = l.brightness * STYLE.brightnessScale
	Lighting.ColorShift_Top = STYLE.sunTint:Lerp(l.tint, 0.35)
	Lighting.ColorShift_Bottom = STYLE.bounce
	Lighting.ShadowSoftness = STYLE.shadowSoftness
	Lighting.EnvironmentSpecularScale = STYLE.specular
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.ExposureCompensation = 0
	color.TintColor = l.tint
	color.Saturation = l.saturation * STYLE.saturation
	color.Contrast = l.contrast * STYLE.contrast
	color.Brightness = 0.01
	atmosphere.Color = l.fog
	atmosphere.Decay = l.fog:Lerp(Color3.new(0, 0, 0), 0.4)
	-- a sky the owner added (any Sky but the game's "MowALawnSky") stays visible, with the area's haze over the
	-- horizon
	local sky = Lighting:FindFirstChildOfClass("Sky")
	local ownSky = sky ~= nil and sky.Name ~= "MowALawnSky"
	atmosphere.Haze = if ownSky then l.haze * STYLE.hazeOwnSky else l.haze
	atmosphere.Density = if ownSky then l.density * STYLE.densityOwnSky else l.density
	atmosphere.Offset = 0.22
	atmosphere.Glare = STYLE.glare
	rays.Intensity = l.sunRays
	bloom.Intensity = l.bloom * STYLE.bloom
	bloom.Threshold = STYLE.bloomThreshold
	bloom.Size = STYLE.bloomSize
end

-- Off while something else owns the lighting (the lobby, the class room, a cutscene): set the attribute
-- "BiomeLightOff" on this script's player to pause it.
local lastApplied: Look? = nil
local appliedAt = 0
local function differs(a: Look, b: Look): boolean
	for _, k in KEYS do
		local x, y = a[k], b[k]
		if typeof(x) == "Color3" then
			if math.abs(x.R - y.R) + math.abs(x.G - y.G) + math.abs(x.B - y.B) > 0.004 then
				return true
			end
		elseif math.abs(x - y) > 0.003 then
			return true
		end
	end
	return false
end

local acc = 0
RunService.RenderStepped:Connect(function(dt)
	acc += dt
	if acc < 1 / 15 then
		return
	end
	local step = acc
	acc = 0
	if player:GetAttribute("BiomeLightOff") or not Config.WORLD_GEN then
		current = nil
		lastApplied = nil
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	-- the lobby (generated-world style) always has the village's sunny meadow look
	local want = if State.isRun() then target(root.Position) else preset(0)
	if not current then
		current = want
	else
		current = mix(current, want, 1 - math.exp(-step * 1.1))
	end
	-- once the look has settled the blend keeps making tiny changes: only write Lighting when something visibly
	-- moved (every write makes the engine redo its lighting), or when the effects were replaced
	-- (and every 2 s anyway, in case something else wrote Lighting)
	local now = os.clock()
	if lastApplied and now - appliedAt < 2 and not differs(lastApplied, current :: Look) and atmosphere and atmosphere.Parent and bloom.Parent and color.Parent and rays.Parent then
		-- (the time of day is still held to the zone's, as before: the server's clock writes it too)
		local clock = (current :: Look).clock
		if math.abs(Lighting.ClockTime - clock) > 0.01 then
			Lighting.ClockTime = clock
		end
		return
	end
	lastApplied = current
	appliedAt = now
	apply(current :: Look)
end)

return BiomeLight
