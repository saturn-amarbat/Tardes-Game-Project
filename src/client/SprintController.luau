--!strict
--[[
  SprintController  –  Horror-paced stamina & sprint controller.

  • WalkSpeed = 14 (base) / 22 (sprint, outruns MainNPC_Stalker's 20 chase speed).
  • Drains 22 stamina/sec, regenerates 15/sec (2x faster inside ToadMakerSafeRoom).
  • Subtle FOV kick (70 -> 76) on sprint for responsive chase momentum.
  • LeftShift / Gamepad ButtonL3 / touch button when TouchEnabled.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local SprintController = {}

local CONFIG = {
	BaseWalkSpeed = 14,
	SprintWalkSpeed = 22,
	BaseFOV = 70,
	SprintFOV = 76,
	MaxStamina = 100,
	DrainPerSec = 22,
	RegenPerSec = 15,
	RegenDelay = 0.85,
	SprintKey = Enum.KeyCode.LeftShift,
	GamepadSprintKey = Enum.KeyCode.ButtonL3,
}

local player = Players.LocalPlayer
local stamina = CONFIG.MaxStamina
local wantSprint = false
local isSprinting = false
local exhausted = false
local lastSprintStop = 0

function SprintController.getStamina(): number
	return stamina
end

function SprintController.isSprinting(): boolean
	return isSprinting
end

local function createTouchSprintButton()
	if not UserInputService.TouchEnabled then
		return
	end
	local pg = player:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild("SprintHUD_Touch")
	if old then
		old:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "SprintHUD_Touch"
	gui.ResetOnSpawn = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = pg

	-- Positioned cleanly above StarterGui/GameHUD/FlashlightButton
	local btn = Instance.new("TextButton")
	btn.Name = "SprintButton"
	btn.Size = UDim2.fromOffset(76, 42)
	btn.Position = UDim2.new(1, -108, 1, -162)
	btn.AnchorPoint = Vector2.new(0, 0)
	btn.BackgroundColor3 = Color3.fromRGB(26, 30, 28)
	btn.BackgroundTransparency = 0.25
	btn.Text = "RUN"
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 13
	btn.TextColor3 = Color3.fromRGB(240, 232, 210)
	btn.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn

	local _ = StarterGui
	btn.MouseButton1Down:Connect(function()
		wantSprint = true
	end)
	btn.MouseButton1Up:Connect(function()
		wantSprint = false
	end)
	btn.TouchLongPress:Connect(function(_, state)
		if state == Enum.UserInputState.End then
			wantSprint = false
		end
	end)
end

function SprintController.init()
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if input.KeyCode == CONFIG.SprintKey or input.KeyCode == CONFIG.GamepadSprintKey then
			wantSprint = true
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.KeyCode == CONFIG.SprintKey or input.KeyCode == CONFIG.GamepadSprintKey then
			wantSprint = false
		end
	end)

	Workspace:GetAttributeChangedSignal("ExpeditionNumber"):Connect(function()
		stamina = CONFIG.MaxStamina
		exhausted = false
		wantSprint = false
		isSprinting = false
	end)

	createTouchSprintButton()

	RunService.RenderStepped:Connect(function(dt: number)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local inDungeon = player:GetAttribute("DungeonEntered") == true
		local sittingOut = player:GetAttribute("SittingOut") == true

		if not humanoid or humanoid.Health <= 0 or sittingOut then
			isSprinting = false
			return
		end

		local moving = humanoid.MoveDirection.Magnitude > 0.1
		local canSprint = inDungeon and not exhausted and stamina > 1
		local activeSprint = wantSprint and moving and canSprint

		if activeSprint then
			isSprinting = true
			stamina = math.max(0, stamina - CONFIG.DrainPerSec * dt)
			lastSprintStop = os.clock()
			if stamina <= 0 then
				exhausted = true
				isSprinting = false
			end
		else
			if isSprinting then
				lastSprintStop = os.clock()
			end
			isSprinting = false
			if os.clock() - lastSprintStop >= CONFIG.RegenDelay then
				local safeBoost = if player:GetAttribute("InSafeRoom") == true then 2 else 1
				stamina = math.min(CONFIG.MaxStamina, stamina + CONFIG.RegenPerSec * safeBoost * dt)
				if exhausted and stamina >= 25 then
					exhausted = false
				end
			end
		end

		humanoid.WalkSpeed = if isSprinting
			then CONFIG.SprintWalkSpeed
			elseif inDungeon then CONFIG.BaseWalkSpeed
			else 16

		local camera = Workspace.CurrentCamera
		if camera then
			local targetFOV = if isSprinting then CONFIG.SprintFOV else CONFIG.BaseFOV
			camera.FieldOfView += (targetFOV - camera.FieldOfView) * math.min(1, dt * 8)
		end
	end)

	print("[SprintController] Ready (LeftShift / ButtonL3).")
end

return SprintController
