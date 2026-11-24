--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShopCatalog"))
local MatchScaleManager = require(script.Parent.MatchScaleManager)

local MonetizationService = {}

function MonetizationService.init()
	local remotes = ReplicatedStorage:FindFirstChild("ShopRemotes") :: Folder?
	if not remotes then
		local folder = Instance.new("Folder")
		folder.Name = "ShopRemotes"
		folder.Parent = ReplicatedStorage
		remotes = folder
	end
	local shopFolder = remotes :: Folder

	local function ensureRemote(name: string): RemoteEvent
		local existing = shopFolder:FindFirstChild(name)
		if existing and existing:IsA("RemoteEvent") then
			return existing
		end
		local ev = Instance.new("RemoteEvent")
		ev.Name = name
		ev.Parent = shopFolder
		return ev
	end

	local equipTint = ensureRemote("EquipFlashlightTint")
	local batteryGift = ensureRemote("BatteryGiftReceived")
	local setGiftTarget = ensureRemote("SetGiftTarget")

	local unlockedTints: { [Player]: { [string]: boolean } } = {}
	local pendingGiftTarget: { [number]: number } = {}
	local processedReceipts: { [string]: boolean } = {}

	local function watchPlayer(player: Player)
		unlockedTints[player] = { StandardHalogen = true }
		player:SetAttribute("FlashlightTint", "StandardHalogen")
	end

	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(player)
		unlockedTints[player] = nil
		pendingGiftTarget[player.UserId] = nil
	end)
	for _, p in Players:GetPlayers() do
		watchPlayer(p)
	end

	equipTint.OnServerEvent:Connect(function(player: Player, tintId: unknown)
		if typeof(tintId) ~= "string" then
			return
		end
		local tint = (ShopCatalog.Tints :: { [string]: ShopCatalog.FlashlightTint })[tintId]
		if not tint then
			return
		end
		local owned = unlockedTints[player]
		if owned and owned[tintId] then
			player:SetAttribute("FlashlightTint", tintId)
		elseif tint.productId > 0 then
			MarketplaceService:PromptProductPurchase(player, tint.productId)
		end
	end)

	setGiftTarget.OnServerEvent:Connect(function(player: Player, targetUserId: unknown)
		if typeof(targetUserId) == "number" and Players:GetPlayerByUserId(targetUserId) then
			pendingGiftTarget[player.UserId] = targetUserId
		end
	end)

	MarketplaceService.ProcessReceipt = function(receiptInfo)
		if processedReceipts[receiptInfo.PurchaseId] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		local buyer = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not buyer then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		for tintId, tint in ShopCatalog.Tints do
			if tint.productId > 0 and receiptInfo.ProductId == tint.productId then
				local owned = unlockedTints[buyer] or {}
				unlockedTints[buyer] = owned
				owned[tintId] = true
				buyer:SetAttribute("FlashlightTint", tintId)
				processedReceipts[receiptInfo.PurchaseId] = true
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
		end

		local batteryProduct = ShopCatalog.SupportProducts.GiftBatteryPack
		if batteryProduct.productId > 0 and receiptInfo.ProductId == batteryProduct.productId then
			local targetId = pendingGiftTarget[buyer.UserId] or buyer.UserId
			local target = Players:GetPlayerByUserId(targetId)
			if not target then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			batteryGift:FireClient(target, 50)
			processedReceipts[receiptInfo.PurchaseId] = true
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		local reviveProduct = ShopCatalog.SupportProducts.GiftFieldRevive
		if reviveProduct.productId > 0 and receiptInfo.ProductId == reviveProduct.productId then
			local targetId = pendingGiftTarget[buyer.UserId]
			local target = if targetId then Players:GetPlayerByUserId(targetId) else nil
			if not target or not MatchScaleManager.revivePlayer(target) then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			processedReceipts[receiptInfo.PurchaseId] = true
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	print("[MonetizationService] Cosmetic tints & altruistic receipt handler ready.")
end

return MonetizationService
