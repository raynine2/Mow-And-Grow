--!strict
-- THE GUIDES IN THE HUB (10 Nov 2026; owner picked "5": the two of them standing in the hub, goofy, a tip or a joke
-- when you talk to them, a small gift once a day). RAYAN and BRRBRR (Config.TUTOR_GUIDES, the same bodies, bubbles
-- and moves as the tutorial's: client/TutorGuide's kit) stand at the hub's GuidesSpot (server/HubFun), turn to you
-- when you come close, and goof around now and then (a dance, a laugh, a spin, a wave). TALK: a tip or a joke; the
-- other one sometimes answers. When the daily gift is ready (player attribute HubGiftNext) a present bobs by Rayan's
-- head and TALK says DAILY GIFT: the server checks it and gives Config.HUB_FUN.gift gems (Fx "hubGift").
-- Only in the lobby (the spot is only there); each player sees their own pair.
local HubGuides = {}
task.spawn(function()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")

	local player = Players.LocalPlayer
	local here = script.Parent
	local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
	local State = require(here:WaitForChild("State"))
	local TutorGuide = require(here:WaitForChild("TutorGuide")) :: any
	if not Config.HUB_FUN or not Config.HUB_FUN.on then
		return
	end

	-- what they say (short: one bubble each)
	local TIPS = {
		"Buy {Swing Speed} first. Trust me.",
		"{Golden grass} sells for way more!",
		"Full bag? Run to the {shredder}!",
		"Pets make you stronger. Hatch some in the {Pet Garden}!",
		"Bosses drop big loot. Bring {friends}!",
		"Step on a {pad} to start a run.",
		"The {wheel} over there is free every day!",
		"Do your {quests} for free gems.",
		"Mow it ALL to open the next area!",
	}
	local JOKES = {
		"Why did the grass go to school? To get {greener}!",
		"I mowed so much, I AM the lawn mower now.",
		"Brrbrr thinks grass is a vegetable. It's not.",
		"My favourite dance? The {lawn-moonwalk}.",
	}
	local SIDE = {
		"Hehehe!",
		"He says that every day.",
		"Brrr... it's windy up here!",
		"Don't tell him, but I'm the better dancer.",
		"True story!",
	}
	local GOOFS = { "dance1", "dance2", "dance3", "laugh", "spin", "wave", "spin" }

	local kit: any = nil
	repeat
		kit = TutorGuide.kit
		if not kit then
			task.wait(0.5)
		end
	until kit
	local src = ReplicatedStorage:WaitForChild("MowALawnGuides", 60)
	if not src then
		return
	end

	local function serverNow(): number
		return workspace:GetServerTimeNow()
	end
	local function giftReady(): boolean
		local nxt = player:GetAttribute("HubGiftNext")
		return type(nxt) == "number" and nxt <= serverNow()
	end

	type Hub = { guides: { any }, folder: Folder, spot: BasePart, conns: { RBXScriptConnection } }
	local hub: Hub? = nil
	local building = false -- (bringOut waits for the bodies: one at a time)

	local function stand(g: any, at: CFrame, dt: number)
		local up = g.hum.HipHeight + g.root.Size.Y / 2
		local yawCF = CFrame.Angles(0, g.yaw, 0)
		g.model:PivotTo(CFrame.new(at.Position + Vector3.new(0, up + kit.hopY(g), 0)) * yawCF * kit.goofyPose(g, dt))
		if os.clock() > g.busyUntil then
			kit.play(g, "idle")
		end
	end

	local function goof(g: any, now: number)
		if now < g.nextGoof or g.bubble.Enabled or now < g.busyUntil then
			return
		end
		g.nextGoof = now + 5 + math.random() * 5
		local k = GOOFS[math.random(1, #GOOFS)]
		if k == "spin" then
			g.spinAt, g.hopAt = now, now
		elseif k == "wave" then
			kit.gesture(g, "wave", 1.8, true)
		elseif k == "laugh" then
			kit.gesture(g, "laugh", 1.6, true)
		else
			kit.gesture(g, k, 3, true)
			kit.emote(g, "♪")
		end
	end

	local function talk(h: Hub, who: any)
		local lead, other = h.guides[1], h.guides[2]
		if giftReady() and lead then
			State.fire("HubFun", "gift")
			return
		end
		local pool = if who == lead or not other then (if math.random() < 0.6 then TIPS else JOKES) else SIDE
		kit.say(who, pool[math.random(1, #pool)], 1.5)
		who.hopAt = os.clock()
		local partner = if who == lead then other else lead
		if partner and math.random() < 0.45 then
			task.delay(2.2, function()
				if hub == h then
					kit.say(partner, SIDE[math.random(1, #SIDE)], 1)
				end
			end)
		end
	end

	local function promptOn(h: Hub, g: any): ProximityPrompt
		local pp = Instance.new("ProximityPrompt")
		pp.ActionText = "Talk"
		pp.ObjectText = g.def.label or g.def.key
		pp.KeyboardKeyCode = Enum.KeyCode.E
		pp.HoldDuration = 0
		pp.MaxActivationDistance = 11
		pp.RequiresLineOfSight = false
		pp.Parent = g.root
		pp.Triggered:Connect(function()
			talk(h, g)
		end)
		return pp
	end

	local function bringOut(spot: BasePart)
		local f = Instance.new("Folder")
		f.Name = "HubGuides"
		f.Parent = workspace
		local h: Hub = { guides = {}, folder = f, spot = spot, conns = {} }
		for i, def in Config.TUTOR_GUIDES do
			local template = src:WaitForChild(def.key, 15) :: Model?
			if template then
				local g = kit.build(def, template)
				if g then
					g.model.Parent = f
					kit.loadTracks(g)
					g.home = spot.CFrame * CFrame.new(if i == 1 then 2.4 else -2.4, 0, 0)
					g.yaw = select(2, g.home:ToEulerAnglesYXZ())
					g.nextGoof = os.clock() + 2 + i * 2.5
					g.prompt = promptOn(h, g)
					table.insert(h.guides, g)
				end
			end
		end
		return h
	end

	local function putAway(h: Hub)
		for _, c in h.conns do
			c:Disconnect()
		end
		h.folder:Destroy()
	end

	-- the gift: the answer from the server
	State.on("fx", function(kind: string, payload: any)
		local h = hub
		if kind ~= "hubGift" or not h then
			return
		end
		local lead, other = h.guides[1], h.guides[2]
		if payload.gems then
			kit.say(lead, ("Here, take {%d gems}! See you tomorrow!"):format(payload.gems), 2)
			kit.emote(lead, "heart")
			lead.hopAt = os.clock()
			kit.burst(lead.root.Position + Vector3.new(0, 2, 0), lead.def.color, false)
			if other then
				task.delay(0.4, function()
					kit.gesture(other, "cheer", 1.6)
					kit.emote(other, "star")
				end)
			end
		end
	end)

	RunService.Heartbeat:Connect(function(dt: number)
		local world = workspace:FindFirstChild("World")
		local fun = world and world:FindFirstChild("HubFun")
		local spot = fun and fun:FindFirstChild("GuidesSpot") :: BasePart?
		if not spot or State.isRun() then
			if hub then
				putAway(hub)
				hub = nil
			end
			return
		end
		if not hub then
			if not building then
				building = true
				task.spawn(function()
					local h = bringOut(spot)
					building = false
					if spot.Parent and not State.isRun() then
						hub = h
					else
						putAway(h)
					end
				end)
			end
			return
		end
		local h = hub :: Hub
		local now = os.clock()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local ready = giftReady()
		for i, g in h.guides do
			-- face you when you're close, else look out over the plaza
			local yawWant = select(2, g.home:ToEulerAnglesYXZ())
			if root and (root.Position - g.home.Position).Magnitude < 20 then
				local v = root.Position - g.home.Position
				yawWant = math.atan2(-v.X, -v.Z)
			end
			local dy = (yawWant - g.yaw + math.pi) % (2 * math.pi) - math.pi
			g.yaw += dy * math.min(1, dt * 6)
			stand(g, g.home, dt)
			goof(g, now)
			if i == 1 then
				g.prompt.ActionText = if ready then "Daily gift!" else "Talk"
				if ready and now > (g.giftPing or 0) then
					g.giftPing = now + 3.2
					kit.emote(g, "🎁")
				end
			end
		end
	end)
end)
return HubGuides
