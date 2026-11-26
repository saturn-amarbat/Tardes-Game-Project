--!strict
--[[
  ShopGuiController  –  CLIENT builds and manages the Dark Forest ShopGui.

  Features:
    - ScreenGui friendly across Mobile, PC, and Console (gamepad selectable + ButtonB close).
    - Tabs for Character Skins and Weapon Skins, driven strictly by ShopCatalog.
    - Each card renders a real 3D ViewportFrame preview of the skin.
    - Shows Rarity, Price, and Buy / Equip / Equipped states + Confirm popup.
    - Displays DataStore error banner & clear toast messages for insufficient coins,
      already-owned, and save failures.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LobbyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyConfig"))
local ShopCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShopCatalog"))
local Typography = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Typography"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local ShopGuiController = {}

local shopGui: ScreenGui? = nil
local mainFrame: Frame? = nil
local activeTab: ShopCatalog.SkinCategory = "Character"
local ownedSkins: { [string]: boolean } = {}
local equippedCharacter: string = "char_default"
local equippedWeapon: string = "wpn_default"
local confirmPopup: Frame? = nil
local coinLabel: TextLabel? = nil
local dataWarningBanner: TextLabel? = nil
local previewSpinners: { { model: Model, baseCF: CFrame } } = {}
local firstTabButton: TextButton? = nil
local renderConn: RBXScriptConnection? = nil
local inputConn: RBXScriptConnection? = nil

local BG_COLOR = Color3.fromRGB(14, 17, 16)
local HEADER_BG = Color3.fromRGB(20, 24, 22)
local CARD_BG = Color3.fromRGB(22, 26, 25)
local TEXT_PRIMARY = Typography.Colors.Bone
local TEXT_SECONDARY = Typography.Colors.MutedSlate
local ACCENT_GOLD = Typography.Colors.ParchmentGold
local BUTTON_BUY = Color3.fromRGB(58, 128, 72)
local BUTTON_EQUIP = Color3.fromRGB(48, 102, 148)
local BUTTON_EQUIPPED = Color3.fromRGB(64, 68, 64)
local BUTTON_DISABLED = Color3.fromRGB(84, 48, 46)

local function getRemotes(): Instance?
	return ReplicatedStorage:FindFirstChild("LobbyRemotes")
end

local function getCoins(): number
	local coins = player:GetAttribute("LobbyCoins")
	return if typeof(coins) == "number" then coins else 0
end

local function updateCoinDisplay()
	if coinLabel then
		coinLabel.Text = tostring(getCoins()) .. " Coins"
	end
end

local function addPreviewPart(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	mat: Enum.Material,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.Anchored = true
	p.CastShadow = false
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function buildViewportPreview(parent: Frame, entry: ShopCatalog.SkinEntry)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "PreviewViewport"
	viewport.Size = UDim2.new(1, -12, 0, 88)
	viewport.Position = UDim2.fromOffset(6, 6)
	viewport.BackgroundColor3 = Color3.fromRGB(16, 20, 22)
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(130, 145, 145)
	viewport.LightColor = Color3.fromRGB(255, 240, 220)
	viewport.LightDirection = Vector3.new(-1, -1, -1)
	viewport.Parent = parent

	local vpCorner = Instance.new("UICorner")
	vpCorner.CornerRadius = UDim.new(0, 6)
	vpCorner.Parent = viewport

	local world = Instance.new("WorldModel")
	world.Parent = viewport

	local model = Instance.new("Model")
	model.Name = "PreviewModel"
	model.Parent = world

	local pCfg = entry.preview
	if entry.category == "Character" then
		-- Stylized character bust + skin headpiece
		local torso =
			addPreviewPart(model, Vector3.new(2, 2, 1), CFrame.new(0, -0.7, 0), pCfg.primaryColor, Enum.Material.Fabric)
		addPreviewPart(
			model,
			Vector3.new(1.2, 1.2, 1.2),
			CFrame.new(0, 0.95, 0),
			pCfg.secondaryColor,
			Enum.Material.SmoothPlastic,
			Enum.PartType.Ball
		)
		addPreviewPart(
			model,
			Vector3.new(0.8, 2, 1),
			CFrame.new(-1.45, -0.7, 0),
			pCfg.primaryColor,
			Enum.Material.Fabric
		)
		addPreviewPart(
			model,
			Vector3.new(0.8, 2, 1),
			CFrame.new(1.45, -0.7, 0),
			pCfg.primaryColor,
			Enum.Material.Fabric
		)

		if pCfg.style == "ranger" or pCfg.style == "warden" then
			addPreviewPart(
				model,
				Vector3.new(2.1, 0.16, 2.1),
				CFrame.new(0, 1.55, 0),
				pCfg.primaryColor,
				Enum.Material.Fabric
			)
			addPreviewPart(
				model,
				Vector3.new(1.3, 0.55, 1.3),
				CFrame.new(0, 1.85, 0),
				pCfg.accentColor,
				Enum.Material.Fabric
			)
		elseif pCfg.style == "miner" then
			addPreviewPart(
				model,
				Vector3.new(1.5, 0.65, 1.5),
				CFrame.new(0, 1.6, 0),
				pCfg.primaryColor,
				Enum.Material.Metal
			)
			addPreviewPart(
				model,
				Vector3.new(0.36, 0.3, 0.25),
				CFrame.new(0, 1.68, 0.78),
				pCfg.glowColor or pCfg.accentColor,
				Enum.Material.Neon
			)
		elseif pCfg.style == "cultist" then
			addPreviewPart(
				model,
				Vector3.new(1.75, 1.55, 1.75),
				CFrame.new(0, 1.15, -0.05),
				pCfg.primaryColor,
				Enum.Material.Fabric
			)
			addPreviewPart(
				model,
				Vector3.new(0.24, 0.16, 0.2),
				CFrame.new(-0.28, 1.0, 0.62),
				pCfg.glowColor or pCfg.accentColor,
				Enum.Material.Neon
			)
			addPreviewPart(
				model,
				Vector3.new(0.24, 0.16, 0.2),
				CFrame.new(0.28, 1.0, 0.62),
				pCfg.glowColor or pCfg.accentColor,
				Enum.Material.Neon
			)
		elseif pCfg.style == "spectre" then
			local aura = addPreviewPart(
				model,
				Vector3.new(1.6, 1.6, 1.6),
				CFrame.new(0, 0.95, 0),
				pCfg.glowColor or pCfg.accentColor,
				Enum.Material.ForceField,
				Enum.PartType.Ball
			)
			aura.Transparency = 0.45
		elseif pCfg.style == "antler" then
			for _, side in { -1, 1 } do
				addPreviewPart(
					model,
					Vector3.new(0.2, 1.35, 0.2),
					CFrame.new(side * 0.55, 2.0, 0) * CFrame.Angles(0, 0, math.rad(-side * 24)),
					pCfg.accentColor,
					Enum.Material.SmoothPlastic
				)
				addPreviewPart(
					model,
					Vector3.new(0.15, 0.75, 0.15),
					CFrame.new(side * 0.92, 2.4, 0.12) * CFrame.Angles(math.rad(15), 0, math.rad(-side * 12)),
					pCfg.accentColor,
					Enum.Material.SmoothPlastic
				)
			end
		end
		model.PrimaryPart = torso
	else
		-- 3D Weapon / Flashlight preview
		if pCfg.style == "torch" then
			local barrel = addPreviewPart(
				model,
				Vector3.new(0.6, 0.6, 2.2),
				CFrame.new(0, 0, 0),
				pCfg.primaryColor,
				Enum.Material.Metal
			)
			addPreviewPart(
				model,
				Vector3.new(0.85, 0.85, 0.7),
				CFrame.new(0, 0, 1.15),
				pCfg.secondaryColor,
				Enum.Material.Metal
			)
			addPreviewPart(
				model,
				Vector3.new(0.7, 0.7, 0.12),
				CFrame.new(0, 0, 1.52),
				pCfg.glowColor or pCfg.accentColor,
				Enum.Material.Neon
			)
			model.PrimaryPart = barrel
		elseif pCfg.style == "shard" then
			local core = addPreviewPart(
				model,
				Vector3.new(0.35, 2.6, 0.7),
				CFrame.Angles(0, 0, math.rad(-22)),
				pCfg.primaryColor,
				Enum.Material.Glass
			)
			addPreviewPart(
				model,
				Vector3.new(0.16, 2.2, 0.82),
				CFrame.Angles(0, 0, math.rad(-22)),
				pCfg.glowColor or pCfg.accentColor,
				Enum.Material.Neon
			)
			model.PrimaryPart = core
		elseif pCfg.style == "cleaver" then
			local blade = addPreviewPart(
				model,
				Vector3.new(0.16, 2.2, 0.9),
				CFrame.new(0, 0.35, 0) * CFrame.Angles(0, 0, math.rad(-18)),
				pCfg.primaryColor,
				Enum.Material.SmoothPlastic
			)
			addPreviewPart(
				model,
				Vector3.new(0.22, 0.9, 0.28),
				CFrame.new(0.35, -0.9, 0) * CFrame.Angles(0, 0, math.rad(-18)),
				pCfg.secondaryColor,
				Enum.Material.Wood
			)
			addPreviewPart(
				model,
				Vector3.new(0.18, 0.7, 0.15),
				CFrame.new(-0.15, 0.5, 0.38) * CFrame.Angles(0, 0, math.rad(-18)),
				pCfg.accentColor,
				Enum.Material.SmoothPlastic
			)
			model.PrimaryPart = blade
		else
			local blade = addPreviewPart(
				model,
				Vector3.new(0.14, 2.5, 0.5),
				CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(-24)),
				pCfg.primaryColor,
				Enum.Material.Metal
			)
			addPreviewPart(
				model,
				Vector3.new(0.24, 0.85, 0.28),
				CFrame.new(0.45, -0.95, 0) * CFrame.Angles(0, 0, math.rad(-24)),
				pCfg.secondaryColor,
				Enum.Material.Wood
			)
			if pCfg.glowColor then
				addPreviewPart(
					model,
					Vector3.new(0.08, 2.4, 0.12),
					CFrame.new(-0.08, 0.32, 0.24) * CFrame.Angles(0, 0, math.rad(-24)),
					pCfg.glowColor,
					Enum.Material.Neon
				)
			end
			model.PrimaryPart = blade
		end
	end

	local cam = Instance.new("Camera")
	cam.FieldOfView = 38
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 0.55, 5.1), Vector3.new(0, 0.3, 0))
	cam.Parent = viewport
	viewport.CurrentCamera = cam

	local baseCF = model:GetPivot()
	table.insert(previewSpinners, { model = model, baseCF = baseCF })

	-- Rarity badge inside ViewportFrame
	local rarityBadge = Instance.new("TextLabel")
	rarityBadge.Name = "RarityBadge"
	rarityBadge.Size = UDim2.fromOffset(72, 18)
	rarityBadge.Position = UDim2.fromOffset(4, 4)
	rarityBadge.BackgroundColor3 = LobbyConfig.RARITY_COLORS[entry.rarity] or TEXT_SECONDARY
	rarityBadge.BackgroundTransparency = 0.22
	rarityBadge.Text = entry.rarity
	rarityBadge.TextColor3 = Color3.fromRGB(12, 14, 14)
	rarityBadge.Font = Typography.Fonts.UIBold
	rarityBadge.TextSize = 10
	rarityBadge.BorderSizePixel = 0
	rarityBadge.Parent = viewport
	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0, 4)
	badgeCorner.Parent = rarityBadge
