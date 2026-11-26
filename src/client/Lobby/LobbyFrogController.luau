--!strict
--[[
  LobbyFrogController  –  CLIENT subtle horror idle animation & greeting for FrogShopkeeper.

  Drives smooth 60 FPS breathing, throat pulse, blinking, occasional tongue flick,
  head tracking toward nearby/interacting players, and short greeting subtitle lines.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LobbyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyConfig"))
local Typography = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Typography"))

local LobbyFrogController = {}

local player = Players.LocalPlayer
local greetingLabel: TextLabel? = nil
local greetingGui: ScreenGui? = nil
local renderConn: RBXScriptConnection? = nil
local greetingToken = 0
local forceLookUntil = 0

local function buildGreetingUI(): TextLabel
	local pg = player:WaitForChild("PlayerGui") :: PlayerGui
	local old = pg:FindFirstChild("FrogGreetingUI")
	if old then
		old:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "FrogGreetingUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.Parent = pg

	local label = Instance.new("TextLabel")
	label.Name = "GreetingLabel"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Size = UDim2.new(0.76, 0, 0, 48)
	label.Position = UDim2.new(0.5, 0, 1, -74)
	label.BackgroundTransparency = 1
	label.Font = Typography.Fonts.Narrative
	label.TextSize = 22
	label.TextWrapped = true
	label.TextColor3 = Typography.Colors.Bone
	Typography.applyStroke(label, 0.25)
	label.Text = ""
	label.TextTransparency = 1
	label.Parent = gui

	greetingGui = gui
	return label
end

function LobbyFrogController.stop()
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
	if greetingGui then
		greetingGui:Destroy()
		greetingGui = nil
	end
	greetingLabel = nil
end

function LobbyFrogController.greetPlayer()
	forceLookUntil = os.clock() + 8
	if not greetingLabel then
		return
	end

	local lines = LobbyConfig.FROG_GREETINGS
	if #lines == 0 then
		return
	end
	local line = lines[math.random(1, #lines)]

	greetingToken += 1
	local myToken = greetingToken
	greetingLabel.Text = string.format('Frog Merchant: "%s"', line)
	greetingLabel.TextTransparency = 1
	TweenService:Create(greetingLabel, TweenInfo.new(0.35), { TextTransparency = 0 }):Play()

	task.delay(4.5, function()
		if greetingToken ~= myToken or not greetingLabel then
			return
		end
		TweenService:Create(greetingLabel, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
	end)
end

function LobbyFrogController.init()
	greetingLabel = buildGreetingUI()

	task.spawn(function()
		local map = Workspace:WaitForChild("LobbyMap", 15)
		local frog = map and map:WaitForChild("FrogShopkeeper", 15)
		if not frog or not frog:IsA("Model") then
			return
		end

		local body = frog:FindFirstChild("Body") :: BasePart?
		local belly = frog:FindFirstChild("Belly") :: BasePart?
		local throat = frog:FindFirstChild("Throat") :: BasePart?
		local headRig = frog:FindFirstChild("HeadRig") :: Model?
		if not body or not headRig or not headRig.PrimaryPart then
			return
		end

		local headPrimary = headRig.PrimaryPart
		local headBaseCF = headPrimary.CFrame
		local bodyBaseCF = body.CFrame
		local bellyBaseCF = if belly then belly.CFrame else nil
		local throatBaseCF = if throat then throat.CFrame else nil
		local throatBaseSize = if throat then throat.Size else Vector3.zero

		-- Cache head sub-part offsets relative to HeadRig PrimaryPart
		local headOffsets: { { part: BasePart, offset: CFrame } } = {}
		local eyelidL = headRig:FindFirstChild("Eyelid_L") :: BasePart?
		local eyelidR = headRig:FindFirstChild("Eyelid_R") :: BasePart?
		local tongue = headRig:FindFirstChild("Tongue") :: BasePart?
		local eyelidLOffset = if eyelidL then headBaseCF:ToObjectSpace(eyelidL.CFrame) else nil
		local eyelidROffset = if eyelidR then headBaseCF:ToObjectSpace(eyelidR.CFrame) else nil
		local tongueOffset = if tongue then headBaseCF:ToObjectSpace(tongue.CFrame) else nil

		for _, child in headRig:GetDescendants() do
			if child:IsA("BasePart") and child ~= eyelidL and child ~= eyelidR and child ~= tongue then
				table.insert(headOffsets, {
					part = child,
					offset = headBaseCF:ToObjectSpace(child.CFrame),
				})
			end
		end

		local blinkAlpha = 0
		local nextBlink = os.clock() + 3.5
		local blinkEnd = 0

		local tongueAlpha = 0
		local nextTongue = os.clock() + 10
		local tongueEnd = 0

		local nextPulse = os.clock() + 4
		local pulseStart = 0

		local currentYaw = 0

		renderConn = RunService.RenderStepped:Connect(function(dt: number)
			if not frog.Parent then
				return
			end
			local now = os.clock()

			-- 1. Slow breathing
			local breath = math.sin(now * 1.35)
			local bodyLift = breath * 0.14
			body.CFrame = bodyBaseCF * CFrame.new(0, bodyLift, 0)
			if belly and bellyBaseCF then
				belly.CFrame = bellyBaseCF * CFrame.new(0, bodyLift * 0.9, -breath * 0.08)
			end

			-- 2. Throat pulse cycle
			local pulseAmount = 0
			if now >= nextPulse then
				pulseStart = now
				nextPulse = now + 4.5 + math.random() * 4.5
			end
			local pulseElapsed = now - pulseStart
			if pulseElapsed >= 0 and pulseElapsed < 1.1 then
				pulseAmount = math.sin((pulseElapsed / 1.1) * math.pi)
			end
			if throat and throatBaseCF then
				throat.Size = throatBaseSize + Vector3.new(pulseAmount * 0.9, pulseAmount * 0.7, pulseAmount * 1.1)
				throat.CFrame = throatBaseCF * CFrame.new(0, bodyLift * 0.7 - pulseAmount * 0.25, -pulseAmount * 0.45)
			end

			-- 3. Head tracking toward nearby or interacting player
			local targetYaw = 0
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and hrp:IsA("BasePart") then
				local toPlayer = hrp.Position - headBaseCF.Position
				if toPlayer.Magnitude <= 18 or now < forceLookUntil then
					local localDir = headBaseCF:VectorToObjectSpace(Vector3.new(toPlayer.X, 0, toPlayer.Z))
					-- -Z is forward
					local angle = math.atan2(-localDir.X, -localDir.Z)
					targetYaw = math.clamp(angle, math.rad(-48), math.rad(48))
				end
			end
			currentYaw += (targetYaw - currentYaw) * math.min(1, dt * 4.5)

			-- 4. Natural blinking
			if now >= nextBlink then
				blinkEnd = now + 0.16
				nextBlink = now + 3.2 + math.random() * 4.2
			end
			local targetBlink = if now < blinkEnd then 1 else 0
			blinkAlpha += (targetBlink - blinkAlpha) * math.min(1, dt * 28)

			-- 5. Occasional tongue flick
			if now >= nextTongue then
				tongueEnd = now + 0.18
				nextTongue = now + 11 + math.random() * 9
			end
			local targetTongue = if now < tongueEnd then 1 else 0
			tongueAlpha += (targetTongue - tongueAlpha) * math.min(1, dt * 32)

			-- Apply animated head transform
			local animatedHeadCF = headBaseCF * CFrame.new(0, bodyLift * 1.15, 0) * CFrame.Angles(0, currentYaw, 0)
			for _, entry in headOffsets do
				entry.part.CFrame = animatedHeadCF * entry.offset
			end
			if eyelidL and eyelidLOffset then
				eyelidL.CFrame = animatedHeadCF * eyelidLOffset * CFrame.new(0, -blinkAlpha * 1.05, 0)
			end
			if eyelidR and eyelidROffset then
				eyelidR.CFrame = animatedHeadCF * eyelidROffset * CFrame.new(0, -blinkAlpha * 1.05, 0)
			end
			if tongue and tongueOffset then
				tongue.CFrame = animatedHeadCF * tongueOffset * CFrame.new(0, -tongueAlpha * 0.25, -tongueAlpha * 3.1)
			end
		end)
	end)

	print("[LobbyFrogController] Ready.")
end

return LobbyFrogController
