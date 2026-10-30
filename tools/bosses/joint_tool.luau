-- tools/bosses/joint_tool.luau (30 Oct): turns a segmented ForgeGUI boss copy into a jointed boss template for
-- client/BossView + client/BossLife. Run in Studio's Edit mode as a ModuleScript (it was ServerStorage.
-- ClaudeBossJointTool while the bosses were made, then removed).
--
-- How the jointed bosses were made (owner, 30 Oct: "the bosses are very stiff ... just a statue", then "ik heb het
-- ook over de armen"):
--   1. a picture of each old boss (Studio screen_capture) -> ForgeGUI generation_model_3d with that picture as the
--      reference, published as a Model on the owner's account (connection @RayanPoepHoof); see HANDOFF for the ids
--   2. insert_asset, scale to the old rig's height, then Studio's segment_mesh with plain part names (head, left
--      arm, right arm, body, base). Names like "arm holding the staff" cut out the staff only; blobby bosses
--      (bramble, bunker) only gave a clean base
--   3. T.build(rig, model, where): turns it to face -Z (the ForgeGUI models came turned 45 degrees, so 135 more),
--      puts its feet at the pivot, names each piece by its Limb (head, armL, armR, body, base; the boss's left is
--      -X), and copies the old template's critters (bees, crow, butterflies, gnome)
--   4. T.joints(model): a `Joint` attachment in each head and arm where it touches the body (from the meshes'
--      vertices, so the pieces must be on the place owner's account), and a held thing (staff, pitchfork, scythe)
--      goes with the arm that touches it
--   5. the old template went to ServerStorage.MowALawnBackups.pre_jointed_30oct, the new one to
--      ReplicatedStorage.BossModels.<rig>
local AS = game:GetService("AssetService")
local T = {}

local function limbOf(name, x)
	local n = name:lower()
	if n:find("staff") or n:find("pitchfork") or n:find("scythe") then
		return "item"
	elseif n:find("base") and not n:find("body") then
		return "base"
	elseif n:find("head") then
		return "head"
	elseif n:find("arm") or n:find("claw") or n:find("tentacle") then
		return if x < 0 then "armL" else "armR"
	end
	return "body"
end

function T.build(rig, srcModel, at)
	local src = srcModel:Clone()
	local cf = src:GetBoundingBox()
	local c = cf.Position
	local rot = CFrame.new(c) * CFrame.Angles(0, math.rad(135), 0) * CFrame.new(-c)
	local pieces = {}
	for _, d in src:GetDescendants() do
		if d:IsA("MeshPart") then
			table.insert(pieces, d)
		end
	end
	for _, p in pieces do
		p.CFrame = rot * p.CFrame
	end
	local mn, mx = Vector3.one * 1e9, -Vector3.one * 1e9
	for _, p in pieces do
		local h = p.Size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local w = p.CFrame * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)
					mn = mn:Min(w)
					mx = mx:Max(w)
				end
			end
		end
	end
	local feet = Vector3.new((mn.X + mx.X) / 2, mn.Y, (mn.Z + mx.Z) / 2)
	local model = Instance.new("Model")
	model.Name = rig .. "_jointed"
	local out = {}
	for _, p in pieces do
		local rel = CFrame.new(feet):ToObjectSpace(p.CFrame)
		local limb = limbOf(p.Name, rel.Position.X)
		p:SetAttribute("Part", p.Name)
		p:SetAttribute("Limb", limb)
		p.Name = limb
		p.Anchored = true
		p.CanCollide = false
		p.CFrame = CFrame.new(0, -500, 0) * rel
		p.Parent = model
		table.insert(out, limb .. "<-" .. p:GetAttribute("Part"))
	end
	local old = game.ReplicatedStorage.BossModels[rig]
	local opiv = old:GetPivot()
	for _, q in old:GetDescendants() do
		if q:IsA("BasePart") and q.Name ~= "P00" and not q:GetAttribute("Limb") then
			local k = q:Clone()
			k.CFrame = CFrame.new(0, -500, 0) * opiv:ToObjectSpace(q.CFrame)
			k.Parent = model
		end
	end
	model.WorldPivot = CFrame.new(0, -500, 0)
	model.Parent = workspace.BossRigTest
	model:PivotTo(at)
	src:Destroy()
	return model, table.concat(out, ", ")
end

local function verts(p, want)
	local em = AS:CreateEditableMeshAsync(Content.fromUri(p.MeshId))
	local ids = em:GetVertices()
	local mn, mx = Vector3.one * 1e9, -Vector3.one * 1e9
	for _, id in ids do
		local v = em:GetPosition(id)
		mn = mn:Min(v)
		mx = mx:Max(v)
	end
	local c = (mn + mx) / 2
	local k = p.Size / (mx - mn)
	local step = math.max(1, math.floor(#ids / want))
	local out = {}
	for i = 1, #ids, step do
		table.insert(out, p.CFrame * ((em:GetPosition(ids[i]) - c) * k))
	end
	em:Destroy()
	return out
end

-- the centroid of a's points nearest to b's (where they touch), and the smallest gap
local function contact(aPts, bPts)
	local scored = {}
	for _, a in aPts do
		local best = math.huge
		for _, b in bPts do
			local d = (a - b).Magnitude
			if d < best then
				best = d
			end
		end
		table.insert(scored, { d = best, p = a })
	end
	table.sort(scored, function(x, y)
		return x.d < y.d
	end)
	local n = math.max(12, math.floor(#scored * 0.04))
	local sum = Vector3.zero
	for i = 1, n do
		sum += scored[i].p
	end
	return sum / n, scored[1].d
end

function T.joints(model)
	local parts = {}
	for _, p in model:GetChildren() do
		if p:IsA("MeshPart") and p:GetAttribute("Limb") then
			parts[p] = p:GetAttribute("Limb")
		end
	end
	local body
	for p, l in parts do
		if l == "body" then
			body = p
		end
	end
	local bodyPts = verts(body, 1500)
	local res = {}
	local armPts = {}
	for p, l in parts do
		if l == "head" or l == "armL" or l == "armR" then
			local pts = verts(p, 900)
			if l ~= "head" then
				armPts[p] = pts
			end
			local j, gap = contact(pts, bodyPts)
			local att = p:FindFirstChild("Joint") or Instance.new("Attachment")
			att.Name = "Joint"
			att.Parent = p
			att.WorldPosition = j
			local rel = model:GetPivot():PointToObjectSpace(j)
			table.insert(res, string.format("%s joint %.2f,%.2f,%.2f gap %.2f", l, rel.X, rel.Y, rel.Z, gap))
			task.wait()
		end
	end
	-- a held thing (staff, pitchfork, scythe) goes with the arm that touches it
	for p, l in parts do
		if l == "item" then
			local pts = verts(p, 600)
			local bestArm, bestGap = nil, math.huge
			for arm, aPts in armPts do
				local _, gap = contact(pts, aPts)
				if gap < bestGap then
					bestArm, bestGap = arm, gap
				end
			end
			if bestArm then
				local limb = bestArm:GetAttribute("Limb")
				p:SetAttribute("Limb", limb)
				p.Name = limb .. "_item"
				local att = p:FindFirstChild("Joint") or Instance.new("Attachment")
				att.Name = "Joint"
				att.Parent = p
				att.WorldPosition = bestArm.Joint.WorldPosition
				table.insert(res, string.format("item -> %s (gap %.2f)", limb, bestGap))
			end
		end
	end
	return table.concat(res, " | ")
end

return T