end

function ShopGuiController._showMessage(msg: string, color: Color3)
	local gui = shopGui
	if not gui then
		return
	end

	local old = gui:FindFirstChild("Toast")
	if old then
		old:Destroy()
	end

	local toast = Instance.new("TextLabel")
	toast.Name = "Toast"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Size = UDim2.fromOffset(340, 42)
	toast.Position = UDim2.new(0.5, 0, 0, 18)
	toast.BackgroundColor3 = Color3.fromRGB(16, 18, 18)
	toast.BackgroundTransparency = 0.1
	toast.Text = msg
	toast.TextColor3 = color
	toast.Font = Typography.Fonts.UIBold
	toast.TextSize = 14
	toast.TextWrapped = true
	toast.BorderSizePixel = 0
	toast.ZIndex = 20
	toast.Parent = gui

	local tCorner = Instance.new("UICorner")
	tCorner.CornerRadius = UDim.new(0, 8)
	tCorner.Parent = toast

	local tStroke = Instance.new("UIStroke")
	tStroke.Color = color
	tStroke.Thickness = 1
	tStroke.Transparency = 0.4
	tStroke.Parent = toast

	task.delay(2.8, function()
		if toast.Parent then
			toast:Destroy()
		end
	end)
end

function ShopGuiController._showConfirm(entry: ShopCatalog.SkinEntry)
	if confirmPopup then
		confirmPopup:Destroy()
	end

	local gui = shopGui
	if not gui then
		return
	end

	local overlay = Instance.new("Frame")
	overlay.Name = "ConfirmOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.45
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 12
	overlay.Parent = gui

	local popup = Instance.new("Frame")
	popup.Name = "ConfirmPopup"
	popup.Size = UDim2.fromOffset(310, 186)
	popup.Position = UDim2.fromScale(0.5, 0.5)
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.BackgroundColor3 = CARD_BG
	popup.BorderSizePixel = 0
	popup.ZIndex = 13
	popup.Parent = overlay

	local popupCorner = Instance.new("UICorner")
	popupCorner.CornerRadius = UDim.new(0, 10)
	popupCorner.Parent = popup

	local popupStroke = Instance.new("UIStroke")
	popupStroke.Color = ACCENT_GOLD
	popupStroke.Thickness = 1.4
	popupStroke.Transparency = 0.35
	popupStroke.Parent = popup

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 32)
	title.Position = UDim2.fromOffset(10, 14)
	title.BackgroundTransparency = 1
	title.Text = "Confirm Purchase"
	title.TextColor3 = ACCENT_GOLD
	title.Font = Typography.Fonts.Calligraphy
	title.TextSize = 24
	title.ZIndex = 14
	title.Parent = popup

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -24, 0, 56)
	desc.Position = UDim2.fromOffset(12, 52)
	desc.BackgroundTransparency = 1
	desc.Text = string.format('Buy "%s" for %d Coins?\nCurrent balance: %d Coins', entry.name, entry.price, getCoins())
	desc.TextColor3 = TEXT_PRIMARY
	desc.Font = Typography.Fonts.UI
	desc.TextSize = 14
	desc.TextWrapped = true
	desc.ZIndex = 14
	desc.Parent = popup

	local confirmBtn = Instance.new("TextButton")
	confirmBtn.Size = UDim2.fromOffset(124, 38)
	confirmBtn.Position = UDim2.new(0.25, -62, 0, 126)
	confirmBtn.BackgroundColor3 = BUTTON_BUY
	confirmBtn.Text = "CONFIRM"
	confirmBtn.TextColor3 = TEXT_PRIMARY
	confirmBtn.Font = Typography.Fonts.UIBold
	confirmBtn.TextSize = 14
	confirmBtn.Selectable = true
	confirmBtn.BorderSizePixel = 0
	confirmBtn.ZIndex = 14
	confirmBtn.Parent = popup
	local cBtnCorner = Instance.new("UICorner")
	cBtnCorner.CornerRadius = UDim.new(0, 6)
	cBtnCorner.Parent = confirmBtn

	local cancelBtn = Instance.new("TextButton")
	cancelBtn.Size = UDim2.fromOffset(124, 38)
	cancelBtn.Position = UDim2.new(0.75, -62, 0, 126)
	cancelBtn.BackgroundColor3 = Color3.fromRGB(120, 44, 42)
	cancelBtn.Text = "CANCEL"
	cancelBtn.TextColor3 = TEXT_PRIMARY
	cancelBtn.Font = Typography.Fonts.UIBold
	cancelBtn.TextSize = 14
	cancelBtn.Selectable = true
	cancelBtn.BorderSizePixel = 0
	cancelBtn.ZIndex = 14
	cancelBtn.Parent = popup
	local xBtnCorner = Instance.new("UICorner")
	xBtnCorner.CornerRadius = UDim.new(0, 6)
	xBtnCorner.Parent = cancelBtn

	confirmPopup = overlay
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = confirmBtn
	end

	cancelBtn.Activated:Connect(function()
		overlay:Destroy()
		confirmPopup = nil
		if UserInputService.GamepadEnabled and firstTabButton then
			GuiService.SelectedObject = firstTabButton
		end
	end)

	confirmBtn.Activated:Connect(function()
		overlay:Destroy()
		confirmPopup = nil

		local remotes = getRemotes()
		local purchaseRemote = if remotes then remotes:FindFirstChild("RequestPurchase") else nil
		if not purchaseRemote or not purchaseRemote:IsA("RemoteFunction") then
			ShopGuiController._showMessage("Shop service unavailable.", Color3.fromRGB(240, 96, 86))
			return
		end

		local okCall, result = pcall(function()
			return purchaseRemote:InvokeServer(entry.id)
		end)
		if not okCall then
			ShopGuiController._showMessage("Network error: " .. tostring(result), Color3.fromRGB(240, 96, 86))
			return
		end
		if typeof(result) == "table" then
			local res = result :: { ok: boolean, reason: string }
			local color = if res.ok then Color3.fromRGB(110, 220, 130) else Color3.fromRGB(240, 96, 86)
			ShopGuiController._showMessage(res.reason, color)
		end
	end)
