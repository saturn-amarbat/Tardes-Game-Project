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

local HapticService = game:GetService("HapticService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local FlashlightOptics = require(script.Parent.FlashlightOptics)
local HUDIcons = require(script.Parent.HUDIcons)
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
	FillBrightness = 0.25,
	FillRange = 10,
	BeamLength = 12,
	BeamWidth0 = 0.16,
	BeamWidth1 = 3.2,
	FirstPersonThreshold = 2.4,
	MAX_BATTERY = 100,
	DRAIN_RATE_PER_SEC = 0.5, -- ~200 s runtime
	LOW_BATTERY_THRESHOLD = 15,
	TELEPORT_SNAP_DISTANCE = 25,
}

local RENDER_STEP = "AimFlashlight"
local inputConn: RBXScriptConnection? = nil

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
local fillLight: PointLight? = nil
local dustBeam: Beam? = nil
local clickSound: Sound? = nil
local syncDockVisual: ((boolean) -> ())? = nil

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

local function cleanupStaleFlashlights()
	for _, container in { Workspace, Workspace.CurrentCamera } do
		if container then
			for _, child in container:GetChildren() do
				if child.Name == "FlashlightEmitter" or child.Name == "ClientFlashlightRig" then
					child:Destroy()
				end
			end
		end
	end
end

local function createFlashlightEmitter(): (Part, SpotLight, SpotLight, PointLight, Beam, Sound)
	cleanupStaleFlashlights()

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
	emitter.Parent = camera or Workspace

	local core, spill, fill, beam = FlashlightOptics.localBeam(emitter, CONFIG)

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

	return emitter, core, spill, fill, beam, sfx
end

local function styleFlashlightDock(btn: GuiButton)
	btn.AnchorPoint = Vector2.new(1, 1)
	btn.Size = UDim2.fromOffset(56, 56)
	btn.Position = UDim2.new(1, -20, 1, -20)
	btn.BackgroundColor3 = Color3.fromRGB(14, 17, 16)
	btn.BackgroundTransparency = 0.14
	if btn:IsA("TextButton") then
		btn.Text = ""
	end

	for _, c in btn:GetChildren() do
		if c:IsA("GuiObject") or c:IsA("UICorner") or c:IsA("UIStroke") then
			c:Destroy()
		end
	end

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Color = Color3.fromRGB(68, 76, 72)
	stroke.Transparency = 0.25
	stroke.Parent = btn

	local icon, rays = HUDIcons.flashlight(btn, Color3.fromRGB(228, 198, 130), 26)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.48)

	if not UserInputService.TouchEnabled then
		local keycap = Instance.new("TextLabel")
		keycap.AnchorPoint = Vector2.new(0.5, 1)
		keycap.Position = UDim2.new(0.5, 0, 1, -3)
		keycap.Size = UDim2.fromOffset(18, 13)
		keycap.BackgroundColor3 = Color3.fromRGB(24, 28, 26)
		keycap.Font = Enum.Font.GothamBold
		keycap.TextSize = 9
		keycap.TextColor3 = Color3.fromRGB(210, 206, 194)
		keycap.Text = "F"
		keycap.Parent = btn
		local kc = Instance.new("UICorner")
		kc.CornerRadius = UDim.new(0, 3)
		kc.Parent = keycap
	end

	syncDockVisual = function(enabled: boolean)
		stroke.Color = if enabled then Color3.fromRGB(228, 198, 130) else Color3.fromRGB(68, 76, 72)
		stroke.Transparency = if enabled then 0.1 else 0.4
		for _, r in rays do
			r.Visible = enabled
		end
	end
	syncDockVisual(isOn)
end

local function ensureTouchButton()
	local hud = player.PlayerGui:FindFirstChild("GameHUD")
	if not hud and StarterGui:FindFirstChild("GameHUD") then
		hud = player.PlayerGui:WaitForChild("GameHUD", 5)
	end
	local authored = hud and hud:FindFirstChild("FlashlightButton")
	if authored and authored:IsA("GuiButton") then
		styleFlashlightDock(authored)
		authored.Activated:Connect(function()
			FlashlightController.toggle()
		end)
		return
	end

	-- Clean up duplicate dock if re-initialized
	local oldFallback = player.PlayerGui:FindFirstChild("FlashlightHUD_Fallback")
	if oldFallback then
		oldFallback:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "FlashlightHUD_Fallback"
	gui.ResetOnSpawn = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player.PlayerGui

	local btn = Instance.new("TextButton")
	btn.Name = "FlashlightButton"
	btn.Parent = gui
	styleFlashlightDock(btn)

	btn.Activated:Connect(function()
		FlashlightController.toggle()
		if UserInputService.TouchEnabled then
			hapticPulse()
		end
	end)
end

-- ── Core API ─────────────────────────────────────────────────────────────────
function FlashlightController.setLights(state: boolean, showBeam: boolean?)
	if coreLight then
		coreLight.Enabled = state
	end
	if spillLight then
		spillLight.Enabled = state
	end
	if fillLight then
		fillLight.Enabled = state
	end
	if dustBeam then
		dustBeam.Enabled = state and (showBeam == true)
	end
end

function FlashlightController.setFlashlightState(state: boolean)
	local targetState = battery > 0 and state
	if targetState == isOn then
		return
	end
	isOn = targetState
	FlashlightController.setLights(isOn)
	if syncDockVisual then
		syncDockVisual(isOn)
	end

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

