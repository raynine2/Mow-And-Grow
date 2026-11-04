--!strict
-- FilmClear (5 Nov; owner, of the opening in a run: "de bosses zitten random ergens verstopt": the camp's roofs, its
-- garage sign and trees stood between the lens and the guardian).
--   local stop = FilmClear.keep(getModel)
-- While a film shows a guardian, every shot keeps it clear: whatever of the world stands between the camera and its
-- body is hidden on this client (a whole building or tree at once, its signs too), and the world's always-on-top
-- signs are off. stop() brings it all back. Ground, and anything over 160 studs across, is never hidden.
local Film = require(script.Parent.Film)

local FilmClear = {}

local BIG = 160

local function sizeOf(unit: Instance): Vector3
	if unit:IsA("Model") then
		local _, s = unit:GetBoundingBox()
		return s
	elseif unit:IsA("BasePart") then
		return unit.Size
	end
	return Vector3.zero
end

-- the parts of the workspace that are the world (the client's padlock and its COMING SOON sign are in MowerLocks)
local ROOTS = { World = true, MowerLocks = true, Maps = true }

function FilmClear.keep(getModel: () -> Model?): () -> ()
	local world = workspace:FindFirstChild("World")
	local hidden: { [Instance]: boolean } = {}
	local guis: { [LayerCollector]: boolean } = {}
	local function hideUnit(unit: Instance)
		if hidden[unit] then
			return
		end
		hidden[unit] = true
		local list = unit:GetDescendants()
		table.insert(list, unit)
		for _, d in list do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 1
			elseif d:IsA("LayerCollector") and d.Enabled then
				d.Enabled = false
				guis[d] = true
			end
		end
	end
	-- the world's floating signs (the garage's COMING SOON was drawn across the King) are off while a guardian is
	-- on the set
	for _, f in workspace:GetChildren() do
		if ROOTS[f.Name] then
			for _, d in f:GetDescendants() do
				if d:IsA("BillboardGui") and d.Enabled then
					d.Enabled = false
					guis[d] = true
				end
			end
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local nextAt = 0
	local stopEvery = Film.every(function(_: number, now: number)
		if now < nextAt then
			return
		end
		nextAt = now + 0.08
		local cam = workspace.CurrentCamera
		local m = getModel()
		if not (cam and m and world and m.Parent) then
			return
		end
		local cf, size = m:GetBoundingBox()
		if cf.Position.Y < -200 then
			return -- (BossView parks a hidden boss far below)
		end
		local from = cam.CFrame.Position
		local right = cam.CFrame.RightVector
		-- only the world's own pieces can be in the way: not the film's set, the effects, the guardian or the ground
		local excl: { Instance } = {}
		for _, f in workspace:GetChildren() do
			if not ROOTS[f.Name] and not f:IsA("Terrain") then
				table.insert(excl, f)
			end
		end
		local ground = world:FindFirstChild("Ground")
		if ground then
			table.insert(excl, ground)
		end
		for unit in hidden do
			table.insert(excl, unit)
		end
		local wide = math.max(size.X, size.Z)
		for _, y in { -0.35, 0, 0.35 } do
			for _, x in { -0.3, 0, 0.3 } do
				local to = cf.Position + Vector3.new(0, size.Y * y, 0) + right * (wide * x)
				for _ = 1, 6 do
					params.FilterDescendantsInstances = excl
					local res = workspace:Spherecast(from, 0.6, to - from, params)
					local hit = res and res.Instance
					if not (hit and hit:IsA("BasePart")) then
						break
					end
					-- the whole building or tree in the way: the biggest model under the world that's still a prop
					local unit: Instance = hit
					local a = hit.Parent
					while a and a ~= workspace and not (a.Parent == workspace and ROOTS[a.Name]) do
						if a:IsA("Model") and sizeOf(a).Magnitude < BIG then
							unit = a
						end
						a = a.Parent
					end
					table.insert(excl, unit)
					if sizeOf(unit).Magnitude < BIG then
						hideUnit(unit)
					end
				end
			end
		end
	end)
	return function()
		stopEvery()
		for unit in hidden do
			local list = unit:GetDescendants()
			table.insert(list, unit)
			for _, d in list do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = 0
				end
			end
		end
		for g in guis do
			if g.Parent then
				g.Enabled = true
			end
		end
		table.clear(hidden)
		table.clear(guis)
	end
end

return FilmClear