end

local function createItemCard(parent: Instance, entry: ShopCatalog.SkinEntry, index: number): Frame
	local card = Instance.new("Frame")
	card.Name = "Card_" .. entry.id
	card.Size = UDim2.fromOffset(166, 232)
	card.BackgroundColor3 = CARD_BG
	card.BorderSizePixel = 0
	card.LayoutOrder = index
	card.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = LobbyConfig.RARITY_COLORS[entry.rarity] or TEXT_SECONDARY
	stroke.Thickness = 1.4
	stroke.Transparency = 0.45
	stroke.Parent = card

	buildViewportPreview(card, entry)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, -12, 0, 20)
	nameLabel.Position = UDim2.fromOffset(6, 100)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = entry.name
	nameLabel.TextColor3 = TEXT_PRIMARY
	nameLabel.Font = Typography.Fonts.UIBold
	nameLabel.TextSize = 14
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = card

	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "DescLabel"
	descLabel.Size = UDim2.new(1, -12, 0, 34)
	descLabel.Position = UDim2.fromOffset(6, 122)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = entry.description
	descLabel.TextColor3 = TEXT_SECONDARY
	descLabel.Font = Typography.Fonts.UIRegular
	descLabel.TextSize = 10
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.TextWrapped = true
	descLabel.TextTruncate = Enum.TextTruncate.AtEnd
	descLabel.Parent = card

	local priceLabel = Instance.new("TextLabel")
	priceLabel.Name = "PriceLabel"
	priceLabel.Size = UDim2.new(1, -12, 0, 20)
	priceLabel.Position = UDim2.fromOffset(6, 160)
	priceLabel.BackgroundTransparency = 1
	priceLabel.Text = if entry.price > 0 then tostring(entry.price) .. " Coins" else "FREE"
	priceLabel.TextColor3 = ACCENT_GOLD
	priceLabel.Font = Typography.Fonts.UIBold
	priceLabel.TextSize = 13
	priceLabel.TextXAlignment = Enum.TextXAlignment.Left
	priceLabel.Parent = card

	local actionBtn = Instance.new("TextButton")
	actionBtn.Name = "ActionBtn"
	actionBtn.Size = UDim2.new(1, -12, 0, 36)
	actionBtn.Position = UDim2.fromOffset(6, 188)
	actionBtn.BorderSizePixel = 0
	actionBtn.Font = Typography.Fonts.UIBold
	actionBtn.TextSize = 13
	actionBtn.TextColor3 = TEXT_PRIMARY
	actionBtn.Selectable = true
	actionBtn.Parent = card

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = actionBtn

	card:SetAttribute("_skinId", entry.id)

	actionBtn.Activated:Connect(function()
		local isOwned = ownedSkins[entry.id] or entry.price == 0
		local isEquipped = (equippedCharacter == entry.id) or (equippedWeapon == entry.id)

		if isEquipped then
			return
		end

		if isOwned then
			local remotes = getRemotes()
			local equipRemote = if remotes then remotes:FindFirstChild("RequestEquip") else nil
			if equipRemote and equipRemote:IsA("RemoteEvent") then
				equipRemote:FireServer(entry.id)
			end
			return
		end

		if player:GetAttribute("DataLoadFailed") == true then
			ShopGuiController._showMessage("Database unavailable — purchases disabled.", Color3.fromRGB(240, 96, 86))
			return
		end

		if getCoins() < entry.price then
			ShopGuiController._showMessage(
				string.format("Insufficient coins (need %d, have %d).", entry.price, getCoins()),
				Color3.fromRGB(240, 96, 86)
			)
			return
		end

		ShopGuiController._showConfirm(entry)
	end)

	return card
