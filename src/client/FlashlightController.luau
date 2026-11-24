--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local FlashlightController = {}

-- Configuration
local CONFIG = {
	MAX_BATTERY = 100,
	DRAIN_RATE_PER_SEC = 0.5, -- Battery lasts ~200 seconds when on
	SPOT_BRIGHTNESS = 2.8,
	SPOT_RANGE = 60,
	SPOT_ANGLE = 48,
	AMBIENT_BRIGHTNESS = 0.45,
	AMBIENT_RANGE = 14,
	LIGHT_COLOR = Color3.fromRGB(245, 240, 220), -- Slightly warm incandescent beam
	TWEEN_ROTATION_SPEED = 18,
}

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local isEnabled = false
local battery = CONFIG.MAX_BATTERY
local isFlickering = false

-- Physical / visual light rig
local _lightModel: Model? = nil
local lightRoot: Part? = nil
local primarySpot: SpotLight? = nil
local fillPoint: PointLight? = nil
local toggleSound: Sound? = nil

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

	-- Primary crisp SpotLight (Slender-man narrow directional cone with shadows)
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

	-- Secondary ambient PointLight (Soft ambient fill for mobile / low graphics compatibility)
	local point = Instance.new("PointLight")
	point.Name = "AmbientFill"
	point.Range = CONFIG.AMBIENT_RANGE
	point.Brightness = CONFIG.AMBIENT_BRIGHTNESS
	point.Color = CONFIG.LIGHT_COLOR
	point.Shadows = false
	point.Enabled = false
	point.Parent = root

	-- Toggle SFX
	local sfx = Instance.new("Sound")
	sfx.Name = "ClickSound"
	sfx.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	sfx.Volume = 0.5
	sfx.Parent = root

	rig.Parent = Workspace.CurrentCamera
	return rig, root, spot, point, sfx
end

-- Teleport helper with StreamingEnabled safety
function FlashlightController.safeTeleport(targetCF: CFrame)
	local character = player.Character
	if not character then
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end

	-- Pre-stream region before teleporting to prevent void-falling
	task.spawn(function()
		player:RequestStreamAroundAsync(targetCF.Position)
		character:PivotTo(targetCF)
	end)
end

function FlashlightController.setLights(state: boolean)
	if not primarySpot or not fillPoint then
		return
	end
	primarySpot.Enabled = state
	fillPoint.Enabled = state
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

	-- Fire server replication event if available
	local remotes = ReplicatedStorage:FindFirstChild("FlashlightRemotes")
	if remotes then
		local updateRemote = remotes:FindFirstChild("ToggleState") :: RemoteEvent?
		if updateRemote then
			updateRemote:FireServer(isEnabled)
		end
	end
end

-- Hook for horror entities / anomalies to induce realistic flickering
function FlashlightController.triggerAnomalyFlicker(duration: number, intensity: number)
	if not isEnabled or isFlickering then
		return
	end
	isFlickering = true

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

function FlashlightController.init()
	local rig, root, spot, point, sfx = createFlashlightRig()
	_lightModel = rig
	lightRoot = root
	primarySpot = spot
	fillPoint = point
	toggleSound = sfx

	-- Keybind: 'F' or Gamepad ButtonY / ButtonL3 to toggle flashlight
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonY then
			FlashlightController.toggle()
		end
	end)

	-- Battery & Light Tracking Render Loop
	RunService.RenderStepped:Connect(function(dt: number)
		if not camera or not lightRoot then
			camera = Workspace.CurrentCamera
			return
		end

		-- Drain battery if turned on
		if isEnabled and not isFlickering then
			battery = math.clamp(battery - (CONFIG.DRAIN_RATE_PER_SEC * dt), 0, CONFIG.MAX_BATTERY)
			if battery <= 0 then
				FlashlightController.toggle()
			end
		end

		-- Camera tracking: Offset slightly below and to the right of camera for realistic shoulder perspective
		local camCF = camera.CFrame
		local targetCF = camCF * CFrame.new(0.6, -0.5, -0.2)

		-- Smoothly rotate towards camera look vector for tactile feel
		lightRoot.CFrame = lightRoot.CFrame:Lerp(targetCF, math.clamp(dt * CONFIG.TWEEN_ROTATION_SPEED, 0, 1))
	end)

	print("[FlashlightController] Initialized Slender-Man layered flashlight system.")
end

return FlashlightController
