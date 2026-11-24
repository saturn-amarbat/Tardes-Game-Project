--!strict
--[[
  ObjectiveHUD  –  Tasteful 1970s Blackpine field-survey HUD.

  Unifies supplies (Keys, Fuses, Scrap), active objective guidance, and compact
  survival vitals (Battery, Health, Stamina) into one dark-slate dossier card
  with crisp vector-style icons (HUDIcons), plus a subtle center reticle,
  red damage vignette, and CluePanel reader.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local FlashlightController = require(script.Parent.FlashlightController)
local HUDIcons = require(script.Parent.HUDIcons)
local SprintController = require(script.Parent.SprintController)
local Typography = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Typography"))

local player = Players.LocalPlayer
local playerGui = player.PlayerGui

local existingHud = playerGui:FindFirstChild("ObjectiveHUD")
if existingHud then
	existingHud:Destroy()
end

local PALETTE = {
	CardBg = Color3.fromRGB(14, 17, 16),
	Stroke = Color3.fromRGB(68, 76, 72),
	Track = Color3.fromRGB(28, 34, 32),
	Brass = Color3.fromRGB(228, 198, 130),
	Ivory = Color3.fromRGB(238, 234, 224),
	Muted = Color3.fromRGB(156, 164, 158),
	Copper = Color3.fromRGB(196, 146, 98),
	Sage = Color3.fromRGB(96, 186, 118),
	Steel = Color3.fromRGB(154, 198, 220),
	Crimson = Color3.fromRGB(208, 66, 58),
}

local gui = Instance.new("ScreenGui")
gui.Name = "ObjectiveHUD"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = player:GetAttribute("DungeonEntered") == true
gui.Parent = playerGui

-- Minimal center aim reticle (helps aim camera prompts & flashlight beam)
local reticle = Instance.new("Frame")
reticle.Name = "AimReticle"
reticle.AnchorPoint = Vector2.new(0.5, 0.5)
reticle.Size = UDim2.fromOffset(3, 3)
reticle.Position = UDim2.fromScale(0.5, 0.5)
reticle.BackgroundColor3 = PALETTE.Ivory
reticle.BackgroundTransparency = 0.52
reticle.BorderSizePixel = 0
reticle.Parent = gui
local rCorn = Instance.new("UICorner")
rCorn.CornerRadius = UDim.new(1, 0)
rCorn.Parent = reticle

-- Unified top-left Field Dossier Card
local card = Instance.new("Frame")
card.Name = "CounterFrame"
card.Size = UDim2.fromOffset(278, 116)
card.Position = UDim2.fromOffset(16, 16)
card.BackgroundColor3 = PALETTE.CardBg
card.BackgroundTransparency = 0.14
card.Parent = gui

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 8)
cardCorner.Parent = card

local cardStroke = Instance.new("UIStroke")
cardStroke.Color = PALETTE.Stroke
cardStroke.Thickness = 1
cardStroke.Transparency = 0.3
cardStroke.Parent = card

-- Row 1: Supplies Strip (Keys | Fuses | Scrap)
local function makeCounterPill(xPos: number, width: number, makeIcon: (Instance) -> Frame): TextLabel
	local holder = Instance.new("Frame")
	holder.Position = UDim2.fromOffset(xPos, 10)
	holder.Size = UDim2.fromOffset(width, 22)
	holder.BackgroundTransparency = 1
	holder.Parent = card

	local icon = makeIcon(holder)
	icon.Position = UDim2.fromOffset(0, 3)

	local lbl = Instance.new("TextLabel")
	lbl.Position = UDim2.fromOffset(22, 0)
	lbl.Size = UDim2.new(1, -22, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 14
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextColor3 = PALETTE.Ivory
	lbl.Text = "0/1"
	lbl.Parent = holder
	return lbl
end

local keysLabel = makeCounterPill(14, 76, function(p)
	return HUDIcons.key(p, PALETTE.Brass, 16)
end)
local fusesLabel = makeCounterPill(98, 76, function(p)
	return HUDIcons.fuse(p, PALETTE.Copper, 16)
end)
local scrapLabel = makeCounterPill(184, 80, function(p)
	return HUDIcons.scrap(p, PALETTE.Brass, 16)
end)
scrapLabel.Text = "15"

-- Row 2: Active objective guidance
local instruction = Instance.new("TextLabel")
instruction.Position = UDim2.fromOffset(14, 34)
instruction.Size = UDim2.new(1, -28, 0, 18)
instruction.BackgroundTransparency = 1
instruction.TextColor3 = PALETTE.Brass
instruction.Font = Enum.Font.Gotham
instruction.TextSize = 12
instruction.TextTruncate = Enum.TextTruncate.AtEnd
instruction.TextXAlignment = Enum.TextXAlignment.Left
instruction.Text = "Search the galleries for supplies"
instruction.Parent = card

-- Hairline divider
local divider = Instance.new("Frame")
divider.Position = UDim2.fromOffset(14, 58)
divider.Size = UDim2.new(1, -28, 0, 1)
divider.BackgroundColor3 = PALETTE.Stroke
divider.BackgroundTransparency = 0.55
divider.BorderSizePixel = 0
divider.Parent = card

-- Row 3a: Battery track + % readout
local batRow = Instance.new("Frame")
batRow.Name = "BatteryFrame"
batRow.Position = UDim2.fromOffset(14, 66)
batRow.Size = UDim2.new(1, -28, 0, 18)
batRow.BackgroundTransparency = 1
batRow.Parent = card

local batIcon = HUDIcons.flashlight(batRow, PALETTE.Brass, 15)
batIcon.Position = UDim2.fromOffset(0, 1)

local batTrack = Instance.new("Frame")
batTrack.Position = UDim2.fromOffset(22, 6)
batTrack.Size = UDim2.new(1, -60, 0, 5)
batTrack.BackgroundColor3 = PALETTE.Track
batTrack.BorderSizePixel = 0
batTrack.Parent = batRow
local btCorn = Instance.new("UICorner")
btCorn.CornerRadius = UDim.new(1, 0)
btCorn.Parent = batTrack

local batteryFill = Instance.new("Frame")
batteryFill.Name = "Fill"
batteryFill.Size = UDim2.fromScale(1, 1)
batteryFill.BackgroundColor3 = PALETTE.Brass
batteryFill.BorderSizePixel = 0
batteryFill.Parent = batTrack
local bfCorn = Instance.new("UICorner")
bfCorn.CornerRadius = UDim.new(1, 0)
bfCorn.Parent = batteryFill

local batteryText = Instance.new("TextLabel")
batteryText.Position = UDim2.new(1, -34, 0, 0)
batteryText.Size = UDim2.fromOffset(34, 18)
batteryText.BackgroundTransparency = 1
batteryText.Font = Enum.Font.GothamMedium
batteryText.TextSize = 11
batteryText.TextXAlignment = Enum.TextXAlignment.Right
batteryText.TextColor3 = PALETTE.Muted
batteryText.Text = "100%"
batteryText.Parent = batRow

-- Row 3b: Paired Health & Stamina tracks
local vitalsRow = Instance.new("Frame")
vitalsRow.Name = "VitalsRow"
vitalsRow.Position = UDim2.fromOffset(14, 88)
vitalsRow.Size = UDim2.new(1, -28, 0, 16)
vitalsRow.BackgroundTransparency = 1
vitalsRow.Parent = card

local hpIcon = HUDIcons.health(vitalsRow, PALETTE.Sage, 13)
hpIcon.Position = UDim2.fromOffset(1, 1)

local hpTrack = Instance.new("Frame")
hpTrack.Position = UDim2.fromOffset(22, 5)
hpTrack.Size = UDim2.fromOffset(102, 5)
hpTrack.BackgroundColor3 = PALETTE.Track
hpTrack.BorderSizePixel = 0
hpTrack.Parent = vitalsRow
local htCorn = Instance.new("UICorner")
htCorn.CornerRadius = UDim.new(1, 0)
htCorn.Parent = hpTrack

local healthFill = Instance.new("Frame")
healthFill.Name = "Fill"
healthFill.Size = UDim2.fromScale(1, 1)
healthFill.BackgroundColor3 = PALETTE.Sage
healthFill.BorderSizePixel = 0
healthFill.Parent = hpTrack
local hfCorn = Instance.new("UICorner")
hfCorn.CornerRadius = UDim.new(1, 0)
hfCorn.Parent = healthFill

local stamIcon = HUDIcons.sprint(vitalsRow, PALETTE.Steel, 14)
stamIcon.Position = UDim2.fromOffset(136, 1)

local stamTrack = Instance.new("Frame")
stamTrack.Position = UDim2.fromOffset(156, 5)
stamTrack.Size = UDim2.new(1, -156, 0, 5)
stamTrack.BackgroundColor3 = PALETTE.Track
stamTrack.BorderSizePixel = 0
stamTrack.Parent = vitalsRow
local stCorn = Instance.new("UICorner")
stCorn.CornerRadius = UDim.new(1, 0)
stCorn.Parent = stamTrack

local staminaFill = Instance.new("Frame")
staminaFill.Name = "Fill"
staminaFill.Size = UDim2.fromScale(1, 1)
staminaFill.BackgroundColor3 = PALETTE.Steel
staminaFill.BorderSizePixel = 0
staminaFill.Parent = stamTrack
local sfCorn = Instance.new("UICorner")
sfCorn.CornerRadius = UDim.new(1, 0)
sfCorn.Parent = staminaFill

-- Centre Clue Reader Panel
local cluePanel = Instance.new("Frame")
cluePanel.Name = "CluePanel"
cluePanel.AnchorPoint = Vector2.new(0.5, 0.5)
cluePanel.Size = UDim2.fromOffset(440, 224)
cluePanel.Position = UDim2.fromScale(0.5, 0.5)
cluePanel.BackgroundColor3 = Color3.fromRGB(20, 17, 14)
cluePanel.BackgroundTransparency = 0.05
cluePanel.Visible = false
cluePanel.Parent = gui

local cluePanelCorner = Instance.new("UICorner")
cluePanelCorner.CornerRadius = UDim.new(0, 8)
cluePanelCorner.Parent = cluePanel

local clueStroke = Instance.new("UIStroke")
clueStroke.Color = Color3.fromRGB(132, 108, 72)
clueStroke.Thickness = 1.3
clueStroke.Transparency = 0.25
clueStroke.Parent = cluePanel

local clueIcon = HUDIcons.journal(cluePanel, PALETTE.Brass, 18)
clueIcon.Position = UDim2.fromOffset(18, 17)

local clueTitle = Instance.new("TextLabel")
clueTitle.Size = UDim2.new(1, -96, 0, 34)
clueTitle.Position = UDim2.fromOffset(44, 10)
clueTitle.BackgroundTransparency = 1
clueTitle.TextColor3 = Typography.Colors.ParchmentGold
Typography.applyStroke(clueTitle, 0.3)
clueTitle.Font = Typography.Fonts.Calligraphy
clueTitle.TextSize = 26
clueTitle.TextXAlignment = Enum.TextXAlignment.Left
clueTitle.Text = ""
clueTitle.Parent = cluePanel

local clueRule = Instance.new("Frame")
clueRule.Position = UDim2.fromOffset(18, 48)
clueRule.Size = UDim2.new(1, -36, 0, 1)
clueRule.BackgroundColor3 = Color3.fromRGB(132, 108, 72)
clueRule.BackgroundTransparency = 0.65
clueRule.BorderSizePixel = 0
clueRule.Parent = cluePanel

local clueBody = Instance.new("TextLabel")
clueBody.Size = UDim2.new(1, -36, 1, -72)
clueBody.Position = UDim2.fromOffset(18, 58)
clueBody.BackgroundTransparency = 1
clueBody.TextColor3 = Typography.Colors.Bone
Typography.applyStroke(clueBody, 0.5)
clueBody.Font = Typography.Fonts.Narrative
clueBody.TextSize = 18
clueBody.TextWrapped = true
clueBody.TextXAlignment = Enum.TextXAlignment.Left
clueBody.TextYAlignment = Enum.TextYAlignment.Top
clueBody.Text = ""
clueBody.Parent = cluePanel

local clueClose = Instance.new("TextButton")
clueClose.Size = UDim2.fromOffset(28, 28)
clueClose.Position = UDim2.new(1, -40, 0, 12)
clueClose.BackgroundColor3 = Color3.fromRGB(58, 32, 28)
clueClose.TextColor3 = PALETTE.Ivory
clueClose.Font = Enum.Font.GothamBold
clueClose.TextSize = 14
clueClose.Text = "×"
clueClose.Parent = cluePanel
local closeCorn = Instance.new("UICorner")
closeCorn.CornerRadius = UDim.new(0, 6)
closeCorn.Parent = clueClose

clueClose.Activated:Connect(function()
	cluePanel.Visible = false
end)

-- Red damage flash overlay when taking Stalker damage
local damageFlash = Instance.new("Frame")
damageFlash.Name = "DamageFlash"
damageFlash.Size = UDim2.fromScale(1, 1)
damageFlash.BackgroundColor3 = Color3.fromRGB(150, 14, 14)
damageFlash.BackgroundTransparency = 1
damageFlash.BorderSizePixel = 0
damageFlash.ZIndex = 10
damageFlash.Parent = gui

-- Top-centre status banner (never overlaps centre CluePanel or SanctuaryBadge)
local flashLabel = Instance.new("TextLabel")
flashLabel.Name = "FlashLabel"
flashLabel.AnchorPoint = Vector2.new(0.5, 0)
flashLabel.Size = UDim2.new(0.6, 0, 0, 44)
flashLabel.Position = UDim2.new(0.5, 0, 0, 68)
flashLabel.BackgroundTransparency = 1
flashLabel.TextColor3 = Typography.Colors.MintClear
flashLabel.Font = Typography.Fonts.UI
flashLabel.TextSize = 19
Typography.applyStroke(flashLabel, 0.3)
flashLabel.Text = ""
flashLabel.TextTransparency = 1
flashLabel.Parent = gui

local function showBunkerArrivalTitle()
	local old = gui:FindFirstChild("ZoneTitle")
	if old then
		old:Destroy()
	end
	local title = Instance.new("TextLabel")
	title.Name = "ZoneTitle"
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.fromScale(0.5, 0.14)
	title.Size = UDim2.new(0.8, 0, 0, 50)
	title.BackgroundTransparency = 1
	title.Text = "THE LOWER GALLERIES"
	title.Font = Typography.Fonts.Calligraphy
	title.TextSize = 36
	title.TextColor3 = Typography.Colors.ParchmentGold
	Typography.applyStroke(title, 0.25)
	title.TextTransparency = 1
	title.Parent = gui

	TweenService:Create(title, TweenInfo.new(0.75), { TextTransparency = 0 }):Play()
	task.delay(3.5, function()
		if not title.Parent then
			return
		end
		local fade =
			TweenService:Create(title, TweenInfo.new(1.0), { TextTransparency = 1, TextStrokeTransparency = 1 })
		fade:Play()
		fade.Completed:Once(function()
			title:Destroy()
		end)
	end)
end

local function init()
	local matchRemotes = ReplicatedStorage:WaitForChild("MatchRemotes", 10)
	if not matchRemotes then
		warn("[ObjectiveHUD] MatchRemotes not found.")
		return
	end

	local clueEv = matchRemotes:WaitForChild("ClueCollected", 10) :: RemoteEvent?

	local function refreshProgress()
		local phase = matchRemotes:GetAttribute("RunState")
		local waiting = player:GetAttribute("SittingOut") == true
		local underground = player:GetAttribute("DungeonEntered") == true
		local message = ""
		if phase == "Escaped" then
			message = "Squad escaped! Next expedition soon."
		elseif phase == "Wiped" then
			message = "Squad lost. Next expedition soon."
		elseif waiting then
			message = "Waiting for the next expedition"
		elseif underground and matchRemotes:GetAttribute("ExitOpen") then
			message = "Exit open • extract at the bulkhead"
		elseif underground and matchRemotes:GetAttribute("ObjectivesComplete") then
			message = if matchRemotes:GetAttribute("Survivors") == 1
				then "Hold one exit lever for 3 seconds"
				else "Hold both exit levers together for 3 seconds"
		end

		gui.Enabled = underground or waiting or message ~= ""
		card.Visible = underground and not waiting and phase == "Active"
		reticle.Visible = card.Visible and not cluePanel.Visible

		instruction.Text = if matchRemotes:GetAttribute("ExitOpen")
			then "Reach the extraction bulkhead"
			elseif matchRemotes:GetAttribute("ObjectivesComplete") then "Operate the exit levers"
			else "Search the galleries for supplies"
		if phase == "Escaped" or phase == "Wiped" then
			flashLabel.Font = Typography.Fonts.Calligraphy
			flashLabel.TextSize = 26
			flashLabel.TextColor3 = if phase == "Escaped"
				then Typography.Colors.ParchmentGold
				else Typography.Colors.WallBlood
		else
			flashLabel.Font = Typography.Fonts.UI
			flashLabel.TextSize = 18
			flashLabel.TextColor3 = Typography.Colors.MintClear
		end
		flashLabel.Text = message
		flashLabel.TextTransparency = 0
		if not underground or waiting then
			cluePanel.Visible = false
		end

		local scrap = player:GetAttribute("RunScrap")
		keysLabel.Text =
			string.format("%d/%d", matchRemotes:GetAttribute("Keys") or 0, matchRemotes:GetAttribute("KeysTotal") or 1)
		fusesLabel.Text = string.format(
			"%d/%d",
			matchRemotes:GetAttribute("Fuses") or 0,
			matchRemotes:GetAttribute("FusesTotal") or 1
		)
		scrapLabel.Text = tostring(if typeof(scrap) == "number" then scrap else 0)
	end

	matchRemotes.AttributeChanged:Connect(refreshProgress)
	refreshProgress()

	local wasUnderground = player:GetAttribute("DungeonEntered") == true
	player:GetAttributeChangedSignal("DungeonEntered"):Connect(function()
		local nowUnderground = player:GetAttribute("DungeonEntered") == true
		if nowUnderground and not wasUnderground and player:GetAttribute("SittingOut") ~= true then
			showBunkerArrivalTitle()
		end
		wasUnderground = nowUnderground
		refreshProgress()
	end)
	player:GetAttributeChangedSignal("SittingOut"):Connect(refreshProgress)
	player:GetAttributeChangedSignal("RunScrap"):Connect(refreshProgress)

	local lastPct = -1
	local lastHp = 100
	local lastStam = -1
	RunService.Heartbeat:Connect(function()
		reticle.Visible = card.Visible and not cluePanel.Visible

		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			local hpPct = math.clamp(math.floor((hum.Health / math.max(1, hum.MaxHealth)) * 100 + 0.5), 0, 100)
			if hpPct < lastHp then
				damageFlash.BackgroundTransparency = 0.55
				TweenService:Create(damageFlash, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
			end
			if hpPct ~= lastHp then
				lastHp = hpPct
				healthFill.Size = UDim2.fromScale(hpPct / 100, 1)
				healthFill.BackgroundColor3 = if hpPct <= 35
					then PALETTE.Crimson
					elseif hpPct <= 65 then PALETTE.Brass
					else PALETTE.Sage
			end
		end

		if not card.Visible then
			return
		end

		local pct = math.clamp(math.floor(FlashlightController.getBattery() + 0.5), 0, 100)
		if pct ~= lastPct then
			lastPct = pct
			batteryFill.Size = UDim2.fromScale(pct / 100, 1)
			batteryFill.BackgroundColor3 = if pct <= 20
				then PALETTE.Crimson
				elseif pct <= 45 then PALETTE.Copper
				else PALETTE.Brass
			batteryText.Text = string.format("%d%%", pct)
		end

		local stamPct = math.clamp(math.floor(SprintController.getStamina() + 0.5), 0, 100)
		if stamPct ~= lastStam then
			lastStam = stamPct
			staminaFill.Size = UDim2.fromScale(stamPct / 100, 1)
			staminaFill.BackgroundColor3 = if stamPct <= 25 then PALETTE.Copper else PALETTE.Steel
		end
	end)

	if clueEv then
		clueEv.OnClientEvent:Connect(function(entry: { title: string, body: string, isWallScribble: boolean? })
			if not gui.Enabled or player:GetAttribute("SittingOut") then
				return
			end
			local scribble = entry.isWallScribble == true
			clueTitle.Font = if scribble then Typography.Fonts.Scribble else Typography.Fonts.Calligraphy
			clueTitle.TextSize = if scribble then 24 else 26
			clueTitle.TextColor3 = if scribble then Typography.Colors.WallBlood else Typography.Colors.ParchmentGold
			clueBody.Font = if scribble then Typography.Fonts.Calligraphy else Typography.Fonts.Narrative
			clueBody.TextSize = if scribble then 19 else 18
			clueStroke.Color = if scribble then Color3.fromRGB(140, 58, 52) else Color3.fromRGB(132, 108, 72)
			clueTitle.Text = entry.title
			clueBody.Text = entry.body
			cluePanel.Visible = true
		end)
	end

	local doorEv = matchRemotes:WaitForChild("DoorUnlocked", 10) :: RemoteEvent?
	if doorEv then
		doorEv.OnClientEvent:Connect(function(status: string)
			if status == "Locked" then
				flashLabel.TextColor3 = Color3.fromRGB(240, 118, 92)
				flashLabel.Text = "Locked — Missing Keys/Fuses"
				flashLabel.TextTransparency = 0
				task.delay(2.5, function()
					if flashLabel.Text == "Locked — Missing Keys/Fuses" then
						flashLabel.TextColor3 = Color3.fromRGB(118, 224, 152)
						refreshProgress()
					end
				end)
			else
				flashLabel.TextColor3 = Color3.fromRGB(118, 224, 152)
			end
		end)
	end

	print("[ObjectiveHUD] Ready.")
end

return { init = init }
