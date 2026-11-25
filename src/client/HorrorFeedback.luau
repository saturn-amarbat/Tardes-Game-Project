--!strict
--[[
  HorrorFeedback  –  Visual & sensory horror tension layer.

  • Monitors distance to MainNPC_Stalker in Workspace.NPCs and drives:
    - Heartbeat-pulsing peripheral edge vignette (non-blocking ScreenGui).
    - Subtle HorrorTerrorGrade ColorCorrectionEffect (contrast + desaturation).
    - Gentle Humanoid.CameraOffset micro-tremor during close chases.
  • Adds low-health desaturation and a warm Toad-Maker Sanctuary relief badge.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Typography = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Typography"))

local HorrorFeedback = {}

local player = Players.LocalPlayer
local DREAD_START_RANGE = 38
local CHASE_SHAKE_RANGE = 22

local function makeEdgeStrip(
	parent: Frame,
	name: string,
	size: UDim2,
	pos: UDim2,
	rotation: number
): (Frame, UIGradient)
	local strip = Instance.new("Frame")
	strip.Name = name
	strip.Size = size
	strip.Position = pos
	strip.BackgroundColor3 = Color3.fromRGB(28, 4, 6)
	strip.BackgroundTransparency = 0
	strip.BorderSizePixel = 0
	strip.Parent = parent

	local grad = Instance.new("UIGradient")
	grad.Rotation = rotation
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	grad.Parent = strip

	return strip, grad
end

function HorrorFeedback.init()
	local pg = player:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild("HorrorFeedbackUI")
	if old then
		old:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "HorrorFeedbackUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = -1
	gui.Parent = pg

	local container = Instance.new("Frame")
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Parent = gui

	local _, gradTop = makeEdgeStrip(container, "EdgeTop", UDim2.fromScale(1, 0.24), UDim2.fromScale(0, 0), 90)
	local _, gradBot = makeEdgeStrip(container, "EdgeBot", UDim2.fromScale(1, 0.24), UDim2.fromScale(0, 0.76), 270)
	local _, gradLeft = makeEdgeStrip(container, "EdgeLeft", UDim2.fromScale(0.18, 1), UDim2.fromScale(0, 0), 0)
	local _, gradRight = makeEdgeStrip(container, "EdgeRight", UDim2.fromScale(0.18, 1), UDim2.fromScale(0.82, 0), 180)
	local gradients = { gradTop, gradBot, gradLeft, gradRight }

	-- Safe room sanctuary pill badge (top-centre)
	local safeBadge = Instance.new("TextLabel")
	safeBadge.Name = "SanctuaryBadge"
	safeBadge.AnchorPoint = Vector2.new(0.5, 0)
	safeBadge.Size = UDim2.fromOffset(290, 28)
	safeBadge.Position = UDim2.new(0.5, 0, 0, 16)
	safeBadge.BackgroundColor3 = Color3.fromRGB(24, 42, 32)
	safeBadge.BackgroundTransparency = 1
	safeBadge.Text = "Toad-Maker Sanctuary"
	safeBadge.Font = Typography.Fonts.Calligraphy
	safeBadge.TextSize = 21
	safeBadge.TextColor3 = Typography.Colors.ParchmentGold
	Typography.applyStroke(safeBadge, 0.35)
	safeBadge.TextTransparency = 1
	safeBadge.Parent = gui

	local safeCorner = Instance.new("UICorner")
	safeCorner.CornerRadius = UDim.new(0, 6)
	safeCorner.Parent = safeBadge

	local safeStroke = Instance.new("UIStroke")
	safeStroke.Color = Color3.fromRGB(110, 168, 120)
	safeStroke.Transparency = 1
	safeStroke.Parent = safeBadge

	local oldGrade = Lighting:FindFirstChild("HorrorTerrorGrade")
	if oldGrade then
		oldGrade:Destroy()
	end
	local terrorGrade = Instance.new("ColorCorrectionEffect")
	terrorGrade.Name = "HorrorTerrorGrade"
	terrorGrade.Saturation = 0
	terrorGrade.Contrast = 0
	terrorGrade.TintColor = Color3.new(1, 1, 1)
	terrorGrade.Parent = Lighting

	player:GetAttributeChangedSignal("InSafeRoom"):Connect(function()
		local inside = player:GetAttribute("InSafeRoom") == true and player:GetAttribute("DungeonEntered") == true
		local info = TweenInfo.new(0.45)
		TweenService:Create(safeBadge, info, {
			BackgroundTransparency = if inside then 0.25 else 1,
			TextTransparency = if inside then 0 else 1,
		}):Play()
		TweenService:Create(safeStroke, info, { Transparency = if inside then 0.35 else 1 }):Play()
	end)

	local beatPhase = 0
	local smoothTension = 0

	RunService.RenderStepped:Connect(function(dt: number)
		local inDungeon = player:GetAttribute("DungeonEntered") == true
		local sittingOut = player:GetAttribute("SittingOut") == true
		local inSafe = player:GetAttribute("InSafeRoom") == true
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")

		local targetTension = 0
		local stalkerDist = math.huge

		if inDungeon and not sittingOut and not inSafe and hrp and hrp:IsA("BasePart") then
			local npcs = Workspace:FindFirstChild("NPCs")
			local stalker = npcs and npcs:FindFirstChild("MainNPC_Stalker")
			if stalker and stalker:IsA("Model") then
				stalkerDist = (hrp.Position - stalker:GetPivot().Position).Magnitude
				if stalkerDist < DREAD_START_RANGE then
					targetTension = math.clamp((DREAD_START_RANGE - stalkerDist) / (DREAD_START_RANGE - 8), 0, 1)
				end
			end
			if hum and hum.MaxHealth > 0 then
				local hpFrac = hum.Health / hum.MaxHealth
				if hpFrac <= 0.45 then
					targetTension = math.max(targetTension, (0.45 - hpFrac) * 1.3)
				end
			end
		end

		smoothTension += (targetTension - smoothTension) * math.min(1, dt * 4)
		local pulseRate = 1.1 + smoothTension * 1.4
		beatPhase += dt * pulseRate * math.pi * 2
		local beat = math.pow(math.max(0, math.sin(beatPhase)), 4)

		-- Apply peripheral edge vignette alpha
		local edgeAlpha = math.clamp(1 - (smoothTension * (0.38 + beat * 0.28)), 0.28, 1)
		if smoothTension < 0.02 then
			edgeAlpha = 1
		end
		local seq = NumberSequence.new({
			NumberSequenceKeypoint.new(0, edgeAlpha),
			NumberSequenceKeypoint.new(1, 1),
		})
		for _, grad in gradients do
			grad.Transparency = seq
		end

		-- Subtle desaturated dread color grade
		terrorGrade.Saturation = -0.45 * smoothTension
		terrorGrade.Contrast = 0.12 * smoothTension
		local tintLerp = smoothTension * 0.14
		terrorGrade.TintColor = Color3.new(1, 1 - tintLerp * 0.6, 1 - tintLerp)

		-- Gentle chase tremor via Humanoid.CameraOffset (never fights camera scripts)
		if hum and hum.Health > 0 then
			if stalkerDist < CHASE_SHAKE_RANGE and not sittingOut and not inSafe then
				local shakeAmt = ((CHASE_SHAKE_RANGE - stalkerDist) / CHASE_SHAKE_RANGE) * 0.065
				hum.CameraOffset = Vector3.new((math.random() - 0.5) * shakeAmt, (math.random() - 0.5) * shakeAmt, 0)
			elseif hum.CameraOffset.Magnitude > 0.001 then
				hum.CameraOffset = hum.CameraOffset:Lerp(Vector3.zero, math.min(1, dt * 10))
			end
		end
	end)

	print("[HorrorFeedback] Proximity vignette & Sanctuary relief active.")
end

return HorrorFeedback
