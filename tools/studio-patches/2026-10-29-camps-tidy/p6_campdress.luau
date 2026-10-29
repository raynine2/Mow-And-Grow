local m = game.ServerScriptService.MowALawn.CampDress
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "46062 1653425206" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[		floor(ctx, cf, 11, 11, rgb(62, 56, 58), Enum.Material.Basalt)
]======], [======[]======] },
	{ [======[		floor(ctx, cf, 12, 12, rgb(240, 246, 252), Enum.Material.Snow)
]======], [======[]======] },
	{ [======[		floor(ctx, cf, 11, 11, rgb(92, 76, 56))
]======], [======[]======] },
	{ [======[		floor(ctx, cf, 11, 11, rgb(196, 166, 92), Enum.Material.Fabric)
]======], [======[]======] },
	{ [======[			lamps(ctx, m, id == "blossom")
]======], [======[			if id == "blossom" then
				lamps(ctx, m, true) -- the pavilion's paper lanterns
			end
]======] },
	{ [======[end

-- a flat floor (a pen, a pond's bed) at `cf`: w x d
local function floor(ctx: Ctx, cf: CFrame, w: number, d: number, color: Color3, material: Enum.Material?)
	part(ctx.f, "PenFloor", cf * CFrame.new(0, 0.06, 0), Vector3.new(w, 0.12, d), color, material or Enum.Material.Ground, true)
]======], [======[]======] },
	{ [======[		smoke(m, if ctx.id == "ember" then rgb(120, 110, 106) else nil)
		lamps(ctx, m)
	end
]======], [======[		smoke(m, if ctx.id == "ember" then rgb(120, 110, 106) else nil)
	end
]======] },
	{ [======[				end
				lamps(ctx, m)
]======], [======[				end
				m:SetAttribute("NParts", left) -- (client/CampLife waits for all of them to stream in)
				local _ = name
				lamps(ctx, m)
]======] },
	{ [======[				local face = CampProps.markers(m, "SignFace")[1]
				if face then
					signText(face, string.upper(name) .. " CAMP")
]======], [======[				-- no name board (owner, 29 Oct: "remove every slop part thats ugly like signs"): the board, its rim and
				-- chains hang between the posts under the beams
				local left = 0
				for _, p in m:GetChildren() do
					if p:IsA("BasePart") then
						local lp = cf:PointToObjectSpace(p.Position)
						if math.abs(lp.X) <= 4.7 and lp.Y > 5.5 and lp.Y < 9.05 and math.abs(lp.Z) <= 0.6 then
							p:Destroy()
						else
							left += 1
						end
					end
]======] },
	{ [======[	local stone = ctx.roles.base[2] :: Color3
	part(ctx.f, "Footing", spot.cf * CFrame.new(0, -h / 2, 0), Vector3.new(w, h, d), VoxelKit.jitter(ctx.rng, stone, 0.03), "stone", true)
	part(ctx.f, "FootingCap", spot.cf * CFrame.new(0, -0.15, 0), Vector3.new(w + 0.5, 0.3, d + 0.5), C.timber, nil, true)
	local n = math.floor((h - 0.6) / 1.1)
	for i = 1, n do
		part(ctx.f, "Step", spot.cf * CFrame.new(0, -0.6 - (i - 1) * 1.1 - 0.55, -(d / 2 + 0.6 + (i - 1) * 1.2)), Vector3.new(4, 1.1, 1.2), VoxelKit.jitter(ctx.rng, stone, 0.05), "stone", true)
]======], [======[	local c = spot.cf.Position
	local hit = workspace:Raycast(c + Vector3.new(0, 40, 0), Vector3.new(0, -90, 0), ctx.ground)
	local top = hit and hit.Instance
	if not (hit and top and top:IsA("BasePart")) then
		return
	end
	local layer = math.min(1.2, h + 0.5)
	local q = top:Clone()
	q:ClearAllChildren()
	q.Name = "Fill"
	q.Size = Vector3.new(w, layer, d)
	q.CFrame = spot.cf * CFrame.new(0, -layer / 2, 0)
	q.Parent = ctx.f
	local bodyH = spot.y - layer - (spot.gmin - 0.5)
	if bodyH > 0.05 then
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { ctx.w:FindFirstChild("Ground") :: Instance }
		local under = workspace:GetPartBoundsInBox(CFrame.new(hit.Position - Vector3.new(0, 2, 0)), Vector3.one * 0.2, params)
		local b = (under[1] or top):Clone()
		b:ClearAllChildren()
		b.Name = "Fill"
		b.Size = Vector3.new(w, bodyH, d)
		b.CFrame = spot.cf * CFrame.new(0, -layer - bodyH / 2, 0)
		b.Parent = ctx.f
]======] },
	{ [======[	local h = spot.y - spot.gmin + 0.6
	if h < 0.7 then
]======], [======[	local h = spot.y - spot.gmin
	if h < 0.1 then
]======] },
	{ [======[-- A stone footing under a building (w x d) from the lowest ground up to its floor, with steps down at its front.
]======], [======[-- Under a building (w x d) where the ground falls away: the area's own ground built up to its floor (copies of the
-- terrain's top layer and body there), so it stands on a little terrace of the ground, not on a stone slab with
-- steps (owner, 29 Oct: "remove every slop part thats ugly").
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "46639 415893255" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
