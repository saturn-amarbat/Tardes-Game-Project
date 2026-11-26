--!strict
--[[
  Lobby Client Bootstrap  –  initializes all Dark Forest Lobby client systems.

  Runs whenever the server starts in the Dark Forest Lobby first.
  Listens for LobbyRemotes.EnterGame to transition smoothly into the game
  when a Play Circle launches inside Studio Playtest.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")

local LobbyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyConfig"))

local player = Players.LocalPlayer
if not LobbyConfig.shouldStartInLobby() or player:GetAttribute("InGame") == true then
	return
end

if player:GetAttribute("LobbyClientBooted") == true then
	return
end
player:SetAttribute("LobbyClientBooted", true)

local remotes = ReplicatedStorage:WaitForChild("LobbyRemotes", 10)
if not remotes then
	return
end

local Typography = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Typography"))
local ShopGuiController = require(script.ShopGuiController)
local QueueHudController = require(script.QueueHudController)
local LobbyAmbience = require(script.LobbyAmbience)
local LobbyFrogController = require(script.LobbyFrogController)

local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

ShopGuiController.init()
QueueHudController.init()
LobbyAmbience.init()
LobbyFrogController.init()

-- Frog ProximityPrompt opens ShopGui, turns head, and plays a greeting line
local promptConn = ProximityPromptService.PromptTriggered:Connect(
	function(prompt: ProximityPrompt, triggerPlayer: Player)
		if triggerPlayer == player and prompt.Name == "BrowseShopPrompt" then
			LobbyFrogController.greetPlayer()
			ShopGuiController.open()
		end
	end
)

-- Persistent HUD: always-visible coin pill + bottom bar (Invite Friends, Shop, Emotes)
local function buildPersistentHud()
	local old = playerGui:FindFirstChild("LobbyHUD")
	if old then
		old:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "LobbyHUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 4
	gui.Parent = playerGui

	-- Top-left always-visible Coin Balance pill
	local coinCard = Instance.new("Frame")
	coinCard.Name = "CoinCard"
	coinCard.Size = UDim2.fromOffset(156, 38)
	coinCard.Position = UDim2.fromOffset(16, 16)
	coinCard.BackgroundColor3 = Color3.fromRGB(14, 17, 16)
	coinCard.BackgroundTransparency = 0.14
	coinCard.BorderSizePixel = 0
	coinCard.Parent = gui

	local coinCorner = Instance.new("UICorner")
	coinCorner.CornerRadius = UDim.new(0, 8)
	coinCorner.Parent = coinCard

	local coinStroke = Instance.new("UIStroke")
	coinStroke.Color = Color3.fromRGB(68, 76, 72)
	coinStroke.Thickness = 1
	coinStroke.Transparency = 0.3
	coinStroke.Parent = coinCard

	local coinLabel = Instance.new("TextLabel")
	coinLabel.Name = "CoinLabel"
	coinLabel.Size = UDim2.new(1, -16, 1, 0)
	coinLabel.Position = UDim2.fromOffset(8, 0)
	coinLabel.BackgroundTransparency = 1
	coinLabel.Font = Typography.Fonts.UIBold
	coinLabel.TextSize = 14
	coinLabel.TextColor3 = Typography.Colors.ParchmentGold
	coinLabel.TextXAlignment = Enum.TextXAlignment.Left
	coinLabel.Parent = coinCard

	local function refreshCoins()
		local c = player:GetAttribute("LobbyCoins")
		local val = if typeof(c) == "number" then c else 0
		coinLabel.Text = string.format("Coins: %d", val)
	end
	player:GetAttributeChangedSignal("LobbyCoins"):Connect(refreshCoins)
	refreshCoins()

	-- Bottom-center action bar (Invite Friends | Shop | Sit/Emote)
	local bar = Instance.new("Frame")
	bar.Name = "BottomBar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Size = UDim2.new(0.92, 0, 0, 46)
	bar.Position = UDim2.new(0.5, 0, 1, -14)
	bar.BackgroundColor3 = Color3.fromRGB(14, 17, 16)
	bar.BackgroundTransparency = 0.16
	bar.BorderSizePixel = 0
	bar.Parent = gui

	local barSize = Instance.new("UISizeConstraint")
	barSize.MaxSize = Vector2.new(410, 46)
	barSize.MinSize = Vector2.new(280, 42)
	barSize.Parent = bar

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 10)
	barCorner.Parent = bar

	local barStroke = Instance.new("UIStroke")
	barStroke.Color = Color3.fromRGB(68, 76, 72)
	barStroke.Transparency = 0.3
	barStroke.Parent = bar

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0.02, 4)
	layout.Parent = bar

	local function makeBarBtn(name: string, text: string, bgColor: Color3, widthScale: number): TextButton
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Size = UDim2.fromScale(widthScale, 0.74)
		btn.BackgroundColor3 = bgColor
		btn.Text = text
		btn.TextColor3 = Typography.Colors.Bone
		btn.Font = Typography.Fonts.UIBold
		btn.TextSize = 13
		btn.Selectable = true
		btn.BorderSizePixel = 0
		btn.Parent = bar
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 6)
		c.Parent = btn
		return btn
	end

	local inviteBtn = makeBarBtn("InviteBtn", "Invite Friends", Color3.fromRGB(46, 82, 128), 0.32)
	local shopBtn = makeBarBtn("ShopBtn", "Shop", Color3.fromRGB(54, 108, 66), 0.28)
	local sitBtn = makeBarBtn("SitBtn", "Sit / Stand", Color3.fromRGB(62, 58, 48), 0.3)

	inviteBtn.Activated:Connect(function()
		local canOk, canInvite = pcall(function()
			return SocialService:CanSendGameInviteAsync(player)
		end)
		if canOk and canInvite then
			local ok, err = pcall(function()
				SocialService:PromptGameInvite(player)
			end)
			if not ok then
				warn("[LobbyClient] PromptGameInvite failed: " .. tostring(err))
			end
		else
			inviteBtn.Text = "Unavailable"
			task.delay(2, function()
				if inviteBtn.Parent then
					inviteBtn.Text = "Invite Friends"
				end
			end)
		end
	end)

	shopBtn.Activated:Connect(function()
		ShopGuiController.toggle()
	end)

	sitBtn.Activated:Connect(function()
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			hum.Sit = not hum.Sit
		end
	end)
