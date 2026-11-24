--!strict
--[[
  ObjectiveHUD  –  CLIENT-SIDE

  Listens to:
    MatchRemotes/ObjectiveProgress  → updates key/fuse counters.
    MatchRemotes/ClueCollected      → shows collected clue text.
    MatchRemotes/DoorUnlocked       → shows "EXIT OPEN!" flash.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player.PlayerGui

-- ── Build HUD ─────────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "ObjectiveHUD"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = player:GetAttribute("DungeonEntered") == true
player:GetAttributeChangedSignal("DungeonEntered"):Connect(function()
	gui.Enabled = player:GetAttribute("DungeonEntered") == true
end)
gui.Parent = playerGui

-- Top-left objective counter.
local counterFrame = Instance.new("Frame")
counterFrame.Name = "CounterFrame"
counterFrame.Size = UDim2.fromOffset(200, 60)
counterFrame.Position = UDim2.fromOffset(16, 16)
counterFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
counterFrame.BackgroundTransparency = 0.4
counterFrame.Parent = gui

local counterCorner = Instance.new("UICorner")
counterCorner.CornerRadius = UDim.new(0, 8)
counterCorner.Parent = counterFrame

local counterLabel = Instance.new("TextLabel")
counterLabel.Size = UDim2.fromScale(1, 1)
counterLabel.BackgroundTransparency = 1
counterLabel.TextColor3 = Color3.new(1, 1, 1)
counterLabel.Font = Enum.Font.GothamMedium
counterLabel.TextSize = 16
counterLabel.Text = "🔑 0/0  🔧 0/0"
counterLabel.Parent = counterFrame

-- Centre clue reader panel (hidden by default).
local cluePanel = Instance.new("Frame")
cluePanel.Name = "CluePanel"
cluePanel.Size = UDim2.fromScale(0.5, 0.3)
cluePanel.Position = UDim2.fromScale(0.25, 0.35)
cluePanel.BackgroundColor3 = Color3.fromRGB(15, 12, 10)
cluePanel.BackgroundTransparency = 0.1
cluePanel.Visible = false
cluePanel.Parent = gui

local cluePanelCorner = Instance.new("UICorner")
cluePanelCorner.CornerRadius = UDim.new(0, 10)
cluePanelCorner.Parent = cluePanel

local clueTitle = Instance.new("TextLabel")
clueTitle.Size = UDim2.new(1, -20, 0, 36)
clueTitle.Position = UDim2.fromOffset(10, 10)
clueTitle.BackgroundTransparency = 1
clueTitle.TextColor3 = Color3.fromRGB(240, 200, 140)
clueTitle.Font = Enum.Font.GothamBold
clueTitle.TextSize = 18
clueTitle.TextXAlignment = Enum.TextXAlignment.Left
clueTitle.Text = ""
clueTitle.Parent = cluePanel

local clueBody = Instance.new("TextLabel")
clueBody.Size = UDim2.new(1, -20, 1, -60)
clueBody.Position = UDim2.fromOffset(10, 50)
clueBody.BackgroundTransparency = 1
clueBody.TextColor3 = Color3.new(1, 1, 1)
clueBody.Font = Enum.Font.Gotham
clueBody.TextSize = 15
clueBody.TextWrapped = true
clueBody.TextXAlignment = Enum.TextXAlignment.Left
clueBody.Text = ""
clueBody.Parent = cluePanel

-- Close button.
local clueClose = Instance.new("TextButton")
clueClose.Size = UDim2.fromOffset(60, 28)
clueClose.Position = UDim2.new(1, -70, 0, 8)
clueClose.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
clueClose.TextColor3 = Color3.new(1, 1, 1)
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

-- Centre flash label for door/exit events.
local flashLabel = Instance.new("TextLabel")
flashLabel.Name = "FlashLabel"
flashLabel.Size = UDim2.new(0.6, 0, 0, 60)
flashLabel.Position = UDim2.fromScale(0.2, 0.4)
flashLabel.BackgroundTransparency = 1
flashLabel.TextColor3 = Color3.fromRGB(100, 255, 140)
flashLabel.Font = Enum.Font.GothamBold
flashLabel.TextSize = 36
flashLabel.TextStrokeTransparency = 0.3
flashLabel.Text = ""
flashLabel.TextTransparency = 1
flashLabel.Parent = gui

local function flashText(text: string)
	flashLabel.Text = text
	flashLabel.TextTransparency = 0
	TweenService:Create(flashLabel, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
	}):Play()
end

-- ── Wire remotes ──────────────────────────────────────────────────────────────
local function init()
	local matchRemotes = ReplicatedStorage:WaitForChild("MatchRemotes", 10)
	if not matchRemotes then
		warn("[ObjectiveHUD] MatchRemotes not found.")
		return
	end

	local progressEv = matchRemotes:WaitForChild("ObjectiveProgress", 10) :: RemoteEvent?
	local clueEv = matchRemotes:WaitForChild("ClueCollected", 10) :: RemoteEvent?
	local doorEv = matchRemotes:WaitForChild("DoorUnlocked", 10) :: RemoteEvent?

	local function refreshProgress()
		counterLabel.Text = string.format(
			"🔑 %d/%d  🔧 %d/%d",
			matchRemotes:GetAttribute("Keys") or 0,
			matchRemotes:GetAttribute("KeysTotal") or 1,
			matchRemotes:GetAttribute("Fuses") or 0,
			matchRemotes:GetAttribute("FusesTotal") or 1
		)
	end
	matchRemotes.AttributeChanged:Connect(refreshProgress)
	refreshProgress()

	if progressEv then
		progressEv.OnClientEvent:Connect(
			function(data: { keys: number, keysTotal: number, fuses: number, fusesTotal: number })
				counterLabel.Text =
					string.format("🔑 %d/%d  🔧 %d/%d", data.keys, data.keysTotal, data.fuses, data.fusesTotal)
			end
		)
	end

	if clueEv then
		clueEv.OnClientEvent:Connect(function(entry: { title: string, body: string })
			clueTitle.Text = entry.title
			clueBody.Text = entry.body
			cluePanel.Visible = true
		end)
	end

	if doorEv then
		doorEv.OnClientEvent:Connect(function(_doorName: string)
			flashText("EXIT OPEN!")
		end)
	end

	print("[ObjectiveHUD] Ready.")
end

return { init = init }
