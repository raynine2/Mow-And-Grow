-- Robux: developer products (ProcessReceipt) and game passes. Ids live in Config; 0 means "not set up yet".
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Policy = require(ReplicatedStorage.MowALawn.Policy)
local Net = require(script.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)
local Stats = require(script.Parent.Stats)
local Mode = require(script.Parent.Mode)
local Tools = require(script.Parent.Tools)
local Quests = require(script.Parent.Quests)

local Monetization = {}

-- True when buying this tool product would give the player nothing new (so we never take Robux for it).
local function toolOwned(data, product): boolean
	local index = Config.toolIndex(product.tool) or 0
	if data.tools[product.tool] then
		return true
	end
	if product.forever then
		return false
	end
	return data.run ~= nil and data.run.tool >= index
end

-- Already owns what this (non-tool) product gives? Gems, eggs and restocks can always be bought again.
local function alreadyOwned(data, product): boolean
	if product.class then
		return data.classes[product.class] == true
	elseif product.gun then
		return data.guns ~= nil and data.guns[product.gun] == true
	elseif product.mower then
		local def = Config.mower(product.mower)
		if def and def.currency == "trial" then
			return data.run ~= nil and data.run.trial == true
		end
		return data.mowers[product.mower] == true
	end
	return false
end

-- Grant a product to a loaded profile. Returns true when granted.
local function grant(player: Player, data, key: string, product): boolean
	if product.gems then
		data.gems += product.gems
		Net.notify(player, "+" .. product.gems .. " gems! Thank you!", "purple")
	elseif product.mower then
		local def = Config.mower(product.mower)
		if not def then
			return false
		end
		if def.currency == "trial" then
			if not data.run then
				data.run = PlayerData.newRun() -- ready for the next run
			end
			data.run.trial = true
			data.run.fuel[def.id] = def.fuel
			Net.notify(player, "Trial Mower unlocked for this run! Spawn it at the Garage.", "purple")
		else
			data.mowers[def.id] = true
			Net.notify(player, def.name .. " is yours forever!", "purple")
		end
	elseif product.gun then
		local g = Config.gun(product.gun)
		if not g then
			return false
		end
		data.guns[g.id] = true
		Net.notify(player, "The " .. g.name .. " is in every boss crate for you now!", "purple")
	elseif product.egg then
		-- paid eggs hatch straight away (never refused: the Robux is already spent)
		local Pets = require(script.Parent.Pets) :: any
		if not Pets.hatch(player, data, product.egg, product.count or 1, true) then
			return false
		end
	elseif product.restock then
		-- the class card deal: new cards for this player until the next restock
		local lucky = product.restock == "lucky"
		-- (a full STOCK_WINDOW from now: bought late in a window it used to vanish at the restock seconds later)
		data.classDeal = { window = Config.stockWindow(), expires = workspace:GetServerTimeNow() + Config.STOCK_WINDOW, ids = Config.rollStock(Random.new(), lucky), lucky = lucky }
		Net.notify(player, if lucky then "Lucky cards dealt!" else "New cards dealt!", "pink")
	elseif product.tool then
		local index = Config.toolIndex(product.tool)
		if not index then
			return false
		end
		local def = Config.TOOLS[index]
		if product.forever then
			data.tools[def.id] = true
			Net.notify(player, def.name .. " is yours in every run!", "purple")
		else
			Net.notify(player, def.name .. " is yours for this run!", "purple")
		end
		if not data.run then
			data.run = PlayerData.newRun() -- ready for the next run
		end
		if index > data.run.tool then
			data.run.tool = index
		end
		if Mode.current == "Run" then
			Tools.give(player)
			Quests.event(player, "tool", data.run.tool)
		end
	elseif product.class then
		data.classes[product.class] = true
		data.class = product.class
		local c = Config.class(product.class)
		Net.notify(player, "You are now a " .. (if c then c.name else product.class) .. "!", "purple")
		Stats.applyCharacter(player, data)
	else
		warn("[Monetization] product " .. key .. " has nothing to grant")
		return false
	end
	Net.send(player, "Fx", "purchase", { big = true })
	return true
