--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Config = require(script.Parent.Config)
local Layout = require(script.Parent.Layout)

type Rider = {
	player: Player,
	character: Model,
	root: BasePart,
	destination: CFrame,
	anchored: boolean,
	streamed: boolean,
}
local SquadFall = {}
local remote = Instance.new("RemoteEvent")
remote.Name = "BunkerFall"
remote.Parent = ReplicatedStorage
local generation = 0
local busy = false

local function living(player: Player): (Model?, BasePart?)
	local char = player.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	if char and hum and hum.Health > 0 and root and root:IsA("BasePart") then
		return char, root
	end
	return nil, nil
end
local function valid(r: Rider): boolean
	local character, root = living(r.player)
	return r.player.Parent == Players and character == r.character and root == r.root
end

function SquadFall.attach(hatch: BasePart, lift: BasePart): () -> ()
	local layout = Layout.get()
	local landing = layout.landing
	local exitDoor = layout.rooms[10]:FindFirstChild("Exit") :: BasePart
	local returnPrompt = Instance.new("ProximityPrompt")
	returnPrompt.ActionText = "Continue to survey lift"
	returnPrompt.ObjectText = "Exit airlock"
	returnPrompt.RequiresLineOfSight = false
	returnPrompt.Parent = exitDoor
	local returning: { [Player]: boolean } = {}
	returnPrompt.Triggered:Connect(function(player)
		local char, root = living(player)
		if not char or not root or returning[player] or (root.Position - exitDoor.Position).Magnitude > 12 then
			return
		end
		returning[player] = true
		local probe = RaycastParams.new()
		probe.FilterType = Enum.RaycastFilterType.Include
		probe.FilterDescendantsInstances = { lift.Parent :: Instance }
		probe.RespectCanCollide = true
		local target = lift.Position + Vector3.new(0, 3, 5)
		local hit = Workspace:Raycast(target, -Vector3.yAxis * 12, probe)
		if hit and hit.Normal.Y > 0.8 then
			local pos = hit.Position + Vector3.yAxis * 3
			local ok = pcall(function()
				player:RequestStreamAroundAsync(pos, Config.StreamTimeout)
			end)
			if ok and living(player) == char and (root.Position - exitDoor.Position).Magnitude <= 12 then
				char:PivotTo(CFrame.new(pos))
			end
		end
		returning[player] = nil
	end)

	-- Keep the hatch solid throughout. The server moves the party exactly once
	-- at blackout; nobody enters a physical free-fall or blocks a late arrival.
	return function()
		if busy then
			return
		end
		local riders: { Rider } = {}
		for _, player in Players:GetPlayers() do
			local char, root = living(player)
			if char and root and not char:GetAttribute("BunkerLanded") then
				local i = #riders
				local spread =
					Vector3.new((i % 2 - 0.5) * 5, landing.Size.Y / 2 + 3.5, (math.floor(i / 2) % 2 - 0.5) * 5)
				table.insert(riders, {
					player = player,
					character = char,
					root = root,
					destination = landing.CFrame * CFrame.new(spread),
					anchored = root.Anchored,
					streamed = false,
				})
			end
		end
		if #riders == 0 then
			return
		end
		busy = true
		generation += 1
		local ticket = generation
		local deadline = time() + Config.StreamTimeout
		local finished = 0
		for _, r in riders do
			task.spawn(function()
				local ok = pcall(function()
					r.player:RequestStreamAroundAsync(r.destination.Position, Config.StreamTimeout)
				end)
				r.streamed = ok and time() < deadline
				finished += 1
			end)
		end
		while finished < #riders and time() < deadline do
			task.wait()
		end
		local duration = if Config.FallMode == "Skip" then 0 elseif Config.FallMode == "Short" then 0.4 else 1.7
		for _, r in riders do
			if valid(r) and not r.streamed then
				duration = 0
			end
		end
		local arrival = Workspace:GetServerTimeNow() + duration
		for _, r in riders do
			if valid(r) then
				r.root.Anchored = true
				r.root.AssemblyLinearVelocity = Vector3.zero
				r.root.AssemblyAngularVelocity = Vector3.zero
				remote:FireClient(r.player, "Begin", ticket, arrival, hatch.Position)
			end
		end
		if duration > 0 then
			task.wait(duration)
		end
		for _, r in riders do
			if valid(r) then
				r.character:PivotTo(r.destination)
				r.root.AssemblyLinearVelocity = Vector3.zero
				r.root.AssemblyAngularVelocity = Vector3.zero
				r.character:SetAttribute("BunkerLanded", true)
				r.root.Anchored = r.anchored
				-- While a slow client catches up, the server simulates the landing
				-- against its already-present floor. A stalled request cannot block the group.
				if not r.streamed and not r.anchored and r.root:CanSetNetworkOwnership() then
					r.root:SetNetworkOwner(nil)
					task.spawn(function()
						pcall(function()
							r.player:RequestStreamAroundAsync(r.destination.Position, 5)
						end)
						if valid(r) and r.root:CanSetNetworkOwnership() then
							r.root:SetNetworkOwnershipAuto()
						end
					end)
				end
			elseif r.root.Parent then
				r.root.Anchored = r.anchored
			end
			if r.player.Parent == Players then
				remote:FireClient(r.player, "Finish", ticket)
			end
		end
		busy = false
	end
end
return SquadFall