end

buildPersistentHud()

local enterGameEv = remotes:WaitForChild("EnterGame", 10)
if enterGameEv and enterGameEv:IsA("RemoteEvent") then
	local transitioning = false
	enterGameEv.OnClientEvent:Connect(function()
		if transitioning then
			return
		end
		transitioning = true
		promptConn:Disconnect()

		-- Smooth black transition curtain into the actual game
		local veilGui = Instance.new("ScreenGui")
		veilGui.Name = "LobbyEnterGameFade"
		veilGui.IgnoreGuiInset = true
		veilGui.ResetOnSpawn = false
		veilGui.DisplayOrder = 200
		veilGui.Parent = playerGui

		local veil = Instance.new("Frame")
		veil.Size = UDim2.fromScale(1, 1)
		veil.BackgroundColor3 = Color3.new(0, 0, 0)
		veil.BackgroundTransparency = 1
		veil.BorderSizePixel = 0
		veil.Parent = veilGui

		local statusTxt = Instance.new("TextLabel")
		statusTxt.AnchorPoint = Vector2.new(0.5, 0.5)
		statusTxt.Position = UDim2.fromScale(0.5, 0.5)
		statusTxt.Size = UDim2.new(0.8, 0, 0, 48)
		statusTxt.BackgroundTransparency = 1
		statusTxt.Text = "Entering Blackpine Woods..."
		statusTxt.Font = Typography.Fonts.Narrative
		statusTxt.TextSize = 24
		statusTxt.TextColor3 = Typography.Colors.ParchmentGold
		statusTxt.TextTransparency = 1
		statusTxt.Parent = veil

		TweenService:Create(veil, TweenInfo.new(0.45), { BackgroundTransparency = 0 }):Play()
		TweenService:Create(statusTxt, TweenInfo.new(0.45), { TextTransparency = 0 }):Play()
		task.wait(0.5)

		ShopGuiController.destroy()
		QueueHudController.destroy()
		LobbyAmbience.stop()
		LobbyFrogController.stop()
		local lobbyHud = playerGui:FindFirstChild("LobbyHUD")
		if lobbyHud then
			lobbyHud:Destroy()
		end
		Lighting.FogEnd = 100000

		local waitStart = os.clock()
		while player:GetAttribute("GameTeleportComplete") ~= true and os.clock() - waitStart < 3.0 do
			task.wait(0.05)
		end
		task.wait(0.25)

		TweenService:Create(statusTxt, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		local fadeOut = TweenService:Create(veil, TweenInfo.new(0.7), { BackgroundTransparency = 1 })
		fadeOut:Play()
		fadeOut.Completed:Wait()
		veilGui:Destroy()
	end)
end

print("[LobbyClient] Dark Forest Lobby client initialized.")
