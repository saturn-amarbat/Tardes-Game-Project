--!strict
--[[
  FieldJournal  –  Interactive Lore Archive, Flashlight Tint Picker & Squad Support UI.

  • Opens/closes with [J] or the top-right "Journal [J]" button once inside the bunker.
  • Tab 1 (Clues): Lists all 7 ClueData entries, allowing players to re-read collected clues.
  • Tab 2 (Gear & Squad): Equips cosmetic FlashlightTints (ShopCatalog) and lets teammates
    trigger SetGiftTarget + Battery / Revive support products.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local FieldJournal = {}

local player = Players.LocalPlayer

function FieldJournal.init()
	local pg = player:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild("FieldJournalUI")
	if old then
		old:Destroy()
	end

	local sharedFolder = ReplicatedStorage:WaitForChild("Shared", 10)
	local clueDataMod = sharedFolder and sharedFolder:FindFirstChild("ClueData")
	local catalogMod = sharedFolder and sharedFolder:FindFirstChild("ShopCatalog")
	local clues = if clueDataMod and clueDataMod:IsA("ModuleScript")
		then require(clueDataMod) :: { { id: string, title: string, body: string, isWallScribble: boolean } }
		else {}
	local catalog = if catalogMod and catalogMod:IsA("ModuleScript")
		then require(catalogMod) :: {
			Tints: {
				[string]: {
					id: string,
					label: string,
					hotspotColor: Color3,
					spillColor: Color3,
					productId: number,
				},
			},
			SupportProducts: {
				[string]: { id: string, label: string, description: string, productId: number },
			},
		}
		else nil

	local gui = Instance.new("ScreenGui")
	gui.Name = "FieldJournalUI"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = pg

	-- Top-right toggle pill (Prologue SkipButton hides underground, so zero overlap)
	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Name = "JournalToggle"
	toggleBtn.AnchorPoint = Vector2.new(1, 0)
	toggleBtn.Size = UDim2.fromOffset(122, 34)
	toggleBtn.Position = UDim2.new(1, -16, 0, 16)
	toggleBtn.BackgroundColor3 = Color3.fromRGB(26, 38, 34)
	toggleBtn.BackgroundTransparency = 0.16
	toggleBtn.Font = Enum.Font.GothamMedium
	toggleBtn.TextSize = 13
	toggleBtn.TextColor3 = Color3.fromRGB(240, 224, 184)
	toggleBtn.Text = "Journal [J] 0/7"
	toggleBtn.Visible = false
	toggleBtn.Parent = gui

	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, 6)
	toggleCorner.Parent = toggleBtn

	local toggleStroke = Instance.new("UIStroke")
	toggleStroke.Color = Color3.fromRGB(118, 108, 82)
	toggleStroke.Transparency = 0.35
	toggleStroke.Parent = toggleBtn

	-- Main Modal Drawer
	local panel = Instance.new("Frame")
	panel.Name = "JournalPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Size = UDim2.fromOffset(480, 350)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.BackgroundColor3 = Color3.fromRGB(20, 18, 15)
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.Parent = gui

	local pCorner = Instance.new("UICorner")
	pCorner.CornerRadius = UDim.new(0, 10)
	pCorner.Parent = panel

	local pStroke = Instance.new("UIStroke")
	pStroke.Color = Color3.fromRGB(132, 110, 74)
	pStroke.Thickness = 1.5
	pStroke.Transparency = 0.25
	pStroke.Parent = panel

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, -100, 0, 36)
	header.Position = UDim2.fromOffset(18, 10)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.Garamond
	header.TextSize = 25
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.TextColor3 = Color3.fromRGB(242, 214, 158)
	header.Text = "EXPEDITION FIELD JOURNAL"
	header.Parent = panel

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.fromOffset(64, 28)
	closeBtn.Position = UDim2.new(1, -78, 0, 14)
	closeBtn.BackgroundColor3 = Color3.fromRGB(76, 36, 32)
	closeBtn.TextColor3 = Color3.fromRGB(242, 236, 226)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 12
	closeBtn.Text = "Close"
	closeBtn.Parent = panel
	local cCorn = Instance.new("UICorner")
	cCorn.CornerRadius = UDim.new(0, 6)
	cCorn.Parent = closeBtn

	-- Tabs
	local tabClues = Instance.new("TextButton")
	tabClues.Size = UDim2.fromOffset(140, 30)
	tabClues.Position = UDim2.fromOffset(18, 52)
	tabClues.BackgroundColor3 = Color3.fromRGB(54, 48, 36)
	tabClues.Font = Enum.Font.GothamBold
	tabClues.TextSize = 12
	tabClues.TextColor3 = Color3.fromRGB(244, 226, 186)
	tabClues.Text = "Collected Clues"
	tabClues.Parent = panel
	local tcCorn = Instance.new("UICorner")
	tcCorn.CornerRadius = UDim.new(0, 5)
	tcCorn.Parent = tabClues

	local tabGear = Instance.new("TextButton")
	tabGear.Size = UDim2.fromOffset(156, 30)
	tabGear.Position = UDim2.fromOffset(166, 52)
	tabGear.BackgroundColor3 = Color3.fromRGB(34, 32, 28)
	tabGear.Font = Enum.Font.GothamBold
	tabGear.TextSize = 12
	tabGear.TextColor3 = Color3.fromRGB(190, 186, 174)
	tabGear.Text = "Lenses & Squad"
	tabGear.Parent = panel
	local tgCorn = Instance.new("UICorner")
	tgCorn.CornerRadius = UDim.new(0, 5)
	tgCorn.Parent = tabGear

	local clueScroll = Instance.new("ScrollingFrame")
	clueScroll.Position = UDim2.fromOffset(18, 92)
	clueScroll.Size = UDim2.new(1, -36, 1, -108)
	clueScroll.BackgroundTransparency = 1
	clueScroll.ScrollBarThickness = 5
	clueScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	clueScroll.CanvasSize = UDim2.fromOffset(0, 0)
	clueScroll.Parent = panel

	local clueLayout = Instance.new("UIListLayout")
	clueLayout.Padding = UDim.new(0, 8)
	clueLayout.Parent = clueScroll

	local gearScroll = Instance.new("ScrollingFrame")
	gearScroll.Position = UDim2.fromOffset(18, 92)
	gearScroll.Size = UDim2.new(1, -36, 1, -108)
	gearScroll.BackgroundTransparency = 1
	gearScroll.ScrollBarThickness = 5
	gearScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	gearScroll.CanvasSize = UDim2.fromOffset(0, 0)
	gearScroll.Visible = false
	gearScroll.Parent = panel

	local gearLayout = Instance.new("UIListLayout")
	gearLayout.Padding = UDim.new(0, 8)
	gearLayout.Parent = gearScroll

	local matchRemotes = ReplicatedStorage:WaitForChild("MatchRemotes", 10)
	local collectedFolder = matchRemotes and matchRemotes:WaitForChild("CollectedClues", 10)
	local shopRemotes = ReplicatedStorage:WaitForChild("ShopRemotes", 10)
	local equipTintEv = shopRemotes and shopRemotes:FindFirstChild("EquipFlashlightTint")
	local setTargetEv = shopRemotes and shopRemotes:FindFirstChild("SetGiftTarget")

	local function rebuildClues()
		for _, c in clueScroll:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local count = 0
		for _, entry in clues do
			local unlocked = collectedFolder ~= nil and collectedFolder:FindFirstChild(entry.id) ~= nil
			if unlocked then
				count += 1
			end
			local card = Instance.new("Frame")
			card.Size = UDim2.new(1, -8, 0, if unlocked then 74 else 42)
			card.BackgroundColor3 = if unlocked then Color3.fromRGB(34, 30, 24) else Color3.fromRGB(24, 23, 21)
			card.Parent = clueScroll
			local cc = Instance.new("UICorner")
			cc.CornerRadius = UDim.new(0, 6)
			cc.Parent = card

			local t = Instance.new("TextLabel")
			t.Position = UDim2.fromOffset(10, 6)
			t.Size = UDim2.new(1, -20, 0, 20)
			t.BackgroundTransparency = 1
			t.Font = Enum.Font.GothamBold
			t.TextSize = 13
			t.TextXAlignment = Enum.TextXAlignment.Left
			t.TextColor3 = if unlocked then Color3.fromRGB(240, 208, 146) else Color3.fromRGB(115, 112, 104)
			t.Text = if unlocked then entry.title else "Undiscovered Clue"
			t.Parent = card

			if unlocked then
				local b = Instance.new("TextLabel")
				b.Position = UDim2.fromOffset(10, 27)
				b.Size = UDim2.new(1, -20, 1, -32)
				b.BackgroundTransparency = 1
				b.Font = Enum.Font.Gotham
				b.TextSize = 12
				b.TextWrapped = true
				b.TextXAlignment = Enum.TextXAlignment.Left
				b.TextYAlignment = Enum.TextYAlignment.Top
				b.TextColor3 = Color3.fromRGB(224, 218, 206)
				b.Text = entry.body
				b.Parent = card
			end
		end
		toggleBtn.Text = string.format("Journal [J] %d/%d", count, #clues)
	end

	local function rebuildGear()
		for _, c in gearScroll:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end

		if catalog then
			local secTitle = Instance.new("TextLabel")
			secTitle.Size = UDim2.new(1, -8, 0, 20)
			secTitle.BackgroundTransparency = 1
			secTitle.Font = Enum.Font.GothamBold
			secTitle.TextSize = 12
			secTitle.TextXAlignment = Enum.TextXAlignment.Left
			secTitle.TextColor3 = Color3.fromRGB(214, 198, 162)
			secTitle.Text = "FLASHLIGHT LENS TINTS"
			secTitle.Parent = gearScroll

			local activeTint = player:GetAttribute("FlashlightTint") or "StandardHalogen"
			for _, tint in catalog.Tints do
				local row = Instance.new("TextButton")
				row.Size = UDim2.new(1, -8, 0, 38)
				row.BackgroundColor3 = if activeTint == tint.id
					then Color3.fromRGB(52, 58, 44)
					else Color3.fromRGB(30, 29, 26)
				row.Text = ""
				row.Parent = gearScroll
				local rc = Instance.new("UICorner")
				rc.CornerRadius = UDim.new(0, 6)
				rc.Parent = row

				local swatch = Instance.new("Frame")
				swatch.Size = UDim2.fromOffset(20, 20)
				swatch.Position = UDim2.fromOffset(10, 9)
				swatch.BackgroundColor3 = tint.hotspotColor
				swatch.Parent = row
				local sc = Instance.new("UICorner")
				sc.CornerRadius = UDim.new(1, 0)
				sc.Parent = swatch

				local lbl = Instance.new("TextLabel")
				lbl.Position = UDim2.fromOffset(40, 0)
				lbl.Size = UDim2.new(1, -50, 1, 0)
				lbl.BackgroundTransparency = 1
				lbl.Font = Enum.Font.GothamMedium
				lbl.TextSize = 13
				lbl.TextXAlignment = Enum.TextXAlignment.Left
				lbl.TextColor3 = Color3.fromRGB(236, 232, 222)
				lbl.Text = if activeTint == tint.id then tint.label .. "  (Equipped)" else tint.label
				lbl.Parent = row

				row.Activated:Connect(function()
					if equipTintEv and equipTintEv:IsA("RemoteEvent") then
						equipTintEv:FireServer(tint.id)
					end
				end)
			end
		end

		local sqTitle = Instance.new("TextLabel")
		sqTitle.Size = UDim2.new(1, -8, 0, 24)
		sqTitle.BackgroundTransparency = 1
		sqTitle.Font = Enum.Font.GothamBold
		sqTitle.TextSize = 12
		sqTitle.TextXAlignment = Enum.TextXAlignment.Left
		sqTitle.TextYAlignment = Enum.TextYAlignment.Bottom
		sqTitle.TextColor3 = Color3.fromRGB(214, 198, 162)
		sqTitle.Text = "SQUAD SUPPORT"
		sqTitle.Parent = gearScroll

		for _, target in Players:GetPlayers() do
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, -8, 0, 40)
			row.BackgroundColor3 = Color3.fromRGB(28, 28, 30)
			row.Parent = gearScroll
			local rc = Instance.new("UICorner")
			rc.CornerRadius = UDim.new(0, 6)
			rc.Parent = row

			local isDead = target:GetAttribute("SittingOut") == true
			local nameLbl = Instance.new("TextLabel")
			nameLbl.Position = UDim2.fromOffset(10, 0)
			nameLbl.Size = UDim2.fromScale(0.48, 1)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Font = Enum.Font.GothamMedium
			nameLbl.TextSize = 12
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			nameLbl.TextColor3 = if isDead then Color3.fromRGB(224, 122, 114) else Color3.fromRGB(224, 228, 220)
			nameLbl.Text = target.DisplayName .. (if isDead then " (Fallen)" else "")
			nameLbl.Parent = row

			local giftBat = Instance.new("TextButton")
			giftBat.Size = UDim2.fromOffset(96, 26)
			giftBat.Position = UDim2.new(1, -202, 0, 7)
			giftBat.BackgroundColor3 = Color3.fromRGB(54, 72, 54)
			giftBat.Font = Enum.Font.GothamBold
			giftBat.TextSize = 11
			giftBat.TextColor3 = Color3.new(1, 1, 1)
			giftBat.Text = "Gift Battery"
			giftBat.Parent = row
			local gbc = Instance.new("UICorner")
			gbc.CornerRadius = UDim.new(0, 4)
			gbc.Parent = giftBat

			local giftRev = Instance.new("TextButton")
			giftRev.Size = UDim2.fromOffset(92, 26)
			giftRev.Position = UDim2.new(1, -100, 0, 7)
			giftRev.BackgroundColor3 = if isDead then Color3.fromRGB(118, 54, 48) else Color3.fromRGB(46, 44, 44)
			giftRev.Font = Enum.Font.GothamBold
			giftRev.TextSize = 11
			giftRev.TextColor3 = Color3.new(1, 1, 1)
			giftRev.Text = "Gift Revive"
			giftRev.Active = isDead
			giftRev.Parent = row
			local grc = Instance.new("UICorner")
			grc.CornerRadius = UDim.new(0, 4)
			grc.Parent = giftRev

			giftBat.Activated:Connect(function()
				if setTargetEv and setTargetEv:IsA("RemoteEvent") then
					setTargetEv:FireServer(target.UserId)
				end
				if catalog and catalog.SupportProducts.GiftBatteryPack.productId > 0 then
					MarketplaceService:PromptProductPurchase(player, catalog.SupportProducts.GiftBatteryPack.productId)
				else
					giftBat.Text = "ID Pending"
				end
			end)

			giftRev.Activated:Connect(function()
				if not isDead then
					return
				end
				if setTargetEv and setTargetEv:IsA("RemoteEvent") then
					setTargetEv:FireServer(target.UserId)
				end
				if catalog and catalog.SupportProducts.GiftFieldRevive.productId > 0 then
					MarketplaceService:PromptProductPurchase(player, catalog.SupportProducts.GiftFieldRevive.productId)
				else
					giftRev.Text = "ID Pending"
				end
			end)
		end
	end

	local function showTab(cluesTab: boolean)
		clueScroll.Visible = cluesTab
		gearScroll.Visible = not cluesTab
		tabClues.BackgroundColor3 = if cluesTab then Color3.fromRGB(54, 48, 36) else Color3.fromRGB(34, 32, 28)
		tabClues.TextColor3 = if cluesTab then Color3.fromRGB(244, 226, 186) else Color3.fromRGB(190, 186, 174)
		tabGear.BackgroundColor3 = if not cluesTab then Color3.fromRGB(54, 48, 36) else Color3.fromRGB(34, 32, 28)
		tabGear.TextColor3 = if not cluesTab then Color3.fromRGB(244, 226, 186) else Color3.fromRGB(190, 186, 174)
		if not cluesTab then
			rebuildGear()
		end
	end

	local function setOpen(openState: boolean)
		panel.Visible = openState
		if openState then
			rebuildClues()
			rebuildGear()
		end
	end

	local function refreshVisibility()
		local show = player:GetAttribute("DungeonEntered") == true and player:GetAttribute("SittingOut") ~= true
		toggleBtn.Visible = show
		if not show then
			panel.Visible = false
		end
	end

	toggleBtn.Activated:Connect(function()
		setOpen(not panel.Visible)
	end)
	closeBtn.Activated:Connect(function()
		setOpen(false)
	end)
	tabClues.Activated:Connect(function()
		showTab(true)
	end)
	tabGear.Activated:Connect(function()
		showTab(false)
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.J and toggleBtn.Visible then
			setOpen(not panel.Visible)
		end
	end)

	if collectedFolder then
		collectedFolder.ChildAdded:Connect(rebuildClues)
		collectedFolder.ChildRemoved:Connect(rebuildClues)
	end
	player:GetAttributeChangedSignal("FlashlightTint"):Connect(rebuildGear)
	player:GetAttributeChangedSignal("DungeonEntered"):Connect(refreshVisibility)
	player:GetAttributeChangedSignal("SittingOut"):Connect(refreshVisibility)

	rebuildClues()
	refreshVisibility()
	print("[FieldJournal] Ready (J).")
end

return FieldJournal
