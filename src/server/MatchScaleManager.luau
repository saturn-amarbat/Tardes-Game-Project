--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ExitGate = require(script.Parent.ExitGate)
local ObjectivePickups = require(script.Parent.ObjectivePickups)
local TeleportManager = require(script.Parent.TeleportManager)

local MatchScaleManager = {}
local REPLAY_DELAY = 12
local activeReviveHandler: ((Player) -> boolean)? = nil

function MatchScaleManager.revivePlayer(target: Player): boolean
	if activeReviveHandler then
		return activeReviveHandler(target)
	end
	return false
end

function MatchScaleManager.init(buildRooms: () -> { Model })
	local remotes = ReplicatedStorage:FindFirstChild("MatchRemotes") :: Folder?
	if not remotes then
		local folder = Instance.new("Folder")
		folder.Name = "MatchRemotes"
		folder.Parent = ReplicatedStorage
		remotes = folder
	end
	local state = remotes :: Folder
	local function remote(name: string): RemoteEvent
		local existing = state:FindFirstChild(name)
		if existing then
			return existing :: RemoteEvent
		end
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = state
		return event
	end
	local collect = remote("CollectObjective")
	local progress = remote("ObjectiveProgress")
	local claimRevive = remote("ClaimReviveToken")
	remote("DoorUnlocked")
	local phase = "Preparing"
	local members: { [Player]: boolean } = {}
	local rooms: { Model } = {}
	local gate: { arm: () -> (), close: () -> (), destroy: () -> () }? = nil
	local claims: RBXScriptConnection? = nil
	local round = 0
	local keys, fuses, keyTotal, fuseTotal = 0, 0, 1, 1
	local function setPhase(new: string)
		phase = new
		state:SetAttribute("RunState", new)
	end
	local function publish()
		state:SetAttribute("Keys", keys)
		state:SetAttribute("Fuses", fuses)
		state:SetAttribute("KeysTotal", keyTotal)
		state:SetAttribute("FusesTotal", fuseTotal)
		progress:FireAllClients({ keys = keys, fuses = fuses, keysTotal = keyTotal, fusesTotal = fuseTotal })
	end
	local function scale(count: number)
		keyTotal = math.clamp(count, 1, 4)
		fuseTotal = math.ceil((keyTotal + 1) / 2)
		publish()
	end
	local function survivors(): number
		local n = 0
		for _ in members do
			n += 1
		end
		return n
	end
	local function eligible(player: Player): boolean
		return phase == "Active" and members[player] == true and player:GetAttribute("DungeonEntered") == true
	end
	local function reset()
		setPhase("Preparing")
		if gate then
			gate.destroy()
			gate = nil
		end
		if claims then
			claims:Disconnect()
			claims = nil
		end
		table.clear(members)
		round += 1
		keys, fuses = 0, 0
		state:SetAttribute("Survivors", 0)
		state:SetAttribute("ExitOpen", false)
		state:SetAttribute("ObjectivesComplete", false)
		workspace:SetAttribute("ExpeditionNumber", round)
		for _, p in Players:GetPlayers() do
			p:SetAttribute("DungeonEntered", false)
			p:SetAttribute("SittingOut", false)
		end
		rooms = buildRooms()
		scale(#Players:GetPlayers())
		if round > 1 then
			-- Wait for all old characters to be replaced before admitting a new roster.
			for _, p in Players:GetPlayers() do
				if p.Parent == Players then
					local ok, err = pcall(function()
						p:LoadCharacterAsync()
					end)
					if not ok and p.Parent == Players then
						warn("[MatchScaleManager] Respawn: " .. tostring(err))
					end
				end
			end
		end
		setPhase("Forest")
	end
	local function finish(outcome: string)
		if phase ~= "Active" then
			return
		end
		setPhase(outcome)
		if gate then
			gate.close()
		end
		for _, p in Players:GetPlayers() do
			p:SetAttribute("SittingOut", true)
		end
		task.delay(REPLAY_DELAY, reset)
	end
	local function eliminate(p: Player)
		if phase ~= "Active" or not members[p] then
			return
		end
		members[p] = nil
		state:SetAttribute("Survivors", survivors())
		p:SetAttribute("SittingOut", true)
		if survivors() == 0 then
			finish("Wiped")
		end
	end

	local function findReviveDestination(): CFrame?
		for member in members do
			if member.Parent == Players and member:GetAttribute("SittingOut") ~= true then
				local char = member.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if hrp and hrp:IsA("BasePart") and hum and hum.Health > 0 then
					return hrp.CFrame * CFrame.new(0, 0, 2.5)
				end
			end
		end
		local first = rooms[1]
		local entrance = first and first:FindFirstChild("Entrance")
		if entrance and entrance:IsA("BasePart") then
			return entrance.CFrame + Vector3.yAxis * 2
		end
		return nil
	end

	local function doRevive(target: Player): boolean
		if phase ~= "Active" or target.Parent ~= Players or members[target] then
			return false
		end
		local dest = findReviveDestination()
		if not dest then
			return false
		end
		members[target] = true
		target:SetAttribute("SittingOut", false)
		target:SetAttribute("DungeonEntered", true)
		state:SetAttribute("Survivors", survivors())
		task.spawn(function()
			local ok = pcall(function()
				target:LoadCharacterAsync()
			end)
			if ok and target.Parent == Players and phase == "Active" and members[target] then
				TeleportManager.teleportPlayer(target, dest)
			end
		end)
		return true
	end
	activeReviveHandler = doRevive

	claimRevive.OnServerEvent:Connect(function(player: Player)
		if phase ~= "Active" or members[player] or player:GetAttribute("ReviveTokenClaimed") == true then
			return
		end
		local tokens = player:GetAttribute("ReviveTokens")
		if typeof(tokens) ~= "number" or tokens < 1 then
			return
		end
		if doRevive(player) then
			player:SetAttribute("ReviveTokens", tokens - 1)
			player:SetAttribute("ReviveTokenClaimed", true)
		end
	end)
	local function enter(player: Player)
		if phase ~= "Forest" or player:GetAttribute("DungeonEntered") ~= true or #rooms == 0 then
			return
		end
		-- Reserve seats for connected teammates still completing the forest.
		members[player] = true
		for _, other in Players:GetPlayers() do
			if survivors() < 4 then
				members[other] = true
			end
			other:SetAttribute("SittingOut", members[other] ~= true)
		end
		state:SetAttribute("Survivors", survivors())
		scale(survivors())
		setPhase("Active")
		gate = ExitGate.install(rooms[#rooms], state, eligible, survivors, function()
			finish("Escaped")
		end)
		claims = ObjectivePickups.spawn(rooms, keyTotal, fuseTotal, collect, eligible, function(kind)
			if kind == "Key" then
				keys += 1
			else
				fuses += 1
			end
			publish()
			if keys == keyTotal and fuses == fuseTotal and gate then
				gate.arm()
			end
		end)
	end
	local function watch(p: Player)
		p:SetAttribute("SittingOut", phase ~= "Preparing" and phase ~= "Forest" and not members[p])
		if phase == "Forest" then
			scale(#Players:GetPlayers())
		end
		p:GetAttributeChangedSignal("DungeonEntered"):Connect(function()
			enter(p)
		end)
		local function characterAdded(character: Model)
			local humanoid = character:WaitForChild("Humanoid", 10)
			if humanoid and humanoid:IsA("Humanoid") then
				humanoid.Died:Once(function()
					if p.Character == character then
						eliminate(p)
					end
				end)
			end
		end
		p.CharacterAdded:Connect(characterAdded)
		p.CharacterRemoving:Connect(function()
			eliminate(p)
		end)
		if p.Character then
			task.spawn(characterAdded, p.Character)
		end
		enter(p)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(p)
		eliminate(p)
		task.defer(function()
			if phase == "Forest" then
				scale(#Players:GetPlayers())
			end
		end)
	end)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	reset()
	for _, p in Players:GetPlayers() do
		enter(p)
	end
end

return MatchScaleManager
