--!strict
--[[
  ShopService  –  SERVER-AUTHORITATIVE lobby shop & cosmetic equip handler.

  Remotes (under ReplicatedStorage/LobbyRemotes):
    RequestPurchase (RemoteFunction) client -> server (skinId) -> { ok, reason }
    RequestEquip    (RemoteEvent)    client -> server (skinId)
    ShopDataReply   (RemoteEvent)    server -> client { owned, equippedCharacter, equippedWeapon, dataError }
    PurchaseResult  (RemoteEvent)    server -> client { ok, reason, skinId? }

  Never trusts client for price or coin balance. Validates coins, ownership,
  and DataStore persistence; rolls back on DataStore save failure.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyConfig"))
local ShopCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShopCatalog"))
local PlayerDataService = require(script.Parent.PlayerDataService)

local ShopService = {}

local lastPurchaseTime: { [Player]: number } = {}
local lastEquipTime: { [Player]: number } = {}
local activeTransactions: { [Player]: boolean } = {}

local function ensureFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild("LobbyRemotes")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "LobbyRemotes"
	folder.Parent = ReplicatedStorage
	return folder
end

local function ensureRemoteEvent(parent: Folder, name: string): RemoteEvent
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local ev = Instance.new("RemoteEvent")
	ev.Name = name
	ev.Parent = parent
	return ev
end

local function ensureRemoteFunction(parent: Folder, name: string): RemoteFunction
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("RemoteFunction") then
		return existing
	end
	local rf = Instance.new("RemoteFunction")
	rf.Name = name
	rf.Parent = parent
	return rf
end

local function attachLobbyCosmetics(player: Player, character: Model)
	local existing = character:FindFirstChild("LobbyCosmeticProps")
	if existing then
		existing:Destroy()
	end

	local data = PlayerDataService.getData(player)
	if not data then
		return
	end

	local props = Instance.new("Folder")
	props.Name = "LobbyCosmeticProps"
	props.Parent = character

	local function weldPartTo(
		targetPart: BasePart,
		name: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		mat: Enum.Material
	): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = mat
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CFrame = targetPart.CFrame * offset
		p.Parent = props

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = targetPart
		weld.Part1 = p
		weld.Parent = p
		return p
	end

	-- Character skin headpiece / shoulder accent
	local charEntry = ShopCatalog.getSkinById(data.EquippedCharacterSkin)
	local head = character:FindFirstChild("Head")
	if charEntry and head and head:IsA("BasePart") then
		local style = charEntry.preview.style
		local primary = charEntry.preview.primaryColor
		local accent = charEntry.preview.accentColor

		if style == "ranger" or style == "warden" then
			weldPartTo(
				head,
				"HatBrim",
				Vector3.new(1.9, 0.14, 1.9),
				CFrame.new(0, 0.52, 0),
				primary,
				Enum.Material.Fabric
			)
			weldPartTo(
				head,
				"HatCrown",
				Vector3.new(1.25, 0.48, 1.25),
				CFrame.new(0, 0.78, 0),
				accent,
				Enum.Material.Fabric
			)
		elseif style == "miner" then
			weldPartTo(
				head,
				"MinerHelmet",
				Vector3.new(1.5, 0.55, 1.5),
				CFrame.new(0, 0.58, 0),
				primary,
				Enum.Material.Metal
			)
			local lamp = weldPartTo(
				head,
				"MinerLamp",
				Vector3.new(0.32, 0.28, 0.24),
				CFrame.new(0, 0.65, -0.78),
				accent,
				Enum.Material.Neon
			)
			lamp.CastShadow = false
		elseif style == "cultist" then
			weldPartTo(
				head,
				"CultHood",
				Vector3.new(1.65, 1.35, 1.65),
				CFrame.new(0, 0.25, 0.08),
				primary,
				Enum.Material.Fabric
			)
		elseif style == "spectre" then
			local halo = weldPartTo(
				head,
				"SpectreVeil",
				Vector3.new(1.55, 1.4, 1.55),
				CFrame.new(0, 0.1, 0),
				primary,
				Enum.Material.ForceField
			)
			halo.Transparency = 0.45
		elseif style == "antler" then
			for _, side in { -1, 1 } do
				weldPartTo(
					head,
					"AntlerBase",
					Vector3.new(0.18, 1.2, 0.18),
					CFrame.new(side * 0.48, 0.95, 0) * CFrame.Angles(0, 0, math.rad(-side * 24)),
					accent,
					Enum.Material.SmoothPlastic
				)
				weldPartTo(
					head,
					"AntlerTine",
					Vector3.new(0.14, 0.65, 0.14),
					CFrame.new(side * 0.82, 1.32, -0.18) * CFrame.Angles(math.rad(-25), 0, math.rad(-side * 12)),
					accent,
					Enum.Material.SmoothPlastic
				)
			end
		end
	end

	-- Weapon skin hip holster / belt prop
	local wpnEntry = ShopCatalog.getSkinById(data.EquippedWeaponSkin)
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if wpnEntry and torso and torso:IsA("BasePart") then
		local style = wpnEntry.preview.style
		local primary = wpnEntry.preview.primaryColor
		local accent = wpnEntry.preview.accentColor

		if style == "torch" then
			weldPartTo(
				torso,
				"HipTorch",
				Vector3.new(0.28, 0.9, 0.28),
				CFrame.new(1.05, -0.35, 0) * CFrame.Angles(math.rad(15), 0, 0),
				primary,
				Enum.Material.Metal
			)
		elseif style == "shard" then
			local shard = weldPartTo(
				torso,
				"HipShard",
				Vector3.new(0.22, 1.6, 0.45),
				CFrame.new(0, 0.2, 0.72) * CFrame.Angles(0, 0, math.rad(28)),
				accent,
				Enum.Material.Neon
			)
			shard.Transparency = 0.2
		else
			weldPartTo(
				torso,
				"HipWeapon",
				Vector3.new(0.14, 1.9, 0.34),
				CFrame.new(0, 0.15, 0.68) * CFrame.Angles(0, 0, math.rad(35)),
				primary,
				Enum.Material.Metal
			)
		end
	end
end

function ShopService.init()
	local remotes = ensureFolder()
	local requestPurchase = ensureRemoteFunction(remotes, "RequestPurchase")
	local requestEquip = ensureRemoteEvent(remotes, "RequestEquip")
	local shopDataReply = ensureRemoteEvent(remotes, "ShopDataReply")
	local purchaseResult = ensureRemoteEvent(remotes, "PurchaseResult")

	local function sendShopData(player: Player)
		local data = PlayerDataService.getData(player)
		if not data then
			return
		end
		local owned: { string } = {}
		for _, id in data.OwnedCharacterSkins do
			table.insert(owned, id)
		end
		for _, id in data.OwnedWeaponSkins do
			table.insert(owned, id)
		end
		shopDataReply:FireClient(player, {
			owned = owned,
			equippedCharacter = data.EquippedCharacterSkin,
			equippedWeapon = data.EquippedWeaponSkin,
			dataError = PlayerDataService.hasLoadFailed(player),
		})
	end

	local function watchPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.defer(function()
				if character.Parent then
					attachLobbyCosmetics(player, character)
				end
			end)
		end)
		task.spawn(function()
			local data = PlayerDataService.getData(player)
			if player.Parent ~= Players or not data then
				return
			end
			sendShopData(player)
			if player.Character then
				attachLobbyCosmetics(player, player.Character)
			end
		end)
	end

	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(player)
		lastPurchaseTime[player] = nil
		lastEquipTime[player] = nil
		activeTransactions[player] = nil
	end)
	for _, p in Players:GetPlayers() do
		watchPlayer(p)
	end

	local function replyResult(
		player: Player,
		ok: boolean,
		reason: string,
		skinId: string?
	): { ok: boolean, reason: string }
		local payload = { ok = ok, reason = reason, skinId = skinId }
		purchaseResult:FireClient(player, payload)
		return { ok = ok, reason = reason }
	end

	requestPurchase.OnServerInvoke = function(player: Player, skinId: unknown): { ok: boolean, reason: string }
		if typeof(skinId) ~= "string" or #skinId == 0 or #skinId > 64 then
			return replyResult(player, false, "Invalid item request.")
		end

		local now = os.clock()
		local lastTime = lastPurchaseTime[player]
		if lastTime and (now - lastTime) < LobbyConfig.PURCHASE_COOLDOWN then
			return replyResult(player, false, "Too fast. Please wait a moment.")
		end
		if activeTransactions[player] then
			return replyResult(player, false, "Purchase already in progress.")
		end

		local entry = ShopCatalog.getSkinById(skinId)
		if not entry then
			return replyResult(player, false, "Item not found in catalog.")
		end

		local data = PlayerDataService.getData(player)
		if not data then
			return replyResult(player, false, "Player profile is still loading.")
		end
		if PlayerDataService.hasLoadFailed(player) then
			return replyResult(player, false, "Database unavailable — purchases disabled to protect your save.")
		end

		if PlayerDataService.ownsSkin(player, skinId) then
			return replyResult(player, false, "Already owned.")
		end

		lastPurchaseTime[player] = now
		activeTransactions[player] = true

		if entry.price > 0 then
			if not PlayerDataService.spendCoins(player, entry.price) then
				activeTransactions[player] = nil
				return replyResult(
					player,
					false,
					string.format("Insufficient coins (need %d, have %d).", entry.price, data.Coins)
				)
			end
		end

		if not PlayerDataService.grantSkin(player, skinId) then
			if entry.price > 0 then
				PlayerDataService.addCoins(player, entry.price)
			end
			activeTransactions[player] = nil
			return replyResult(player, false, "Could not grant item.")
		end

		-- Persist purchase immediately; roll back if DataStore fails
		local saved, saveErr = PlayerDataService.savePlayer(player)
		if not saved then
			PlayerDataService.revokeSkin(player, skinId)
			if entry.price > 0 then
				PlayerDataService.addCoins(player, entry.price)
			end
			activeTransactions[player] = nil
			sendShopData(player)
			warn("[ShopService] DataStore save error on purchase: " .. tostring(saveErr))
			return replyResult(player, false, "Save failed (DataStore error). Coins were not spent.")
		end

		activeTransactions[player] = nil
		sendShopData(player)
		return replyResult(player, true, string.format("Purchased %s!", entry.name), skinId)
	end

	requestEquip.OnServerEvent:Connect(function(player: Player, skinId: unknown)
		if typeof(skinId) ~= "string" or #skinId == 0 or #skinId > 64 then
			return
		end
		local now = os.clock()
		local last = lastEquipTime[player]
		if last and (now - last) < 0.25 then
			return
		end
		lastEquipTime[player] = now

		if not PlayerDataService.ownsSkin(player, skinId) then
			purchaseResult:FireClient(player, { ok = false, reason = "You do not own this item." })
			return
		end

		if PlayerDataService.equipSkin(player, skinId) then
			sendShopData(player)
			if player.Character then
				attachLobbyCosmetics(player, player.Character)
			end
			task.spawn(PlayerDataService.savePlayer, player)
		end
	end)

	print("[ShopService] Initialized.")
end

return ShopService
