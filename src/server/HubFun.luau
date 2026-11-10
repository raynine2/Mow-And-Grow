--!strict
-- THE HUB'S EXTRAS (10 Nov 2026; owner: "the main hub is so boring, what can we add", picked: the top 3 as statues,
-- the two guides standing in the hub with tips and a daily gift, a free daily wheel; then "make the pets from eggs walk
-- here and make a hatch place to interact"). Config.HUB_FUN.
--
-- The server makes the spots (invisible anchored parts in World.HubFun: StatuesSpot, GuidesSpot, WheelSpot,
-- GardenSpot), the statues (server/HubStatues) and checks the two daily rewards; everything else is drawn by the
-- clients at the spots (client/HubGuides, client/HubWheel, client/HubGarden). A part named "HubSpot_<name>" in the
-- lobby map (the owner can drop one in Maps.Lobby in Studio) moves that spot.
--
-- Remote "HubFun": (action) "spin" | "gift". Each is once a UTC day, only near its spot; the answer comes back on Fx
-- ("hubSpin" { index, gems } / "hubGift" { gems }, or { wait } when it isn't ready). The player attributes
-- HubSpinNext / HubGiftNext are when the next one is ready (server time, 0 = now), for the clients' labels.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Net = require(script.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)

local HubFun = {}

local DAY = 86400
local NEAR = 26 -- how close you must be to the wheel / the guides
local folder: Folder? = nil
local spots: { [string]: BasePart } = {}
local rng = Random.new()
local wired = false

local function today(): number
	return os.time() // DAY
end

local function nextOf(day: number?): number
	return if day == today() then (today() + 1) * DAY else 0
end

local function refresh(player: Player, data: any)
	player:SetAttribute("HubSpinNext", nextOf(data.hubSpinDay))
	player:SetAttribute("HubGiftNext", nextOf(data.hubGiftDay))
end

-- where a spot is: the owner's HubSpot_<name> part in the map, else Config's position, on the ground
local function spotFrame(world: Instance, name: string, def: any): CFrame
	local override = world:FindFirstChild("HubSpot_" .. name, true)
	if override and (override:IsA("BasePart") or override:IsA("Model")) then
		-- (10 Nov, owner: "Import het") a part, or the imported model itself (Maps.Lobby.HubExtras: the owner drags it
		-- where he wants it in Studio); the model is only there to see and move, the game builds the working one
		local cf = if override:IsA("Model") then override:GetPivot() else (override :: BasePart).CFrame
		if override:IsA("BasePart") then
			override.Transparency = 1
			override.CanCollide = false
			override.CanQuery = false
		else
			override:Destroy()
		end
		local look = cf.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		local p = cf.Position
		return CFrame.lookAt(p, p + (if flat.Magnitude > 0.1 then flat else Vector3.zAxis))
	end
	local pos = def.pos :: Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { world, workspace.Terrain }
	local hit = workspace:Raycast(pos + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), params)
	local at = Vector3.new(pos.X, if hit then hit.Position.Y else pos.Y, pos.Z)
	local face = def.face :: Vector3
	return CFrame.lookAt(at, Vector3.new(face.X, at.Y, face.Z))
end

local function near(player: Player, name: string): boolean
	local spot = spots[name]
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return spot ~= nil and root ~= nil and (root.Position - spot.Position).Magnitude <= NEAR
end

local function pick(): (number, any)
	local list = Config.HUB_FUN.prizes
	local total = 0
	for _, p in list do
		total += p.weight
	end
	local r = rng:NextNumber() * total
	for i, p in list do
		r -= p.weight
		if r <= 0 then
			return i, p
		end
	end
	return #list, list[#list]
end

local function spin(player: Player, data: any)
	if not near(player, "Wheel") then
		return
	end
	if data.hubSpinDay == today() then
		Net.send(player, "Fx", "hubSpin", { wait = nextOf(data.hubSpinDay) })
		return
	end
	local i, prize = pick()
	data.hubSpinDay = today()
	data.gems += prize.gems
	refresh(player, data)
	Net.send(player, "Fx", "hubSpin", { index = i, gems = prize.gems })
	-- the gem counter goes up when the wheel stops (client/HubWheel spins ~5 s), not before
	task.delay(5.5, function()
		if player.Parent then
			PlayerData.changed(player)
		end
	end)
end

local function gift(player: Player, data: any)
	if not near(player, "Guides") then
		return
	end
	if data.hubGiftDay == today() then
		Net.send(player, "Fx", "hubGift", { wait = nextOf(data.hubGiftDay) })
		return
	end
	data.hubGiftDay = today()
	data.gems += Config.HUB_FUN.gift
	refresh(player, data)
	Net.send(player, "Fx", "hubGift", { gems = Config.HUB_FUN.gift })
	task.delay(1.2, function()
		if player.Parent then
			PlayerData.changed(player)
		end
	end)
end

local function wire()
	if wired then
		return
	end
	wired = true
	PlayerData.onLoaded(function(player, data)
		refresh(player, data)
	end)
end

function HubFun.start(world: Instance)
	if not Config.HUB_FUN or not Config.HUB_FUN.on then
		return
	end
	HubFun.stop()
	local f = Instance.new("Folder")
	f.Name = "HubFun"
	for name, def in Config.HUB_FUN.spots do
		local p = Instance.new("Part")
		p.Name = name .. "Spot"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(1, 1, 1)
		p.CFrame = spotFrame(world, name, def)
		p.Parent = f
		spots[name] = p
	end
	f.Parent = world
	folder = f
	wire()
	Net.on("HubFun", 2, function(player, action)
		local data = PlayerData.get(player)
		if not data or not folder or not folder.Parent then
			return
		end
		if action == "spin" then
			spin(player, data)
		elseif action == "gift" then
			gift(player, data)
		end
	end)
	local ok, err = pcall(function()
		require(script.Parent.HubStatues).start(f, spots.Statues)
	end)
	if not ok then
		warn("[HubFun] statues: " .. tostring(err))
	end
	print("[HubFun] the hub's extras are up (statues, guides, wheel, garden)")
end

function HubFun.stop()
	pcall(function()
		require(script.Parent.HubStatues).stop()
	end)
	if folder then
		folder:Destroy()
		folder = nil
	end
	table.clear(spots)
end

return HubFun
