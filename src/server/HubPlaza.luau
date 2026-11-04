--!strict
-- THE AREA CAMPS, SECOND LOOK (owner, 4 Nov: "the zone hubs ... feel a bit ass"). Each area's camp (server/Outposts)
-- was a square of grey pixel-textured tiles with pixel-stone footings, the stalls side by side at one edge, benches
-- at odd angles: the same in every area and nothing that frames it. Built like the lobby's windmill square, which the
-- owner liked (and kept calm: on 29 Oct he had the houses, animals and villagers taken off these camps again):
--   * a round plaza in rings of stones round the drop-off pad (server/LobbyPaving), in the area's own stone: warm
--     sandstone in the wheat, pink-white marble in the blossom, mossy grey in the pines, peat brown in the swamp, ice
--     blue in the frost, basalt with glowing joints in the ember fields, lilac in the isles;
--   * on a round stone plinth with ring steps where the ground falls away (instead of pixel blocks);
--   * framed by the area's own ForgeGUI arena kit, the models the owner rates highest: four pillars (two at the way
--     in, two at the back) lit in the area's glow (its wall pieces were tried behind the stalls: placed at camp size
--     they came out as one 15-stud block hiding them);
--   * the SHOP and UPGRADES stalls at the back, turned to face the pad; benches face it too (made things align).
local Models = require(script.Parent.Models)
local LobbyPaving = require(script.Parent.LobbyPaving)

local HubPlaza = {}

local C = Color3.fromRGB

export type Look = {
	paving: LobbyPaving.Look,
	side: Color3, -- the plinth and its steps
	pillar: string, -- ForgeGUI model names (shared/ForgeModelIds)
	glow: Color3,
}

HubPlaza.LOOKS = {
	wheat = {
		paving = { tones = { C(232, 186, 104), C(218, 170, 92), C(240, 198, 118), C(206, 160, 86) }, cream = C(246, 222, 164), grout = C(118, 82, 50), kerb = { C(170, 120, 74), C(156, 108, 66) } },
		side = C(196, 150, 94),
		pillar = "fa_pillar_wheat",
		glow = C(255, 210, 140),
	},
	blossom = {
		paving = { tones = { C(240, 220, 226), C(228, 204, 212), C(246, 232, 236), C(218, 192, 202) }, cream = C(255, 238, 244), grout = C(146, 100, 120), kerb = { C(196, 156, 172), C(182, 142, 158) } },
		side = C(220, 196, 204),
		pillar = "fa_pillar_blossom",
		glow = C(255, 190, 222),
	},
	pine = {
		paving = { tones = { C(150, 160, 146), C(138, 148, 134), C(162, 170, 154), C(126, 136, 122) }, cream = C(178, 186, 168), grout = C(58, 78, 58), kerb = { C(96, 104, 92), C(86, 94, 82) } },
		side = C(116, 124, 110),
		pillar = "fa_pillar_pine",
		glow = C(255, 206, 140),
	},
	swamp = {
		paving = { tones = { C(140, 114, 84), C(126, 102, 74), C(150, 124, 92), C(116, 94, 68) }, cream = C(164, 142, 104), grout = C(60, 80, 46), kerb = { C(92, 96, 68), C(82, 86, 60) } },
		side = C(104, 88, 64),
		pillar = "fa_pillar_swamp",
		glow = C(170, 255, 140),
	},
	frost = {
		paving = { tones = { C(212, 226, 244), C(198, 214, 236), C(224, 236, 250), C(188, 204, 228) }, cream = C(238, 246, 255), grout = C(92, 122, 168), kerb = { C(148, 170, 204), C(134, 156, 192) } },
		side = C(172, 192, 220),
		pillar = "apost_frost",
		glow = C(170, 230, 255),
	},
	ember = {
		paving = { tones = { C(88, 80, 82), C(78, 71, 73), C(98, 88, 90), C(70, 63, 66) }, cream = C(112, 100, 100), grout = C(255, 104, 36), groutNeon = true, kerb = { C(54, 48, 52), C(46, 41, 45) } },
		side = C(62, 56, 60),
		pillar = "fa_pillar_ember",
		glow = C(255, 150, 70),
	},
	isles = {
		paving = { tones = { C(178, 162, 224), C(164, 148, 212), C(190, 176, 234), C(152, 136, 200) }, cream = C(216, 206, 246), grout = C(76, 60, 128), kerb = { C(120, 104, 170), C(108, 94, 156) } },
		side = C(140, 126, 190),
		pillar = "fa_pillar_isles",
		glow = C(150, 230, 255),
	},
} :: { [string]: Look }

local STEP_H = 1.3 -- the plinth's ring steps: rise and tread
local STEP_W = 1.8
local MAX_STEPS = 4
local PAVE = 0.36 -- LobbyPaving's stones stand this far above the level they're laid at

