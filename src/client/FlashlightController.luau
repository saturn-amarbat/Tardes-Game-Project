--!strict
--[[
  FlashlightController  –  Camera-aligned flashlight with a warm hotspot and narrow spill.

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

local FlashlightOptics = require(script.Parent.FlashlightOptics)
local FlashlightController = {}

-- ── Configuration ──────────────────────────────────────────────────────────
local CONFIG = {
	MAX_BATTERY = 100,
	DRAIN_RATE_PER_SEC = 0.5, -- ~200 s runtime
}

local ACTION_NAME = "ToggleFlashlight"
local RENDER_STEP = "AimFlashlight"

-- ── State ───────────────────────────────────────────────────────────────────
local player = Players.LocalPlayer

local isEnabled = false
local battery = CONFIG.MAX_BATTERY
local isFlickering = false

local _lightModel: Model? = nil
local lightRoot: Part? = nil
local primarySpot: SpotLight? = nil
local warmSpill: SpotLight? = nil
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
local function createFlashlightRig(): (Model, Part, SpotLight, SpotLight, Sound)
	local rig = Instance.new("Model")
	rig.Name = "ClientFlashlightRig"

	local root = Instance.new("Part")
	root.Name = "LightMount"
	root.Size = Vector3.new(0.05, 0.05, 0.05)
	root.CastShadow = false
	local camera = Workspace.CurrentCamera
	if camera then
		root.CFrame = camera.CFrame
	end
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Anchored = true
	root.Parent = rig

	local hotspot, spill = FlashlightOptics.localBeam(root)

	-- Toggle click SFX
	local sfx = Instance.new("Sound")
	sfx.Name = "ClickSound"
	sfx.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	sfx.Volume = 0.5
	sfx.Parent = root

	rig.Parent = Workspace
	return rig, root, hotspot, spill, sfx
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
	if warmSpill then
		warmSpill.Enabled = state
	end
end

function FlashlightController.toggle()
	local enabled = battery > 0 and not isEnabled
	if enabled == isEnabled then
		return
	end
	isEnabled = enabled
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
		while elapsed < duration and isEnabled do
			local flickerOn = math.random() > (0.3 * intensity)
			FlashlightController.setLights(flickerOn)
			FlashlightOptics.setIntensity(primarySpot, warmSpill, 0.3 + math.random() * 0.7)
			local step = math.random(3, 8) / 100
			task.wait(step)
			elapsed += step
		end
		FlashlightOptics.setIntensity(primarySpot, warmSpill, 1)
		FlashlightController.setLights(isEnabled)
		isFlickering = false
	end)
end

function FlashlightController.getBattery(): number
	return battery
end

-- ── Initialisation ──────────────────────────────────────────────────────────
function FlashlightController.init()
	Workspace:GetAttributeChangedSignal("ExpeditionNumber"):Connect(function()
		battery = CONFIG.MAX_BATTERY
		if not isEnabled then
			FlashlightController.toggle()
		end
	end)
	local rig, root, spot, spill, sfx = createFlashlightRig()
	_lightModel = rig
	lightRoot = root
	primarySpot = spot
	warmSpill = spill
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
	RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		local camera = Workspace.CurrentCamera
		if camera and lightRoot then
			lightRoot.CFrame = camera.CFrame
		end

		if isEnabled and not isFlickering then
			battery = math.clamp(battery - CONFIG.DRAIN_RATE_PER_SEC * dt, 0, CONFIG.MAX_BATTERY)
			if battery <= 0 then
				FlashlightController.toggle()
			end
		end
	end)

	print("[FlashlightController] Initialised. Input: F / ButtonY / touch button.")
end

-- Cleanup (call when character dies / round ends).
function FlashlightController.destroy()
	ContextActionService:UnbindAction(ACTION_NAME)
	RunService:UnbindFromRenderStep(RENDER_STEP)
	if _lightModel then
		_lightModel:Destroy()
		_lightModel = nil
		lightRoot = nil
		primarySpot = nil
		warmSpill = nil
		toggleSound = nil
	end
end

return FlashlightController