function FlashlightController.drainBattery(amount: number)
	battery = math.clamp(battery - amount, 0, CONFIG.MAX_BATTERY)
	if battery <= 0 and isOn then
		FlashlightController.setFlashlightState(false)
	end
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

	local emitter, core, spill, fill, beam, sfx = createFlashlightEmitter()
	emitterPart = emitter
	coreLight = core
	spillLight = spill
	fillLight = fill
	dustBeam = beam
	clickSound = sfx

	-- Input handling via UserInputService (works cleanly even while holding Shift / Shift-Lock)
	if inputConn then
		inputConn:Disconnect()
	end
	inputConn = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if input.KeyCode == CONFIG.ToggleKey or input.KeyCode == CONFIG.GamepadToggleKey then
			FlashlightController.toggle()
		end
	end)

	ensureTouchButton()

	-- Wire entity flicker requests, cosmetic tints, and battery gifts
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("FlashlightRemotes", 10)
		if remotes then
			local flickerEv = remotes:WaitForChild("FlickerRequest", 10) :: RemoteEvent?
			if flickerEv then
				flickerEv.OnClientEvent:Connect(function(dur: number, intensity: number, drainAmount: number?)
					if typeof(drainAmount) == "number" and drainAmount > 0 then
						FlashlightController.drainBattery(drainAmount)
					end
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
					FlashlightOptics.setTint(
						coreLight,
						spillLight,
						fillLight,
						dustBeam,
						CONFIG.CoreColor,
						CONFIG.SpillColor
					)
					return
				end
				local tint = if typeof(tintId) == "string" then catalog.Tints[tintId] else nil
				if tint then
					FlashlightOptics.setTint(
						coreLight,
						spillLight,
						fillLight,
						dustBeam,
						tint.hotspotColor,
						tint.spillColor
					)
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

	-- Frame-rate-independent smooth camera tracking + wall-clip raycast + layered sway + battery/flicker
	local clipParams = RaycastParams.new()
	clipParams.FilterType = Enum.RaycastFilterType.Exclude
	clipParams.RespectCanCollide = true

	RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		swayTime += dt

		local camera = Workspace.CurrentCamera
		local inFirstPerson = true
		if camera and emitterPart then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local head = character and character:FindFirstChild("Head")
			local isMoving = humanoid ~= nil
				and humanoid.MoveDirection.Magnitude > 0.1
				and humanoid.FloorMaterial ~= Enum.Material.Air

			local targetWalkBlend = if isMoving then 1 else 0
			walkBlend += (targetWalkBlend - walkBlend) * math.min(1, dt * 8)

			local idleX = math.cos(swayTime * CONFIG.IdleSwaySpeed) * CONFIG.IdleSwayAmount
			local idleY = math.sin(swayTime * CONFIG.IdleSwaySpeed * 2) * CONFIG.IdleSwayAmount

			local walkX = math.cos(swayTime * CONFIG.WalkBobSpeed) * CONFIG.WalkBobAmount * walkBlend
			local walkY = math.abs(math.sin(swayTime * CONFIG.WalkBobSpeed)) * -CONFIG.WalkBobAmount * walkBlend

			local originCFrame = camera.CFrame
			local rayOrigin = originCFrame.Position
			local forwardOffset = -0.5

			if head and head:IsA("BasePart") then
				local camDist = (camera.CFrame.Position - head.Position).Magnitude
				if camDist >= CONFIG.FirstPersonThreshold then
					-- In 3rd-person, originate beam ahead of the player's head so hair/torso never cast starburst shadows
					inFirstPerson = false
					local aimPos = head.Position + camera.CFrame.LookVector * 1.45 - Vector3.new(0, 0.1, 0)
					originCFrame = CFrame.new(aimPos) * camera.CFrame.Rotation
					rayOrigin = head.Position
					forwardOffset = 0
				end
			end

			local swayOffset = CFrame.new(idleX + walkX, idleY + walkY, forwardOffset)
			local targetCFrame = originCFrame * swayOffset

			-- Prevent emitter from clipping into walls in Realistic/Future lighting
			local exclude: { Instance } = { emitterPart }
			if character then
				table.insert(exclude, character)
			end
			clipParams.FilterDescendantsInstances = exclude
			local delta = targetCFrame.Position - rayOrigin
			if delta.Magnitude > 0.01 then
				local hit = Workspace:Raycast(rayOrigin, delta, clipParams)
				if hit then
					local safePos = hit.Position - delta.Unit * 0.14
					targetCFrame = CFrame.new(safePos) * targetCFrame.Rotation
				end
			end

			if (currentCFrame.Position - targetCFrame.Position).Magnitude > CONFIG.TELEPORT_SNAP_DISTANCE then
				currentCFrame = targetCFrame
			else
				local alpha = 1 - math.exp(-CONFIG.LagStiffness * dt)
				currentCFrame = currentCFrame:Lerp(targetCFrame, alpha)
			end

			emitterPart.CFrame = currentCFrame
		end

		if dustBeam then
			dustBeam.Enabled = isOn and inFirstPerson
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
			if fillLight then
				fillLight.Brightness = CONFIG.FillBrightness * flickerMultiplier
			end
		end
	end)

	print("[FlashlightController] Initialised. Smooth camera tracking + dual-cone + volumetric beam.")
end

function FlashlightController.destroy()
	if inputConn then
		inputConn:Disconnect()
		inputConn = nil
	end
	RunService:UnbindFromRenderStep(RENDER_STEP)
	if emitterPart then
		emitterPart:Destroy()
		emitterPart = nil
		coreLight = nil
		spillLight = nil
		fillLight = nil
		dustBeam = nil
		clickSound = nil
	end
end

return FlashlightController
