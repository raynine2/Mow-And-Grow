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
local bad = {}
local function put(name, text, want)
	if hashOf(text) ~= want then
		table.insert(bad, name .. " garbled")
		return
	end
	local v = buf:FindFirstChild(name) or Instance.new("StringValue")
	v.Name = name
	v.Value = text
	v.Parent = buf
end

put("CampProps.4", [====[			part.CanCollide = false
			part.CanQuery = false
			part.CastShadow = false
		else
			part.Name = "P"
			part.Material = mt.material
			if mt.variant then
				part.MaterialVariant = mt.variant
			end
			part.Color = mt.color
			part.Transparency = mt.t
			local big = math.max(size.X, size.Y, size.Z) >= 1.6
			part.CanCollide = o.collide == true and big
			part.CanQuery = o.collide == true and big
			part.CastShadow = big
		end
		if gi and spec.groups[gi] then
			part:SetAttribute("G", spec.groups[gi].name)
		end
		part.Parent = model
		n += 1
	end
	for _, g in spec.groups do
		model:SetAttribute("Pivot_" .. g.name, g.pivot * k)
	end
	model:SetAttribute("NParts", n)
	model.WorldPivot = cf
	model.Parent = parent
	return model
end

-- The marker parts called `name` in a placed model (Smoke, Lamp, SignFace, Hand ...).
function CampProps.markers(model: Instance, name: string): { BasePart }
	local out = {}
	for _, d in model:GetChildren() do
		if d.Name == name and d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

-- Turn group `g` of a placed model about its pivot by `rot` (in the model's own axes), e.g. a signpost's arrow.
function CampProps.turnGroup(model: Model, g: string, rot: CFrame)
	local pivot = model:GetAttribute("Pivot_" .. g)
	if typeof(pivot) ~= "Vector3" then
		return
	end
	local at = model:GetPivot() * CFrame.new(pivot)
	local move = at * rot * at:Inverse()
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") and d:GetAttribute("G") == g then
			d.CFrame = move * d.CFrame
		end
	end
end

return CampProps
]====], "1574 651922944")
return "part 4/13 (CampProps.4): " .. (if #bad == 0 then "ok" else table.concat(bad, ", "))
