--!strict
-- Uses replicated expedition state and displays clue text when it arrives.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FlashlightController = require(script.Parent.FlashlightController)

local player = Players.LocalPlayer
local playerGui = player.PlayerGui

local existingHud = playerGui:FindFirstChild("ObjectiveHUD")
if existingHud then
	existingHud:Destroy()
end

-- ── Build HUD ─────────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "ObjectiveHUD"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = player:GetAttribute("DungeonEntered") == true

gui.Parent = playerGui

-- Top-left objective counter.
local counterFrame = Instance.new("Frame")
counterFrame.Name = "CounterFrame"
counterFrame.Size = UDim2.fromOffset(290, 71)
counterFrame.Position = UDim2.fromOffset(16, 16)
counterFrame.BackgroundColor3 = Color3.fromRGB(26, 41, 37)
counterFrame.BackgroundTransparency = 0.16
counterFrame.Parent = gui

local counterCorner = Instance.new("UICorner")
counterCorner.CornerRadius = UDim.new(0, 4)
counterCorner.Parent = counterFrame

local counterLabel = Instance.new("TextLabel")
counterLabel.Size = UDim2.new(1, -24, 0, 24)
counterLabel.Position = UDim2.fromOffset(12, 8)
counterLabel.TextXAlignment = Enum.TextXAlignment.Left
counterLabel.BackgroundTransparency = 1
counterLabel.TextColor3 = Color3.new(1, 1, 1)
counterLabel.Font = Enum.Font.GothamMedium
counterLabel.TextSize = 15
counterLabel.Text = ""
counterLabel.Parent = counterFrame

local instruction = Instance.new("TextLabel")
instruction.Size = UDim2.new(1, -24, 0, 30)
instruction.Position = UDim2.fromOffset(12, 31)
instruction.BackgroundTransparency = 1
instruction.TextColor3 = Color3.fromRGB(225, 202, 153)
instruction.Font = Enum.Font.Gotham
instruction.TextSize = 13
instruction.TextWrapped = true
instruction.TextXAlignment = Enum.TextXAlignment.Left
instruction.Parent = counterFrame

-- Centre clue reader panel (hidden by default).
local cluePanel = Instance.new("Frame")
cluePanel.Name = "CluePanel"
cluePanel.AnchorPoint = Vector2.new(0.5, 0.5)
cluePanel.Size = UDim2.fromOffset(440, 220)
cluePanel.Position = UDim2.fromScale(0.5, 0.5)
cluePanel.BackgroundColor3 = Color3.fromRGB(22, 19, 15)
cluePanel.BackgroundTransparency = 0.06
cluePanel.Visible = false
cluePanel.Parent = gui

local cluePanelCorner = Instance.new("UICorner")
cluePanelCorner.CornerRadius = UDim.new(0, 8)
cluePanelCorner.Parent = cluePanel

local clueStroke = Instance.new("UIStroke")
clueStroke.Color = Color3.fromRGB(132, 108, 72)
clueStroke.Thickness = 1.5
clueStroke.Transparency = 0.25
clueStroke.Parent = cluePanel

local clueTitle = Instance.new("TextLabel")
clueTitle.Size = UDim2.new(1, -90, 0, 36)
clueTitle.Position = UDim2.fromOffset(18, 14)
clueTitle.BackgroundTransparency = 1
clueTitle.TextColor3 = Color3.fromRGB(242, 212, 154)
clueTitle.Font = Enum.Font.Garamond
clueTitle.TextSize = 24
clueTitle.TextXAlignment = Enum.TextXAlignment.Left
clueTitle.Text = ""
clueTitle.Parent = cluePanel

local clueBody = Instance.new("TextLabel")
clueBody.Size = UDim2.new(1, -36, 1, -68)
clueBody.Position = UDim2.fromOffset(18, 54)
clueBody.BackgroundTransparency = 1
clueBody.TextColor3 = Color3.fromRGB(232, 226, 214)
clueBody.Font = Enum.Font.Gotham
clueBody.TextSize = 15
clueBody.TextWrapped = true
clueBody.TextXAlignment = Enum.TextXAlignment.Left
clueBody.TextYAlignment = Enum.TextYAlignment.Top
clueBody.Text = ""
clueBody.Parent = cluePanel

-- Close button.
local clueClose = Instance.new("TextButton")
clueClose.Size = UDim2.fromOffset(64, 28)
clueClose.Position = UDim2.new(1, -78, 0, 14)
clueClose.BackgroundColor3 = Color3.fromRGB(74, 34, 30)
clueClose.TextColor3 = Color3.fromRGB(240, 234, 224)
clueClose.Font = Enum.Font.GothamBold
clueClose.TextSize = 13
clueClose.Text = "Close"
clueClose.Parent = cluePanel
local closeCorn = Instance.new("UICorner")
closeCorn.CornerRadius = UDim.new(0, 6)
closeCorn.Parent = clueClose

