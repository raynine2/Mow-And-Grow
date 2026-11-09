--!strict
-- THE GRASS BUNDLE IN THE GAME'S VOXEL LOOK (owner, 4 Nov, on the stack on your back: "i also dont like how this is
-- like maybe make it better idk it feels so bas and low qaulity"). The ForgeGUI bundles (shared/BundleArt) were soft,
-- painted meshes next to a world of blocks. This one is blocks on a quarter-stud grain (LihFolk vault: one grain per
-- model, 0.25 for props; three tones per material): a sheaf of stems with a rounded (plus-shaped) cross-section in the
-- area's own grass shades (shared/GrassShades, like its clumps), tied round the middle with an orange-brown band,
-- the cut end a straw-green face inset like the stubble's (server/Stubble), blade tips fanning out of the other end.
-- A mutated bundle is its mutation's colours (Config.MUTATIONS); the rarest have glowing tips.
-- Lying down: its length along X (cut end toward -X), its pivot at the middle of its underside. Anchored, no
-- collisions or queries. Used by server/Carry (your back), server/Loot (the ground), client/SellFx (into the shredder)
-- and server/ShopRoom (the stack by the wall).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("MowALawn")
local Zones = require(Shared:WaitForChild("Zones"))
local GrassShades: { [string]: { Color3 } } = require(Shared:WaitForChild("GrassShades")) :: any

local BundleVoxel = {}

local C = Color3.fromRGB
local TIE = C(196, 112, 48)
local TIE_DARK = C(150, 80, 36)
local STRAW = C(226, 206, 118)
-- mutations: { top, side, tips, glowing tips }
local MUTATED: { [string]: { any } } = {
	Golden = { C(255, 205, 40), C(226, 160, 30), C(255, 236, 140), false },
	Rainbow = { C(255, 110, 200), C(110, 200, 255), C(255, 236, 90), false },
	Diamond = { C(120, 230, 255), C(70, 170, 220), C(220, 250, 255), true },
	Toxic = { C(150, 255, 40), C(90, 190, 30), C(210, 255, 120), true },
	Galaxy = { C(130, 70, 255), C(70, 36, 160), C(230, 190, 255), true },
}

local function mul(c: Color3, k: number): Color3
	return Color3.new(math.min(1, c.R * k), math.min(1, c.G * k), math.min(1, c.B * k))
end

local function block(m: Model, name: string, size: Vector3, at: Vector3, col: Color3, glow: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	-- (9 Nov, owner: "the ones u pick up and go on ur back" more stud like) studded plastic like the stud look
	-- (server/StudLook), the glowing tips stay neon
	p.Material = if glow then Enum.Material.Neon else Enum.Material.Plastic
	local s = if glow then Enum.SurfaceType.Smooth else Enum.SurfaceType.Studs
	p.TopSurface = s
	p.FrontSurface = s
	p.BackSurface = s
	p.LeftSurface = s
	p.RightSurface = s
	p.BottomSurface = if glow then Enum.SurfaceType.Smooth else Enum.SurfaceType.Inlet
	p.Size = size
	p.CFrame = CFrame.new(at)
	p.Color = col
	p.Parent = m
	return p
end

-- The colours of a bundle of area `z`'s grass with mutation `mut`: top, side, tips, glowing tips.
local function colours(z: number?, mut: string?): (Color3, Color3, Color3, boolean)
	local m = mut and MUTATED[mut]
	if m then
		return m[1], m[2], m[3], m[4]
	end
	local def = Zones.list[z or 1] or Zones.list[1]
	local sh = GrassShades[def and def.id or "meadow"] or GrassShades.meadow
	local main = sh[1]
	return sh[2] or mul(main, 1.1), mul(main, 0.82), mul(main, 1.25), false
end

-- A bundle of area `z`'s grass with mutation `mut` (nil or "None": plain), `length` studs end to end (tips included).
function BundleVoxel.make(z: number?, mut: string?, length: number): Model
	local top, side, tips, glow = colours(z, mut)
	local v = length / 9 -- the grain: 9 long, 4 thick
	local m = Instance.new("Model")
	m.Name = "Bundle"
	local L = 7 * v -- the sheaf without its tips
	local cx = -v -- (tips take the last 2 grains at +X)
	local cy = 2 * v
	-- the sheaf: a plus-shaped cross-section, its top and bottom ridges lighter than its sides
	local core = block(m, "Core", Vector3.new(L, 4 * v, 2 * v), Vector3.new(cx, cy, 0), top)
	block(m, "Sheaf", Vector3.new(L, 2 * v, 4 * v), Vector3.new(cx, cy, 0), side)
	-- the tie round the middle, a hair proud of the sheaf
	local e = 0.04
	block(m, "Tie", Vector3.new(1.2 * v, 4 * v + e, 2 * v + e), Vector3.new(0.6 * v, cy, 0), TIE)
	block(m, "Tie", Vector3.new(1.2 * v, 2 * v + e, 4 * v + e), Vector3.new(0.6 * v, cy, 0), TIE_DARK)
	-- the cut end: the stems' straw-green insides, inset
	block(m, "Cut", Vector3.new(0.04, 2 * v, 2 * v), Vector3.new(cx - L / 2 - 0.015, cy, 0), top:Lerp(STRAW, 0.55))
	-- the blade tips fanning out of the other end
	local x0 = cx + L / 2
	for _, t in { { 1.4, 0, 2.4 }, { -0.9, 1.3, 2 }, { -0.9, -1.3, 2 }, { 0.3, 0.6, 1.6 } } do
		block(m, "Tip", Vector3.new(t[3] * v, v, v), Vector3.new(x0 + t[3] * v / 2 - 0.3 * v, cy + t[1] * v, t[2] * v), tips, glow)
	end
	m.PrimaryPart = core
	m.WorldPivot = CFrame.new()
	return m
end

-- How thick a bundle of that length is (its height lying down).
function BundleVoxel.thickness(length: number): number
	return 4 * length / 9
end

return BundleVoxel
