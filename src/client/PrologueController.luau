--!strict
--[[
  PrologueController  –  CLIENT-SIDE

  Listens to PrologueRemotes:
    • ShowDialogue(text)  –  shows bottom guidance text; "" hides it.
    • SkipPrologue        –  sends a skip vote to the server.

  Guidance text ("Find shelter before nightfall") is shown as soon as the
  client spawns, then replaced by deer dialogue during the omen sequence.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player.PlayerGui

-- ── Build the dialogue / guidance UI ─────────────────────────────────────────
local function buildDialogueUI(): (ScreenGui, TextLabel, TextButton)
	local gui = Instance.new("ScreenGui")
	gui.Name = "PrologueUI"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- Bottom-centre guidance label.
	local label = Instance.new("TextLabel")
	label.Name = "DialogueLabel"
	label.Size = UDim2.new(0.7, 0, 0, 56)
	label.Position = UDim2.fromScale(0.15, 0.88)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 22
	label.TextWrapped = true
	label.Text = "Find shelter before nightfall."
	label.Parent = gui

	-- Skip button (top-right corner, subtle).
	local skipBtn = Instance.new("TextButton")
	skipBtn.Name = "SkipButton"
	skipBtn.Size = UDim2.fromOffset(120, 36)
	skipBtn.Position = UDim2.new(1, -140, 0, 20)
	skipBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	skipBtn.BackgroundTransparency = 0.4
	skipBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
	skipBtn.Font = Enum.Font.Gotham
	skipBtn.TextSize = 15
	skipBtn.Text = "Skip intro  ▶"
	skipBtn.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = skipBtn

	return gui, label, skipBtn
end

local function setDialogueText(label: TextLabel, text: string)
	if text == "" then
		TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
	else
		label.TextTransparency = 1
		label.Text = text
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
	end
end

local function init()
	local prologueFolder = ReplicatedStorage:WaitForChild("PrologueRemotes", 10)
	if not prologueFolder then
		warn("[PrologueController] PrologueRemotes not found.")
		return
	end

	local dialogueEvent = prologueFolder:WaitForChild("ShowDialogue", 10) :: RemoteEvent?
	local skipEvent = prologueFolder:WaitForChild("SkipPrologue", 10) :: RemoteEvent?
	if not dialogueEvent or not skipEvent then
		warn("[PrologueController] Missing remote events.")
		return
	end

	local _gui, label, skipBtn = buildDialogueUI()

	-- Show initial guidance text with a brief fade-in delay.
	task.delay(2, function()
		setDialogueText(label, "Find shelter before nightfall.")
	end)

	dialogueEvent.OnClientEvent:Connect(function(text: string)
		setDialogueText(label, text)
	end)

	skipBtn.Activated:Connect(function()
		skipBtn.Text = "Voted ✓"
		skipBtn.Active = false
		(skipEvent :: RemoteEvent):FireServer()
	end)

	print("[PrologueController] Ready.")
end

return { init = init }
