-- Best Times: the fastest finished runs. A run's time is the time you spent playing it (profile.run.time, counted
-- by server/Run), so leaving and coming back later doesn't count. Each player's best is in their profile
-- (bestTime); the all-servers top list is an OrderedDataStore (lower = better) that the lobby's trophy board reads.
-- Every character wears a small trophy tag with its best time. Studio dry runs never write.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Format = require(ReplicatedStorage.MowALawn.Format)
local PlayerData = require(script.Parent.PlayerData)

local BestTimes = {}

local store: OrderedDataStore? = nil
pcall(function()
	store = DataStoreService:GetOrderedDataStore(Config.SAVE_KEY .. "_BestTimes")
end)

local names: { [number]: string } = {}
local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local p = Players:GetPlayerByUserId(userId)
	local name = if p then p.DisplayName else nil
	if not name then
		local ok, result = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		name = if ok and result then result else "Player"
	end
	names[userId] = name :: string
	return name :: string
end

-- A run was finished in `seconds`. Returns true if it's the player's new best.
function BestTimes.submit(player: Player, data, seconds: number): boolean
	seconds = math.floor(seconds)
	if seconds <= 0 then
		return false
	end
	local better = (data.bestTime or 0) == 0 or seconds < data.bestTime
	if not better then
		return false
	end
	data.bestTime = seconds
	if store and not data._dryRun and not RunService:IsStudio() then
		task.spawn(function()
			local ok, err = pcall(function()
				(store :: OrderedDataStore):SetAsync(tostring(player.UserId), seconds)
			end)
			if not ok then
				warn("[BestTimes] couldn't save " .. player.Name .. "'s time: " .. tostring(err))
			end
		end)
	end
	return true
end

-- The `n` fastest runs from every server: { { name, time } }, fastest first. Empty if the store can't be read.
function BestTimes.top(n: number): { { name: string, time: number } }
	local out = {}
	if not store then
		return out
	end
	local ok, pages = pcall(function()
		return (store :: OrderedDataStore):GetSortedAsync(true, n)
	end)
	if not ok or not pages then
		return out
	end
	for _, entry in (pages :: DataStorePages):GetCurrentPage() do
		local id = tonumber(entry.key)
		if id and type(entry.value) == "number" and entry.value > 0 then
			table.insert(out, { name = nameOf(id), time = entry.value })
		end
	end
	return out
end

-- The trophy tag over a character's head (only once they have a best time).
local function tag(player: Player)
	local data = PlayerData.get(player)
	local char = player.Character
	local head = char and char:FindFirstChild("Head") :: BasePart?
	if not head or not data then
		return
	end
	local gui = head:FindFirstChild("BestTimeTag") :: BillboardGui?
	if (data.bestTime or 0) <= 0 then
		if gui then
			gui:Destroy()
		end
		return
	end
	if not gui then
		local g = Instance.new("BillboardGui")
		g.Name = "BestTimeTag"
		g.Size = UDim2.fromOffset(150, 28)
		g.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
		g.MaxDistance = 70
		g.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Name = "Time"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Config.UI.font
		label.TextScaled = true
		label.TextColor3 = Config.UI.yellow
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Config.UI.outline
		stroke.Parent = label
		label.Parent = g
		g.Parent = head
		gui = g
	end
	local label = (gui :: BillboardGui):FindFirstChild("Time") :: TextLabel
	local text = "🏆 " .. Format.clock(data.bestTime)
	if label.Text ~= text then
		label.Text = text
	end
end

local started = false
function BestTimes.start()
	if started then
		return
	end
	started = true
	PlayerData.onLoaded(function(player)
		player.CharacterAdded:Connect(function(char)
			char:WaitForChild("Head", 10)
			tag(player)
		end)
		if player.Character then
			task.spawn(tag, player)
		end
	end)
	PlayerData.onChanged(function(player)
		tag(player)
	end)
end

return BestTimes
