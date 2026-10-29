-- Every class's own gimmick (owner, 27 Oct: "make every class feel unique and have its own gimmick, so don't only
-- increase stats"). The stats in Config.CLASSES stay; on top each class plays differently (Config.CLASSES[i].gimmick
-- has the name and the line the class cards show):
--   Weed Puller        Root Rip      every 6th swing hits 8x as hard (rips clumps out by the root)
--   Gardener           Green Thumb   bundles fly to you from much further away
--   Groundskeeper      Tidy Up       when a clump falls, the 2 nearest clumps take a free hit
--   Lawn Baron         Courier       a full bag sells itself (60%) wherever you are, every 60 s
--   Hedge Reaper       Reap Wave     every 8th swing sends out a wave that hits every clump round you
--   Mower Specialist   Turbo Deck    ride-on mowers cut 25% wider, drive 15% faster, burn 40% less fuel
--   Grass Titan        Titan Stomp   land from a jump to stomp: every clump round you takes 2 hits (4 s cooldown)
--   Ultimate Gardener  Midas Touch   every 20th clump you uncover is a mutation (Golden or better)
--   Lawn Legend        Hot Streak    each clump you cut in a streak adds +5% power (up to +60%); fades 2.5 s after
--   Goat Man           Graze         you eat grass as you walk: clumps round you take a hit every 0.75 s
-- Server-checked: the only thing a client can ask for is a stomp, and that has a cooldown and needs the class.
-- server/Run calls in here; client/ClassFx draws the effects ("classFx") and sends the stomp.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Net = require(script.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)

local ClassPerks = {}

-- the numbers (Config.CLASS_GIMMICK holds the same in words for the cards)
-- (29 Oct, balance 2) the owner: "check our mowers its way too op and some classes". A one-hit rip on every target of a
-- wide tool let a Weed Puller fell a late area with Bare Hands (any HP, every 6th swing), so the rip is a big hit
-- now; Courier was 80% every 45 s, Turbo Deck 1.4 / 1.2 / 0.5, Graze every 0.5 s (tools/balance_model.py).
local ROOT_RIP_EVERY, ROOT_RIP_MULT = 6, 8
local TIDY_RADIUS, TIDY_COUNT = 12, 2
local COURIER_CUT, COURIER_COOLDOWN = 0.6, 60
local WAVE_EVERY, WAVE_RADIUS = 8, 14
local TURBO = { radius = 1.25, speed = 1.15, fuel = 0.6 }
local STOMP_RADIUS, STOMP_HITS, STOMP_COOLDOWN = 12, 2, 4
local MIDAS_EVERY = 20
local STREAK_PER, STREAK_MAX, STREAK_WINDOW = 0.05, 0.6, 2.5
local GRAZE_RADIUS, GRAZE_EVERY = 7, 0.75
local MAGNET_BONUS = 14

type P = { swings: number, reveals: number, streak: number, streakAt: number, lastStomp: number, lastCourier: number, lastGraze: number, splashing: boolean }
local per: { [Player]: P } = {}

local function state(player: Player): P
	local s = per[player]
	if not s then
		s = { swings = 0, reveals = 0, streak = 0, streakAt = 0, lastStomp = 0, lastCourier = 0, lastGraze = 0, splashing = false }
		per[player] = s
	end
	return s
end

Players.PlayerRemoving:Connect(function(p)
	per[p] = nil
end)

local function classOf(player: Player): string?
	local data = PlayerData.get(player)
	return data and data.class or nil
end

-- Every player's equipped class as the player attribute "Class", so every client can draw its aura
-- (client/RarityFx). Main.server requires this module in the lobby too, so it runs in both modes.
task.spawn(function()
	while true do
		for _, p in Players:GetPlayers() do
			local id = classOf(p)
			if p:GetAttribute("Class") ~= id then
				p:SetAttribute("Class", id)
			end
		end
		task.wait(1)
	end
end)

function ClassPerks.is(player: Player, id: string): boolean
	return classOf(player) == id
end

local function fx(kind: string, pos: Vector3, r: number?, extra: { [string]: any }?)
	local msg = { kind = kind, pos = pos, r = r }
	for k, v in extra or {} do
		msg[k] = v
	end
	Net.all("Fx", "classFx", msg)
end

