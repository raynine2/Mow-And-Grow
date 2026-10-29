-- Run in Studio (Edit mode) after the data is in ServerStorage.ClaudeVfxBuf (StringValues, one per effect: zlib +
-- base64 of tools/vfx-import/export.luau's JSON): rebuilds each effect into ReplicatedStorage.OwnerVFX.<Name>
-- (an existing one of that name is moved to ServerStorage.MowALawnBackups first). Paste inflate.luau's two
-- functions above this (as `inf`).
return function(inf: any)
	local HttpService = game:GetService("HttpService")
	local buf = game.ServerStorage:FindFirstChild("ClaudeVfxBuf")
	if not buf then
		return "no ClaudeVfxBuf"
	end
	local dest = game.ReplicatedStorage:FindFirstChild("OwnerVFX")
	if not dest then
		dest = Instance.new("Folder")
		dest.Name = "OwnerVFX"
		dest.Parent = game.ReplicatedStorage
	end
	local function dec(v: any): any
		if type(v) ~= "table" then
			return v
		end
		local t, x = v.t, v.v
		if t == "V3" then
			return Vector3.new(x[1], x[2], x[3])
		elseif t == "V2" then
			return Vector2.new(x[1], x[2])
		elseif t == "CF" then
			return CFrame.new(table.unpack(x))
		elseif t == "C3" then
			return Color3.new(x[1], x[2], x[3])
		elseif t == "NR" then
			return NumberRange.new(x[1], x[2])
		elseif t == "NS" then
			local k = {}
			for _, p in x do
				table.insert(k, NumberSequenceKeypoint.new(p[1], p[2], p[3]))
			end
			return NumberSequence.new(k)
		elseif t == "CS" then
			local k = {}
			for _, p in x do
				table.insert(k, ColorSequenceKeypoint.new(p[1], Color3.new(p[2], p[3], p[4])))
			end
			return ColorSequence.new(k)
		elseif t == "E" then
			local et = string.gsub(x[1], "^Enum%.", "")
			return (Enum :: any)[et][x[2]]
		end
		return nil
	end
	local report = {}
	for _, sv in buf:GetChildren() do
		local data = HttpService:JSONDecode(inf.inflate(inf.unbase64(sv.Value)))
		local byId: { [number]: Instance } = {}
		local skipped = 0
		local function build(n: any, parent: Instance?): Instance
			local i = Instance.new(n.c)
			i.Name = n.n
			for prop, v in n.p do
				local ok = pcall(function()
					(i :: any)[prop] = dec(v)
				end)
				if not ok then
					skipped += 1
				end
			end
			for k, v in n.a do
				pcall(function()
					i:SetAttribute(k, dec(v))
				end)
			end
			if i:IsA("BasePart") then
				i.Anchored = true -- (templates sit still; the game moves them)
			end
			byId[n.id] = i
			for _, c in n.k do
				build(c, i)
			end
			if parent then
				i.Parent = parent
			end
			return i
		end
		local roots = {}
		for _, r in data.roots do
			table.insert(roots, build(r, nil))
		end
		for _, r in data.refs do
			local a, b = byId[r[1]], byId[r[3]]
			if a and b then
				pcall(function()
					(a :: any)[r[2]] = b
				end)
			end
		end
		for _, root in roots do
			local old = dest:FindFirstChild(root.Name)
			if old then
				local bk = game.ServerStorage:FindFirstChild("MowALawnBackups") or Instance.new("Folder", game.ServerStorage)
				bk.Name = "MowALawnBackups"
				old.Name = old.Name .. "_old"
				old.Parent = bk
			end
			-- a Model needs a PrimaryPart to be moved about: its first part
			if root:IsA("Model") and not root.PrimaryPart then
				root.PrimaryPart = root:FindFirstChildWhichIsA("BasePart", true)
			end
			root.Parent = dest
			local n = #root:GetDescendants()
			table.insert(report, root.Name .. " " .. n .. " instances" .. (if skipped > 0 then " (" .. skipped .. " props skipped)" else ""))
		end
	end
	return table.concat(report, "; ")
end
