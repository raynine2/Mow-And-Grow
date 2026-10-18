-- Robux: developer products (ProcessReceipt) and game passes. Ids live in Config; 0 means "not set up yet".
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Net = require(script.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)
local Stats = require(script.Parent.Stats)

local Monetization = {}

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
			if p.id == 0 then
				Net.notify(player, "Coming soon!", "yellow")
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
