--!strict
--[[
  FlashlightController  –  Client-side Slender-Man layered flashlight system.

  Input binding hierarchy (highest priority first):
    1. ContextActionService action "ToggleFlashlight"
       • KeyCode.F  (keyboard)
       • KeyCode.ButtonY  (gamepad)
       • Touch InputBinding via HUD button (GameHUD/FlashlightButton) if present,
         else a runtime ScreenGui fallback button is created automatically.
    2. HapticEffect (UIClick pulse) fires on mobile toggle and anomaly flicker start.

  Co-op replication:
    • toggle() fires ReplicatedStorage/FlashlightRemotes/ToggleState → server
      broadcasts to all other clients → they show/hide the SpotLight on the
      character's torso attachment (see FlashlightReplicator.luau server side).

  Battery:
    • Drains at DRAIN_RATE_PER_SEC while enabled, auto-off at 0%.
    • triggerAnomalyFlicker(duration, intensity) pauses drain during flicker.
    • getBattery() returns current 0–100 value for HUD display.
]]

local ContextActionService = game:GetService("ContextActionService")
local HapticService = game:GetService("HapticService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local FlashlightController = {}

-- ── Configuration ──────────────────────────────────────────────────────────
local CONFIG = {
	MAX_BATTERY = 100,
	DRAIN_RATE_PER_SEC = 0.5, -- ~200 s runtime
	SPOT_BRIGHTNESS = 2.8,
	SPOT_RANGE = 60,
	SPOT_ANGLE = 48,
	AMBIENT_BRIGHTNESS = 0.45,
	AMBIENT_RANGE = 14,
	LIGHT_COLOR = Color3.fromRGB(245, 240, 220),
	TWEEN_ROTATION_SPEED = 18,
}

local ACTION_NAME = "ToggleFlashlight"

-- ── State ───────────────────────────────────────────────────────────────────
local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local isEnabled = false
local battery = CONFIG.MAX_BATTERY
local isFlickering = false

local _lightModel: Model? = nil
local lightRoot: Part? = nil
local primarySpot: SpotLight? = nil
local fillPoint: PointLight? = nil
local toggleSound: Sound? = nil

-- ── Helpers ─────────────────────────────────────────────────────────────────
local function hapticPulse()
	-- Vibrate left-hand motor briefly on supported gamepads / mobile.
	local ok = pcall(function()
		HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.LeftHand, 0.3)
	end)
	if ok then
		task.delay(0.08, function()
			pcall(function()
				HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.LeftHand, 0)
			end)
		end)
	end
end

-- ── Light Rig ───────────────────────────────────────────────────────────────
local function createFlashlightRig(): (Model, Part, SpotLight, PointLight, Sound)
	local rig = Instance.new("Model")
	rig.Name = "ClientFlashlightRig"

	local root = Instance.new("Part")
	root.Name = "LightMount"
	root.Size = Vector3.new(0.4, 0.4, 0.8)
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Anchored = true
	root.Parent = rig

	-- Primary crisp cone (shadows on)
	local spot = Instance.new("SpotLight")
	spot.Name = "PrimaryCone"
	spot.Angle = CONFIG.SPOT_ANGLE
	spot.Range = CONFIG.SPOT_RANGE
	spot.Brightness = CONFIG.SPOT_BRIGHTNESS
	spot.Color = CONFIG.LIGHT_COLOR
	spot.Shadows = true
	spot.Enabled = false
	spot.Face = Enum.NormalId.Front
	spot.Parent = root

	-- Soft ambient fill (mobile/low-graphics friendly, no shadows)
	local point = Instance.new("PointLight")
	point.Name = "AmbientFill"
	point.Range = CONFIG.AMBIENT_RANGE
	point.Brightness = CONFIG.AMBIENT_BRIGHTNESS
	point.Color = CONFIG.LIGHT_COLOR
	point.Shadows = false
	point.Enabled = false
	point.Parent = root

	-- Toggle click SFX
	local sfx = Instance.new("Sound")
	sfx.Name = "ClickSound"
	sfx.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	sfx.Volume = 0.5
	sfx.Parent = root

	rig.Parent = Workspace.CurrentCamera
	return rig, root, spot, point, sfx
end

