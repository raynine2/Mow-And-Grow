-- Roblox policy checks, on the server and the client. The owner's rule: a Robux purchase with a random result
-- (Config.PRODUCTS[...].paidRandom: the Golden Egg, the class restocks) shows its odds and is hidden where
-- PolicyService says paid random items are restricted. If the policy can't be read, we treat it as restricted.
local PolicyService = game:GetService("PolicyService")
local Players = game:GetService("Players")

local Policy = {}

local cache: { [number]: boolean } = {}
local pending: { [number]: boolean } = {}

local function fetch(player: Player): boolean
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	if ok and type(info) == "table" then
		return info.ArePaidRandomItemsRestricted == false
	end
	return false
end

-- May this player buy paid random items? Yields the first time (one web call); false until it is known.
function Policy.paidRandomOk(player: Player?): boolean
	local p = player or Players.LocalPlayer
	if not p then
		return false
	end
	local v = cache[p.UserId]
	if v ~= nil then
		return v
	end
	if pending[p.UserId] then
		while pending[p.UserId] do
			task.wait()
		end
		return cache[p.UserId] == true
	end
	pending[p.UserId] = true
	local result = fetch(p)
	cache[p.UserId] = result
	pending[p.UserId] = nil
	return result
end

-- The cached answer without yielding (nil = not asked yet).
function Policy.known(player: Player?): boolean?
	local p = player or Players.LocalPlayer
	return p and cache[p.UserId]
end

Players.PlayerRemoving:Connect(function(p)
	cache[p.UserId] = nil
end)

return Policy
