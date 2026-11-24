--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local SpectatorController = {}

local localPlayer = Players.LocalPlayer

local function getSurvivors(): { Player }
	local list: { Player } = {}
	for _, p in Players:GetPlayers() do
		if p ~= localPlayer and p:GetAttribute("DungeonEntered") == true and p:GetAttribute("SittingOut") ~= true then
			local char = p.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				table.insert(list, p)
			end
		end
	end
	return list
end

function SpectatorController.init()
	local pg = localPlayer:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild("SpectatorHUD")
	if old then
		old:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "SpectatorHUD"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = pg

	local bar = Instance.new("Frame")
	bar.Name = "SpectatorBar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Size = UDim2.fromOffset(360, 44)
	bar.Position = UDim2.new(0.5, 0, 1, -24)
	bar.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
	bar.BackgroundTransparency = 0.2
	bar.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = bar

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(110, 114, 120)
	stroke.Thickness = 1
	stroke.Transparency = 0.4
	stroke.Parent = bar

	local label = Instance.new("TextButton")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(235, 232, 224)
	label.Text = "Spectating"
	label.Parent = bar

	local reviveBtn = Instance.new("TextButton")
	reviveBtn.Name = "ReviveTokenButton"
	reviveBtn.AnchorPoint = Vector2.new(0.5, 1)
	reviveBtn.Size = UDim2.fromOffset(220, 38)
	reviveBtn.Position = UDim2.new(0.5, 0, 1, -76)
	reviveBtn.BackgroundColor3 = Color3.fromRGB(48, 108, 66)
	reviveBtn.TextColor3 = Color3.fromRGB(245, 248, 240)
	reviveBtn.Font = Enum.Font.GothamBold
	reviveBtn.TextSize = 14
	reviveBtn.Text = "Use Revive Token (1 left)"
	reviveBtn.Visible = false
	reviveBtn.Parent = gui
	local revCorner = Instance.new("UICorner")
	revCorner.CornerRadius = UDim.new(0, 8)
	revCorner.Parent = reviveBtn

	local index = 1
	local matchRemotes = ReplicatedStorage:WaitForChild("MatchRemotes", 10)
	local claimRevive = matchRemotes and matchRemotes:FindFirstChild("ClaimReviveToken")

	reviveBtn.Activated:Connect(function()
		if claimRevive and claimRevive:IsA("RemoteEvent") then
			claimRevive:FireServer()
		end
	end)

	local function restoreCamera()
		gui.Enabled = false
		reviveBtn.Visible = false
		local camera = Workspace.CurrentCamera
		local char = localPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if camera and hum then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = hum
		end
	end

	local function updateCamera()
		local phase = matchRemotes and matchRemotes:GetAttribute("RunState")
		local shouldSpectate = localPlayer:GetAttribute("SittingOut") == true and phase == "Active"
		if not shouldSpectate then
			if gui.Enabled then
				restoreCamera()
			end
			return
		end

		local tokens = localPlayer:GetAttribute("ReviveTokens")
		local claimed = localPlayer:GetAttribute("ReviveTokenClaimed") == true
		reviveBtn.Visible = typeof(tokens) == "number" and tokens >= 1 and not claimed

		local targets = getSurvivors()
		if #targets == 0 then
			gui.Enabled = true
			label.Text = "No active survivors in the bunker"
			return
		end

		index = ((index - 1) % #targets) + 1
		local target = targets[index]
		local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
		local camera = Workspace.CurrentCamera
		if camera and hum then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = hum
		end
		gui.Enabled = true
		label.Text = string.format("Spectating: %s  (Q / E or Tap to switch)", target.DisplayName)
	end

	local function cycle(delta: number)
		index += delta
		updateCamera()
	end

	label.Activated:Connect(function()
		cycle(1)
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or not gui.Enabled then
			return
		end
		if input.KeyCode == Enum.KeyCode.E then
			cycle(1)
		elseif input.KeyCode == Enum.KeyCode.Q then
			cycle(-1)
		end
	end)

	localPlayer:GetAttributeChangedSignal("SittingOut"):Connect(updateCamera)
	if matchRemotes then
		matchRemotes:GetAttributeChangedSignal("RunState"):Connect(updateCamera)
	end
	localPlayer.CharacterAdded:Connect(function()
		task.defer(updateCamera)
	end)

	task.spawn(function()
		while gui.Parent do
			if gui.Enabled or localPlayer:GetAttribute("SittingOut") == true then
				updateCamera()
			end
			task.wait(0.75)
		end
	end)
end

return SpectatorController