-- ── Touch HUD Button (created if GameHUD/FlashlightButton not present) ──────
local function ensureTouchButton()
	-- Try to find the button created by the Creative Lead first.
	local hud = player.PlayerGui:FindFirstChild("GameHUD")
	if not hud and game:GetService("StarterGui"):FindFirstChild("GameHUD") then
		hud = player.PlayerGui:WaitForChild("GameHUD", 5)
	end
	if hud and hud:FindFirstChild("FlashlightButton") and hud.FlashlightButton:IsA("GuiButton") then
		local btn = hud:FindFirstChild("FlashlightButton") :: GuiButton
		btn.Activated:Connect(function()
			FlashlightController.toggle()
		end)
		return
	end

	if not UserInputService.TouchEnabled then
		return
	end

	-- Runtime fallback ScreenGui with a simple torch button.
	local gui = Instance.new("ScreenGui")
	gui.Name = "FlashlightHUD_Fallback"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player.PlayerGui

	local btn = Instance.new("TextButton")
	btn.Name = "FlashlightButton"
	btn.Size = UDim2.fromOffset(80, 80)
	btn.Position = UDim2.new(1, -100, 1, -120)
	btn.AnchorPoint = Vector2.new(1, 1)
	btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	btn.BackgroundTransparency = 0.3
	btn.Text = "🔦"
	btn.TextSize = 32
	btn.Font = Enum.Font.GothamBold
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = btn

	btn.Activated:Connect(function()
		FlashlightController.toggle()
		hapticPulse()
	end)
end

-- ── Core API ─────────────────────────────────────────────────────────────────
function FlashlightController.setLights(state: boolean)
	if primarySpot then
		primarySpot.Enabled = state
	end
	if fillPoint then
		fillPoint.Enabled = state
	end
end

function FlashlightController.toggle()
	if battery <= 0 then
		isEnabled = false
		FlashlightController.setLights(false)
		return
	end

	isEnabled = not isEnabled
	if toggleSound then
		toggleSound:Play()
	end
	FlashlightController.setLights(isEnabled)

	-- Replicate to server for co-op teammate SpotLight visibility.
	local remotes = ReplicatedStorage:FindFirstChild("FlashlightRemotes")
	if remotes then
		local ev = remotes:FindFirstChild("ToggleState") :: RemoteEvent?
		if ev then
			ev:FireServer(isEnabled)
		end
	end
end

function FlashlightController.triggerAnomalyFlicker(duration: number, intensity: number)
	if not isEnabled or isFlickering then
		return
	end
	isFlickering = true
	hapticPulse() -- tactile cue on anomaly start

	task.spawn(function()
		local elapsed = 0
		local origBrightness = CONFIG.SPOT_BRIGHTNESS
		while elapsed < duration and isEnabled do
			local flickerOn = math.random() > (0.3 * intensity)
			FlashlightController.setLights(flickerOn)
			if primarySpot then
				primarySpot.Brightness = flickerOn and (origBrightness * (0.3 + math.random() * 0.7)) or 0
			end
			local step = math.random(3, 8) / 100
			task.wait(step)
			elapsed += step
		end
		if primarySpot then
			primarySpot.Brightness = origBrightness
		end
		FlashlightController.setLights(isEnabled)
		isFlickering = false
	end)
end

function FlashlightController.getBattery(): number
	return battery
end

-- ── Initialisation ──────────────────────────────────────────────────────────
function FlashlightController.init()
	local rig, root, spot, point, sfx = createFlashlightRig()
	_lightModel = rig
	lightRoot = root
	primarySpot = spot
	fillPoint = point
	toggleSound = sfx

	-- ContextActionService binding (keyboard + gamepad + mobile sink).
	ContextActionService:BindAction(
		ACTION_NAME,
		function(_name: string, state: Enum.UserInputState, _input: InputObject)
			if state == Enum.UserInputState.Begin then
				FlashlightController.toggle()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.KeyCode.F,
		Enum.KeyCode.ButtonY
	)

	ensureTouchButton()

	-- Wire server->client flicker request from NPCManager.
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("FlashlightRemotes", 10)
		if remotes then
			local flickerEv = remotes:WaitForChild("FlickerRequest", 10) :: RemoteEvent?
			if flickerEv then
				flickerEv.OnClientEvent:Connect(function(dur: number, intensity: number)
					FlashlightController.triggerAnomalyFlicker(dur, intensity)
				end)
			end
		end
	end)

	-- Battery drain + camera-tracking render loop.
	RunService.RenderStepped:Connect(function(dt: number)
		if not camera then
			camera = Workspace.CurrentCamera
			return
		end
		if not lightRoot then
			return
		end

		if isEnabled and not isFlickering then
			battery = math.clamp(battery - CONFIG.DRAIN_RATE_PER_SEC * dt, 0, CONFIG.MAX_BATTERY)
			if battery <= 0 then
				FlashlightController.toggle()
			end
		end

		-- Shoulder-offset camera tracking.
		local targetCF = camera.CFrame * CFrame.new(0.6, -0.5, -0.2)
		lightRoot.CFrame = lightRoot.CFrame:Lerp(targetCF, math.clamp(dt * CONFIG.TWEEN_ROTATION_SPEED, 0, 1))
	end)

	print("[FlashlightController] Initialised. Input: F / ButtonY / touch button.")
end

-- Cleanup (call when character dies / round ends).
function FlashlightController.destroy()
	ContextActionService:UnbindAction(ACTION_NAME)
	if _lightModel then
		_lightModel:Destroy()
		_lightModel = nil
		lightRoot = nil
		primarySpot = nil
		fillPoint = nil
		toggleSound = nil
	end
end

return FlashlightController
