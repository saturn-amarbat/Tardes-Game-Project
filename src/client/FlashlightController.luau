--!strict
--[[
  FlashlightController  –  Atmospheric horror detached flashlight system.

  Core features:
    1. Detached Smooth Camera Tracking:
       Drives an invisible, anchored, non-collidable Part ("FlashlightEmitter")
       in Workspace via RunService:BindToRenderStep using exponential damping
       (1 - math.exp(-LagStiffness * dt)) and CFrame:Lerp().
    2. Layered Movement Sway:
       Blends idle breathing sway with walk-bobbing driven by Humanoid.MoveDirection.
    3. Dual-Cone Lighting + Volumetric Beam:
       Narrow shadow-casting CoreSpotLight + wide soft SpillSpotLight + subtle
       high-transparency volumetric dust Beam (see FlashlightOptics.luau).
    4. Tactile Audio & Modular Flicker:
       Randomized toggle click PlaybackSpeed (0.95–1.05) and organic
       triggerFlicker(duration, intensity) callable by monsters or battery logic.
    5. Co-op Replication, Mobile Touch & Cosmetics:
       Fires ReplicatedStorage/FlashlightRemotes/ToggleState, supports
       GameHUD/FlashlightButton (or automatic mobile fallback), HapticService,
       and ShopCatalog cosmetic tints / battery gifts.
]]