-- The hooks server/Run fills in (Field, the run's hit numbers, selling): set by Run.start.
ClassPerks.hitArea = nil :: ((Player, Vector3, number, number, number?) -> number)? -- (player, pos, radius, damage, max)
ClassPerks.baseDamage = nil :: ((Player) -> number)? -- a normal hit with the player's best tool
ClassPerks.sellAnywhere = nil :: ((Player, number) -> number)? -- (player, value multiplier) -> coins

-------------------------------------------------------------------------------------------------------------
-- power (Hot Streak) and swings (Root Rip, Reap Wave)
-------------------------------------------------------------------------------------------------------------
-- Extra power multiplier right now (Lawn Legend's streak).
function ClassPerks.powerMult(player: Player): number
	if not ClassPerks.is(player, "LawnLegend") then
		return 1
	end
	local s = state(player)
	if os.clock() - s.streakAt > STREAK_WINDOW then
		s.streak = 0
		return 1
	end
	return 1 + math.min(STREAK_MAX, s.streak * STREAK_PER)
end

-- A hand-tool swing is about to land: returns the damage to use (Root Rip makes it an 8x hit).
function ClassPerks.swing(player: Player, damage: number, rootPos: Vector3): number
	local s = state(player)
	s.swings += 1
	local id = classOf(player)
	if id == "WeedPuller" and s.swings % ROOT_RIP_EVERY == 0 then
		fx("rootRip", rootPos, 4)
		return damage * ROOT_RIP_MULT * ClassPerks.powerMult(player)
	end
	if id == "HedgeReaper" and s.swings % WAVE_EVERY == 0 and ClassPerks.hitArea then
		fx("reapWave", rootPos, WAVE_RADIUS)
		task.defer(ClassPerks.hitArea, player, rootPos, WAVE_RADIUS, damage)
	end
	return damage * ClassPerks.powerMult(player)
end

-------------------------------------------------------------------------------------------------------------
-- cuts (Tidy Up, the streak) and reveals (Midas Touch)
-------------------------------------------------------------------------------------------------------------
-- A clump was cut down by this player.
function ClassPerks.cut(player: Player, pos: Vector3)
	local id = classOf(player)
	local s = state(player)
	if id == "LawnLegend" then
		if os.clock() - s.streakAt > STREAK_WINDOW then
			s.streak = 0
		end
		s.streak += 1
		s.streakAt = os.clock()
		player:SetAttribute("ClassStreak", math.floor(math.min(STREAK_MAX, s.streak * STREAK_PER) * 100 + 0.5))
	elseif id == "Groundskeeper" and not s.splashing and ClassPerks.hitArea and ClassPerks.baseDamage then
		-- the splash hits don't splash again (no chain reactions across the field)
		task.defer(function()
			s.splashing = true
			local n = (ClassPerks.hitArea :: any)(player, pos, TIDY_RADIUS, (ClassPerks.baseDamage :: any)(player), TIDY_COUNT)
			s.splashing = false
			if n > 0 then
				fx("tidy", pos, TIDY_RADIUS)
			end
		end)
	end
end

-- A clump is being uncovered by this player: the mutation to force, or nil to roll as usual.
function ClassPerks.forcedMutation(player: Player?, rolled: string): string?
	if not player or not ClassPerks.is(player, "UltimateGardener") then
		return nil
	end
	local s = state(player)
	s.reveals += 1
	if s.reveals % MIDAS_EVERY == 0 and rolled == "None" then
		return "Golden"
	end
	return nil
end

function ClassPerks.midasShown(player: Player, pos: Vector3)
	fx("midas", pos, 5, { by = player.UserId })
end

-------------------------------------------------------------------------------------------------------------
-- mowers (Turbo Deck) and pickup reach (Green Thumb)
-------------------------------------------------------------------------------------------------------------
function ClassPerks.mower(player: Player): { radius: number, speed: number, fuel: number }
	if ClassPerks.is(player, "MowerSpecialist") then
		return TURBO
	end
	return { radius = 1, speed = 1, fuel = 1 }
end

function ClassPerks.reachBonus(player: Player): number
	return if ClassPerks.is(player, "Gardener") then MAGNET_BONUS else 0
end

-------------------------------------------------------------------------------------------------------------
-- every tick (Graze, Courier) and the stomp
-------------------------------------------------------------------------------------------------------------
function ClassPerks.tick(player: Player, root: BasePart?, driving: boolean, bagIsFull: boolean)
	local id = classOf(player)
	if not id or not root then
		return
	end
	local s = state(player)
	local now = os.clock()
	if id == "GoatMan" and not driving and now - s.lastGraze >= GRAZE_EVERY and ClassPerks.hitArea and ClassPerks.baseDamage then
		local v = root.AssemblyLinearVelocity
		if Vector3.new(v.X, 0, v.Z).Magnitude > 4 then
			s.lastGraze = now
			local n = ClassPerks.hitArea(player, root.Position, GRAZE_RADIUS, ClassPerks.baseDamage(player))
			if n > 0 then
				fx("graze", root.Position, GRAZE_RADIUS)
			end
		end
	elseif id == "LawnBaron" and bagIsFull and now - s.lastCourier >= COURIER_COOLDOWN and ClassPerks.sellAnywhere then
		local coins = ClassPerks.sellAnywhere(player, COURIER_CUT)
		if coins > 0 then
			s.lastCourier = now
			fx("courier", root.Position, 6, { coins = coins, by = player.UserId })
		end
	end
end

-- (client -> server) "stomp": a Grass Titan landed from a jump
function ClassPerks.setup()
	Net.on("ClassAct", 3, function(player: Player, action: any)
		if action ~= "stomp" or not ClassPerks.is(player, "GrassTitan") or not ClassPerks.hitArea or not ClassPerks.baseDamage then
			return
		end
		local s = state(player)
		local now = os.clock()
		if now - s.lastStomp < STOMP_COOLDOWN then
			return
		end
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not root or not hum or hum.FloorMaterial == Enum.Material.Air or hum.Sit then
			return
		end
		s.lastStomp = now
		fx("stomp", root.Position - Vector3.new(0, 2.5, 0), STOMP_RADIUS)
		ClassPerks.hitArea(player, root.Position, STOMP_RADIUS, ClassPerks.baseDamage(player) * STOMP_HITS)
	end)
end

return ClassPerks