end

local function refreshCards()
	local frame = mainFrame
	if not frame then
		return
	end
	local grid = frame:FindFirstChild("ItemGrid")
	if not grid or not grid:IsA("ScrollingFrame") then
		return
	end

	for _, child in grid:GetChildren() do
		if child:IsA("Frame") then
			local skinId = child:GetAttribute("_skinId")
			if typeof(skinId) == "string" then
				local actionBtn = child:FindFirstChild("ActionBtn")
				if actionBtn and actionBtn:IsA("TextButton") then
					local entry = ShopCatalog.getSkinById(skinId)
					local isOwned = ownedSkins[skinId] == true or (entry ~= nil and entry.price == 0)
					local isEquipped = (equippedCharacter == skinId) or (equippedWeapon == skinId)

					if isEquipped then
						actionBtn.Text = "EQUIPPED"
						actionBtn.BackgroundColor3 = BUTTON_EQUIPPED
						actionBtn.Active = false
					elseif isOwned then
						actionBtn.Text = "EQUIP"
						actionBtn.BackgroundColor3 = BUTTON_EQUIP
						actionBtn.Active = true
					elseif player:GetAttribute("DataLoadFailed") == true then
						actionBtn.Text = "DB OFFLINE"
						actionBtn.BackgroundColor3 = BUTTON_DISABLED
						actionBtn.Active = true
					elseif entry and getCoins() < entry.price then
						actionBtn.Text = string.format("BUY (%d)", entry.price)
						actionBtn.BackgroundColor3 = BUTTON_DISABLED
						actionBtn.Active = true
					else
						actionBtn.Text = string.format("BUY (%d)", if entry then entry.price else 0)
						actionBtn.BackgroundColor3 = BUTTON_BUY
						actionBtn.Active = true
					end
				end
			end
		end
	end

	if dataWarningBanner then
		dataWarningBanner.Visible = player:GetAttribute("DataLoadFailed") == true
	end
	updateCoinDisplay()
