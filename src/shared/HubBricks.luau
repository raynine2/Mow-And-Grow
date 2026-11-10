--!strict
-- HUB BRICKS (10 Nov 2026; owner: "make the models with blender but make it like the style we have the stud voxel
-- style"). Builds one of the hub's stud-voxel models (tools/blender/hub/hub_models.py -> shared/HubBrickData) out of
-- studded Plastic bricks, the way server/StudKit builds the windmill and the houses: studs on top and sides, an inlet
-- underneath, every colour a shade darker (Config.STUD_FORGE.tone); metal, glass and the wheel's face stay smooth.
-- Used by the server (the Top Mowers stage) and the clients (the wheel booth, the wheel, the pet garden).
--
-- Two layers per model: bricks (1 stud, studded) and detail (half studs, smooth: trims, flowers, bunting, the wheel).
-- HubBricks.build(name, pivot, parent, opts?) -> (Model, anchors)
--   pivot: the model's bottom middle, LookVector = its front. anchors[name] = that point in the world (Vector3), or
--   the raw value for a non-point anchor (a list, a number). opts.collide = false: no collisions (the wheel).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("MowALawn")
local Data = require(Shared:WaitForChild("HubBrickData")) :: any
local Config = require(Shared:WaitForChild("Config")) :: any

local HubBricks = {}

local TONE = math.clamp(tonumber(type(Config.STUD_FORGE) == "table" and Config.STUD_FORGE.tone or nil) or 0.85, 0.4, 1)
local STUDS, INLET, SMOOTH = Enum.SurfaceType.Studs, Enum.SurfaceType.Inlet, Enum.SurfaceType.Smooth
local METAL = { gold = true, silver = true, bronze = true }

local function toned(c: Color3): Color3
	return Color3.new(c.R * TONE, c.G * TONE, c.B * TONE)
end

local function dress(p: Part, colour: string, detail: boolean)
	local smooth = detail or Data.smooth[colour] == true
	local s = if smooth then SMOOTH else STUDS
	p.TopSurface = s
	p.FrontSurface = s
	p.BackSurface = s
	p.LeftSurface = s
	p.RightSurface = s
	p.BottomSurface = if smooth then SMOOTH else INLET
	p.Material = Enum.Material.Plastic
	local c = Data.colours[colour] or Color3.new(1, 0, 1)
	p.Color = toned(c)
	local base = string.match(colour, "^[^_]+") or colour
	if detail then
		p.Material = Enum.Material.SmoothPlastic
	end
	if METAL[base] then
		p.Material = Enum.Material.SmoothPlastic
		p.Reflectance = 0.2
		p.Color = c
	elseif base == "water" then
		p.Material = Enum.Material.Glass
		p.Transparency = 0.25
	elseif base == "lamp" then
		p.Material = Enum.Material.Neon
		p.Color = c
	elseif base == "glass" then -- (10 Nov) the Tool Shop's windows
		p.Material = Enum.Material.Glass
		p.Transparency = 0.45
		p.Color = c
		p.CastShadow = false
	end
end

function HubBricks.has(name: string): boolean
	return Data.models[name] ~= nil
end

function HubBricks.build(name: string, pivot: CFrame, parent: Instance?, opts: { collide: boolean? }?): (Model, { [string]: any })
	local def = Data.models[name]
	local m = Instance.new("Model")
	m.Name = name
	local anchors: { [string]: any } = {}
	if not def then
		return m, anchors
	end
	local collide = not (opts and opts.collide == false)
	-- the bricks in studs (studded), the detail in half studs (smooth; no collisions: they're small)
	for _, layer in { { def.bricks or {}, 1, false }, { def.detail or {}, 0.5, true } } do
		local k, detail = layer[2], layer[3]
		for _, b in layer[1] do
			local lo = Vector3.new(b[1], b[2], b[3]) * k
			local hi = Vector3.new(b[4], b[5], b[6]) * k
			local p = Instance.new("Part")
			p.Name = b[7]
			p.Anchored = true
			p.CanCollide = collide and not detail
			p.CanTouch = false
			p.CastShadow = not detail or (hi - lo).Magnitude > 1.2
			p.Size = hi - lo
			p.CFrame = pivot * CFrame.new((lo + hi) / 2)
			dress(p, b[7], detail)
			p.Parent = m
		end
	end
	for key, v in def.anchors do
		if type(v) == "table" and #v == 3 and type(v[1]) == "number" and key ~= "pond" and key ~= "tree" then
			anchors[key] = (pivot * CFrame.new(v[1], v[2], v[3])).Position
		else
			anchors[key] = v
		end
	end
	m:SetAttribute("StudBuilt", true) -- (server/StudLook leaves it as built)
	m:SetAttribute("Bricks", #(def.bricks or {}) + #(def.detail or {}))
	m.WorldPivot = pivot
	if parent then
		m.Parent = parent
	end
	return m, anchors
end

return HubBricks