local function solid(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanTouch = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Parent = parent
	return p
end

-- a flat round slab from y0 up to y1 (a cylinder on its side)
local function drum(parent: Instance, name: string, c: Vector3, r: number, y0: number, y1: number, color: Color3): Part?
	if y1 - y0 < 0.05 then
		return nil
	end
	local p = solid(parent, name, Vector3.new(y1 - y0, r * 2, r * 2), CFrame.new(c.X, (y0 + y1) / 2, c.Z) * CFrame.Angles(0, 0, math.rad(90)), color)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- The ground under (x, z), looking down from `from` (only the world's ground blocks).
local function groundAt(ground: { Instance }, x: number, z: number, from: number): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = ground
	local hit = workspace:Raycast(Vector3.new(x, from + 60, z), Vector3.new(0, -200, 0), params)
	return if hit then hit.Position.Y else nil
end

-- The plaza at `c` (its centre on the paving's top), radius `R`, the middle `r0` left for the pad: paving, plinth and
-- ring steps. `room`: how far past the plaza's edge the steps may reach (the isles' boss arena stands close). Returns
-- the lowest ground found.
function HubPlaza.ground(f: Instance, c: Vector3, R: number, r0: number, look: Look, ground: { Instance }, room: number): number
	local top = c.Y
	-- the lowest ground under the plaza and just round it
	local low = top
	local lowOut = top
	for r = 0, R + 2 + MAX_STEPS * STEP_W, 3 do
		local n = math.max(1, math.floor(2 * math.pi * r / 4))
		for k = 0, n - 1 do
			local a = k / n * 2 * math.pi
			local g = groundAt(ground, c.X + math.cos(a) * r, c.Z + math.sin(a) * r, top)
			if g then
				if r <= R + 1 then
					low = math.min(low, g)
				else
					lowOut = math.min(lowOut, g)
				end
			end
		end
	end
	local plinth = Instance.new("Model")
	plinth.Name = "Plinth"
	local edge = R + 0.8 -- (LobbyPaving's kerb stands on it)
	local paveLevel = top - PAVE
	local bottom = math.min(low, lowOut) - 1.5
	-- the plinth under the paving, down into the ground
	drum(plinth, "Plinth", c, edge, bottom, paveLevel, look.side)
	-- ring steps round it, as far down as the ground falls (buried where the ground is higher)
	do
		local drop = paveLevel - math.min(low, lowOut)
		local n = math.clamp(math.floor(drop / STEP_H + 0.5), 0, math.min(MAX_STEPS, math.floor(room / STEP_W)))
		for k = 1, n do
			local col = look.side:Lerp(Color3.new(0, 0, 0), if k % 2 == 1 then 0.08 else 0.02)
			drum(plinth, "Step", c, edge + k * STEP_W, bottom, paveLevel - k * STEP_H, col)
		end
	end
	plinth.Parent = f
	-- the paving on top (laid at y = 0, then lifted)
	local holder = Instance.new("Model")
	holder.Name = "Plaza"
	LobbyPaving.lay(holder, { { kind = "disc", c = Vector2.new(c.X, c.Z), r = R, r0 = r0 } }, look.paving)
	holder:PivotTo(holder:GetPivot() + Vector3.new(0, paveLevel, 0))
	holder.Parent = f
	return low
end

-- One of the area's ForgeGUI pieces standing at `cf`, `want` its size; collides. nil when it isn't loaded.
local function piece(f: Instance, name: string, cf: CFrame, want: { [string]: number }): Model?
	return Models.placeForge(name, f, cf, want :: any, false)
end

-- The frame: four pillars (two at the way in, two at the back) lit in the area's glow. `at(x, z, face)` is the camp's own placer (x right, z toward the area's middle).
function HubPlaza.frame(f: Instance, look: Look, R: number, at: (number, number, Vector3?) -> CFrame, centre: Vector3)
	local frame = Instance.new("Model")
	frame.Name = "Frame"
	local rp = R - 2.2
	local spots = {
		{ math.sin(math.rad(22)) * rp, math.cos(math.rad(22)) * rp },
		{ -math.sin(math.rad(22)) * rp, math.cos(math.rad(22)) * rp },
		{ math.sin(math.rad(118)) * rp, math.cos(math.rad(118)) * rp },
		{ -math.sin(math.rad(118)) * rp, math.cos(math.rad(118)) * rp },
	}
	for _, s in spots do
		local cf = at(s[1], s[2])
		local face = Vector3.new(centre.X - cf.X, 0, centre.Z - cf.Z)
		local p = cf.Position
		local m = piece(frame, look.pillar, CFrame.lookAt(p, p + face), { height = 11 })
		if m then
			m.Name = "Pillar"
			local box, size = m:GetBoundingBox()
			local lamp = Instance.new("Part")
			lamp.Name = "PillarLight"
			lamp.Anchored = true
			lamp.CanCollide = false
			lamp.CanQuery = false
			lamp.CanTouch = false
			lamp.Transparency = 1
			lamp.Size = Vector3.new(0.4, 0.4, 0.4)
			lamp.CFrame = CFrame.new(box.Position + Vector3.new(0, size.Y * 0.36, 0))
			lamp.Parent = m
			local light = Instance.new("PointLight")
			light.Color = look.glow
			light.Range = 16
			light.Brightness = 1.4
			light.Shadows = false
			light.Parent = lamp
		end
	end
	frame.Parent = f
end

return HubPlaza
