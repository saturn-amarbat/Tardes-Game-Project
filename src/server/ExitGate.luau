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
	local leaves: { [BasePart]: { collide: boolean, transparency: number } } = {}
	local function remember(part: BasePart)
		leaves[part] = { collide = part.CanCollide, transparency = part.Transparency }
	end
	if door then
		if door:IsA("BasePart") then
			remember(door)
		end
		for _, part in door:GetDescendants() do
			if part:IsA("BasePart") then
				remember(part)
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
			part.Transparency = 1
		end
		remotes:SetAttribute("ExitOpen", true)
		local doorEvent = remotes:FindFirstChild("DoorUnlocked") :: RemoteEvent
		doorEvent:FireAllClients("ExitDoor")
		extract.Enabled = true
	end
	for index, name in { "ExitLever_A", "ExitLever_B" } do
		local part = Workspace:FindFirstChild(name)
		if not part then
			local hook = Instance.new("Part")
			hook.Name = name
			hook.Anchored = true
			hook.CanCollide = false
			hook.Size = Vector3.new(0.8, 2, 0.8)
			hook.Material = Enum.Material.Neon
			hook.Color = Color3.fromRGB(180, 130, 54)
			hook.CFrame = exit.CFrame * CFrame.new(if index == 1 then -2 else 2, -exit.Size.Y / 2 + 2, 0)
			hook.Parent = Workspace
			part = hook
			table.insert(owned, hook)
			warn("[ExitGate] Runtime placeholder for Workspace." .. name)
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