local ContextActionService = game:GetService("ContextActionService")
local HapticService = game:GetService("HapticService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local FlashlightOptics = require(script.Parent.FlashlightOptics)
local FlashlightController = {}

-- ── Configuration (tweak all feel/visual values here) ────────────────────────
local CONFIG = {
	ToggleKey = Enum.KeyCode.F,
	GamepadToggleKey = Enum.KeyCode.ButtonY,
	LagStiffness = 12, -- Lower = heavier drag, Higher = snappier aim
	IdleSwaySpeed = 1.6,
	IdleSwayAmount = 0.025,
	WalkBobSpeed = 9.0,
	WalkBobAmount = 0.06,
	CoreAngle = 42,
	CoreBrightness = 3.5,
	CoreRange = 45,
	CoreColor = Color3.fromRGB(255, 248, 235),
	SpillAngle = 95,
	SpillBrightness = 0.75,
	SpillRange = 26,
	SpillColor = Color3.fromRGB(235, 240, 255),
	BeamLength = 14,
	BeamWidth0 = 0.35,
	BeamWidth1 = 5.5,
	MAX_BATTERY = 100,
	DRAIN_RATE_PER_SEC = 0.5, -- ~200 s runtime
	LOW_BATTERY_THRESHOLD = 15,
	TELEPORT_SNAP_DISTANCE = 25,
}

local ACTION_NAME = "ToggleFlashlight"
local RENDER_STEP = "AimFlashlight"

-- ── State ───────────────────────────────────────────────────────────────────
local player = Players.LocalPlayer

local isOn = false
local battery = CONFIG.MAX_BATTERY
local isFlickering = false
local flickerMultiplier = 1
local flickerToken = 0

local emitterPart: Part? = nil
local coreLight: SpotLight? = nil
local spillLight: SpotLight? = nil
local dustBeam: Beam? = nil
local clickSound: Sound? = nil

local currentCFrame = CFrame.new()
local swayTime = 0
local walkBlend = 0

-- ── Helpers ─────────────────────────────────────────────────────────────────
local function hapticPulse()
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

local function createFlashlightEmitter(): (Part, SpotLight, SpotLight, Beam, Sound)
	local emitter = Instance.new("Part")
	emitter.Name = "FlashlightEmitter"
	emitter.Size = Vector3.new(0.2, 0.2, 0.2)
	emitter.Transparency = 1
	emitter.Anchored = true
	emitter.CanCollide = false
	emitter.CanQuery = false
	emitter.CanTouch = false
	emitter.CastShadow = false

	local camera = Workspace.CurrentCamera
	if camera then
		currentCFrame = camera.CFrame * CFrame.new(0, 0, -0.5)
		emitter.CFrame = currentCFrame
	end
	emitter.Parent = Workspace

	local core, spill, beam = FlashlightOptics.localBeam(emitter, CONFIG)

	-- Optional pre-authored Sound child named "ClickSound" inside this script, or fallback SFX
	local existingClick = script:FindFirstChild("ClickSound")
	local sfx: Sound
	if existingClick and existingClick:IsA("Sound") then
		sfx = existingClick
	else
		sfx = Instance.new("Sound")
		sfx.Name = "ClickSound"
		sfx.SoundId = "rbxasset://sounds/electronicpingshort.wav"
		sfx.Volume = 0.45
		sfx.Parent = emitter
	end

	return emitter, core, spill, beam, sfx
end

local function ensureTouchButton()
	local hud = player.PlayerGui:FindFirstChild("GameHUD")
	if not hud and StarterGui:FindFirstChild("GameHUD") then
		hud = player.PlayerGui:WaitForChild("GameHUD", 5)
	end
	local authored = hud and hud:FindFirstChild("FlashlightButton")
	if authored and authored:IsA("GuiButton") then
		authored.Activated:Connect(function()
			FlashlightController.toggle()
		end)
		return
	end

	if not UserInputService.TouchEnabled then
		return
	end

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
	if coreLight then
		coreLight.Enabled = state
	end
	if spillLight then
		spillLight.Enabled = state
	end
	if dustBeam then
		dustBeam.Enabled = state
	end
end

function FlashlightController.setFlashlightState(state: boolean)
	local targetState = battery > 0 and state
	if targetState == isOn then
		return
	end
	isOn = targetState
	FlashlightController.setLights(isOn)

	if clickSound then
		clickSound.PlaybackSpeed = math.random(95, 105) / 100
		clickSound:Play()
	end

	local remotes = ReplicatedStorage:FindFirstChild("FlashlightRemotes")
	if remotes then
		local ev = remotes:FindFirstChild("ToggleState") :: RemoteEvent?
		if ev then
			ev:FireServer(isOn)
		end
	end
end

function FlashlightController.toggle()
	FlashlightController.setFlashlightState(not isOn)
end

-- Modular organic bulb flicker (callable by entities, anomalies, or low battery)
function FlashlightController.triggerFlicker(duration: number, intensity: number)
	if not isOn then
		return
	end
	flickerToken += 1
	local token = flickerToken
	isFlickering = true
	hapticPulse()

	task.spawn(function()
		local elapsed = 0
		while elapsed < duration and isOn and token == flickerToken do
			local dt = task.wait()
			elapsed += dt
			local targetMult = math.max(0.05, 1 - (math.random() * intensity))
			flickerMultiplier += (targetMult - flickerMultiplier) * 0.35
		end
		if token == flickerToken then
			flickerMultiplier = 1
			isFlickering = false
		end
	end)
end

-- Backwards-compatible alias for NPCManager / FlickerRequest callers
function FlashlightController.triggerAnomalyFlicker(duration: number, intensity: number)
	FlashlightController.triggerFlicker(duration, intensity)
end

function FlashlightController.getBattery(): number
	return battery
end

function FlashlightController.recharge(amount: number)
	battery = math.clamp(battery + amount, 0, CONFIG.MAX_BATTERY)
end

-- ── Initialisation ──────────────────────────────────────────────────────────
function FlashlightController.init()
	Workspace:GetAttributeChangedSignal("ExpeditionNumber"):Connect(function()
		battery = CONFIG.MAX_BATTERY
		flickerMultiplier = 1
		if not isOn then
			FlashlightController.toggle()
		end
	end)

	local emitter, core, spill, beam, sfx = createFlashlightEmitter()
	emitterPart = emitter
	coreLight = core
	spillLight = spill
	dustBeam = beam
	clickSound = sfx

	-- ContextActionService binding (keyboard F + gamepad ButtonY)
	ContextActionService:BindAction(
		ACTION_NAME,
		function(_name: string, state: Enum.UserInputState, _input: InputObject)
			if state == Enum.UserInputState.Begin then
				FlashlightController.toggle()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		CONFIG.ToggleKey,
		CONFIG.GamepadToggleKey
	)

	ensureTouchButton()

	-- Wire entity flicker requests, cosmetic tints, and battery gifts
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("FlashlightRemotes", 10)
		if remotes then
			local flickerEv = remotes:WaitForChild("FlickerRequest", 10) :: RemoteEvent?
			if flickerEv then
				flickerEv.OnClientEvent:Connect(function(dur: number, intensity: number)
					FlashlightController.triggerFlicker(dur, intensity)
				end)
			end
		end

		local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")
		local catalogMod = sharedFolder and sharedFolder:FindFirstChild("ShopCatalog")
		if catalogMod and catalogMod:IsA("ModuleScript") then
			local catalog = require(catalogMod) :: { Tints: { [string]: { hotspotColor: Color3, spillColor: Color3 } } }
			local function applyTint()
				local tintId = player:GetAttribute("FlashlightTint")
				if tintId == "StandardHalogen" then
					FlashlightOptics.setTint(coreLight, spillLight, dustBeam, CONFIG.CoreColor, CONFIG.SpillColor)
					return
				end
				local tint = if typeof(tintId) == "string" then catalog.Tints[tintId] else nil
				if tint then
					FlashlightOptics.setTint(coreLight, spillLight, dustBeam, tint.hotspotColor, tint.spillColor)
				end
			end
			player:GetAttributeChangedSignal("FlashlightTint"):Connect(applyTint)
			applyTint()
		end

		local shopRemotes = ReplicatedStorage:WaitForChild("ShopRemotes", 10)
		if shopRemotes then
			local giftEv = shopRemotes:WaitForChild("BatteryGiftReceived", 10) :: RemoteEvent?
			if giftEv then
				giftEv.OnClientEvent:Connect(function(amount: number)
					FlashlightController.recharge(amount)
				end)
			end
		end
	end)

	-- Frame-rate-independent smooth camera tracking + layered sway + battery/flicker
	RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		swayTime += dt

		local camera = Workspace.CurrentCamera
		if camera and emitterPart then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local isMoving = humanoid ~= nil
				and humanoid.MoveDirection.Magnitude > 0.1
				and humanoid.FloorMaterial ~= Enum.Material.Air

			local targetWalkBlend = if isMoving then 1 else 0
			walkBlend += (targetWalkBlend - walkBlend) * math.min(1, dt * 8)

			local idleX = math.cos(swayTime * CONFIG.IdleSwaySpeed) * CONFIG.IdleSwayAmount
			local idleY = math.sin(swayTime * CONFIG.IdleSwaySpeed * 2) * CONFIG.IdleSwayAmount

			local walkX = math.cos(swayTime * CONFIG.WalkBobSpeed) * CONFIG.WalkBobAmount * walkBlend
			local walkY = math.abs(math.sin(swayTime * CONFIG.WalkBobSpeed)) * -CONFIG.WalkBobAmount * walkBlend

			local swayOffset = CFrame.new(idleX + walkX, idleY + walkY, -0.5)
			local targetCFrame = camera.CFrame * swayOffset

			if (currentCFrame.Position - targetCFrame.Position).Magnitude > CONFIG.TELEPORT_SNAP_DISTANCE then
				currentCFrame = targetCFrame
			else
				local alpha = 1 - math.exp(-CONFIG.LagStiffness * dt)
				currentCFrame = currentCFrame:Lerp(targetCFrame, alpha)
			end

			emitterPart.CFrame = currentCFrame
		end

		if isOn then
			if not isFlickering then
				battery = math.clamp(battery - CONFIG.DRAIN_RATE_PER_SEC * dt, 0, CONFIG.MAX_BATTERY)
				if battery <= 0 then
					FlashlightController.setFlashlightState(false)
					return
				elseif battery <= CONFIG.LOW_BATTERY_THRESHOLD and math.random() < dt * 0.45 then
					FlashlightController.triggerFlicker(0.35, 0.55)
				end
			end

			if coreLight then
				coreLight.Brightness = CONFIG.CoreBrightness * flickerMultiplier
			end
			if spillLight then
				spillLight.Brightness = CONFIG.SpillBrightness * flickerMultiplier
			end
		end
	end)

	print("[FlashlightController] Initialised. Smooth camera tracking + dual-cone + volumetric beam.")
end

function FlashlightController.destroy()
	ContextActionService:UnbindAction(ACTION_NAME)
	RunService:UnbindFromRenderStep(RENDER_STEP)
	if emitterPart then
		emitterPart:Destroy()
		emitterPart = nil
		coreLight = nil
		spillLight = nil
		dustBeam = nil
		clickSound = nil
	end
end

return FlashlightController
