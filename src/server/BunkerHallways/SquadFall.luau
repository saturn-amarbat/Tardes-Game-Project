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
local remoteInst = ReplicatedStorage:FindFirstChild("BunkerFall")
local remote: RemoteEvent
if remoteInst and remoteInst:IsA("RemoteEvent") then
	remote = remoteInst
else
	local created = Instance.new("RemoteEvent")
	created.Name = "BunkerFall"
	created.Parent = ReplicatedStorage
	remote = created
end
local generation = 0
local busy = false

local function living(player: Player): (Model?, BasePart?)
	if Workspace:GetAttribute("LobbyModeActive") == true and player:GetAttribute("InGame") ~= true then
		return nil, nil
	end
	if player:GetAttribute("SittingOut") or player:GetAttribute("DungeonEntered") then
		return nil, nil
	end
	local char = player.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	if char and hum and hum.Health > 0 and root and root:IsA("BasePart") then
		return char, root
	end
	return nil, nil
end

local function valid(r: Rider, expedition: any): boolean
	local character, root = living(r.player)
	return Workspace:GetAttribute("ExpeditionNumber") == expedition
		and r.player.Parent == Players
		and character == r.character
		and root == r.root
end

-- Resolves the entry doorway floor inside the active R.E.P.O.-style GeneratedDungeon.
local function findMazeLandingCF(): CFrame?
	local deadline = os.clock() + 4
	while os.clock() < deadline do
		local dungeon = Workspace:FindFirstChild("GeneratedDungeon")
		if dungeon then
			local first: Model? = nil
			for _, room in dungeon:GetChildren() do
				if room:IsA("Model") and string.match(room.Name, "^Room_01_") then
					first = room
					break
				end
			end
			if first then
				local entrance = first:FindFirstChild("Entrance")
				if entrance and entrance:IsA("BasePart") then
					local ray = RaycastParams.new()
					ray.FilterType = Enum.RaycastFilterType.Include
					ray.FilterDescendantsInstances = { first }
					ray.RespectCanCollide = true
					for _, dir in { 1, -1 } do
						local probe = entrance.Position + entrance.CFrame.LookVector * (4 * dir)
						local hit = Workspace:Raycast(probe + Vector3.yAxis * 3, -Vector3.yAxis * 12, ray)
						if hit and hit.Normal.Y > 0.65 then
							local flatForward =
								Vector3.new(entrance.CFrame.LookVector.X, 0, entrance.CFrame.LookVector.Z)
							local lookTarget = hit.Position
								+ Vector3.yAxis * 3.5
								+ (if flatForward.Magnitude > 0.1 then flatForward.Unit else Vector3.zAxis)
							return CFrame.lookAt(hit.Position + Vector3.yAxis * 3.5, lookTarget)
						end
					end
				end
			end
		end
		task.wait(0.1)
	end
	return nil
end

function SquadFall.attach(hatch: BasePart, lift: BasePart): () -> ()
	local _unusedLift = lift

	-- A shared group barrier keeps every eligible rider on the same cinematic clock.
	return function()
		if busy then
			return
		end
		local expedition = Workspace:GetAttribute("ExpeditionNumber")
		local mazeLandingCF = findMazeLandingCF()
		local baseLandingCF: CFrame
		if mazeLandingCF then
			baseLandingCF = mazeLandingCF
		else
			local layout = Layout.get()
			local landing = layout.landing
			baseLandingCF = landing.CFrame * CFrame.new(0, landing.Size.Y / 2 + 3.5, 0)
		end

		local riders: { Rider } = {}
		for _, player in Players:GetPlayers() do
			local char, root = living(player)
			if
				char
				and root
				and (not char:GetAttribute("BunkerLanded") or char:GetAttribute("BunkerExpedition") ~= expedition)
			then
				local i = #riders
				local spread = Vector3.new((i % 2 - 0.5) * 2.2, 0, math.floor(i / 2) * 2.2)
				table.insert(riders, {
					player = player,
					character = char,
					root = root,
					destination = baseLandingCF * CFrame.new(spread),
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
			if valid(r, expedition) and not r.streamed then
				duration = 0
			end
		end
		local arrival = Workspace:GetServerTimeNow() + duration
		for _, r in riders do
			if valid(r, expedition) then
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
			if valid(r, expedition) then
				r.character:PivotTo(r.destination)
				r.root.AssemblyLinearVelocity = Vector3.zero
				r.root.AssemblyAngularVelocity = Vector3.zero
				r.character:SetAttribute("BunkerExpedition", expedition)
				r.character:SetAttribute("BunkerLanded", true)
				r.player:SetAttribute("DungeonEntered", true)
				r.root.Anchored = r.anchored
				if not r.streamed and not r.anchored and r.root:CanSetNetworkOwnership() then
					r.root:SetNetworkOwner(nil)
					task.spawn(function()
						pcall(function()
							r.player:RequestStreamAroundAsync(r.destination.Position, 5)
						end)
						if valid(r, expedition) and r.root:CanSetNetworkOwnership() then
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