end

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = PlayerData.wait(player, 15)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if PlayerData.hasReceipt(data, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local key, product = Config.productByAssetId(receipt.ProductId)
	if not key or not product then
		warn("[Monetization] unknown product id " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not grant(player, data, key, product) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	PlayerData.addReceipt(data, purchaseId)
	PlayerData.changed(player)
	if not PlayerData.save(player) and not data._dryRun then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Game passes: cached as player attributes "Pass_<key>" (read by Stats).
local function refreshPasses(player: Player)
	for key, pass in Config.PASSES do
		if pass.id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			if ok and owns then
				player:SetAttribute("Pass_" .. key, true)
			end
		end
	end
end

local function vipTag(player: Player)
	if player:GetAttribute("Pass_VIP") ~= true then
		return
	end
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head or head:FindFirstChild("VIPTag") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "VIPTag"
	gui.Size = UDim2.fromScale(3, 1)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Config.UI.font
	label.TextScaled = true
	label.Text = "VIP"
	label.TextColor3 = Config.UI.yellow
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = head
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
	if not bought then
		return
	end
	for key, pass in Config.PASSES do
		if pass.id == passId then
			player:SetAttribute("Pass_" .. key, true)
			Net.notify(player, pass.name .. " unlocked! Thank you!", "purple")
		end
	end
	local data = PlayerData.get(player)
	if data then
		Stats.applyCharacter(player, data)
		PlayerData.changed(player)
	end
	vipTag(player)
end)

local function onPlayer(player: Player)
	task.spawn(function()
		refreshPasses(player)
		local data = PlayerData.wait(player, 30)
		if data then
			Stats.applyCharacter(player, data)
			PlayerData.changed(player)
		end
		vipTag(player)
	end)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		vipTag(player)
	end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do
	onPlayer(p)
end

function Monetization.start()
	Net.on("Prompt", 2, function(player, kind, key)
		if type(kind) ~= "string" or type(key) ~= "string" then
			return
		end
		if kind == "product" then
			local p = Config.PRODUCTS[key]
			if not p then
				return
			end
			if p.tool then
				local data = PlayerData.get(player)
				if not data or toolOwned(data, p) then
					Net.notify(player, "You already have that tool!", "yellow")
					return
				end
			end
			-- don't take Robux for something already owned (a stale window, a double click)
			local data = PlayerData.get(player)
			if data and alreadyOwned(data, p) then
				Net.notify(player, "You already have that!", "yellow")
				return
			end
			if p.id == 0 then
				Net.notify(player, "Coming soon!", "yellow")
				return
			end
			-- random paid items (eggs, restocks) only where Roblox's policy allows them for this player
			if p.paidRandom and not Policy.paidRandomOk(player) then
				Net.notify(player, "That isn't available where you are.", "yellow")
				return
			end
			local cls = if p.class then Config.class(p.class) :: any else nil
			if cls and cls.hidden then -- (30 Oct: a class hidden until its feature opens, shared/Config MOWERS_LOCKED)
				Net.notify(player, Config.MOWERS_LOCKED_TEXT, "yellow")
				return
			end
			if p.mower and Config.MOWERS_LOCKED then -- (30 Oct: never take Robux for a locked mower, shared/Config MOWERS_LOCKED)
				Net.notify(player, Config.MOWERS_LOCKED_TEXT, "yellow")
				return
			end
			MarketplaceService:PromptProductPurchase(player, p.id)
		elseif kind == "pass" then
			local p = Config.PASSES[key]
			if not p then
				return
			end
			if p.id == 0 then
				Net.notify(player, "Coming soon!", "yellow")
				return
			end
			MarketplaceService:PromptGamePassPurchase(player, p.id)
		end
	end)
end

return Monetization
