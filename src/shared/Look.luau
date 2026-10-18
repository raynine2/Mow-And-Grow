-- The world's lighting look (values live in Config.LOOK). The server builds the effects once
-- (server/Environment); the client blends between zone moods (client/ZoneMood). Both write through
-- Look.apply, which only touches the named effects the server made, so hand-made Studio effects are left alone.
local Lighting = game:GetService("Lighting")

local Config = require(script.Parent.Config)

local Look = {}

export type Values = { [string]: any }

-- the post effects the server makes (Environment) and that moods change
Look.NAMES = {
	color = "MowALawnColor",
	atmosphere = "MowALawnAtmosphere",
	bloom = "MowALawnBloom",
	rays = "MowALawnSunRays",
	depth = "MowALawnDepth",
}

-- A full set of values: the base look with a zone style's mood on top (nil style = the base look).
function Look.mood(style: string?): Values
	local out: Values = table.clone(Config.LOOK.base)
	local mood = style and Config.LOOK.moods[style]
	if mood then
		for k, v in mood do
			out[k] = v
		end
	end
	return out
end

-- a + (b - a) * t for every key (numbers and Color3), written into `into`.
function Look.blend(a: Values, b: Values, t: number, into: Values?): Values
	local out = into or {}
	for k, va in a do
		local vb = b[k]
		if vb == nil then
			out[k] = va
		elseif typeof(va) == "Color3" then
			out[k] = (va :: Color3):Lerp(vb, t)
		else
			out[k] = va + (vb - va) * t
		end
	end
	return out
end

-- How different two values are (0 = the same), to skip writes that wouldn't show.
function Look.diff(a: any, b: any): number
	if a == nil or b == nil then
		return 1
	end
	if typeof(a) == "Color3" then
		return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B)
	end
	return math.abs(a - b)
end

local function find(className: string, name: string): Instance?
	local inst = Lighting:FindFirstChild(name)
	if inst and inst:IsA(className) then
		return inst
	end
	return nil
end

-- Write a set of values (any subset of the keys in Config.LOOK.base) to Lighting and its effects.
function Look.apply(v: Values)
	if v.brightness then
		Lighting.Brightness = v.brightness
	end
	if v.exposure then
		Lighting.ExposureCompensation = v.exposure
	end
	if v.ambient then
		Lighting.Ambient = v.ambient
	end
	if v.outdoorAmbient then
		Lighting.OutdoorAmbient = v.outdoorAmbient
	end
	if v.colorShiftTop then
		Lighting.ColorShift_Top = v.colorShiftTop
	end
	local cc = find("ColorCorrectionEffect", Look.NAMES.color) :: ColorCorrectionEffect?
	if cc then
		cc.Saturation = v.saturation or cc.Saturation
		cc.Contrast = v.contrast or cc.Contrast
		cc.Brightness = v.ccBrightness or cc.Brightness
		cc.TintColor = v.tint or cc.TintColor
	end
	local atmo = find("Atmosphere", Look.NAMES.atmosphere) :: Atmosphere?
	if atmo then
		atmo.Density = v.atmoDensity or atmo.Density
		atmo.Offset = v.atmoOffset or atmo.Offset
		atmo.Color = v.atmoColor or atmo.Color
		atmo.Decay = v.atmoDecay or atmo.Decay
		atmo.Glare = v.atmoGlare or atmo.Glare
		atmo.Haze = v.atmoHaze or atmo.Haze
	end
	local bloom = find("BloomEffect", Look.NAMES.bloom) :: BloomEffect?
	if bloom and v.bloomIntensity then
		bloom.Intensity = v.bloomIntensity
	end
	local rays = find("SunRaysEffect", Look.NAMES.rays) :: SunRaysEffect?
	if rays then
		rays.Intensity = v.raysIntensity or rays.Intensity
		rays.Spread = v.raysSpread or rays.Spread
	end
end

return Look
