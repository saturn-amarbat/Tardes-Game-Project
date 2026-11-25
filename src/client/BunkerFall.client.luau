--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("BunkerFall") :: RemoteEvent
local active = 0
local cleanup: (() -> ())? = nil
local function finish()
	if cleanup then
		cleanup()
		cleanup = nil
	end
end
player.CharacterRemoving:Connect(finish)
script.Destroying:Connect(finish)
remote.OnClientEvent:Connect(function(action: string, ticket: number, arrival: number?, hatch: Vector3?)
	if action == "Finish" then
		if ticket == active then
			finish()
		end
		return
	end
	if action ~= "Begin" or not arrival or not hatch then
		return
	end
	finish()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "BunkerFallOverlay"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.Parent = player:FindFirstChildOfClass("PlayerGui")
	local previous = camera.CameraType
	local previousCF = camera.CFrame
	local field = camera.FieldOfView
	local tweens: { Tween } = {}
	local function tween(target: Instance, seconds: number, props: { [string]: any })
		local t =
			TweenService:Create(target, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), props)
		table.insert(tweens, t)
		t:Play()
	end
	local veil = Instance.new("Frame")
	veil.BorderSizePixel = 0
	veil.BackgroundColor3 = Color3.new()
	veil.BackgroundTransparency = 1
	veil.Size = UDim2.fromScale(1, 1)
	veil.ZIndex = 3
	veil.Parent = gui
	for i = 0, 3 do
		local edge = Instance.new("Frame")
		edge.BackgroundColor3 = Color3.new()
		edge.BorderSizePixel = 0
		edge.Size = if i % 2 == 0 then UDim2.fromScale(0.28, 1) else UDim2.fromScale(1, 0.28)
		edge.Position = UDim2.fromScale(if i == 2 then 0.72 else 0, if i == 3 then 0.72 else 0)
		edge.Parent = gui
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = i * 90
		gradient.Transparency = NumberSequence.new(0.17, 1)
		gradient.Parent = edge
	end
	local wind = Instance.new("Sound")
	wind.SoundId = "rbxasset://sounds/action_falling.ogg"
	wind.Volume = 0
	wind.Looped = true
	wind.Parent = SoundService
	ContextActionService:BindActionAtPriority("BunkerFallLock", function()
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 100, table.unpack(Enum.PlayerActions:GetEnumItems()))
	active = ticket
	cleanup = function()
		active = 0
		ContextActionService:UnbindAction("BunkerFallLock")
		for _, t in tweens do
			t:Cancel()
		end
		camera.FieldOfView = field
		if previous == Enum.CameraType.Scriptable then
			camera.CFrame = previousCF
		end
		camera.CameraType = previous
		wind:Destroy()
		gui:Destroy()
	end
	local remaining = math.max(0, arrival - Workspace:GetServerTimeNow())
	camera.CameraType = Enum.CameraType.Scriptable
	if remaining > 0.05 then
		local eye = hatch + Vector3.new(0, 5, 0)
		camera.CFrame = CFrame.lookAt(eye, eye + Vector3.new(0, -1, -0.22))
		tween(
			camera,
			remaining,
			{ CFrame = camera.CFrame * CFrame.new(0, 0, -8) * CFrame.Angles(0, 0, 0.09), FieldOfView = field + 7 }
		)
		wind:Play()
		tween(wind, remaining * 0.7, { Volume = 0.6, PlaybackSpeed = 1.35 })
		task.delay(remaining * 0.65, function()
			if active == ticket then
				tween(veil, remaining * 0.25, { BackgroundTransparency = 0 })
			end
		end)
	else
		veil.BackgroundTransparency = 0
	end
	task.delay(remaining + 2, function()
		if active == ticket then
			finish()
		end
	end)
end)
