--!strict
-- Brief location card, route guidance and optional deer encounter dialogue.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Typography = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Typography"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

-- ── Build the dialogue / guidance UI ─────────────────────────────────────────
local function buildDialogueUI(): (ScreenGui, TextLabel, TextButton)
	local old = playerGui:FindFirstChild("PrologueUI")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "PrologueUI"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- Bottom-centre guidance / omen subtitle (high-contrast bone ivory with dark stroke).
	local label = Instance.new("TextLabel")
	label.Name = "DialogueLabel"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Size = UDim2.new(0.72, 0, 0, 56)
	label.Position = UDim2.new(0.5, 0, 1, -42)
	label.BackgroundTransparency = 1
	label.TextColor3 = Typography.Colors.Bone
	Typography.applyStroke(label, 0.3)
	label.Font = Typography.Fonts.Narrative
	label.TextSize = 24
	label.TextWrapped = true
	label.Text = ""
	label.Parent = gui

	-- Skip button (top-right corner, matching dark-slate dossier style).
	local skipBtn = Instance.new("TextButton")
	skipBtn.Name = "SkipButton"
	skipBtn.AnchorPoint = Vector2.new(1, 0)
	skipBtn.Size = UDim2.fromOffset(112, 32)
	skipBtn.Position = UDim2.new(1, -16, 0, 16)
	skipBtn.BackgroundColor3 = Color3.fromRGB(14, 17, 16)
	skipBtn.BackgroundTransparency = 0.16
	skipBtn.TextColor3 = Color3.fromRGB(228, 198, 130)
	skipBtn.Font = Enum.Font.GothamMedium
	skipBtn.TextSize = 13
	skipBtn.Text = "Skip omen"
	skipBtn.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = skipBtn

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(68, 76, 72)
	stroke.Transparency = 0.3
	stroke.Parent = skipBtn

	return gui, label, skipBtn
end

local function showLocation(gui: ScreenGui)
	local existing = gui:FindFirstChild("Location")
	if existing then
		existing:Destroy()
	end
	local title = Instance.new("TextLabel")
	title.Name = "Location"
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.fromScale(0.5, 0.085)
	title.Size = UDim2.new(0.85, 0, 0, 52)
	title.BackgroundTransparency = 1
	title.Text = "BLACKPINE WOODS"
	title.TextColor3 = Typography.Colors.ParchmentGold
	Typography.applyStroke(title, 0.25)
	title.TextTransparency = 1
	title.Font = Typography.Fonts.Calligraphy
	title.TextSize = 38
	title.Parent = gui
	TweenService:Create(title, TweenInfo.new(0.8), { TextTransparency = 0 }):Play()
	task.delay(4, function()
		if not title.Parent then
			return
		end
		local fade =
			TweenService:Create(title, TweenInfo.new(1.1), { TextTransparency = 1, TextStrokeTransparency = 1 })
		fade:Play()
		fade.Completed:Once(function()
			title:Destroy()
		end)
	end)
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

	local gui, label, skipBtn = buildDialogueUI()
	local omenDialogue = ""
	local shownLocation = false
	local voted = false
	local lastText = ""
	local fade: Tween? = nil

	local function refresh()
		gui.Enabled = player:GetAttribute("DungeonEntered") ~= true and player:GetAttribute("SittingOut") ~= true
		if not gui.Enabled then
			local loc = gui:FindFirstChild("Location")
			if loc then
				loc:Destroy()
			end
			if fade then
				fade:Cancel()
			end
			lastText = ""
			label.Text = ""
		end
		skipBtn.Visible = prologueFolder:GetAttribute("OmenAvailable") == true
		skipBtn.Active = not voted
		skipBtn.Text = if voted then "Voted ✓" else "Skip omen"

		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local start = Workspace:GetAttribute("BlackpineStart")
		local cottage = Workspace:GetAttribute("BlackpineCottage")
		local step = Workspace:GetAttribute("BlackpineOpeningStep")
		local guidance = ""
		if gui.Enabled and root and root:IsA("BasePart") and typeof(cottage) == "Vector3" then
			local pos = root.Position
			if not shownLocation and typeof(start) == "Vector3" and (pos - start).Magnitude < 22 then
				shownLocation = true
				showLocation(gui)
			end
			if pos.Y < cottage.Y - 3.5 then
				guidance = if step == "BoardLift"
					then "Board the survey lift."
					else "Follow the rail. Restore power at the survey lift."
			elseif (pos - cottage).Magnitude > 23 then
				guidance = "Follow the amber stakes to the warden’s cottage."
			elseif step == "FindKey" then
				guidance = "Look for the cellar key in the kitchen."
			elseif step == "UnlockHatch" then
				guidance = "Use the key on the cellar hatch."
			else
				guidance = "Go down through the open hatch."
			end
		end

		local message = if gui.Enabled and omenDialogue ~= "" then omenDialogue else guidance
		if message == lastText then
			return
		end
		lastText = message
		if fade then
			fade:Cancel()
		end
		if message ~= "" then
			label.Text = message
			label.TextTransparency = 1
		end
		fade = TweenService:Create(label, TweenInfo.new(0.32), { TextTransparency = if message == "" then 1 else 0 })
		fade:Play()
	end

	Workspace:GetAttributeChangedSignal("ExpeditionNumber"):Connect(function()
		voted = false
		omenDialogue = ""
		refresh()
	end)
	Workspace:GetAttributeChangedSignal("BlackpineOpeningStep"):Connect(refresh)
	player:GetAttributeChangedSignal("DungeonEntered"):Connect(refresh)
	player:GetAttributeChangedSignal("SittingOut"):Connect(refresh)
	prologueFolder:GetAttributeChangedSignal("OmenAvailable"):Connect(refresh)
	dialogueEvent.OnClientEvent:Connect(function(message: string)
		omenDialogue = message
		refresh()
	end)

	skipBtn.Activated:Connect(function()
		if voted or not skipBtn.Visible then
			return
		end
		voted = true
		refresh()
		skipEvent:FireServer()
	end)

	task.spawn(function()
		while gui.Parent do
			refresh()
			task.wait(0.25)
		end
	end)

	print("[PrologueController] Ready.")
end

return { init = init }
