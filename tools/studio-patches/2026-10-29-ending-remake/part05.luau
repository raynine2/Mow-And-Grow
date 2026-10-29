local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end

local ss = game:GetService("ServerStorage")
local buf = ss:FindFirstChild("ClaudePatchBuf")
if not buf then
	buf = Instance.new("Folder")
	buf.Name = "ClaudePatchBuf"
	buf.Parent = ss
end
local function put(name, text, want)
	if hashOf(text) ~= want then
		return name .. " garbled"
	end
	local v = buf:FindFirstChild(name) or Instance.new("StringValue")
	v.Name = name
	v.Value = text
	v.Parent = buf
	return nil
end
local bad = {}
local function chk(r)
	if r then
		table.insert(bad, r)
	end
end
chk(put("o74", [======[

-- How well a camera at `p` sees a shot: 2 for each of `targets` in sight, 1 off for each edge of the frame (`half`
]======], "117 523716244"))
chk(put("n74", [======[

-------------------------------------------------------------------------------------------------------------
-- keeping the camera out of the scenery (29 Oct, as client/Intro does): most of the trees and props can't be hit
-- by a raycast (CanQuery is off on them), so Film.sees can't see them. The scenery round the film's places is
-- taken as boxes, in a grid (Ending.play builds it under the black cover, and drops it at the end).
-------------------------------------------------------------------------------------------------------------
type Box = { cf: CFrame, h: Vector3, p: Vector3, r: number }
type Boxes = { list: { Box }, grid: { [number]: { number } }, mark: { [number]: number }, tick: number }
local CELL = 32
local scenery: Boxes? = nil

local function cellOf(v: number): number
	return math.floor(v / CELL)
end

-- The scenery within `r` studs (sideways) of any of `places`, as boxes. Thousands of parts: spread over frames.
local function sceneryBoxes(places: { { at: Vector3, r: number } }): Boxes
	local B: Boxes = { list = {}, grid = {}, mark = {}, tick = 0 }
	local world = workspace:FindFirstChild("World")
	local n = 0
	for _, name in { "Visuals", "Hub", "Ground", "Gates", "Patches", "Ways", "Pads", "Arenas" } do
		local f = world and world:FindFirstChild(name)
		if f then
			for _, d in f:GetDescendants() do
				n += 1
				if n % 3000 == 0 then
					task.wait()
				end
				if d:IsA("BasePart") and d.Transparency < 0.95 and d.Size.Magnitude > 3 then
					local p = d.Position
					local near = false
					for _, pl in places do
						if flat(p - pl.at).Magnitude < pl.r then
							near = true
							break
						end
					end
					if near then
						local cf, h = d.CFrame, d.Size / 2
						table.insert(B.list, { cf = cf, h = h, p = p, r = h.Magnitude })
						local id = #B.list
						-- (the cells its upright bounding box covers)
						local ex = math.abs(cf.XVector.X) * h.X + math.abs(cf.YVector.X) * h.Y + math.abs(cf.ZVector.X) * h.Z
						local ez = math.abs(cf.XVector.Z) * h.X + math.abs(cf.YVector.Z) * h.Y + math.abs(cf.ZVector.Z) * h.Z
						for ix = cellOf(p.X - ex), cellOf(p.X + ex) do
							for iz = cellOf(p.Z - ez), cellOf(p.Z + ez) do
								local key = ix * 65536 + iz
								local cell = B.grid[key]
								if cell then
									table.insert(cell, id)
								else
									B.grid[key] = { id }
								end
							end
						end
					end
				end
			end
		end
	end
	return B
end

-- (one axis of a line-through-a-box test: the part of the line, t0..t1, inside the box's slab on that axis)
local function slab(o: number, v: number, e: number, t0: number, t1: number): (number, number)
	if math.abs(v) < 1e-6 then
		if o < -e or o > e then
			return 1, 0
		end
		return t0, t1
	end
	local u0, u1 = (-e - o) / v, (e - o) / v
	if u0 > u1 then
		u0, u1 = u1, u0
	end
	return math.max(t0, u0), math.min(t1, u1)
end

-- Whether the line from `a` to `b` goes through any of the scenery's boxes.
local function blocked(a: Vector3, b: Vector3): boolean
	local B = scenery
	if not B then
		return false
	end
	B.tick += 1
	local tick = B.tick
	local ab = b - a
	local len2 = math.max(ab:Dot(ab), 1e-6)
	for ix = cellOf(math.min(a.X, b.X)), cellOf(math.max(a.X, b.X)) do
		for iz = cellOf(math.min(a.Z, b.Z)), cellOf(math.max(a.Z, b.Z)) do
			local cell = B.grid[ix * 65536 + iz]
			if cell then
				for _, id in cell do
					if B.mark[id] ~= tick then
						B.mark[id] = tick
						local bx = B.list[id]
						local t = math.clamp((bx.p - a):Dot(ab) / len2, 0, 1)
						if (a + ab * t - bx.p).Magnitude <= bx.r then
							local la = bx.cf:PointToObjectSpace(a)
							local d = bx.cf:PointToObjectSpace(b) - la
							local t0, t1 = slab(la.X, d.X, bx.h.X, 0, 1)
							if t0 <= t1 then
								t0, t1 = slab(la.Y, d.Y, bx.h.Y, t0, t1)
							end
							if t0 <= t1 then
								t0, t1 = slab(la.Z, d.Z, bx.h.Z, t0, t1)
							end
							if t0 <= t1 then
								return true
							end
						end
					end
				end
			end
		end
	end
	return false
end

-- Whether a camera at `p` would stand inside something of the scenery.
local function inside(p: Vector3): boolean
	return blocked(p - UP * 0.1, p + UP * 0.1)
end

-- Whether `from` sees `to`: nothing solid between them (a raycast: the ground, the buildings) and none of the
-- scenery's boxes either (the trees and props a raycast goes through).
local function sees(from: Vector3, to: Vector3): boolean
	return Film.sees(from, to) and not blocked(from, to)
end

local function turn(v: Vector3, deg: number): Vector3
	return CFrame.Angles(0, math.rad(deg), 0):VectorToWorldSpace(v)
end

local YAWS = { 0, 30, -30, 60, -60, 90, -90, 120, -120, 150, -150, 180 }

-- Which way the sun lies (flat) at `clock` o'clock, to keep faces in the light: read with the clock set for a
-- moment (the film sets its own light afterwards).
local function sunAt(clock: number): Vector3
	local was = Lighting.ClockTime
	Lighting.ClockTime = clock
	local d = Lighting:GetSunDirection()
	Lighting.ClockTime = was
	return unit(flat(d), Vector3.zAxis)
end

-- How well a camera at `p` sees a shot: 2 for each of `targets` in sight, 1 off for each edge of the frame (`half`
]======], "5149 1828352813"))
chk(put("o75", [======[	E5 = "Spawn Village is SAVED! Now, everyone... say GRASS!",
]======], "61 1686497707"))
chk(put("n75", [======[	E5 = "The valley is SAVED! Now, everyone... say GRASS!",
]======], "58 156663591"))
chk(put("o76", [======[local FilmVfx = require(script.Parent.FilmVfx) -- (29 Oct) the effects as VFX Forge templates (old ones: the fallback)

]======], "120 1023460902"))
chk(put("n76", [======[local FilmVfx = require(script.Parent.FilmVfx) -- (29 Oct) the effects as VFX Forge templates (old ones: the fallback)
local HitFx = require(script.Parent.HitFx) -- (29 Oct) the dust where the Mowers land

]======], "206 600157164"))
chk(put("o77", [======[-- Impact frames (client/FilmPanels) on the three big hits after the credits. Camera, light and grade: client/Film;
-- music and sound: client/FilmAudio (licensed library audio); the Mayor's mumble: client/Babble; the actors and the
-- screen: client/IntroCast, client/IntroUi, as in the opening. SKIP jumps to the scene after the credits (from the
-- film or the credits); that scene always plays, and SKIP comes back on its last title, for the end screen.
]======], "458 1775472633"))
chk(put("n77", [======[-- Impact frames (client/FilmPanels) on the guardian set free and the three big hits after the credits. Camera, light
-- and grade: client/Film; music and sound: client/FilmAudio (licensed library audio); the effects: client/FilmVfx
-- (VFX Forge templates, the old code as the fallback); the Mayor's mumble: client/Babble; the actors and the screen:
-- client/IntroCast, client/IntroUi, as in the opening. SKIP jumps to the scene after the credits (from the film or
-- the credits); that scene always plays, and SKIP comes back on its last title, for the end screen.
local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
]======], "672 1461762921"))
chk(put("o78", [======[-- the opening film (client/Intro) starts: Mayor Thistlewick's valley, overgrown since "the grass came back and
-- never stopped growing", is mowed at last.
--   I.   THE LAST BLADE: the last guardian kneels in its arena with the glitch still in it; the pink tears out of
--        it, its own colours come back, it bows to us and goes up into the sky as light; the sun breaks through
--        ("The last wild grass in the valley... was gone.");
--   II.  THE VALLEY BREATHES: a long flight back over every area, mowed in stripes, each name ticking off;
--   III. HOMECOMING: the Mayor alone on his soapbox; footsteps; he turns: the Mowers are back ("You... you
--        actually DID it!");
--   IV.  THE CELEBRATION: cheering, music, confetti, fireworks over the village at dusk, and the group photo
--        ("Everyone... say GRASS!"), frozen for a moment as a snapshot;
]======], "876 1405946745"))
chk(put("n78", [======[-- the opening film (client/Intro) starts: Mayor Thistlewick's valley, overgrown since the pink got into its
-- guardians, is mowed at last.
-- Remade on 29 Oct the way the opening was (owner: "do the same u did for intro for the outro"; of both films:
-- "sometimes the camera just pans to the ground or just some useless thing"): no flight over the ground, no walking,
-- no shot of nothing. Every shot has someone in it doing something; the cameras keep out of the trees and the ruins
-- (the scenery as boxes: a raycast goes through most of it); every shot was checked on a contact sheet in Studio
-- (client/FilmSheet).
--   I.   THE LAST BLADE: in its arena the last guardian kneels in front of the Mowers (copies of everyone's avatars,
--        where they beat it), the glitch still in it; close on its face the pink TEARS out of it [an impact frame, in
--        gold]; its own colours come back, it stands up tall over them... and bows; then it goes up as light and the
--        sun breaks through over the Mowers ("And just like that... the last wild grass in the valley was gone.");
--   II.  THE VALLEY BREATHES: the guardians back home in their own lands, free, in their own colours, one after
--        another, each bowing as its land's name comes up; the Dandelion King last, the one the pink fell on first;
--   III. HOMECOMING: sunset; the Mayor alone on his soapbox, looking out over his meadow... THUD: behind him the Mowers
--        drop out of the sky one after another, as they did in the opening; he spins round: "You... you actually DID
--        it!";
--   IV.  THE CELEBRATION: cheering, confetti, fireworks over the camp at dusk, and the group photo ("Everyone... say
--        GRASS!"), frozen for a moment as a snapshot;
]======], "1754 379372135"))
return "part 5/5 (edits 74-78): " .. (if #bad == 0 then "ok" else table.concat(bad, ", "))