clueClose.Activated:Connect(function()
	cluePanel.Visible = false
end)

-- Slim battery indicator directly below CounterFrame (zero overlap).
local batteryFrame = Instance.new("Frame")
batteryFrame.Name = "BatteryFrame"
batteryFrame.Size = UDim2.fromOffset(290, 18)
batteryFrame.Position = UDim2.fromOffset(16, 93)
batteryFrame.BackgroundColor3 = Color3.fromRGB(20, 26, 24)
batteryFrame.BackgroundTransparency = 0.2
batteryFrame.Parent = gui

local batteryCorner = Instance.new("UICorner")
batteryCorner.CornerRadius = UDim.new(0, 4)
batteryCorner.Parent = batteryFrame

local batteryFill = Instance.new("Frame")
batteryFill.Name = "Fill"
batteryFill.Size = UDim2.fromScale(1, 1)
batteryFill.BackgroundColor3 = Color3.fromRGB(238, 214, 152)
batteryFill.BorderSizePixel = 0
batteryFill.Parent = batteryFrame

local batteryFillCorner = Instance.new("UICorner")
batteryFillCorner.CornerRadius = UDim.new(0, 4)
batteryFillCorner.Parent = batteryFill

local batteryText = Instance.new("TextLabel")
batteryText.Size = UDim2.fromScale(1, 1)
batteryText.BackgroundTransparency = 1
batteryText.Font = Enum.Font.GothamMedium
batteryText.TextSize = 11
batteryText.TextColor3 = Color3.fromRGB(240, 238, 232)
batteryText.TextStrokeTransparency = 0.5
batteryText.Text = "Battery 100%"
batteryText.Parent = batteryFrame

-- Top-centre banner for door/exit events (never overlaps centre CluePanel).
local flashLabel = Instance.new("TextLabel")
flashLabel.Name = "FlashLabel"
flashLabel.AnchorPoint = Vector2.new(0.5, 0)
flashLabel.Size = UDim2.new(0.55, 0, 0, 44)
flashLabel.Position = UDim2.new(0.5, 0, 0, 84)
flashLabel.BackgroundTransparency = 1
flashLabel.TextColor3 = Color3.fromRGB(100, 255, 140)
flashLabel.Font = Enum.Font.GothamBold
flashLabel.TextSize = 22
flashLabel.TextStrokeTransparency = 0.3
flashLabel.Text = ""
flashLabel.TextTransparency = 1
flashLabel.Parent = gui

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
		counterFrame.Visible = underground and not waiting and phase == "Active"
		batteryFrame.Visible = counterFrame.Visible
		instruction.Text = if matchRemotes:GetAttribute("ExitOpen")
			then "Reach the extraction bulkhead"
			elseif matchRemotes:GetAttribute("ObjectivesComplete") then "Operate the exit levers"
			else "Search the galleries for supplies"
		flashLabel.Text = message
		flashLabel.TextSize = 21
		flashLabel.TextWrapped = true
		flashLabel.TextTransparency = 0
		if not underground or waiting then
			cluePanel.Visible = false
		end
		local scrap = player:GetAttribute("RunScrap")
		counterLabel.Text = string.format(
			"Keys %d/%d   Fuses %d/%d   Scrap %d",
			matchRemotes:GetAttribute("Keys") or 0,
			matchRemotes:GetAttribute("KeysTotal") or 1,
			matchRemotes:GetAttribute("Fuses") or 0,
			matchRemotes:GetAttribute("FusesTotal") or 1,
			if typeof(scrap) == "number" then scrap else 0
		)
	end
	matchRemotes.AttributeChanged:Connect(refreshProgress)
	refreshProgress()

	player:GetAttributeChangedSignal("DungeonEntered"):Connect(refreshProgress)
	player:GetAttributeChangedSignal("SittingOut"):Connect(refreshProgress)
	player:GetAttributeChangedSignal("RunScrap"):Connect(refreshProgress)

	local lastPct = -1
	RunService.Heartbeat:Connect(function()
		if not batteryFrame.Visible then
			return
		end
		local pct = math.clamp(math.floor(FlashlightController.getBattery() + 0.5), 0, 100)
		if pct ~= lastPct then
			lastPct = pct
			batteryFill.Size = UDim2.fromScale(pct / 100, 1)
			batteryFill.BackgroundColor3 = if pct <= 20
				then Color3.fromRGB(206, 72, 62)
				elseif pct <= 45 then Color3.fromRGB(224, 168, 76)
				else Color3.fromRGB(238, 214, 152)
			batteryText.Text = string.format("Battery %d%%", pct)
		end
	end)

	if clueEv then
		clueEv.OnClientEvent:Connect(function(entry: { title: string, body: string })
			if not gui.Enabled or player:GetAttribute("SittingOut") then
				return
			end
			clueTitle.Text = entry.title
			clueBody.Text = entry.body
			cluePanel.Visible = true
		end)
	end

	print("[ObjectiveHUD] Ready.")
end

return { init = init }