end

local function populateGrid()
	local frame = mainFrame
	if not frame then
		return
	end

	local grid = frame:FindFirstChild("ItemGrid")
	if not grid or not grid:IsA("ScrollingFrame") then
		return
	end

	table.clear(previewSpinners)
	for _, child in grid:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local items = ShopCatalog.getSkinsByCategory(activeTab)
	for i, entry in items do
		createItemCard(grid, entry, i)
	end

	refreshCards()
end

local function buildShopGui(): ScreenGui
	local old = playerGui:FindFirstChild("ShopGui")
	if old then
		old:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "ShopGui"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 8
	gui.Enabled = false
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "MainFrame"
	frame.Size = UDim2.fromScale(0.86, 0.84)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = BG_COLOR
	frame.BackgroundTransparency = 0.05
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(300, 340)
	sizeConstraint.MaxSize = Vector2.new(760, 560)
	sizeConstraint.Parent = frame

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 12)
	frameCorner.Parent = frame

	local frameStroke = Instance.new("UIStroke")
	frameStroke.Color = Color3.fromRGB(72, 82, 74)
	frameStroke.Thickness = 1.5
	frameStroke.Parent = frame

	-- Title bar
	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, 0, 0, 54)
	titleBar.BackgroundColor3 = HEADER_BG
	titleBar.BorderSizePixel = 0
	titleBar.Parent = frame

	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, 12)
	titleCorner.Parent = titleBar

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -204, 1, 0)
	titleLabel.Position = UDim2.fromOffset(16, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Frog Merchant"
	titleLabel.TextColor3 = ACCENT_GOLD
	titleLabel.Font = Typography.Fonts.Calligraphy
	titleLabel.TextScaled = true
	Typography.applyStroke(titleLabel, 0.3)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = titleBar
	local titleTextConstraint = Instance.new("UITextSizeConstraint")
	titleTextConstraint.MaxTextSize = 26
	titleTextConstraint.MinTextSize = 16
	titleTextConstraint.Parent = titleLabel

	local coinDisplay = Instance.new("TextLabel")
	coinDisplay.Name = "CoinDisplay"
	coinDisplay.Size = UDim2.fromOffset(124, 32)
	coinDisplay.Position = UDim2.new(1, -182, 0, 11)
	coinDisplay.BackgroundColor3 = Color3.fromRGB(28, 34, 32)
	coinDisplay.Text = tostring(getCoins()) .. " Coins"
	coinDisplay.TextColor3 = ACCENT_GOLD
	coinDisplay.Font = Typography.Fonts.UIBold
	coinDisplay.TextSize = 14
	coinDisplay.BorderSizePixel = 0
	coinDisplay.Parent = titleBar
	coinLabel = coinDisplay

	local coinCorner = Instance.new("UICorner")
	coinCorner.CornerRadius = UDim.new(0, 6)
	coinCorner.Parent = coinDisplay

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.fromOffset(40, 40)
	closeBtn.Position = UDim2.new(1, -48, 0, 7)
	closeBtn.BackgroundColor3 = Color3.fromRGB(96, 36, 34)
	closeBtn.Text = "×"
	closeBtn.TextColor3 = TEXT_PRIMARY
	closeBtn.Font = Typography.Fonts.UIBold
	closeBtn.TextSize = 20
	closeBtn.Selectable = true
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = titleBar

	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = UDim.new(0, 8)
	closeBtnCorner.Parent = closeBtn

	closeBtn.Activated:Connect(function()
		ShopGuiController.close()
	end)

	-- DataStore offline warning banner
	local banner = Instance.new("TextLabel")
	banner.Name = "DataWarningBanner"
	banner.Size = UDim2.new(1, -24, 0, 24)
	banner.Position = UDim2.fromOffset(12, 58)
	banner.BackgroundColor3 = Color3.fromRGB(118, 40, 36)
	banner.Text = "Database unavailable — purchases disabled to protect your save."
	banner.TextColor3 = TEXT_PRIMARY
	banner.Font = Typography.Fonts.UIBold
	banner.TextSize = 12
	banner.Visible = player:GetAttribute("DataLoadFailed") == true
	banner.BorderSizePixel = 0
	banner.Parent = frame
	dataWarningBanner = banner
	local bannerCorner = Instance.new("UICorner")
	bannerCorner.CornerRadius = UDim.new(0, 5)
	bannerCorner.Parent = banner

	-- Tab bar
	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.Size = UDim2.new(1, -24, 0, 38)
	tabBar.Position = UDim2.fromOffset(12, 62)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = frame

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.Parent = tabBar

	local function makeTab(label: string, tabKey: ShopCatalog.SkinCategory): TextButton
		local tab = Instance.new("TextButton")
		tab.Name = "Tab_" .. tabKey
		tab.Size = UDim2.fromOffset(148, 36)
		tab.BackgroundColor3 = if activeTab == tabKey then Color3.fromRGB(44, 54, 46) else Color3.fromRGB(24, 28, 28)
		tab.Text = label
		tab.TextColor3 = if activeTab == tabKey then ACCENT_GOLD else TEXT_SECONDARY
		tab.Font = Typography.Fonts.UIBold
		tab.TextSize = 13
		tab.Selectable = true
		tab.BorderSizePixel = 0
		tab.Parent = tabBar

		local tabCorner = Instance.new("UICorner")
		tabCorner.CornerRadius = UDim.new(0, 6)
		tabCorner.Parent = tab

		tab.Activated:Connect(function()
			activeTab = tabKey
			for _, child in tabBar:GetChildren() do
				if child:IsA("TextButton") then
					local isActive = child.Name == "Tab_" .. tabKey
					child.BackgroundColor3 = if isActive then Color3.fromRGB(44, 54, 46) else Color3.fromRGB(24, 28, 28)
					child.TextColor3 = if isActive then ACCENT_GOLD else TEXT_SECONDARY
				end
			end
			populateGrid()
		end)

		return tab
	end

	firstTabButton = makeTab("Character Skins", "Character")
	makeTab("Weapon Skins", "Weapon")

	-- Scrolling item grid
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "ItemGrid"
	grid.Size = UDim2.new(1, -24, 1, -116)
	grid.Position = UDim2.fromOffset(12, 106)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.ScrollBarImageColor3 = Color3.fromRGB(90, 96, 90)
	grid.CanvasSize = UDim2.fromOffset(0, 0)
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.Parent = frame

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(166, 232)
	gridLayout.CellPadding = UDim2.fromOffset(10, 10)
	gridLayout.FillDirection = Enum.FillDirection.Horizontal
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	local gridPadding = Instance.new("UIPadding")
	gridPadding.PaddingTop = UDim.new(0, 4)
	gridPadding.PaddingLeft = UDim.new(0, 4)
	gridPadding.PaddingBottom = UDim.new(0, 8)
	gridPadding.Parent = grid

	mainFrame = frame
	return gui
end

function ShopGuiController.init()
	shopGui = buildShopGui()

	-- Gentle turntable rotation for ViewportFrame skin models while shop is open
	local spinAngle = 0
	renderConn = RunService.RenderStepped:Connect(function(dt: number)
		if not shopGui or not shopGui.Enabled then
			return
		end
		spinAngle += dt * 0.85
		for _, item in previewSpinners do
			if item.model.Parent then
				item.model:PivotTo(item.baseCF * CFrame.Angles(0, spinAngle, 0))
			end
		end
	end)

	-- Gamepad B / Escape closes popup or shop
	inputConn = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if not shopGui or not shopGui.Enabled then
			return
		end
		if input.KeyCode == Enum.KeyCode.ButtonB or (not gameProcessed and input.KeyCode == Enum.KeyCode.Escape) then
			if confirmPopup then
				confirmPopup:Destroy()
				confirmPopup = nil
				if UserInputService.GamepadEnabled and firstTabButton then
					GuiService.SelectedObject = firstTabButton
				end
			else
				ShopGuiController.close()
			end
		end
	end)

	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("LobbyRemotes", 10)
		if not remotes then
			return
		end
		local shopDataReply = remotes:WaitForChild("ShopDataReply", 10)
		if shopDataReply and shopDataReply:IsA("RemoteEvent") then
			shopDataReply.OnClientEvent:Connect(function(data: {
				owned: { string },
				equippedCharacter: string,
				equippedWeapon: string,
				dataError: boolean?,
			})
				table.clear(ownedSkins)
				for _, id in data.owned do
					ownedSkins[id] = true
				end
				equippedCharacter = data.equippedCharacter
				equippedWeapon = data.equippedWeapon
				refreshCards()
			end)
		end
		local purchaseResult = remotes:WaitForChild("PurchaseResult", 10)
		if purchaseResult and purchaseResult:IsA("RemoteEvent") then
			purchaseResult.OnClientEvent:Connect(function(res: { ok: boolean, reason: string })
				if shopGui and shopGui.Enabled and typeof(res) == "table" and typeof(res.reason) == "string" then
					local color = if res.ok then Color3.fromRGB(110, 220, 130) else Color3.fromRGB(240, 96, 86)
					ShopGuiController._showMessage(res.reason, color)
				end
			end)
		end
	end)

	player:GetAttributeChangedSignal("LobbyCoins"):Connect(refreshCards)
	player:GetAttributeChangedSignal("DataLoadFailed"):Connect(refreshCards)

	populateGrid()
	print("[ShopGuiController] Ready.")
end

function ShopGuiController.open()
	if shopGui then
		shopGui.Enabled = true
		refreshCards()
		if UserInputService.GamepadEnabled and firstTabButton then
			GuiService.SelectedObject = firstTabButton
		end
	end
end

function ShopGuiController.close()
	if confirmPopup then
		confirmPopup:Destroy()
		confirmPopup = nil
	end
	if shopGui then
		shopGui.Enabled = false
	end
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = nil
	end
end

function ShopGuiController.toggle()
	if shopGui and shopGui.Enabled then
		ShopGuiController.close()
	else
		ShopGuiController.open()
	end
end

function ShopGuiController.destroy()
	ShopGuiController.close()
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
	if inputConn then
		inputConn:Disconnect()
		inputConn = nil
	end
	if shopGui then
		shopGui:Destroy()
		shopGui = nil
	end
	mainFrame = nil
end

return ShopGuiController
