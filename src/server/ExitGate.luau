--!strict
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ObjectivePickups = require(script.Parent.ObjectivePickups)

local ExitGate = {}

function ExitGate.install(
	lastRoom: Model,
	remotes: Folder,
	eligible: (Player) -> boolean,
	survivors: () -> number,
	escape: () -> ()
)
	local exit = lastRoom:FindFirstChild("Exit") :: BasePart
	local owned: { Instance } = {}
	local connections: { RBXScriptConnection } = {}
	local prompts: { ProximityPrompt } = {}
	local holders: { [number]: Player? } = {}
	local completed: { [number]: boolean } = {}
	local since: number? = nil
	local open = false
	local ready = false
	local door = Workspace:FindFirstChild("ExitDoor")
	local beacon: Part? = nil
	local beaconLight: PointLight? = nil
	if not door then
		-- Build an authored-looking extraction bulkhead directly at lastRoom.Exit
		local bulkhead = Instance.new("Model")
		bulkhead.Name = "ExitDoor"
		local frameCF = exit.CFrame

		local function bPart(
			name: string,
			size: Vector3,
			cf: CFrame,
			color: Color3,
			mat: Enum.Material,
			collide: boolean
		): Part
			local p = Instance.new("Part")
			p.Name = name
			p.Size = size
			p.CFrame = cf
			p.Color = color
			p.Material = mat
			p.Anchored = true
			p.CanCollide = collide
			p.CanQuery = collide
			p.CanTouch = false
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			p.Parent = bulkhead
			return p
		end

		local blastLeaf = bPart(
			"BlastLeaf",
			Vector3.new(6.8, 7.6, 0.6),
			frameCF * CFrame.new(0, 0.3, 0),
			Color3.fromRGB(48, 54, 52),
			Enum.Material.DiamondPlate,
			true
		)
		bPart(
			"FrameLeft",
			Vector3.new(0.9, 8.4, 1.2),
			frameCF * CFrame.new(-3.8, 0.5, 0),
			Color3.fromRGB(64, 52, 44),
			Enum.Material.CorrodedMetal,
			true
		)
		bPart(
			"FrameRight",
			Vector3.new(0.9, 8.4, 1.2),
			frameCF * CFrame.new(3.8, 0.5, 0),
			Color3.fromRGB(64, 52, 44),
			Enum.Material.CorrodedMetal,
			true
		)
		bPart(
			"FrameTop",
			Vector3.new(8.5, 0.9, 1.2),
			frameCF * CFrame.new(0, 4.4, 0),
			Color3.fromRGB(64, 52, 44),
			Enum.Material.CorrodedMetal,
			true
		)
		local bLightPart = bPart(
			"StatusBeacon",
			Vector3.new(0.8, 0.4, 0.4),
			frameCF * CFrame.new(0, 3.8, 0.7),
			Color3.fromRGB(205, 58, 48),
			Enum.Material.Neon,
			false
		)
		local bl = Instance.new("PointLight")
		bl.Color = Color3.fromRGB(205, 58, 48)
		bl.Range = 14
		bl.Brightness = 1.1
		bl.Shadows = false
		bl.Parent = bLightPart
		beacon = bLightPart
		beaconLight = bl

		bulkhead.PrimaryPart = blastLeaf
		bulkhead.Parent = Workspace
		door = bulkhead
		table.insert(owned, bulkhead)
	end
	local leaves: { [BasePart]: { collide: boolean, transparency: number } } = {}
	local function remember(part: BasePart)
		leaves[part] = { collide = part.CanCollide, transparency = part.Transparency }
	end
	if door then
		if door:IsA("BasePart") then
			remember(door)
		end
		local leaf = door:FindFirstChild("BlastLeaf")
		if leaf and leaf:IsA("BasePart") then
			remember(leaf)
		elseif not leaf then
			for _, part in door:GetDescendants() do
				if part:IsA("BasePart") then
					remember(part)
				end
			end
		end
	end
	local extract = Instance.new("ProximityPrompt")
	extract.Name = "EscapePrompt"
	extract.ActionText = "Escape with squad"
	extract.ObjectText = "Extraction"
	extract.RequiresLineOfSight = false
	extract.Enabled = false
	extract.Parent = if door and door:IsA("BasePart")
		then door
		elseif door and door:IsA("Model") and door.PrimaryPart then door.PrimaryPart
		else exit
	local extractionPart = extract.Parent :: BasePart
	table.insert(owned, extract)
	table.insert(
		connections,
		extract.Triggered:Connect(function(player: Player)
			if
				open
				and eligible(player)
				and ObjectivePickups.inReach(player, extractionPart, extract.MaxActivationDistance)
			then
				escape()
			end
		end)
	)

	local function clear(index: number, player: Player)
		if holders[index] == player then
			holders[index] = nil
			completed[index] = nil
			since = nil
		end
	end
	local function update()
		if open or not ready then
			return
		end
		for i, player in holders do
			if not player then
				continue
			end
			local p = prompts[i]
			local part = p.Parent
			if
				not part
				or not part:IsA("BasePart")
				or not p.Enabled
				or not eligible(player)
				or not ObjectivePickups.inReach(player, part, p.MaxActivationDistance)
			then
				clear(i, player)
			end
		end
		local a, b = holders[1], holders[2]
		local enough = if survivors() == 1 then (a ~= nil or b ~= nil) else (a ~= nil and b ~= nil and a ~= b)
		if not enough then
			since = nil
			return
		end
		local now = os.clock()
		local start = since or now
		since = start
		local confirmed = if survivors() == 1 then completed[1] or completed[2] else completed[1] and completed[2]
		if not confirmed or now - start < 3 then
			return
		end
		open = true
		for _, p in prompts do
			p.Enabled = false
		end
		for part in leaves do
			part.CanCollide = false
			part.Transparency = 0.85
		end
		if beacon then
			beacon.Color = Color3.fromRGB(82, 232, 128)
		end
		if beaconLight then
			beaconLight.Color = Color3.fromRGB(82, 232, 128)
		end
		remotes:SetAttribute("ExitOpen", true)
		local doorEvent = remotes:FindFirstChild("DoorUnlocked") :: RemoteEvent
		doorEvent:FireAllClients("ExitDoor")
		extract.Enabled = true
	end
	for index, name in { "ExitLever_A", "ExitLever_B" } do
		local part = Workspace:FindFirstChild(name)
		if not part then
			local sideOffset = if index == 1 then -4.2 else 4.2
			local baseCF = exit.CFrame * CFrame.new(sideOffset, -exit.Size.Y / 2 + 2.0, 2.2)

			local hook = Instance.new("Part")
			hook.Name = name
			hook.Anchored = true
			hook.CanCollide = true
			hook.Size = Vector3.new(1.0, 4.0, 1.0)
			hook.Material = Enum.Material.CorrodedMetal
			hook.Color = Color3.fromRGB(58, 62, 60)
			hook.CFrame = baseCF
			hook.Parent = Workspace

			local handle = Instance.new("Part")
			handle.Name = "LeverHandle"
			handle.Anchored = true
			handle.CanCollide = false
			handle.Size = Vector3.new(0.22, 1.4, 0.22)
			handle.Material = Enum.Material.Metal
			handle.Color = Color3.fromRGB(190, 140, 56)
			handle.CFrame = baseCF * CFrame.new(0, 0.8, 0.55) * CFrame.Angles(0.45, 0, 0)
			handle.Parent = hook

			local lamp = Instance.new("Part")
			lamp.Name = "LeverLamp"
			lamp.Anchored = true
			lamp.CanCollide = false
			lamp.Size = Vector3.new(0.4, 0.25, 0.2)
			lamp.Material = Enum.Material.Neon
			lamp.Color = Color3.fromRGB(228, 162, 64)
			lamp.CFrame = baseCF * CFrame.new(0, 1.65, 0.48)
			lamp.Parent = hook

			part = hook
			table.insert(owned, hook)
		end
		if not part:IsA("BasePart") then
			warn("[ExitGate] Expected BasePart: " .. name)
			continue
		end
		local lever = part
		local existing = lever:FindFirstChild("Prompt")
		if existing and not existing:IsA("ProximityPrompt") then
			warn("[ExitGate] Expected ProximityPrompt: " .. name .. ".Prompt")
			continue
		end
		local prompt = if existing and existing:IsA("ProximityPrompt")
			then existing
			else Instance.new("ProximityPrompt")
		if not existing then
			table.insert(owned, prompt)
		end
		prompt.Name = "Prompt"
		prompt.ActionText = "Hold Lever"
		prompt.ObjectText = name
		prompt.HoldDuration = 3
		prompt.RequiresLineOfSight = true
		prompt.Enabled = false
		prompt.Parent = lever
		prompts[index] = prompt
		table.insert(
			connections,
			prompt.PromptButtonHoldBegan:Connect(function(player: Player)
				if
					not ready
					or open
					or holders[index]
					or holders[3 - index] == player
					or not eligible(player)
					or not ObjectivePickups.inReach(player, lever, prompt.MaxActivationDistance)
				then
					return
				end
				holders[index] = player
				update()
			end)
		)
		-- HoldEnded also fires when the native progress ring fills. TriggerEnded
		-- is the release after a completed hold; an early cancellation clears immediately.

		table.insert(
			connections,
			prompt.Triggered:Connect(function(player: Player)
				if holders[index] == player then
					completed[index] = true
					update()
				end
			end)
		)
		table.insert(
			connections,
			prompt.PromptButtonHoldEnded:Connect(function(player: Player)
				-- Roblox sends HoldEnded immediately before Triggered on completion.
				-- A cancelled hold never receives Triggered and cannot unlock.
				task.delay(0.1, function()
					if not completed[index] then
						clear(index, player)
					end
				end)
			end)
		)
		table.insert(
			connections,
			prompt.TriggerEnded:Connect(function(player: Player)
				clear(index, player)
			end)
		)
	end
	table.insert(connections, RunService.Heartbeat:Connect(update))
	return {
		arm = function()
			ready = true
			for _, p in prompts do
				p.Enabled = true
			end
			remotes:SetAttribute("ObjectivesComplete", true)
		end,
		close = function()
			ready = false
			open = false
			extract.Enabled = false
			for _, p in prompts do
				p.Enabled = false
			end
			table.clear(holders)
		end,
		destroy = function()
			for _, conn in connections do
				conn:Disconnect()
			end
			for part, state in leaves do
				part.CanCollide = state.collide
				part.Transparency = state.transparency
			end
			for _, item in owned do
				item:Destroy()
			end
		end,
	}
end

return ExitGate
