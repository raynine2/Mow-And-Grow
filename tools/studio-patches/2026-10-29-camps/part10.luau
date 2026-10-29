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

put("CampDress.6", [====[			ctx.lanternPost(ctx.f, ctx.base + d * (ctx.R - 1.5), d)
		end
	end
	VoxelKit.crate(ctx.f, at(ctx, 19.2, 14.6) * CFrame.new(0, 0.6, 0), 1.2, ctx.rng)
	VoxelKit.barrel(ctx.f, at(ctx, -19.6, -9.6), 2.2, ctx.rng)
	-- market goods behind the stall keepers, planters at the sides, flowering bushes by the arch
	for _, s in { -1, 1 } do
		VoxelKit.crate(ctx.f, at(ctx, s * 13.4, -12.9) * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, s * 0.3, 0), 1.2, ctx.rng)
		VoxelKit.barrel(ctx.f, at(ctx, s * 15.0, -11.4), 2.0, ctx.rng)
		local pd = dirAt(ctx, s * 85)
		local pp = ctx.base + pd * (ctx.R - 1.6)
		VoxelKit.planter(ctx.f, CFrame.lookAt(pp, pp - pd), 4.6, { ctx.roles.flower[2], Color3.new(1, 1, 1) }, ctx.rng)
		VoxelKit.bush(ctx.f, at(ctx, s * 9.8, ctx.R - 2.4), C.leaf, ctx.rng, { ctx.roles.flower[2], ctx.roles.accent[2] })
	end
	-- round it
	for _, step in { house, landmark, tents, animals } do
		local ok, err = pcall(step, ctx)
		if not ok then
			warn(("[CampDress] area %d: %s"):format(ctx.z, tostring(err)))
		end
	end
	print(("[CampDress] %s camp: %s"):format(ctx.id :: string, table.concat(ctx.placed :: { string }, ", ")))
	-- people: by the stalls, walking round, and the air
	villager(ctx, at(ctx, -12.4, -9.4, ctx.fwd), "idle", { outfit = 1 })
	villager(ctx, at(ctx, 12.4, -9.4, ctx.fwd), "idle", { outfit = 2 })
	local path = {}
	for _, p in LOOP do
		table.insert(path, ctx.base + ctx.right * p[1] + ctx.fwd * p[2])
	end
	villager(ctx, CFrame.lookAt(path[1], path[2]), "walk", { path = path })
	air(ctx)
end

return CampDress
]====], "1540 1609750314")
return "part 10/13 (CampDress.6): " .. (if #bad == 0 then "ok" else table.concat(bad, ", "))
